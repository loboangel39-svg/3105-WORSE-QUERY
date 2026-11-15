import {body,fail,text,now,json,permit,scope,userInScope,audit,superOnly,passwordHash,b64,ACTIONS} from './auth.mjs';
export function licenseStatus(u){
  if(u.purged_at)return 'purged';if(u.archived_at)return 'archived';if(u.revoked_at)return 'revoked';
  if(u.is_blocked)return 'blocked';if(!u.is_active)return 'inactive';if(u.is_paused)return 'paused';
  if(u.license_expires_at){const expiry=Date.parse(u.license_expires_at);if(!Number.isFinite(expiry))return 'unverified';if(expiry<=Date.now())return 'expired'}
  return 'active';
}
export function profile(u){return {username:u.username,plan:u.plan_id,licenseStatus:licenseStatus(u),licenseExpiresAt:u.license_expires_at||null,serverTime:now()}}
export function expiry(value){if(value===null)return null;if(typeof value!=='string'||!Number.isFinite(Date.parse(value)))fail(400,'invalid_expiry');return new Date(value).toISOString()}
// The retained legacy panel interpolates names into HTML/inline handlers.
// New scoped administrators cannot introduce markup into those retained views.
function userName(value){const name=text(value,120);if(!/^[\p{L}\p{N}_. -]+$/u.test(name))fail(400,'invalid_username');return name}
export function statusSQL(u='u'){return `CASE WHEN ${u}.purged_at IS NOT NULL THEN 'purged' WHEN ${u}.archived_at IS NOT NULL THEN 'archived' WHEN ${u}.revoked_at IS NOT NULL THEN 'revoked' WHEN COALESCE(${u}.is_blocked,0)<>0 THEN 'blocked' WHEN COALESCE(${u}.is_active,0)=0 THEN 'inactive' WHEN COALESCE(${u}.is_paused,0)<>0 THEN 'paused' WHEN ${u}.license_expires_at IS NOT NULL AND julianday(${u}.license_expires_at) IS NULL THEN 'unverified' WHEN julianday(${u}.license_expires_at)<=julianday('now') THEN 'expired' ELSE 'active' END`}
export function selection(a,params,action='read'){
  permit(a,action);let guard=scope(a,action),sql=guard.sql,args=[...guard.args];
  const add=(condition,...values)=>{sql+=' AND '+condition;args.push(...values)};
  const group=params.group||'all';
  if(group==='all'){if(action!=='read')superOnly(a)}
  else if(group==='direct')add("u.distributor_id IS NULL AND u.origin_status='known'");
  else if(group==='unknown'){superOnly(a);add("u.origin_status='unknown'")}
  else if(group==='distributor')add('u.distributor_id=?',text(params.distributorId));
  else if(group==='selected'){
    if(!Array.isArray(params.ids)||params.ids.length<1||params.ids.length>50)fail(400,'invalid_selection_max_50');
    const ids=[...new Set(params.ids.map(id=>text(id)))];add('u.id IN ('+ids.map(()=>'?').join(',')+')',...ids);
  }else fail(400,'invalid_group');
  if(params.distributorId&&group!=='distributor')add('u.distributor_id=?',text(params.distributorId));
  if(params.plan){if(!['basic','pro'].includes(params.plan))fail(400,'invalid_plan');add('u.plan_id=?',params.plan)}
  if(params.creator)add('u.created_by_admin_id=?',text(params.creator));
  if(params.search)add("(u.username LIKE ? ESCAPE '\\' OR u.id=?)",'%'+text(params.search).replace(/[\\%_]/g,'\\$&')+'%',params.search);
  for(const [key,column,op] of [['expiresBefore','license_expires_at','<='],['expiresAfter','license_expires_at','>='],['createdAfter','created_at','>='],['createdBefore','created_at','<=']])if(params[key])add(`julianday(u.${column})${op}julianday(?)`,expiry(params[key]));
  if(params.status){
    if(!['expired','paused','blocked','archived','revoked','active','inactive','unverified'].includes(params.status))fail(400,'invalid_status');add('('+statusSQL()+')=?',params.status);
  }
  add('u.purged_at IS NULL');return {sql,args};
}
export async function listUsers(env,a,params){
  const q=selection(a,params);const offset=Number(params.offset||0),limit=Number(params.limit||100);
  if(!Number.isSafeInteger(offset)||offset<0||!Number.isSafeInteger(limit)||limit<1||limit>200)fail(400,'invalid_page');
  const projection="u.id,u.username,u.plan_id,u.is_premium,u.is_active,u.is_paused,u.is_blocked,u.license_expires_at,u.pause_remaining_ms,u.pause_remaining_known,u.created_by_admin_id,u.distributor_id,u.origin_status,u.created_at,u.archived_at,u.revoked_at,u.purged_at,u.admin_revision,CASE WHEN u.hwid IS NULL OR u.hwid='' THEN NULL WHEN length(u.hwid)<8 THEN '••••' ELSE substr(u.hwid,1,3)||'…'||substr(u.hwid,-3) END AS hwidMasked";
  const rows=await env.DB.prepare(`SELECT ${projection} FROM users u WHERE ${q.sql} ORDER BY u.created_at,u.id LIMIT ? OFFSET ?`).bind(...q.args,limit,offset).all();
  const total=await env.DB.prepare(`SELECT COUNT(*) AS count FROM users u WHERE ${q.sql}`).bind(...q.args).first();
  return json({users:rows.results.map(u=>({...u,licenseStatus:licenseStatus(u)})),total:total.count,offset,limit});
}
export async function createUser(env,a,input){
  permit(a,'create');if(input.created_by_admin_id!==undefined)fail(400,'creator_is_server_owned');
  const username=userName(input.username),plan=input.plan|| (input.isPremium?'pro':'basic');
  if(!['basic','pro'].includes(plan))fail(400,'invalid_plan');
  let distributor=input.distributorId??null;
  if(a.role==='DISTRIBUTOR'){if(distributor&&distributor!==a.distributor_id)fail(403,'scope_forbidden');distributor=a.distributor_id}
  if(a.role==='ADMIN'&&!a.scopes.includes(distributor?'distributor:'+distributor:'direct'))fail(403,'scope_forbidden');
  if(distributor&&!(await env.DB.prepare("SELECT id FROM distributors WHERE id=? AND status='active'").bind(distributor).first()))fail(400,'invalid_distributor');
  const id=crypto.randomUUID(),issued=now(),key=input.licenseKey?text(input.licenseKey,200):'VINI-'+b64(crypto.getRandomValues(new Uint8Array(24)));
  const exp=input.licenseExpiresAt===undefined?null:expiry(input.licenseExpiresAt);
  const guard=scope(a,'create','proposed');
  const result=await env.DB.batch([
    env.DB.prepare(`INSERT INTO users(id,username,hwid,license_key,is_premium,is_active,is_paused,is_blocked,permissions,created_at,updated_at,license_expires_at,plan_id,created_by_admin_id,distributor_id,origin_status) SELECT ?,?,?, ?,?,1,0,0,'{}',?,?,?,?,?,?,'known' FROM (SELECT ? AS distributor_id,'known' AS origin_status) proposed WHERE ${guard.sql} AND (proposed.distributor_id IS NULL OR EXISTS(SELECT 1 FROM distributors d WHERE d.id=proposed.distributor_id AND d.status='active')) AND EXISTS(SELECT 1 FROM plans p WHERE p.id=? AND p.enabled=1) RETURNING id`).bind(id,username,'',key,plan==='pro'?1:0,issued,issued,exp,plan,a.id,distributor,distributor,...guard.args,plan),
    env.DB.prepare('INSERT INTO license_metadata(id,user_id,created_by_admin_id,distributor_id,issued_at,plan_id) SELECT ?,u.id,?,?,?,? FROM users u WHERE u.id=?').bind('license:'+id,a.id,distributor,issued,plan,id),
    audit(env,a,'license_issue_requested',id,null,{plan,distributorId:distributor},true)
  ]);
  if(result[0].results.length!==1)fail(403,'creation_scope_or_plan_changed');
  return json({id,username,licenseKey:key,plan,isPremium:plan==='pro'},201);
}
export async function editUser(env,a,id,input){
  const u=await userInScope(env,a,id,'create');if(u.purged_at)fail(409,'purged');
  for(const key of ['created_by_admin_id','distributor_id','distributorId','licenseKey','license_key','is_paused','is_active','is_blocked'])if(key in input)fail(400,'use_dedicated_operation');
  const plan=input.plan??(input.isPremium===undefined?u.plan_id:(input.isPremium?'pro':'basic'));
  if(!['basic','pro'].includes(plan))fail(400,'invalid_plan');
  const guard=scope(a,'create');
  const result=await env.DB.batch([
    env.DB.prepare(`UPDATE users AS u SET username=?,plan_id=?,updated_at=? WHERE u.id=? AND u.admin_revision=? AND ${guard.sql} RETURNING id`).bind(input.username===undefined?u.username:userName(input.username),plan,now(),id,u.admin_revision,...guard.args),
    audit(env,a,'user_edit_requested',id,null,{plan},true)
  ]);if(result[0].results.length!==1)fail(409,'state_changed');return json({success:true});
}
export async function renewUser(env,a,id,input){
  const u=await userInScope(env,a,id,'renew');if(u.purged_at||u.revoked_at)fail(409,'account_revoked_or_purged');
  const exp=expiry(input.licenseExpiresAt);const guard=scope(a,'renew');
  if(u.archived_at){if(input.restoreArchived!==true)fail(409,'explicit_archive_restore_required');permit(a,'reactivate');if(exp!==null&&Date.parse(exp)<=Date.now())fail(400,'restore_requires_current_license')}
  const result=await env.DB.batch([
    env.DB.prepare(`UPDATE users AS u SET license_expires_at=?,updated_at=?,pause_remaining_ms=CASE WHEN is_paused=1 THEN ? ELSE pause_remaining_ms END,pause_remaining_known=CASE WHEN is_paused=1 THEN 1 ELSE pause_remaining_known END,archived_at=CASE WHEN ?=1 THEN NULL ELSE archived_at END,is_active=CASE WHEN ?=1 THEN COALESCE(archive_previous_active,0) ELSE is_active END WHERE u.id=? AND u.admin_revision=? AND ${guard.sql} RETURNING id`).bind(exp,now(),exp===null?null:Math.max(0,Date.parse(exp)-Date.now()),u.archived_at?1:0,u.archived_at?1:0,id,u.admin_revision,...guard.args),
    audit(env,a,'license_renewal_requested',id,null,{previousExpiresAt:u.license_expires_at,expiresAt:exp,restoreArchived:!!u.archived_at},true)
  ]);if(result[0].results.length!==1)fail(409,'state_changed');return json({success:true,licenseExpiresAt:exp});
}
export async function transferUser(env,a,id,input){
  superOnly(a);const u=await userInScope(env,a,id,'transfer');if(u.purged_at)fail(409,'purged');
  const distributor=input.distributorId??null;
  if(distributor&&!(await env.DB.prepare("SELECT id FROM distributors WHERE id=? AND status='active'").bind(distributor).first()))fail(400,'invalid_distributor');
  const result=await env.DB.batch([
    env.DB.prepare("UPDATE users SET distributor_id=?,origin_status='known',updated_at=? WHERE id=? AND admin_revision=? RETURNING id").bind(distributor,now(),id,u.admin_revision),
    audit(env,a,'distributor_transfer_requested',id,null,{from:u.distributor_id,to:distributor,previousOrigin:u.origin_status},true)
  ]);if(result[0].results.length!==1)fail(409,'state_changed');return json({success:true});
}
export async function listDistributors(env,a){
  permit(a,'read');const guard=scope(a,'read');
  const filter=a.role==='SUPER_ADMIN'?'1':a.role==='DISTRIBUTOR'?'d.id=?':"EXISTS(SELECT 1 FROM admin_scopes s WHERE s.admin_id=? AND s.scope_key='distributor:'||d.id)";
  const binds=a.role==='SUPER_ADMIN'?[]:[a.role==='DISTRIBUTOR'?a.distributor_id:a.id];
  const counters=['active','paused','expired','blocked','archived','revoked','inactive','unverified'].map(state=>`SUM(CASE WHEN u.id IS NOT NULL AND (${statusSQL()})='${state}' THEN 1 ELSE 0 END) AS ${state}`).join(',');
  const result=await env.DB.prepare(`SELECT d.id,d.name,d.status,COUNT(u.id) AS total,${counters} FROM distributors d LEFT JOIN users u ON u.distributor_id=d.id AND u.purged_at IS NULL AND ${guard.sql} WHERE ${filter} GROUP BY d.id ORDER BY d.name,d.id`).bind(...guard.args,...binds).all();
  return json({distributors:result.results});
}
export async function createDistributor(env,a,input){superOnly(a);const id=crypto.randomUUID(),stamp=now();await env.DB.batch([env.DB.prepare("INSERT INTO distributors VALUES(?,?,'active',?,?,?)").bind(id,text(input.name),stamp,a.id,stamp),audit(env,a,'distributor_created',null,null,{distributorId:id})]);return json({id},201)}
export async function createAdmin(env,a,input){
  superOnly(a);const role=input.role;if(!['SUPER_ADMIN','ADMIN','DISTRIBUTOR'].includes(role))fail(400,'invalid_role');
  const username=text(input.username),password=text(input.password,128);if(password.length<14)fail(400,'weak_password');
  const distributor=input.distributorId??null;if(role==='DISTRIBUTOR'&&!distributor)fail(400,'distributor_required');
  if(distributor&&!(await env.DB.prepare("SELECT id FROM distributors WHERE id=? AND status='active'").bind(distributor).first()))fail(400,'invalid_distributor');
  const actions=input.actions||[],scopes=input.scopes||[];
  if(!Array.isArray(actions)||actions.some(v=>!ACTIONS.includes(v))||!Array.isArray(scopes)||scopes.some(v=>v!=='direct'&&!/^distributor:[0-9a-f-]{36}$/.test(v)))fail(400,'invalid_permissions');
  const id=crypto.randomUUID(),salt=b64(crypto.getRandomValues(new Uint8Array(16))),hash=await passwordHash(password,salt);
  const statements=[env.DB.prepare('INSERT INTO admin_accounts(id,username,role,distributor_id,password_salt,password_hash,password_iterations,created_at) VALUES(?,?,?,?,?,?,100000,?)').bind(id,username,role,distributor,salt,hash,now()),audit(env,a,'administrator_created',null,null,{administratorId:id,role})];
  for(const action of new Set(actions))statements.push(env.DB.prepare('INSERT INTO admin_actions VALUES(?,?)').bind(id,action));
  if(role==='ADMIN')for(const s of new Set(scopes))statements.push(env.DB.prepare('INSERT INTO admin_scopes VALUES(?,?)').bind(id,s));
  await env.DB.batch(statements);return json({id,username,role},201);
}
export async function allowedPatch(env,u,patchId){
  const p=await env.DB.prepare('SELECT * FROM patch_policies WHERE patch_id=?').bind(patchId).first();
  // Explicit legacy grandfathering: no policy enrollment means no new entitlement restriction.
  if(!p)return !u.archived_at&&!u.purged_at;
  if(licenseStatus(u)!=='active'||!p.enabled||p.revoked||!p.compatible)return false;
  if(p.distributor_id&&p.distributor_id!==u.distributor_id)return false;
  return !!await env.DB.prepare('SELECT 1 FROM plans p JOIN plan_capabilities pc ON pc.plan_id=p.id JOIN user_patches up ON up.user_id=? AND up.patch_id=? JOIN patches x ON x.id=up.patch_id WHERE p.id=? AND p.enabled=1 AND pc.capability_id=? AND x.active=1').bind(u.id,patchId,u.plan_id,p.capability_id).first();
}
