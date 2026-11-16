import fs from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import crypto from 'node:crypto';

const workerSource = 'C:/Users/ANGEL/Documents/Codex/2026-11-14/instrucci-n-definitiva-integraci-n-completa-2/work/cloudflare-audit-private/vini-v2-api/src/index.js';
const workerModule = 'scripts/phase3g-worker-runtime.mjs';
fs.copyFileSync(workerSource, workerModule);
const { default: worker } = await import(`./phase3g-worker-runtime.mjs?t=${Date.now()}`);

const db = new DatabaseSync(':memory:');
db.exec(`PRAGMA foreign_keys=ON;
CREATE TABLE users(id TEXT PRIMARY KEY, username TEXT, license_key TEXT, hwid TEXT, is_active INTEGER, is_paused INTEGER, is_blocked INTEGER, is_premium INTEGER, license_expires_at TEXT);
CREATE TABLE patches(id TEXT PRIMARY KEY, name TEXT, description TEXT, version TEXT, type TEXT, file_key TEXT, active INTEGER, created_at TEXT, updated_at TEXT, content_key TEXT, password TEXT);
CREATE TABLE user_patches(user_id TEXT, patch_id TEXT, created_at TEXT, PRIMARY KEY(user_id, patch_id));
CREATE TABLE downloads(id TEXT PRIMARY KEY, user_id TEXT, patch_id TEXT, created_at TEXT);
CREATE TABLE patch_targets(id TEXT PRIMARY KEY, patch_id TEXT NOT NULL REFERENCES patches(id) ON DELETE CASCADE, target_id TEXT NOT NULL, project_id TEXT NOT NULL, package_id TEXT NOT NULL, revision INTEGER NOT NULL, sha256 TEXT NOT NULL, file_size INTEGER NOT NULL, category TEXT NOT NULL, required_plan TEXT NOT NULL, authorization_status TEXT NOT NULL, enabled INTEGER NOT NULL, revoked INTEGER NOT NULL, active INTEGER NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
INSERT INTO users VALUES ('u-basic','Basic User','LIC-BASIC','HW-1',1,0,0,0,'2999-01-01T00:00:00Z');
INSERT INTO users VALUES ('u-pro','Pro User','LIC-PRO','HW-2',1,0,0,1,'2999-01-01T00:00:00Z');
INSERT INTO users VALUES ('u-none','No Access','LIC-NONE','HW-3',1,0,0,0,'2999-01-01T00:00:00Z');
INSERT INTO patches VALUES ('p1','ESP Box 2D','fixture','1','3105','esp.3105',1,'now','now',NULL,NULL);
INSERT INTO patches VALUES ('p2','Revoked','fixture','1','3105','revoked.3105',1,'now','now',NULL,NULL);
INSERT INTO patches VALUES ('p3','Inactive','fixture','1','3105','inactive.3105',0,'now','now',NULL,NULL);
INSERT INTO user_patches VALUES ('u-basic','p1','now');
INSERT INTO user_patches VALUES ('u-pro','p1','now');
INSERT INTO user_patches VALUES ('u-basic','p2','now');
INSERT INTO user_patches VALUES ('u-basic','p3','now');
INSERT INTO patch_targets VALUES ('t1','p1','vini.esp_box','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222',1,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',4,'visuals','basic','authorized',1,0,1,'now','now');
INSERT INTO patch_targets VALUES ('t2','p2','vini.revoked','11111111-1111-1111-1111-111111111111','33333333-3333-3333-3333-333333333333',1,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',4,'visuals','basic','revoked',0,1,0,'now','now');`);

