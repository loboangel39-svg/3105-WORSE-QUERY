import {spawn} from 'node:child_process';
import {readFile,mkdir,writeFile,access} from 'node:fs/promises';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import assert from 'node:assert/strict';
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function until(fn,label){for(let i=0;i<150;i++){const result=await fn();if(result)return result;await sleep(100)}throw Error('Browser timeout: '+label)}
export async function browserTest({origin,root,superPassword,distributorPassword,ownedUserId,readUser,superUserName='staging-super',distributorUserName='synthetic-distributor'}){
  const candidates=process.platform==='win32'?['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe','C:/Program Files/Google/Chrome/Application/chrome.exe']:['/usr/bin/google-chrome','/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'];
  let executable=null;for(const candidate of candidates){try{await access(candidate);executable=candidate;break}catch{}}
  if(!executable)throw Error('A real desktop Chrome/Edge executable is required for panel tests');
  const profile=join(tmpdir(),'vini-browser-'+crypto.randomUUID());await mkdir(profile,{recursive:true});
  const child=spawn(executable,['--headless=new','--window-size=1440,1000','--no-first-run','--no-default-browser-check','--disable-sync','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{windowsHide:true,stdio:'ignore'});
  let socket;const pending=new Map();let nextId=0,dialogs=0;
  try{
    const port=await until(async()=>{try{return Number((await readFile(join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0])}catch{return null}},'debug port');
    const targets=await (await fetch('http://127.0.0.1:'+port+'/json/list')).json();
    socket=new WebSocket(targets.find(t=>t.type==='page').webSocketDebuggerUrl);
    await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true})});
    socket.addEventListener('message',event=>{const message=JSON.parse(event.data);if(message.id){const task=pending.get(message.id);if(task){pending.delete(message.id);message.error?task.reject(Error(message.error.message)):task.resolve(message.result)}}if(message.method==='Page.javascriptDialogOpening'){dialogs++;command('Page.handleJavaScriptDialog',{accept:true}).catch(()=>{})}});
    function command(method,params={}){const id=++nextId;return new Promise((resolve,reject)=>{pending.set(id,{resolve,reject});socket.send(JSON.stringify({id,method,params}));setTimeout(()=>{if(pending.delete(id))reject(Error('CDP timeout: '+method))},20000).unref()})}
    async function evaluate(expression){const result=await command('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(result.exceptionDetails)throw Error(result.exceptionDetails.text);return result.result?.value}
    await command('Page.enable');await command('Runtime.enable');await command('Page.navigate',{url:origin+'/admin'});
    await until(()=>evaluate("!!document.getElementById('page-admin-v2')"),'extension loaded');
    async function login(username,password){await evaluate(`document.getElementById('loginUsername').value=${JSON.stringify(username)};document.getElementById('loginPassword').value=${JSON.stringify(password)};document.getElementById('loginForm').requestSubmit();`);await until(()=>evaluate("document.getElementById('page-admin-v2').textContent.includes('Total sin duplicados:')"),'authenticated table')}
    await login(superUserName,superPassword);
    assert(await evaluate("[...document.querySelectorAll('.sidebar button')].some(b=>b.textContent==='Todos los usuarios')"));
    await evaluate("[...document.querySelectorAll('.sidebar button')].find(b=>b.textContent==='Distribuidores').click()");
    await until(()=>evaluate("document.querySelector('#page-admin-v2 h1')?.textContent==='Distribuidores'"),'distributor section');
    await until(()=>evaluate("document.getElementById('page-admin-v2').textContent.includes('Synthetic A')"),'distributor data loaded');
    await evaluate("document.getElementById('logoutBtn').click()");
    await login(distributorUserName,distributorPassword);
    assert(await evaluate("![...document.querySelectorAll('.sidebar button')].some(b=>b.textContent==='Todos los usuarios')"));
    assert(await evaluate("[...document.querySelectorAll('.nav-item[data-page]')].every(b=>getComputedStyle(b).display==='none')"));
    assert(await evaluate("document.getElementById('page-admin-v2').textContent.includes('synthetic-ui-owned')"));
    assert(!await evaluate("document.getElementById('page-admin-v2').textContent.includes('synthetic-other-client')"));
    assert(!await evaluate("[...document.querySelectorAll('#page-admin-v2 button')].some(b=>b.textContent==='Pausar todas las licencias')"));
    assert(await evaluate("[...document.querySelectorAll('#page-admin-v2 button')].some(b=>b.textContent==='Reactivar todas')"));
    assert(await evaluate("!!document.querySelector('#page-admin-v2 .badge')"));
    await evaluate("[...document.querySelectorAll('#page-admin-v2 tbody tr')].find(r=>r.textContent.includes('synthetic-ui-owned')).querySelectorAll('button')[1].click()");
    await until(async()=>!!(await readUser(ownedUserId)).is_paused,'confirmed pause from UI');
    assert(dialogs>=1,'administrative preview must require a browser confirmation');
    await until(()=>evaluate("document.querySelector('#page-admin-v2 h1')?.textContent==='Operaciones e informes'"),'operation report');
    const screenshot=await command('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
    await writeFile(join(root,'dist','admin-staging.png'),Buffer.from(screenshot.data,'base64'));
    await command('Browser.close').catch(()=>{});
    return {engine:executable,confirmations:dialogs,screenshot:'dist/admin-staging.png'};
  }finally{socket?.close();if(child.exitCode===null)child.kill()}
}
