// Pipe stdout directly into encrypted GitHub Actions secret storage; never log it.
import {randomUUID} from 'node:crypto';
const base='https://vini-admin-plans-staging-2b.loboangel39.workers.dev';
let input='';for await(const chunk of process.stdin)input+=chunk;
const credentials=JSON.parse(input);let token;
async function api(path,data,expected=200){const response=await fetch(base+path,{method:data?'POST':'GET',redirect:'error',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},...(data?{body:JSON.stringify(data)}:{})});if(response.status!==expected)throw Error('Staging fixture preparation status '+response.status);return response.json()}
token=(await api('/api/admin/login',{username:'staging-owner',password:credentials.ADMIN_PASSWORD})).token;
const licenses={},tag=randomUUID().slice(0,8);
let proID;
for(const name of ['basic','pro','unassigned','paused','revoked']){
 const u=await api('/api/admin-v2/users',{username:'TEST2D-'+tag+'-'+name,plan:['pro','unassigned'].includes(name)?'pro':'basic',licenseExpiresAt:'2099-01-01T00:00:00.000Z'},201);
 licenses[name]=u.licenseKey;
 if(name==='pro')proID=u.id;
 if(['basic','pro'].includes(name))await api('/api/access',{userId:u.id,patchId:'c0df8b65-a64d-4dca-b262-f12b39831768'});
 if(['paused','revoked'].includes(name)){
  const p=await api('/api/admin-v2/operations/preview',{action:name==='paused'?'pause_individual':'revoke',selection:{group:'selected',ids:[u.id]},reason:'manual',idempotencyKey:randomUUID()},201);
  await api('/api/admin-v2/operations/'+p.id+'/execute',{confirmationToken:p.confirmationToken});
 }
}
const form=new FormData();form.set('name','TEST2D-'+tag+'-revoked-patch');
const created=await fetch(base+'/api/patches',{method:'POST',redirect:'error',headers:{Authorization:'Bearer '+token},body:form});
if(!created.ok)throw Error('Synthetic patch creation failed');
const patch=await created.json();await api('/api/access',{userId:proID,patchId:patch.id});
const policy=await fetch(base+'/api/admin-v2/patch-policies',{method:'PUT',redirect:'error',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify({patchId:patch.id,targetId:'synthetic.revoked',capabilityId:'patch.pro',enabled:true,revoked:true,compatible:true,compatibilityDescription:'Synthetic revoked fixture; no file'})});
if(!policy.ok)throw Error('Synthetic revoked policy failed status='+policy.status+' code='+String((await policy.json()).error));licenses.revokedPatchID=patch.id;
const targetID='package.E4F7CF4A-D0D9-4150-93DE-17AACCD5F037';
const assignment={patchId:'c0df8b65-a64d-4dca-b262-f12b39831768',targetId:targetID,capabilityId:'patch.pro',enabled:true,revoked:false,compatible:true,compatibilityDescription:'2F isolated owned fixture only; package/project E4F7CF4A-D0D9-4150-93DE-17AACCD5F037'};
const assigned=await fetch(base+'/api/admin-v2/patch-policies',{method:'PUT',redirect:'error',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify(assignment)});
if(!assigned.ok)throw Error('Staging fixture assignment failed status='+assigned.status+' code='+String((await assigned.json()).error));
const policies=await api('/api/admin-v2/patch-policies');
if(!policies.policies.some(p=>p.patch_id===assignment.patchId&&p.target_id===targetID&&p.enabled===1&&p.revoked===0))throw Error('Assignment verification failed');
licenses.targetID=targetID;
for(const name of ['expired','blocked']){
 const u=await api('/api/admin-v2/users',{username:'TEST2F-'+tag+'-'+name,plan:'basic',licenseExpiresAt:name==='expired'?'2020-01-01T00:00:00.000Z':null},201);licenses[name]=u.licenseKey;
 if(name==='blocked')await api('/api/users/'+u.id+'/block',{});
}
process.stdout.write(JSON.stringify(licenses));
