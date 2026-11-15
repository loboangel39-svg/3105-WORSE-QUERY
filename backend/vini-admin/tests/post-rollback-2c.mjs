import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
import {createHash,randomUUID} from 'node:crypto';
const base='https://vini-admin-plans-staging-2b.loboangel39.workers.dev';
let input='';for await(const chunk of process.stdin)input+=chunk;
const credentials=JSON.parse(input),state=JSON.parse(await readFile(new URL('../dist/acceptance-2c-state.json',import.meta.url),'utf8')),tests=[];
let token;
async function request(path,{method='GET',data,auth=token,expect=200,headers={}}={}){const r=await fetch(base+path,{method,redirect:'error',signal:AbortSignal.timeout(30000),headers:{'Content-Type':'application/json',...(auth?{Authorization:'Bearer '+auth}:{}),...headers},...(data?{body:JSON.stringify(data)}:{})});assert.equal(r.status,expect,path+' status='+r.status);return r}
const api=async(path,options)=>(await request(path,options)).json();
async function test(name,fn){await fn();tests.push({name,passed:true});console.log('PASS',name)}
token=(await api('/api/admin/login',{method:'POST',auth:null,data:{username:'staging-owner',password:credentials.ADMIN_PASSWORD}})).token;
await test('Post-rollback panel bytes and closed migration bootstrap',async()=>{const r=await request('/admin');assert.equal(createHash('sha256').update(await r.text()).digest('hex'),createHash('sha256').update(await readFile(new URL('../dist/admin.html',import.meta.url))).digest('hex'));await request('/api/admin-v2/migrations/preview',{expect:404})});
const tag='TEST2C-FINAL-'+randomUUID().slice(0,8);
const dist=(await api('/api/admin-v2/distributors',{method:'POST',data:{name:tag},expect:201})).id;
const create=distributorId=>api('/api/admin-v2/users',{method:'POST',data:{username:tag+(distributorId?'-dist':'-direct'),plan:'pro',distributorId},expect:201});
const direct=await create(null),distributed=await create(dist);
const get=async u=>(await api('/api/admin-v2/users?group=all&search='+u.id)).users[0];
await test('Direct bulk pause/resume never changes distributor clients',async()=>{for(const action of ['pause','resume_scope']){const op=await api('/api/admin-v2/operations/preview',{method:'POST',data:{action,selection:{group:'direct',search:tag},reason:'manual',idempotencyKey:randomUUID()},expect:201});assert.equal(op.total,1);const r=await api('/api/admin-v2/operations/'+op.id+'/execute',{method:'POST',data:{confirmationToken:op.confirmationToken}});assert.equal(r.status,'completed');assert.equal((await get(direct)).is_paused,action==='pause'?1:0);assert.equal((await get(distributed)).is_paused,0)}});
await test('Restored R2 binding downloads exact fixture; Range restarts full file',async()=>{await api('/api/access',{method:'POST',data:{userId:direct.id,patchId:state.r2.patchId}});const session=await api('/api/app/validate-license',{method:'POST',auth:null,data:{licenseKey:direct.licenseKey,hwid:'synthetic'}});const r=await request('/api/app/patches/'+state.r2.patchId+'/download',{auth:session.token,headers:{Range:'bytes=1024-'}});assert.equal(Number(r.headers.get('Content-Length')),state.r2.bytes);assert.equal(r.headers.get('Content-Range'),null);assert.equal(createHash('sha256').update(Buffer.from(await r.arrayBuffer())).digest('hex'),state.r2.sha256)});
await writeFile(new URL('../dist/post-rollback-2c-results.json',import.meta.url),JSON.stringify({base,tests,productionModified:false},null,2));
