import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
const base='https://vini-admin-plans-staging-2b.loboangel39.workers.dev';
let input='';for await(const chunk of process.stdin)input+=chunk;
const credentials=JSON.parse(input),state=JSON.parse(await readFile(new URL('../dist/acceptance-2c-state.json',import.meta.url),'utf8'));
let token,serverTime;
async function api(path,{method='GET',data,auth=token,expect=200}={}){const r=await fetch(base+path,{method,redirect:'error',signal:AbortSignal.timeout(30000),headers:{'Content-Type':'application/json',...(auth?{Authorization:'Bearer '+auth}:{})},...(data?{body:JSON.stringify(data)}:{})});serverTime=Date.parse(r.headers.get('Date'));assert.equal(r.status,expect,path+' status='+r.status);return r.json()}
token=(await api('/api/admin/login',{method:'POST',auth:null,data:{username:'staging-owner',password:credentials.ADMIN_PASSWORD}})).token;
const stage=process.argv.find(x=>x.startsWith('--phase='))?.split('=')[1]||'check';
const tests=[];
if(process.argv.includes('--missing')){
  assert(state.missingPatch);const u=await api('/api/admin-v2/users',{method:'POST',data:{username:'TEST2C-probe-'+randomUUID().slice(0,8),plan:'pro'},expect:201});await api('/api/access',{method:'POST',data:{userId:u.id,patchId:state.missingPatch}});const app=(await api('/api/app/validate-license',{method:'POST',auth:null,data:{licenseKey:u.licenseKey,hwid:'synthetic'}})).token;await api('/api/app/patches/'+state.missingPatch+'/download',{auth:app,expect:404});tests.push({name:'Missing R2 object returns 404',passed:true});
}
assert.equal(state.frozen?.length,2,'Both frozen licenses must be present');
for(const u of state.frozen){let row=(await api('/api/admin-v2/users?group=all&search='+u.id)).users[0];assert.equal(row.is_paused,1);assert.equal(row.pause_remaining_ms,u.bank);assert.equal(row.licenseStatus,'paused');if(process.argv.includes('--resume')){const op=await api('/api/admin-v2/operations/preview',{method:'POST',data:{action:'resume_individual',selection:{group:'selected',ids:[u.id]},reason:'manual',idempotencyKey:randomUUID()},expect:201});await api('/api/admin-v2/operations/'+op.id+'/execute',{method:'POST',data:{confirmationToken:op.confirmationToken}});row=(await api('/api/admin-v2/users?group=all&search='+u.id)).users[0];assert.equal(row.is_paused,0);assert(Math.abs(Date.parse(row.license_expires_at)-serverTime-u.bank)<15000);const expiry=row.license_expires_at;await api('/api/admin-v2/operations/'+op.id+'/execute',{method:'POST',data:{confirmationToken:op.confirmationToken}});assert.equal((await api('/api/admin-v2/users?group=all&search='+u.id)).users[0].license_expires_at,expiry)}tests.push({name:u.days+'-day frozen bank '+(process.argv.includes('--resume')?'restored from server time, retry idempotent':'persists unchanged'),passed:true})}
await writeFile(new URL('../dist/probe-2c-'+stage+'.json',import.meta.url),JSON.stringify({base,phase:stage,tests,productionModified:false},null,2));console.log('PASS',stage,tests.length,'probes');
