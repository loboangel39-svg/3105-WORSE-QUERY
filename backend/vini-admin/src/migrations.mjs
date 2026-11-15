import first from '../migrations/0001_admin_plans.sql';
import second from '../migrations/0002_operations_capabilities.sql';
import third from '../migrations/0003_scoped_controls_hwid.sql';
import {verifyAuth} from '../dist/upstream.mjs';
import {fail,json,digest,body} from './auth.mjs';
const sources=[['0001_admin_plans',first],['0002_operations_capabilities',second],['0003_scoped_controls_hwid',third]];
export async function migrationRoute(request,env,apply){
  if(env.ADMIN_MIGRATIONS_ENABLED!=='1')fail(404,'not_found');
  // Bootstrap uses ONLY the existing verified principal, never APP/RBAC tokens.
  if(!(await verifyAuth(request,env)).valid)fail(401,'existing_super_admin_required');
  const manifest=await Promise.all(sources.map(async([name,sql])=>({name,sha256:await digest(sql)})));
  const manifestHash=await digest(JSON.stringify(manifest));
  const found=await env.DB.prepare("SELECT name FROM sqlite_schema WHERE type='table' AND name='vini_admin_migrations'").first();
  const applied=found?(await env.DB.prepare('SELECT name,checksum FROM vini_admin_migrations ORDER BY name').all()).results:[];
  for(const entry of applied){const expected=manifest.find(m=>m.name===entry.name);if(!expected||expected.sha256!==entry.checksum)fail(409,'migration_checksum_mismatch')}
  // Fail before DDL when the existing model is not the audited model.
  const cols=(await env.DB.prepare("PRAGMA table_info('users')").all()).results.map(r=>r.name);
  for(const column of ['id','username','license_key','is_premium','is_active','is_paused','is_blocked','license_expires_at'])if(!cols.includes(column))fail(409,'unexpected_baseline');
  if(!apply)return json({manifest,manifestHash,applied,remaining:manifest.filter(m=>!applied.some(x=>x.name===m.name)).map(m=>m.name)});
  const input=await body(request);if(input.manifestHash!==manifestHash||input.confirm!==true)fail(403,'migration_confirmation_required');
  if(!found)await env.DB.prepare('CREATE TABLE IF NOT EXISTS vini_admin_migrations(name TEXT PRIMARY KEY,checksum TEXT NOT NULL,applied_at TEXT NOT NULL)').run();
  for(let i=0;i<sources.length;i++){
    const [name,source]=sources[i];const existing=await env.DB.prepare('SELECT checksum FROM vini_admin_migrations WHERE name=?').bind(name).first();
    if(existing){if(existing.checksum!==manifest[i].sha256)fail(409,'migration_checksum_mismatch');continue}
    // One complete SQL statement per physical line, including each full trigger.
    const statements=source.split(/\r?\n/).map(s=>s.trim()).filter(s=>s&&!s.startsWith('--'));
    await env.DB.batch([...statements.map(sql=>env.DB.prepare(sql)),env.DB.prepare('INSERT INTO vini_admin_migrations VALUES(?,?,?)').bind(name,manifest[i].sha256,new Date().toISOString())]);
    break; // Bound each invocation: one complete atomic migration per request.
  }
  const finished=(await env.DB.prepare('SELECT name FROM vini_admin_migrations ORDER BY name').all()).results.map(r=>r.name);
  return json({success:true,manifestHash,applied:finished,remaining:manifest.filter(m=>!finished.includes(m.name)).map(m=>m.name)});
}
