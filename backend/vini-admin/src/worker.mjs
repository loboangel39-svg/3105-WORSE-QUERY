import upstream,{verifyAppAuth,verifyAuth,createJWT} from '../dist/upstream.mjs';
import panel from '../dist/panel.mjs';
import {Fault,fail,body,text,json,now,actor,login,superOnly,audit} from './auth.mjs';
import {profile,listUsers,createUser,editUser,renewUser,transferUser,listDistributors,createDistributor,createAdmin,allowedPatch} from './domain.mjs';
import {preview,execute,operationResult,members,reconfirm,cancel} from './operations.mjs';
import {migrationRoute} from './migrations.mjs';

async function appAuth(request,env){const auth=await verifyAppAuth(request,env);if(!auth.valid||auth.user.archived_at||auth.user.purged_at)fail(401,'unauthorized');return auth}
async function legacyFetch(request,env,a){
  superOnly(a);
  if((await verifyAuth(request,env)).valid)return upstream.fetch(request,env);
  // A verified named SUPER_ADMIN can use the retained global views. The
  // short-lived transport credential never leaves the server or becomes APP auth.
  const internal=await createJWT({user:env.ADMIN_USERNAME||'admin',role:'admin',exp:Date.now()+60000},env);
  const headers=new Headers(request.headers);headers.set('Authorization','Bearer '+internal);
  return upstream.fetch(new Request(request,{headers}),env);
}
function adminOrigin(request){const origin=request.headers.get('Origin');if(origin&&origin!==new URL(request.url).origin)fail(403,'cross_origin_admin_request')}
async function adminRoutes(request,env,url){
  adminOrigin(request);
  const path=url.pathname.replace(/^\/api\/admin-v2/,'');
  if(path==='/login'&&request.method==='POST')return login(request,env);
  const a=await actor(request,env),method=request.method;
  if(path==='/me'&&method==='GET')return json({id:a.id,username:a.username,role:a.role,distributorId:a.distributor_id,actions:a.actions,scopes:a.scopes});
  if(path==='/users'&&method==='GET')return listUsers(env,a,Object.fromEntries(url.searchParams));
  if(path==='/users'&&method==='POST')return createUser(env,a,await body(request));
  let match=path.match(/^\/users\/([^/]+)(?:\/(renew|transfer))?$/);
  if(match){const id=decodeURIComponent(match[1]);if(!match[2]&&method==='PATCH')return editUser(env,a,id,await body(request));if(match[2]==='renew'&&method==='POST')return renewUser(env,a,id,await body(request));if(match[2]==='transfer'&&method==='POST')return transferUser(env,a,id,await body(request))}
  if(path==='/distributors'&&method==='GET')return listDistributors(env,a);
  if(path==='/distributors'&&method==='POST')return createDistributor(env,a,await body(request));
  match=path.match(/^\/distributors\/([^/]+)$/);
  if(match&&method==='PATCH'){superOnly(a);const input=await body(request);if(!['active','suspended'].includes(input.status))fail(400,'invalid_status');const result=await env.DB.batch([env.DB.prepare('UPDATE distributors SET status=?,updated_at=? WHERE id=?').bind(input.status,now(),match[1]),audit(env,a,'distributor_status',null,null,{distributorId:match[1],status:input.status})]);if(!result[0].meta.changes)fail(404,'not_found');return json({success:true})}
  if(path==='/administrators'&&method==='POST')return createAdmin(env,a,await body(request));
  if(path==='/administrators'&&method==='GET'){superOnly(a);return json({administrators:(await env.DB.prepare('SELECT id,username,role,distributor_id,status FROM admin_accounts ORDER BY username').all()).results})}
  match=path.match(/^\/administrators\/([^/]+)\/disable$/);
  if(match&&method==='POST'){superOnly(a);if(match[1]==='legacy-super'||match[1]===a.id)fail(409,'cannot_disable_self_or_bootstrap');await env.DB.batch([env.DB.prepare("UPDATE admin_accounts SET status='disabled',session_epoch=session_epoch+1 WHERE id=?").bind(match[1]),audit(env,a,'administrator_disabled',null,null,{administratorId:match[1]})]);return json({success:true})}
  if(path==='/operations/preview'&&method==='POST')return preview(env,a,await body(request));
  match=path.match(/^\/operations\/([^/]+)(?:\/(execute|members|reconfirm|cancel))?$/);
  if(match){if(match[2]==='execute'&&method==='POST')return execute(env,a,match[1],await body(request));if(match[2]==='reconfirm'&&method==='POST')return reconfirm(env,a,match[1]);if(match[2]==='cancel'&&method==='POST')return cancel(env,a,match[1]);if(match[2]==='members'&&method==='GET')return members(env,a,match[1],url);if(!match[2]&&method==='GET')return json(await operationResult(env,a,match[1]))}
  if(path==='/operations'&&method==='GET')return json({operations:(await env.DB.prepare(`SELECT id,actor_id,action,status,reason,created_at,revert_of FROM admin_operations WHERE ${a.role==='SUPER_ADMIN'?'1':'actor_id=?'} ORDER BY created_at DESC LIMIT 100`).bind(...(a.role==='SUPER_ADMIN'?[]:[a.id])).all()).results});
  if(path==='/plans'&&method==='GET')return json({plans:(await env.DB.prepare('SELECT id,name,enabled FROM plans ORDER BY id').all()).results});
  if(path==='/retention'&&method==='GET'){superOnly(a);return json(await env.DB.prepare('SELECT * FROM admin_retention WHERE id=1').first())}
  if(path==='/retention'&&method==='PUT'){superOnly(a);const input=await body(request);if(typeof input.enabled!=='boolean'||!Number.isInteger(input.days)||input.days<90||input.days>3650)fail(400,'invalid_retention');await env.DB.batch([env.DB.prepare('UPDATE admin_retention SET enabled=?,days=?,updated_by=?,updated_at=? WHERE id=1').bind(input.enabled?1:0,input.days,a.id,now()),audit(env,a,'retention_policy',null,null,{enabled:input.enabled,days:input.days})]);return json({success:true})}
  if(path==='/audit'&&method==='GET'){
    const id=text(url.searchParams.get('userId'));const {userInScope}=await import('./auth.mjs');await userInScope(env,a,id,'read');
    return json({events:(await env.DB.prepare('SELECT id,actor_id,user_id,license_id,operation_id,action,details,created_at FROM admin_audit WHERE user_id=? ORDER BY created_at,id LIMIT 200').bind(id).all()).results});
  }
  if(path==='/patch-policies'&&method==='PUT'){
    superOnly(a);const p=await body(request);
    if(!['patch.basic','patch.pro'].includes(p.capabilityId)||typeof p.enabled!=='boolean'||typeof p.revoked!=='boolean'||typeof p.compatible!=='boolean')fail(400,'invalid_policy');
    if(p.distributorId&&!(await env.DB.prepare('SELECT id FROM distributors WHERE id=?').bind(text(p.distributorId)).first()))fail(400,'invalid_distributor');
    await env.DB.batch([env.DB.prepare('INSERT INTO patch_policies(patch_id,target_id,capability_id,distributor_id,enabled,revoked,compatible,compatibility_description) VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(patch_id) DO UPDATE SET target_id=excluded.target_id,capability_id=excluded.capability_id,distributor_id=excluded.distributor_id,enabled=excluded.enabled,revoked=excluded.revoked,compatible=excluded.compatible,compatibility_description=excluded.compatibility_description').bind(text(p.patchId),text(p.targetId),p.capabilityId,p.distributorId||null,p.enabled?1:0,p.revoked?1:0,p.compatible?1:0,text(p.compatibilityDescription,500)),audit(env,a,'patch_policy',null,null,{patchId:p.patchId,capabilityId:p.capabilityId})]);
    return json({success:true});
  }
  if(path==='/patch-policies'&&method==='GET'){superOnly(a);return json({policies:(await env.DB.prepare('SELECT * FROM patch_policies ORDER BY patch_id').all()).results})}
  fail(404,'not_found');
}
async function legacyUserMutation(request,env,url){
  const a=await actor(request,env);superOnly(a);
  if(url.pathname==='/api/users'&&request.method==='POST')return createUser(env,a,await body(request));
  const match=url.pathname.match(/^\/api\/users\/([^/]+)(?:\/(pause|renew|adjust-days|hwid|block))?$/);
  if(!match)return null;
  const id=match[1];
  if(request.method==='PUT'&&!match[2]){
    // Old UI may submit key/HWID; preserve the old handler under SUPER_ADMIN only.
    // Creator/ownership fields are never accepted by that handler and immutable in D1.
    const response=await legacyFetch(request,env,a);if(response.ok)await audit(env,a,'legacy_user_update',id).run();return response;
  }
  if(['renew','adjust-days'].includes(match[2])&&request.method==='POST'){
    const u=await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(id).first();if(!u)fail(404,'not_found');const input=await body(request),days=Number(input.days);
    if(!Number.isInteger(days)||Math.abs(days)>3650||(match[2]==='renew'&&days<0))fail(400,'invalid_days');
    if(u.is_paused&&!u.pause_remaining_known)fail(409,'unknown_remaining_time_requires_explicit_renewal');
    const base=u.is_paused?Date.now()+(u.pause_remaining_ms||0):(Date.parse(u.license_expires_at)||Date.now());
    const adjusted=(match[2]==='renew'?Math.max(Date.now(),base):base)+days*86400000;
    return renewUser(env,a,id,{licenseExpiresAt:days===0?null:new Date(adjusted).toISOString(),restoreArchived:input.restoreArchived===true});
  }
  if((match[2]==='pause'&&request.method==='POST')||(!match[2]&&request.method==='DELETE')){
    const u=await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(id).first();if(!u)fail(404,'not_found');
    const action=request.method==='DELETE'?'archive':u.is_paused?'resume_individual':'pause_individual';
    const result=await preview(env,a,{action,selection:{group:'selected',ids:[id]},reason:'manual',idempotencyKey:request.headers.get('Idempotency-Key')||crypto.randomUUID()});const operation=await result.json();return execute(env,a,operation.id,{confirmationToken:operation.confirmationToken});
  }
  if(['hwid','block'].includes(match[2])&&request.method==='POST'){
    const response=await legacyFetch(request,env,a);if(response.ok)await audit(env,a,'legacy_'+match[2],id).run();return response;
  }
  return null;
}
export default {
  async fetch(request,env){
    try{
      const url=new URL(request.url),path=url.pathname,method=request.method;
      const adminWrite=path.startsWith('/api/')&&!path.startsWith('/api/app/')&&!['GET','HEAD','OPTIONS'].includes(method)&&!['/api/admin/login','/api/admin-v2/login'].includes(path);
      if(env.ADMIN_READ_ONLY==='1'&&adminWrite)fail(503,'administration_read_only');
      if(path==='/api/admin-v2/migrations/preview'&&method==='GET'){adminOrigin(request);return await migrationRoute(request,env,false)}
      if(path==='/api/admin-v2/migrations/apply'&&method==='POST'){adminOrigin(request);return await migrationRoute(request,env,true)}
      // Explicit rollout gate: shipping the experimental artifact never enables
      // its UI, APP responses or new rights before an operator opts in.
      if(env.ADMIN_PLANS_ENABLED!=='1'){
        if(adminWrite||path.startsWith('/api/app/patches')){
          const prepared=await env.DB.prepare("SELECT name FROM sqlite_schema WHERE name='vini_admin_migrations' AND type='table'").first();
          if(prepared)fail(503,'prepared_integration_requires_enable_or_readonly_wrapper');
        }
        return await upstream.fetch(request,env);
      }
      if(['/admin','/admin/','/admin.html'].includes(path)&&method==='GET')return new Response(panel,{headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}});
      if(path.startsWith('/api/admin-v2/'))return await adminRoutes(request,env,url);
      if(path==='/api/app/me'&&method==='GET'){const auth=await appAuth(request,env);return json(profile(auth.user))}
      if(path==='/api/app/validate-license'&&method==='POST'){
        const response=await upstream.fetch(request,env);if(!response.ok)return response;
        const data=await response.json();const auth=await verifyAppAuth(new Request(request.url,{headers:{Authorization:'Bearer '+data.token}}),env);
        return json(auth.valid?{...data,...profile(auth.user)}:data,response.status);
      }
      const patch=path.match(/^\/api\/app\/patches\/([^/]+)(?:\/download)?$/);
      if(patch&&method==='GET'){const auth=await appAuth(request,env);if(!await allowedPatch(env,auth.user,decodeURIComponent(patch[1])))fail(403,'patch_not_authorized')}
      if(path==='/api/app/patches'&&method==='GET'){
        const auth=await appAuth(request,env),response=await upstream.fetch(request,env);if(!response.ok)return response;
        const data=await response.json(),patches=[];for(const patch of data.patches)if(await allowedPatch(env,auth.user,patch.id))patches.push(patch);return json({...data,patches},response.status);
      }
      if(path.startsWith('/api/users')&&!['GET','OPTIONS'].includes(method)){const handled=await legacyUserMutation(request,env,url);if(handled)return handled}
      // Named RBAC tokens are never passed into original global admin APIs.
      // The original verifier also rejects APP tokens; new admins use scoped APIs.
      if(path.startsWith('/api/')&&!path.startsWith('/api/app/')&&path!=='/api/admin/login'&&method!=='OPTIONS'){
        const a=await actor(request,env);superOnly(a);return await legacyFetch(request,env,a);
      }
      return await upstream.fetch(request,env);
    }catch(error){
      if(error instanceof Fault)return json({error:error.code},error.status);
      console.error(JSON.stringify({event:'admin_extension_failure',type:error?.constructor?.name||'Error'}));
      return json({error:'service_unavailable'},503);
    }
  }
};
