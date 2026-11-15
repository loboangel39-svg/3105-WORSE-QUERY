import {randomBytes,randomUUID,createHash,createCipheriv,createDecipheriv} from 'node:crypto';
import {spawnSync} from 'node:child_process';
const py=`import json,sys,plistlib,base64,datetime
def convert(x):
 if isinstance(x,dict):
  if '$data' in x:return base64.b64decode(x['$data'])
  if '$date' in x:return datetime.datetime.fromisoformat(x['$date'])
  return {k:convert(v) for k,v in x.items()}
 if isinstance(x,list):return [convert(v) for v in x]
 return x
sys.stdout.buffer.write(plistlib.dumps(convert(json.load(sys.stdin)),fmt=plistlib.FMT_BINARY))`;
const data=b=>({$data:Buffer.from(b).toString('base64')});
function plist(x){const r=spawnSync('py',['-3','-c',py],{input:JSON.stringify(x),maxBuffer:16*1024*1024});if(r.status!==0)throw Error('Fixture plist serialization failed');return r.stdout}
export function fixture2C(){
  const id=randomUUID().toUpperCase(),rule=randomUUID().toUpperCase(),replacement=randomBytes(2*1024*1024),key=randomBytes(32),iv=randomBytes(12);
  const project={id,name:'TEST2C synthetic transport only',author:'Staging acceptance',isPrivate:false,createdAt:{$date:'2026-11-15T00:00:00'},updatedAt:{$date:'2026-11-15T00:00:00'},bundleIdentifiers:['com.example.vini.acceptance'],directories:[],rules:[{id:rule,bundleID:'com.example.vini.acceptance',relativePath:'Documents/acceptance.bin',replacementFilename:'acceptance.bin',replacementData:data(replacement)}]};
  const payload=plist({project,replacementDigests:{[rule]:data(createHash('sha256').update(replacement).digest())}});
  const aad=Buffer.from('3105PATCH/v3/payload/'+id),cipher=createCipheriv('aes-256-gcm',key,iv);cipher.setAAD(aad);
  const encrypted=Buffer.concat([cipher.update(payload),cipher.final()]),tag=cipher.getAuthTag();
  const envelope=plist({schemaVersion:3,packageID:id,isPasswordProtected:false,publicContentKey:data(key),keyFingerprint:data(createHash('sha256').update(key).digest()),encryptedPayload:data(Buffer.concat([iv,encrypted,tag]))});
  const decoder=createDecipheriv('aes-256-gcm',key,iv);decoder.setAAD(aad);decoder.setAuthTag(tag);
  if(!Buffer.concat([decoder.update(encrypted),decoder.final()]).equals(payload))throw Error('Fixture crypto roundtrip failed');
  return Buffer.concat([Buffer.from('3105PATCH\0'),envelope]);
}
