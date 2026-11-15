import { verifyAuth } from '../dist/upstream.mjs';
export class Fault extends Error { constructor(status,code){super(code);this.status=status;this.code=code;} }
export const requestActors=new WeakMap();
export const fail=(status,code)=>{throw new Fault(status,code)};
export const now=()=>new Date().toISOString();
export const json=(value,status=200)=>Response.json(value,{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}});
export async function body(request){
  if(!request.headers.get('Content-Type')?.startsWith('application/json'))fail(415,'json_required');
  if(Number(request.headers.get('Content-Length')||0)>32768)fail(413,'body_too_large');
  const reader=request.body?.getReader();let bytes=0,chunks=[];
  if(!reader)fail(400,'invalid_json');
  while(true){const {value,done}=await reader.read();if(done)break;bytes+=value.length;if(bytes>32768){await reader.cancel();fail(413,'body_too_large')}chunks.push(value)}
  const joined=new Uint8Array(bytes);let offset=0;for(const chunk of chunks){joined.set(chunk,offset);offset+=chunk.length}
  try {const result=JSON.parse(new TextDecoder().decode(joined));if(!result||Array.isArray(result)||typeof result!=='object')fail(400,'invalid_json');return result}catch{fail(400,'invalid_json')}
}
export function text(value,max=128){if(typeof value!=='string'||!value.trim()||value.length>max||/[\x00-\x1f]/.test(value))fail(400,'invalid_text');return value.trim()}
export const b64=bytes=>btoa(String.fromCharCode(...new Uint8Array(bytes))).replaceAll('+','-').replaceAll('/','_').replaceAll('=','');
const unb64=s=>Uint8Array.from(atob(s.replaceAll('-','+').replaceAll('_','/')),c=>c.charCodeAt(0));
export async function digest(value){return [...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value)))].map(v=>v.toString(16).padStart(2,'0')).join('')}
async function signingKey(env){const secret=env.AUTH_JWT_SECRET??env.JWT_SECRET;if(typeof secret!=='string'||secret.length<32)fail(503,'auth_unavailable');return crypto.subtle.importKey('raw',new TextEncoder().encode('vini-admin-rbac-v1\0'+secret),{name:'HMAC',hash:'SHA-256'},false,['sign','verify'])}
export async function passwordHash(password,salt,iterations=100000){
  const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(password),'PBKDF2',false,['deriveBits']);
  return b64(await crypto.subtle.deriveBits({name:'PBKDF2',hash:'SHA-256',salt:unb64(salt),iterations},key,256));
}
function same(a,b){if(typeof a!=='string'||typeof b!=='string'||a.length!==b.length)return false;let diff=0;for(let i=0;i<a.length;i++)diff|=a.charCodeAt(i)^b.charCodeAt(i);return diff===0}
export async function login(request,env){
  const input=await body(request),username=text(input.username),password=text(input.password,128);
  const subject=await digest(username+'|'+(request.headers.get('CF-Connecting-IP')||'local'));
  const window=Math.floor(Date.now()/900000);
  const limit=await env.DB.prepare('INSERT INTO admin_login_attempts(subject,window,count) VALUES(?,?,1) ON CONFLICT(subject,window) DO UPDATE SET count=count+1 RETURNING count').bind(subject,window).first();
  if(limit.count>10)fail(429,'rate_limited');
  const account=await env.DB.prepare('SELECT * FROM admin_accounts WHERE username=? AND password_hash IS NOT NULL').bind(username).first();
  const salt=account?.password_salt||b64(new Uint8Array(16));
  const hash=await passwordHash(password,salt,account?.password_iterations||100000);
  if(!account||account.status!=='active'||!same(hash,account.password_hash))fail(401,'invalid_credentials');
  if(account.role==='DISTRIBUTOR'&&!(await env.DB.prepare("SELECT id FROM distributors WHERE id=? AND status='active'").bind(account.distributor_id).first()))fail(403,'distributor_suspended');
  const header=b64(new TextEncoder().encode(JSON.stringify({alg:'HS256',typ:'JWT',kid:'rbac-v1'})));
  const payload=b64(new TextEncoder().encode(JSON.stringify({kind:'admin-v2',sub:account.id,epoch:account.session_epoch,exp:Math.floor(Date.now()/1000)+3600})));
  const data=header+'.'+payload;
  const signature=b64(await crypto.subtle.sign('HMAC',await signingKey(env),new TextEncoder().encode(data)));
  return json({token:data+'.'+signature,expiresAt:new Date(Date.now()+3600000).toISOString()});
}
export const ACTIONS=['read','create','renew','pause','reactivate','revoke','archive','transfer','purge','policy','hwid_reset'];
export async function actor(request,env){
  let id=null;
  const legacy=await verifyAuth(request,env);
  if(legacy.valid)id='legacy-super';
  else {
    try{
      const parts=(request.headers.get('Authorization')||'').replace(/^Bearer /,'').split('.');
      if(parts.length!==3)fail(401,'admin_required');
      const h=JSON.parse(new TextDecoder().decode(unb64(parts[0]))),p=JSON.parse(new TextDecoder().decode(unb64(parts[1])));
      if(h.alg!=='HS256'||h.kid!=='rbac-v1'||p.kind!=='admin-v2'||p.exp<=Date.now()/1000)fail(401,'admin_required');
      if(!await crypto.subtle.verify('HMAC',await signingKey(env),unb64(parts[2]),new TextEncoder().encode(parts[0]+'.'+parts[1])))fail(401,'admin_required');
      const valid=await env.DB.prepare("SELECT id FROM admin_accounts WHERE id=? AND session_epoch=? AND status='active'").bind(p.sub,p.epoch).first();
      if(!valid)fail(401,'admin_required');id=valid.id;
    }catch(error){if(error.status===503)throw error;fail(401,'admin_required')}
  }
  const a=await env.DB.prepare("SELECT * FROM admin_accounts WHERE id=? AND status='active'").bind(id).first();
  if(!a)fail(403,'admin_disabled');
  if(a.role==='DISTRIBUTOR'&&!(await env.DB.prepare("SELECT id FROM distributors WHERE id=? AND status='active'").bind(a.distributor_id).first()))fail(403,'distributor_suspended');
  a.actions=(await env.DB.prepare('SELECT action FROM admin_actions WHERE admin_id=?').bind(id).all()).results.map(r=>r.action);
  a.scopes=(await env.DB.prepare('SELECT scope_key FROM admin_scopes WHERE admin_id=?').bind(id).all()).results.map(r=>r.scope_key);
  requestActors.set(request,a.id);return a;
}
export function permit(a,action){if(a.role!=='SUPER_ADMIN'&&!a.actions.includes(action))fail(403,'action_forbidden')}
export function superOnly(a){if(a.role!=='SUPER_ADMIN')fail(403,'super_admin_required')}
// Re-evaluate account status, actions, scopes and distributor status in each SQL
// mutation. Revocation between preview and execution cannot rely on a UI filter.
export function scope(a,action='read',alias='u'){
  return {sql:`EXISTS (SELECT 1 FROM admin_accounts a WHERE a.id=? AND a.status='active' AND (a.role='SUPER_ADMIN' OR (EXISTS(SELECT 1 FROM admin_actions x WHERE x.admin_id=a.id AND x.action=?) AND ((a.role='DISTRIBUTOR' AND a.distributor_id=${alias}.distributor_id AND EXISTS(SELECT 1 FROM distributors d WHERE d.id=a.distributor_id AND d.status='active')) OR (a.role='ADMIN' AND EXISTS(SELECT 1 FROM admin_scopes s WHERE s.admin_id=a.id AND (s.scope_key='distributor:'||${alias}.distributor_id OR (s.scope_key='direct' AND ${alias}.distributor_id IS NULL AND ${alias}.origin_status='known'))))))))`,args:[a.id,action]};
}
export async function userInScope(env,a,id,action='read'){
  permit(a,action);const guard=scope(a,action);
  const u=await env.DB.prepare(`SELECT u.* FROM users u WHERE u.id=? AND ${guard.sql}`).bind(id,...guard.args).first();
  if(!u)fail(404,'user_not_found');return u;
}
export function audit(env,a,action,userId=null,operation=null,details={},lastChange=false){
  // Callers pass only state codes, opaque IDs and counts. Never request bodies.
  const detailSQL=lastChange?"json_set(?, '$.applied', json(CASE WHEN changes()>0 THEN 'true' ELSE 'false' END))":'?';
  return env.DB.prepare(`INSERT INTO admin_audit(id,actor_id,user_id,license_id,operation_id,action,details,created_at) VALUES(?,?,?,?,?,?,${detailSQL},?)`).bind(crypto.randomUUID(),a.id,userId,userId?'license:'+userId:null,operation,action,JSON.stringify(details),now());
}
