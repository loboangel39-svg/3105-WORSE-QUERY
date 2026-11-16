import fs from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
const path = 'phase3g-isolated.sqlite';
const db = new DatabaseSync(path);
db.exec('PRAGMA foreign_keys=ON; CREATE TABLE patches(id TEXT PRIMARY KEY); CREATE TABLE user_patches(user_id TEXT,patch_id TEXT,PRIMARY KEY(user_id,patch_id));');
db.exec(fs.readFileSync('backend/vini-admin/migrations/0004_patch_targets.sql', 'utf8'));
db.exec(`INSERT INTO patches VALUES ('p1');
INSERT INTO patch_targets(id,patch_id,target_id,project_id,package_id,revision,sha256,file_size,category,required_plan,created_at,updated_at)
VALUES ('t1','p1','vini.esp_box','proj','pkg1',1,'${'a'.repeat(64)}',10,'visuals','basic','now','now');`);
let rejected = 0;
for (const sql of [
  `INSERT INTO patch_targets VALUES ('t2','p1','vini.esp_box','proj','pkg2',2,'${'b'.repeat(64)}',10,'visuals','basic','now','now')`,
  `INSERT INTO patch_targets VALUES ('bad','p1','vini.bad','proj','pkg3',1,'xyz',10,'visuals','basic','now','now')`,
  `INSERT INTO patch_targets VALUES ('bad2','p1','vini.bad','proj','pkg4',1,'${'c'.repeat(64)}',0,'visuals','basic','now','now')`
]) { try { db.exec(sql); } catch { rejected++; } }
if (rejected !== 3) throw new Error(`expected 3 rejected rows, got ${rejected}`);
console.log('PASS isolated migration and constraints');
db.close(); fs.unlinkSync(path);