class D1 { constructor(db) { this.db = db; } prepare(sql) { const db=this.db; return { bind(...args) { return { first() { const s=db.prepare(sql); const r=s.get(...args); return r?Object.fromEntries(Object.entries(r)):null; }, all() { const s=db.prepare(sql); return { results:s.all(...args).map(r=>Object.fromEntries(Object.entries(r))) }; }, run() { db.prepare(sql).run(...args); return { success:true }; } }; } }; } }
const goodBody = new TextEncoder().encode('DATA');
const objects = new Map([
  ['esp.3105', { body:goodBody, size:4, checksums:{sha256:'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'} }],
  ['revoked.3105', { body:goodBody, size:4, checksums:{sha256:'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'} }]
]);
const R2 = { async get(key) { const o=objects.get(key); return o ? { ...o } : null; } };
const env = { DB:new D1(db), R2, AUTH_JWT_SECRET:'x'.repeat(40) };
function b64(v){ return Buffer.from(v).toString('base64').replaceAll('=','').replaceAll('+','-').replaceAll('/','_'); }
async function token(userId, licenseKey, hwid) {
  const h=b64(JSON.stringify({alg:'HS256',typ:'JWT',kid:'app-v1'})); const p=b64(JSON.stringify({userId,licenseKey,hwid,exp:Date.now()+3600000}));
  const base=crypto.createHmac('sha256',env.AUTH_JWT_SECRET).update('3105-session-app-v1').digest('base64');
  const s=crypto.createHmac('sha256',base).update(`${h}.${p}`).digest('base64'); return `${h}.${p}.${s}`;
}
async function call(path, userId='u-basic', key='LIC-BASIC', hwid='HW-1') { const req=new Request(`https://test${path}`,{headers:{Authorization:`Bearer ${await token(userId,key,hwid)}`}}); return worker.fetch(req,env); }
let pass=0;
let r=await call('/api/app/patches'); let j=await r.json(); if(r.status===200 && j.patches.length===1 && j.patches[0].target?.targetID==='vini.esp_box') pass++; else throw new Error(`catalog compatibility/auth failed: ${r.status} ${JSON.stringify(j)}`);
r=await call('/api/app/patches/p1/download'); if(r.status===200 && (await r.arrayBuffer()).byteLength===4) pass++; else throw new Error('download failed');
r=await call('/api/app/patches/p2'); if(r.status===404) pass++; else throw new Error('revoked package exposed');
 r=await call('/api/app/patches','u-none','LIC-NONE','HW-3'); j=await r.json(); if(r.status===200 && j.patches.length===0) pass++; else throw new Error('unassigned package exposed');
 r=await call('/api/app/patches','u-pro','LIC-PRO','HW-2'); j=await r.json(); if(r.status===200 && j.patches.length===1) pass++; else throw new Error('PRO authorization failed');
 r=await call('/api/app/patches/p3'); if(r.status===404) pass++; else throw new Error('inactive package exposed');
db.prepare("UPDATE patch_targets SET sha256=? WHERE id='t1'").run('c'.repeat(64)); r=await call('/api/app/patches/p1/download'); if(r.status===409) pass++; else throw new Error('hash mismatch not rejected');
db.prepare("UPDATE patch_targets SET sha256='a'||substr('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',2), file_size=5 WHERE id='t1'"); r=await call('/api/app/patches/p1/download'); if(r.status===409) pass++; else throw new Error('size mismatch not rejected');
db.prepare("UPDATE patch_targets SET enabled=0 WHERE id='t1'").run(); r=await call('/api/app/patches'); j=await r.json(); if(r.status===200 && j.patches.length===0) pass++; else throw new Error('disabled target exposed');
db.prepare("UPDATE patch_targets SET enabled=1, revoked=1 WHERE id='t1'").run(); r=await call('/api/app/patches'); j=await r.json(); if(r.status===200 && j.patches.length===0) pass++; else throw new Error('revoked target exposed');
db.prepare("UPDATE patch_targets SET revoked=0 WHERE id='t1'").run(); db.prepare("UPDATE users SET license_expires_at='2000-01-01T00:00:00Z' WHERE id='u-basic'").run(); r=await call('/api/app/patches'); if(r.status===401) pass++; else throw new Error('expired license accepted');
db.prepare("UPDATE users SET license_expires_at='2999-01-01T00:00:00Z' WHERE id='u-basic'").run(); r=await call('/api/app/patches','u-basic','LIC-BASIC','WRONG'); if(r.status===401) pass++; else throw new Error('wrong HWID accepted');
db.prepare("UPDATE users SET hwid='HW-1' WHERE id='u-basic'").run(); r=await call('/api/app/patches'); if(r.status===200) pass++; else throw new Error('restored auth failed');
db.prepare("UPDATE patch_targets SET revoked=1 WHERE id='t1'").run(); r=await call('/api/app/patches/p1/download'); if(r.status===404) pass++; else throw new Error('revoked download accepted');
console.log(`PASS worker runtime isolated checks: ${pass}/14`);
db.close(); fs.unlinkSync(workerModule);
