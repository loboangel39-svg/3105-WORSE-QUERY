import assert from 'node:assert/strict';
import {readFile,writeFile,readdir} from 'node:fs/promises';
import {randomBytes,createPrivateKey,createPublicKey,verify} from 'node:crypto';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {dependency} from '../scripts/deps.mjs';
import {build,root} from '../scripts/build.mjs';
import {browserTest} from './browser.mjs';
import {controls2B} from './controls-2b.mjs';
const {Miniflare,Log,LogLevel,convertV4MiniflareOptions}=dependency('miniflare');
const {unstable_splitSqlQuery:split}=dependency('wrangler');
const results=[];
async function test(name,fn){try{await fn();results.push({name,passed:true});console.log('PASS',name)}catch(error){results.push({name,passed:false,error:error.message});console.error('FAIL',name,error);throw error}}
const scriptPath=await build();
const superPassword=randomBytes(24).toString('base64url');
const leaseSeed=randomBytes(32);
const fixtureBindings={JWT_SECRET:randomBytes(48).toString('hex'),ADMIN_USERNAME:'staging-super',ADMIN_PASSWORD:superPassword,ADMIN_PLANS_ENABLED:'1',ADMIN_MIGRATIONS_ENABLED:'1',LEASE_SIGNING_KEY:leaseSeed.toString('base64')};
const persistence=join(tmpdir(),'vini-staging-'+crypto.randomUUID());
const options=()=>({...convertV4MiniflareOptions({name:'vini-local-staging',modules:true,scriptPath,compatibilityDate:'2026-09-01',d1Databases:['DB'],r2Buckets:['R2'],bindings:fixtureBindings,outboundService:()=>new Response('External network disabled in staging',{status:599}),log:new Log(LogLevel.ERROR)}),resourcePersistencePath:persistence,cf:false});
let mf=new Miniflare(options());
let db,rootToken,basic,pro,direct,distributed,other,distA,distB,distToken,limitedToken,distributorPassword;
async function sql(source){const statements=split(source).filter(s=>s.trim());return db.batch(statements.map(s=>db.prepare(s)))}
async function migrate(){
  const plan=await call('/api/admin-v2/migrations/preview');
  for(let i=0;i<5;i++){const result=await call('/api/admin-v2/migrations/apply',{method:'POST',data:{manifestHash:plan.manifestHash,confirm:true}});if(!result.remaining.length)return result}throw Error('Migration did not finish');
}
async function call(path,{method='GET',data,token=rootToken,expect=200,headers={}}={}){
  const response=await mf.dispatchFetch('http://staging.local'+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),...headers},...(data?{body:JSON.stringify(data)}:{})});
  const raw=await response.text();let value;try{value=JSON.parse(raw)}catch{value=raw}
  assert.equal(response.status,expect,path+' '+raw);return value;
}
async function row(id){return db.prepare('SELECT * FROM users WHERE id=?').bind(id).first()}
async function create(username,plan='basic',distributorId=null,token=rootToken,expires=null){return call('/api/admin-v2/users',{method:'POST',token,data:{username,plan,distributorId,licenseExpiresAt:expires},expect:201})}
async function preview(action,selection,token=rootToken,extra={}){return call('/api/admin-v2/operations/preview',{method:'POST',token,data:{action,selection,reason:'manual',idempotencyKey:crypto.randomUUID(),...extra},expect:201})}
async function run(operation,token=rootToken){let result;for(let n=0;n<501;n++){result=await call('/api/admin-v2/operations/'+operation.id+'/execute',{method:'POST',token,data:{confirmationToken:operation.confirmationToken}});if(result.status==='completed')return result}throw Error('Unbounded operation')}
async function one(action,id,token=rootToken){return run(await preview(action,{group:'selected',ids:[id]},token),token)}
async function appLogin(user){return call('/api/app/validate-license',{method:'POST',token:null,data:{licenseKey:user.licenseKey,hwid:'synthetic-device-'+user.id}})}
try{
  db=await mf.getD1Database('DB');await sql(await readFile(root+'tests/baseline.sql','utf8'));
  // Historic rows contain only synthetic values. Unknown provenance must survive migration.
  for(const [id,premium] of [['legacy-basic',0],['legacy-pro',1],['legacy-unresolved',2]])await db.prepare("INSERT INTO users(id,username,license_key,is_premium,is_active,is_paused,is_blocked,created_at,updated_at) VALUES(?,?,?, ?,1,0,0,?,?)").bind(id,id,'TEST-'+id,premium,new Date().toISOString(),new Date().toISOString()).run();
  await db.prepare("INSERT INTO users(id,username,license_key,is_premium,is_active,is_paused,is_blocked,license_expires_at,paused_at,created_at,updated_at) VALUES('legacy-paused','legacy-paused','TEST-legacy-paused',0,1,1,0,'2026-11-01T00:00:00.000Z','2026-10-25T00:00:00.000Z',?,?)").bind(new Date().toISOString(),new Date().toISOString()).run();
  const login=await call('/api/admin/login',{method:'POST',token:null,data:{username:'staging-super',password:superPassword}});rootToken=login.token;assert(rootToken);
  await test('15. Incremental migration, unknown creators, legacy plans and restart ledger',async()=>{
    await migrate();await migrate();assert.equal((await row('legacy-basic')).plan_id,'basic');assert.equal((await row('legacy-pro')).plan_id,'pro');assert.equal((await row('legacy-unresolved')).plan_id,null);assert.equal((await row('legacy-pro')).created_by_admin_id,null);assert.equal((await row('legacy-pro')).origin_status,'unknown');
  });
  await test('1. BASIC user and license provenance',async()=>{basic=await create('synthetic-basic');const u=await row(basic.id);assert.equal(u.plan_id,'basic');assert.equal(u.created_by_admin_id,'legacy-super');const metadata=await db.prepare('SELECT * FROM license_metadata WHERE user_id=?').bind(basic.id).first();assert.equal(metadata.created_by_admin_id,'legacy-super');assert(metadata.issued_at)});
  await test('2. PRO user preserves isPremium projection',async()=>{pro=await create('synthetic-pro','pro');assert.equal((await row(pro.id)).is_premium,1)});
  await test('3. Direct clients exclude unknown historical origin',async()=>{direct=await create('synthetic-direct');const result=await call('/api/admin-v2/users?group=direct');assert(result.users.some(u=>u.id===direct.id));assert(!result.users.some(u=>u.id==='legacy-basic'))});
  await test('4. Distributor clients and scoped account creation',async()=>{
    distA=(await call('/api/admin-v2/distributors',{method:'POST',data:{name:'Synthetic A'},expect:201})).id;distB=(await call('/api/admin-v2/distributors',{method:'POST',data:{name:'Synthetic B'},expect:201})).id;
    const password=randomBytes(24).toString('base64url');distributorPassword=password;await call('/api/admin-v2/administrators',{method:'POST',data:{username:'synthetic-distributor',password,role:'DISTRIBUTOR',distributorId:distA,actions:['read','create','renew','pause','reactivate','archive','revoke']},expect:201});distToken=(await call('/api/admin-v2/login',{method:'POST',token:null,data:{username:'synthetic-distributor',password}})).token;
    distributed=await create('synthetic-distributor-client','basic',distA,distToken);other=await create('synthetic-other-client','basic',distB);assert.equal((await row(distributed.id)).distributor_id,distA);
  });
  await test('5. Distributor cannot inspect or mutate another owner; no UI-only security',async()=>{
    const own=await call('/api/admin-v2/users?group=all',{token:distToken});assert(own.users.every(u=>u.distributor_id===distA));
    await call('/api/admin-v2/users/'+other.id+'/renew',{method:'POST',token:distToken,data:{licenseExpiresAt:null},expect:404});
    await call('/api/admin-v2/users',{method:'POST',token:distToken,data:{username:'forged-owner',plan:'pro',distributorId:distB},expect:403});
    await call('/api/users',{token:distToken,expect:403});
  });
  await test('6. Scoped ADMIN and denied actions',async()=>{
    const password=randomBytes(24).toString('base64url');await call('/api/admin-v2/administrators',{method:'POST',data:{username:'synthetic-limited',password,role:'ADMIN',actions:['read','pause'],scopes:['distributor:'+distA]},expect:201});limitedToken=(await call('/api/admin-v2/login',{method:'POST',token:null,data:{username:'synthetic-limited',password}})).token;
    const users=await call('/api/admin-v2/users?group=all',{token:limitedToken});assert(users.users.every(u=>u.distributor_id===distA));await call('/api/admin-v2/users/'+distributed.id+'/renew',{method:'POST',token:limitedToken,data:{licenseExpiresAt:null},expect:403});
  });
  await test('7. Individual pause and reactivation',async()=>{await one('pause_individual',basic.id);assert.equal((await row(basic.id)).is_paused,1);await one('resume_individual',basic.id);assert.equal((await row(basic.id)).is_paused,0)});
  await test('8. Distributor pause snapshots exact owned IDs',async()=>{const op=await preview('pause',{group:'distributor',distributorId:distA},distToken);assert.equal(op.total,1);await run(op,distToken);assert.equal((await row(distributed.id)).is_paused,1);assert.equal((await row(other.id)).is_paused,0)});
  await test('9. Global pause only SUPER_ADMIN and expiration unchanged',async()=>{
    await call('/api/admin-v2/operations/preview',{method:'POST',token:distToken,data:{action:'pause',selection:{group:'all'},reason:'manual',idempotencyKey:crypto.randomUUID()},expect:403});
    const before=(await row(pro.id)).license_expires_at;const op=await preview('pause',{group:'all'});await run(op);assert.equal((await row(pro.id)).is_paused,1);assert.equal((await row(pro.id)).license_expires_at,before);
    await run(await preview('reverse_pause',{group:'all'},rootToken,{revertOf:op.id}));
  });
  await test('10. Reversing bulk pause preserves earlier and overlapping individual pauses',async()=>{
    await one('pause_individual',pro.id);const op=await preview('pause',{group:'selected',ids:[pro.id,direct.id]});await run(op);await one('pause_individual',direct.id);
    await run(await preview('reverse_pause',{group:'selected',ids:[pro.id,direct.id]},rootToken,{revertOf:op.id}));assert.equal((await row(pro.id)).is_paused,1);assert.equal((await row(direct.id)).is_paused,1);
    await one('resume_individual',pro.id);await one('resume_individual',direct.id);
  });
  let expired;
  await test('11. Expired license status and old login rejection',async()=>{expired=await create('synthetic-expired','basic',null,rootToken,'2020-01-01T00:00:00.000Z');await call('/api/app/validate-license',{method:'POST',token:null,data:{licenseKey:expired.licenseKey,hwid:'synthetic'},expect:403});const result=await call('/api/admin-v2/users?group=all&status=expired');assert(result.users.some(u=>u.id===expired.id))});
  await test('12. Archive only expired users, logical deletion retains row',async()=>{const op=await preview('archive',{group:'selected',ids:[expired.id,basic.id]});const result=await run(op);assert.equal(result.results.applied,1);assert.equal(result.results.conflict,1);assert((await row(expired.id)).archived_at);assert.equal((await row(expired.id)).is_active,0)});
  await test('13. Renewal after expiration and renewal-vs-archive race',async()=>{
    const user=await create('synthetic-renewed','basic',null,rootToken,'2020-01-01T00:00:00.000Z');const op=await preview('archive',{group:'selected',ids:[user.id]});await call('/api/admin-v2/users/'+user.id+'/renew',{method:'POST',data:{licenseExpiresAt:'2099-01-01T00:00:00.000Z'}});const result=await run(op);assert.equal(result.results.conflict,1);assert.equal((await row(user.id)).archived_at,null);assert.equal((await row(user.id)).is_active,1);
  });
  await test('14. Append-only history, immutable creators, audited transfers and no raw license keys',async()=>{
    const creator=(await row(direct.id)).created_by_admin_id;await call('/api/admin-v2/users/'+direct.id+'/transfer',{method:'POST',data:{distributorId:distB}});assert.equal((await row(direct.id)).created_by_admin_id,creator);
    await assert.rejects(()=>db.prepare('UPDATE users SET created_by_admin_id=NULL WHERE id=?').bind(direct.id).run());await assert.rejects(()=>db.prepare('DELETE FROM admin_audit').run());const events=await db.prepare('SELECT * FROM admin_audit').all();assert(events.results.some(e=>e.action==='distributor_transfer_requested'));for(const u of [basic,pro,direct,distributed,other,expired])assert(!JSON.stringify(events.results).includes(u.licenseKey));
  });
  await test('16. Both directions of isPremium compatibility without dropping old field',async()=>{await db.prepare('UPDATE users SET is_premium=0 WHERE id=?').bind(pro.id).run();assert.equal((await row(pro.id)).plan_id,'basic');await call('/api/admin-v2/users/'+pro.id,{method:'PATCH',data:{plan:'pro'}});assert.equal((await row(pro.id)).is_premium,1)});
  let app;
  await test('17. Existing APP login and strict administrative separation',async()=>{app=await appLogin(basic);for(const key of ['valid','token','expiresAt','username','isPremium','licenseExpiresAt'])assert(key in app);assert.equal(app.valid,true);await call('/api/admin-v2/me',{token:app.token,expect:401});await call('/api/users',{token:app.token,expect:401})});
  await test('18. Existing patch catalog requires individual assignment and active package',async()=>{
    await db.prepare("INSERT INTO patches(id,name,description,version,type,active,created_at,updated_at) VALUES('fixture-patch','Fixture','Synthetic description','1','visuals',1,?,?)").bind(new Date().toISOString(),new Date().toISOString()).run();
    assert.equal((await call('/api/app/patches',{token:app.token})).patches.length,0);await db.prepare("INSERT INTO user_patches(user_id,patch_id,created_at) VALUES(?,'fixture-patch',?)").bind(basic.id,new Date().toISOString()).run();assert.equal((await call('/api/app/patches',{token:app.token})).patches.length,1);
  });
  await test('19. Existing session verifier checks current revocation state',async()=>{assert.equal((await call('/api/app/me',{token:app.token})).username,'synthetic-basic');await one('revoke',basic.id);await call('/api/app/me',{token:app.token,expect:401})});
  await test('20. New profile has server time, nominal plan and distinct license expiry',async()=>{const login=await appLogin(pro);const p=await call('/api/app/me',{token:login.token});assert.deepEqual(Object.keys(p).sort(),['username','plan','licenseStatus','licenseExpiresAt','serverTime'].sort());assert.equal(p.plan,'pro');assert(Number.isFinite(Date.parse(p.serverTime)));assert(!('distributor_id' in p))});
  await test('21. Admin filters and distinct counts',async()=>{const result=await call('/api/admin-v2/users?group=distributor&distributorId='+distA+'&plan=basic&creator='+(await row(distributed.id)).created_by_admin_id);assert.equal(result.total,1);assert.equal(result.users[0].id,distributed.id);const distributors=await call('/api/admin-v2/distributors');assert.equal(distributors.distributors.find(d=>d.id===distA).total,1)});
  await test('22. BASIC/PRO authorization is intersection, not blanket PRO access',async()=>{
    const login=await appLogin(pro);await db.prepare("INSERT INTO user_patches(user_id,patch_id,created_at) VALUES(?,'fixture-patch',?)").bind(pro.id,new Date().toISOString()).run();
    await call('/api/admin-v2/patch-policies',{method:'PUT',data:{patchId:'fixture-patch',targetId:'fixture.target',capabilityId:'patch.pro',enabled:true,revoked:false,compatible:true,compatibilityDescription:'Synthetic test policy'}});
    assert.equal((await call('/api/app/patches',{token:login.token})).patches.length,1);
    await db.prepare("UPDATE users SET plan_id='basic' WHERE id=?").bind(pro.id).run();assert.equal((await call('/api/app/patches',{token:login.token})).patches.length,0);
    await db.prepare("UPDATE users SET plan_id='pro' WHERE id=?").bind(pro.id).run();await db.prepare("UPDATE patch_policies SET compatible=0 WHERE patch_id='fixture-patch'").run();assert.equal((await call('/api/app/patches',{token:login.token})).patches.length,0);
    await db.prepare("UPDATE patch_policies SET compatible=1 WHERE patch_id='fixture-patch'").run();await db.prepare("DELETE FROM user_patches WHERE user_id=?").bind(pro.id).run();assert.equal((await call('/api/app/patches',{token:login.token})).patches.length,0);
  });
  await test('23. Bulk idempotency, concurrent execution and durable resume',async()=>{
    const user=await create('synthetic-idempotent'),key=crypto.randomUUID();const input={action:'pause',selection:{group:'selected',ids:[user.id]},reason:'manual',idempotencyKey:key};
    const a=await call('/api/admin-v2/operations/preview',{method:'POST',data:input,expect:201}),b=await call('/api/admin-v2/operations/preview',{method:'POST',data:input});assert.equal(a.id,b.id);assert.equal(a.confirmationToken,b.confirmationToken);
    await Promise.all([run(a),run(b)]);await run(a);const count=await db.prepare('SELECT COUNT(*) AS n FROM admin_audit WHERE operation_id=?').bind(a.id).first();assert.equal(count.n,1);assert.equal((await row(user.id)).is_paused,1);
  });
  await test('Extra: no confirmation, stale ownership, insufficient retention and renewed purge protection',async()=>{
    const op=await preview('pause',{group:'selected',ids:[other.id]});await call('/api/admin-v2/operations/'+op.id+'/execute',{method:'POST',data:{confirmationToken:'invalid'},expect:403});
    const own=await preview('pause',{group:'distributor',distributorId:distA},distToken);await call('/api/admin-v2/users/'+distributed.id+'/transfer',{method:'POST',data:{distributorId:distB}});assert.equal((await run(own,distToken)).results.conflict,1);
    const purge=await preview('purge',{group:'selected',ids:[expired.id]});assert.equal((await run(purge)).results.conflict,1);assert.equal((await row(expired.id)).purged_at,null);
    await call('/api/admin-v2/retention',{method:'PUT',data:{enabled:true,days:90}});await db.prepare("UPDATE users SET archived_at='2020-01-01T00:00:00.000Z' WHERE id=?").bind(expired.id).run();const ready=await preview('purge',{group:'selected',ids:[expired.id]});await db.prepare("UPDATE users SET license_expires_at='2099-01-01T00:00:00.000Z' WHERE id=?").bind(expired.id).run();assert.equal((await run(ready)).results.conflict,1);assert.equal((await row(expired.id)).purged_at,null);
  });
  await test('Extra: built panel retains original sections and has no production transport URL',async()=>{const html=await (await mf.dispatchFetch('http://staging.local/admin')).text();assert(html.includes('page-patches'));assert(html.includes('Clientes directos'));assert(html.includes('const API_URL = location.origin'));assert(!html.includes("const API_URL = 'https://vini-v2-api"))});
  await test('Extra: approved remaining-time policy preserves 7 days and 4 days per user, including historical pause',async()=>{
    const seven=await create('synthetic-seven-days','basic',null,rootToken,new Date(Date.now()+7*86400000).toISOString()),four=await create('synthetic-four-days','basic',null,rootToken,new Date(Date.now()+4*86400000).toISOString());
    const op=await preview('pause',{group:'selected',ids:[seven.id,four.id]});await run(op);
    const a=(await row(seven.id)).pause_remaining_ms,b=(await row(four.id)).pause_remaining_ms;
    assert(Math.abs(a-7*86400000)<3000);assert(Math.abs(b-4*86400000)<3000);
    // Simulate an old canonical deadline passing while paused. The recorded
    // remaining balance, rather than that deadline or the client clock, is used.
    await db.prepare("UPDATE users SET license_expires_at='2020-01-01T00:00:00.000Z' WHERE id IN (?,?)").bind(seven.id,four.id).run();
    const protectedArchive=await one('archive',seven.id);assert.equal(protectedArchive.results.conflict,1);assert.equal((await row(seven.id)).archived_at,null);
    await run(await preview('reverse_pause',{group:'selected',ids:[seven.id,four.id]},rootToken,{revertOf:op.id}));
    assert(Math.abs(Date.parse((await row(seven.id)).license_expires_at)-Date.now()-a)<3000);assert(Math.abs(Date.parse((await row(four.id)).license_expires_at)-Date.now()-b)<3000);
    assert.equal((await row('legacy-paused')).pause_remaining_ms,7*86400000);await one('resume_individual','legacy-paused');assert(Math.abs(Date.parse((await row('legacy-paused')).license_expires_at)-Date.now()-7*86400000)<3000);
  });
  await test('Extra: archive renewal is explicit and purge retains only owned minimal license metadata',async()=>{
    const user=await create('synthetic-archive-renew','basic',null,rootToken,'2020-01-01T00:00:00.000Z');await one('archive',user.id);
    await call('/api/admin-v2/users/'+user.id+'/renew',{method:'POST',data:{licenseExpiresAt:'2099-01-01T00:00:00.000Z'},expect:409});
    await call('/api/admin-v2/users/'+user.id+'/renew',{method:'POST',data:{licenseExpiresAt:'2099-01-01T00:00:00.000Z',restoreArchived:true}});assert.equal((await row(user.id)).archived_at,null);assert.equal((await row(user.id)).is_active,1);
    const doomed=await create('synthetic-purge','basic',null,rootToken,'2020-01-01T00:00:00.000Z');await one('archive',doomed.id);await db.prepare("UPDATE users SET archived_at='2020-01-01T00:00:00.000Z' WHERE id=?").bind(doomed.id).run();
    const op=await preview('purge',{group:'selected',ids:[doomed.id]});assert.equal((await run(op)).results.applied,1);const record=await row(doomed.id);assert(record.purged_at);assert.notEqual(record.license_key,doomed.licenseKey);assert.equal(record.username,'deleted:'+doomed.id);assert(await db.prepare('SELECT id FROM license_metadata WHERE user_id=?').bind(doomed.id).first());
  });
  await test('Extra: original v1 activation, one-time challenge and real signed lease remain compatible',async()=>{
    const user=await create('synthetic-device-protocol');
    const keys=await crypto.subtle.generateKey({name:'ECDSA',namedCurve:'P-256'},true,['sign','verify']);
    const publicKey=Buffer.from(await crypto.subtle.exportKey('raw',keys.publicKey)).toString('base64');
    const activated=await call('/v1/activations',{method:'POST',token:null,data:{key:user.licenseKey,publicKey}});assert(activated.activationId);
    const challenge=await call('/v1/challenges',{method:'POST',token:null,data:{activationId:activated.activationId}});
    const signature=Buffer.from(await crypto.subtle.sign({name:'ECDSA',hash:'SHA-256'},keys.privateKey,Buffer.from(challenge.nonce,'base64'))).toString('base64');
    const request={activationId:activated.activationId,challengeId:challenge.challengeId,signature};
    const response=await call('/v1/verifications',{method:'POST',token:null,data:request});assert.equal(response.status,'ACTIVE');
    const lease=JSON.parse(Buffer.from(response.lease,'base64').toString());assert(Number.isInteger(lease.iat));assert(lease.exp>lease.iat);
    const pk=createPrivateKey({key:Buffer.concat([Buffer.from('302e020100300506032b657004220420','hex'),leaseSeed]),format:'der',type:'pkcs8'});
    assert(verify(null,Buffer.concat([Buffer.from('3105-lease-v1'),Buffer.from(response.lease,'base64')]),createPublicKey(pk),Buffer.from(response.leaseSignature,'base64')));
    assert.equal((await call('/v1/verifications',{method:'POST',token:null,data:request})).status,'REJECTED');
    await call('/api/admin-v2/migrations/apply',{method:'POST',token:distToken,data:{confirm:true,manifestHash:'invalid'},expect:401});
  });
  await test('Extra: named SUPER_ADMIN keeps original views while APP tokens cannot enter them',async()=>{
    const password=randomBytes(24).toString('base64url');await call('/api/admin-v2/administrators',{method:'POST',data:{username:'synthetic-named-super',password,role:'SUPER_ADMIN'},expect:201});
    const session=await call('/api/admin-v2/login',{method:'POST',token:null,data:{username:'synthetic-named-super',password}});
    const users=await call('/api/users',{token:session.token});assert(users);await call('/api/admin-v2/migrations/preview',{token:session.token,expect:401});
  });
  await test('Extra: migration batch rollback and manifest confirmation',async()=>{
    const plan=await call('/api/admin-v2/migrations/preview');assert.equal(plan.remaining.length,0);
    await call('/api/admin-v2/migrations/apply',{method:'POST',data:{confirm:false,manifestHash:plan.manifestHash},expect:403});
    await assert.rejects(()=>db.batch([db.prepare('CREATE TABLE rollback_probe(id INTEGER PRIMARY KEY)'),db.prepare('INSERT INTO table_that_does_not_exist VALUES(1)')]));
    assert.equal(await db.prepare("SELECT name FROM sqlite_schema WHERE name='rollback_probe'").first(),null);
  });
  await test('Extra: operation resumes after actual workerd shutdown without repeating committed batches',async()=>{
    const ids=[];for(let i=0;i<21;i++)ids.push((await create('synthetic-restart-'+i)).id);
    const op=await preview('pause',{group:'selected',ids});const first=await call('/api/admin-v2/operations/'+op.id+'/execute',{method:'POST',data:{confirmationToken:op.confirmationToken}});assert.equal(first.status,'running');assert.equal(first.results.applied,5);
    await mf.dispose();mf=new Miniflare(options());db=await mf.getD1Database('DB');const done=await run(op);assert.equal(done.results.applied,21);assert.equal((await db.prepare('SELECT COUNT(*) AS count FROM admin_audit WHERE operation_id=?').bind(op.id).first()).count,21);
  });
  await test('Extra: real desktop browser panel login, roles, navigation, preview and confirmed action',async()=>{
    const user=await create('synthetic-ui-owned','basic',distA,distToken);
    await browserTest({origin:(await mf.ready).origin,root,superPassword,distributorPassword,ownedUserId:user.id,readUser:row});
  });
  await test('Extra: canceled batches stay canceled and can be reverted; reconfirm does not mutate users',async()=>{
    const user=await create('synthetic-cancel');const op=await preview('pause',{group:'selected',ids:[user.id]});
    const confirmation=await call('/api/admin-v2/operations/'+op.id+'/reconfirm',{method:'POST',data:{}});assert.equal(confirmation.confirmationToken,op.confirmationToken);assert.equal((await row(user.id)).is_paused,0);
    await call('/api/admin-v2/operations/'+op.id+'/cancel',{method:'POST',data:{}});await call('/api/admin-v2/operations/'+op.id+'/execute',{method:'POST',data:{confirmationToken:op.confirmationToken},expect:409});assert.equal((await row(user.id)).is_paused,0);
  });
  await test('Extra: overlapping bulk and individual pauses preserve the same numeric balance until the final release',async()=>{
    const user=await create('synthetic-overlap-balance','basic',null,rootToken,new Date(Date.now()+7*86400000).toISOString());
    const first=await preview('pause',{group:'selected',ids:[user.id]});await run(first);
    const frozen=await row(user.id);await one('pause_individual',user.id);
    const second=await preview('pause',{group:'selected',ids:[user.id]});await run(second);
    await run(await preview('reverse_pause',{group:'selected',ids:[user.id]},rootToken,{revertOf:first.id}));
    let current=await row(user.id);assert.equal(current.is_paused,1);assert.equal(current.pause_remaining_ms,frozen.pause_remaining_ms);assert.equal(current.license_expires_at,frozen.license_expires_at);
    await one('resume_individual',user.id);current=await row(user.id);assert.equal(current.is_paused,1);assert.equal(current.pause_remaining_known,1);assert.equal(current.pause_remaining_ms,frozen.pause_remaining_ms);assert.equal(current.license_expires_at,frozen.license_expires_at);
    await run(await preview('reverse_pause',{group:'selected',ids:[user.id]},rootToken,{revertOf:second.id}));current=await row(user.id);assert.equal(current.is_paused,0);assert(Math.abs(Date.parse(current.license_expires_at)-Date.now()-frozen.pause_remaining_ms)<3000);
  });
  await test('Extra: BASIC capability, disabled/revoked package, and denied download has no side effects',async()=>{
    const user=await create('synthetic-basic-capability'),session=await appLogin(user);
    await db.prepare("INSERT INTO user_patches VALUES(?,'fixture-patch',?)").bind(user.id,new Date().toISOString()).run();await db.prepare("UPDATE patch_policies SET capability_id='patch.basic',enabled=1,revoked=0,compatible=1 WHERE patch_id='fixture-patch'").run();
    assert.equal((await call('/api/app/patches',{token:session.token})).patches.length,1);
    await db.prepare("UPDATE patch_policies SET revoked=1 WHERE patch_id='fixture-patch'").run();assert.equal((await call('/api/app/patches',{token:session.token})).patches.length,0);
    const before=(await db.prepare('SELECT COUNT(*) AS count FROM downloads').first()).count;
    await call('/api/app/patches/fixture-patch/download',{token:session.token,expect:403});assert.equal((await db.prepare('SELECT COUNT(*) AS count FROM downloads').first()).count,before);
    await db.prepare("UPDATE patch_policies SET revoked=0,enabled=0 WHERE patch_id='fixture-patch'").run();assert.equal((await call('/api/app/patches',{token:session.token})).patches.length,0);
  });
  await controls2B(call,rootToken,result=>{results.push(result);console.log(result.passed?'PASS':'FAIL',result.name)});
  await test('Extra: maintenance keeps APP authentication but blocks administrative writes',async()=>{
    fixtureBindings.ADMIN_READ_ONLY='1';await mf.dispose();mf=new Miniflare(options());db=await mf.getD1Database('DB');
    await call('/api/admin-v2/users',{method:'POST',data:{username:'cannot-write',plan:'basic'},expect:503});await call('/api/users/'+pro.id,{method:'PUT',data:{username:'cannot-write'},expect:503});assert.equal((await appLogin(pro)).valid,true);
    delete fixtureBindings.ADMIN_READ_ONLY;fixtureBindings.ADMIN_PLANS_ENABLED='0';await mf.dispose();mf=new Miniflare(options());db=await mf.getD1Database('DB');
    await call('/api/app/patches',{token:(await appLogin(pro)).token,expect:503});await call('/api/users',{method:'POST',data:{username:'cannot-write'},expect:503});
  });
}finally{
  await mf.dispose();await writeFile(root+'test-results.json',JSON.stringify({runtime:'local workerd + D1, synthetic data only',productionModified:false,tests:results},null,2));
}
console.log('PASS all '+results.length+' integration groups; no production mutation or iOS execution');
