// Pipe stdout directly into encrypted GitHub Actions secret storage; never log it.
import {randomUUID} from 'node:crypto';
const base='https://vini-admin-plans-staging-2b.loboangel39.workers.dev';
let input='';for await(const chunk of process.stdin)input+=chunk;
const credentials=JSON.parse(input);let token;
async function api(path,data,expected=200){const response=await fetch(base+path,{method:data?'POST':'GET',redirect:'error',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},...(data?{body:JSON.stringify(data)}:{})});if(response.status!==expected)throw Error('Staging fixture preparation status '+response.status);return response.json()}
token=(await api('/api/admin/login',{username:'staging-owner',password:credentials.ADMIN_PASSWORD})).token;
const licenses={},tag=randomUUID().slice(0,8);
for(const name of ['basic','pro','unassigned','paused','revoked']){
 const u=await api('/api/admin-v2/users',{username:'TEST2D-'+tag+'-'+name,plan:['pro','unassigned'].includes(name)?'pro':'basic',licenseExpiresAt:'2099-01-01T00:00:00.000Z'},201);
 licenses[name]=u.licenseKey;
 if(['basic','pro'].includes(name))await api('/api/access',{userId:u.id,patchId:'c0df8b65-a64d-4dca-b262-f12b39831768'});
 if(['paused','revoked'].includes(name)){
  const p=await api('/api/admin-v2/operations/preview',{action:name==='paused'?'pause_individual':'revoke',selection:{group:'selected',ids:[u.id]},reason:'manual',idempotencyKey:randomUUID()},201);
  await api('/api/admin-v2/operations/'+p.id+'/execute',{confirmationToken:p.confirmationToken});
 }
}
process.stdout.write(JSON.stringify(licenses));
