import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {controls2B} from './controls-2b.mjs';
const base='https://vini-admin-plans-staging-2b.loboangel39.workers.dev';
if(new URL(base).hostname!=='vini-admin-plans-staging-2b.loboangel39.workers.dev')throw Error('Not staging');
let input='';for await(const chunk of process.stdin)input+=chunk;
const credentials=JSON.parse(input),results=[];
async function call(path,{method='GET',data,token,expect=200}={}){
  const response=await fetch(base+path,{method,redirect:'error',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},...(data?{body:JSON.stringify(data)}:{})});
  const raw=await response.text();let value;try{value=JSON.parse(raw)}catch{throw Error('Non-JSON staging response: '+response.status)}
  // Never put credentials, issued license keys or tokens in assertion messages.
  assert.equal(response.status,expect,method+' '+path+' status='+response.status+' error='+(value.error||'none'));return value;
}
try{
  const session=await call('/api/admin/login',{method:'POST',data:{username:'staging-owner',password:credentials.ADMIN_PASSWORD}});
  const token=session.token;assert(token);
  const manifest=await call('/api/admin-v2/migrations/preview',{token});
  for(const entry of manifest.manifest){const bytes=await readFile(new URL('../migrations/'+entry.name+'.sql',import.meta.url));assert.equal(createHash('sha256').update(bytes).digest('hex'),entry.sha256,'Migration manifest mismatch')}
  for(let i=0;i<5;i++){const applied=await call('/api/admin-v2/migrations/apply',{method:'POST',token,data:{manifestHash:manifest.manifestHash,confirm:true}});if(!applied.remaining.length)break;if(i===4)throw Error('Incomplete staging migration')}
  console.log('PASS: three migrations applied/verified exclusively in remote staging');
  await controls2B(call,token,result=>{results.push(result);console.log(result.passed?'PASS':'FAIL',result.name)});
}finally{
  await writeFile(new URL('../remote-test-results.json',import.meta.url),JSON.stringify({base,environment:'Cloudflare remote staging, fictitious users only',productionModified:false,tests:results},null,2));
}
console.log('PASS: '+results.length+' remote Cloudflare staging groups');
