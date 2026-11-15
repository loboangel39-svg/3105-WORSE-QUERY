import {randomBytes,createHash} from 'node:crypto';
import {readFile,writeFile,copyFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {browserTest} from './browser.mjs';
import {root} from '../scripts/build.mjs';
const origin='https://vini-admin-plans-staging-2b.loboangel39.workers.dev';
let input='';for await(const chunk of process.stdin)input+=chunk;const credentials=JSON.parse(input);
async function call(path,token,data){const response=await fetch(origin+path,{redirect:'error',method:data?'POST':'GET',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},...(data?{body:JSON.stringify(data)}:{})});const value=await response.json();if(!response.ok)throw Error('Staging panel setup '+response.status+' '+(value.error||'failed'));return value}
const rootToken=(await call('/api/admin/login',null,{username:'staging-owner',password:credentials.ADMIN_PASSWORD})).token;
const distributor=(await call('/api/admin-v2/distributors',rootToken,{name:'Synthetic A'})).id;
const password=randomBytes(24).toString('base64url'),username='TEST2B-browser-'+crypto.randomUUID().slice(0,8);
await call('/api/admin-v2/administrators',rootToken,{username,password,role:'DISTRIBUTOR',distributorId:distributor,actions:['read','create','pause','reactivate','archive','hwid_reset']});
const user=await call('/api/admin-v2/users',rootToken,{username:'synthetic-ui-owned',plan:'basic',distributorId:distributor,licenseExpiresAt:null});
const served=Buffer.from(await (await fetch(origin+'/admin')).arrayBuffer());const built=await readFile(root+'dist/admin.html');assert.deepEqual(served,built,'Served panel differs from artifact');
const result=await browserTest({origin,root,superPassword:credentials.ADMIN_PASSWORD,distributorPassword:password,ownedUserId:user.id,superUserName:'staging-owner',distributorUserName:username,readUser:async id=>(await call('/api/admin-v2/users?group=all&search='+id,rootToken)).users[0]});
await copyFile(root+'dist/admin-staging.png',root+'dist/admin-cloudflare-staging.png');
await writeFile(root+'remote-panel-results.json',JSON.stringify({passed:true,origin,panelSHA256:createHash('sha256').update(served).digest('hex'),engine:result.engine,administrativeConfirmations:result.confirmations,syntheticDataOnly:true},null,2));
console.log('PASS: real desktop browser against Cloudflare staging; roles, scoped buttons, states and confirmed action; served HTML matches artifact');
