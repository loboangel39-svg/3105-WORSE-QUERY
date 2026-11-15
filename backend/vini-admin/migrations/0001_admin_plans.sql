-- Apply with a migration ledger: one atomic D1 batch per migration.
-- No production database identifier or credential is embedded here.
CREATE TABLE plans (id TEXT PRIMARY KEY, name TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)));
INSERT INTO plans(id,name) VALUES ('basic','BASIC'),('pro','PRO');
CREATE TABLE distributors (id TEXT PRIMARY KEY, name TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('active','suspended')), created_at TEXT NOT NULL, created_by TEXT NOT NULL, updated_at TEXT NOT NULL);
CREATE TABLE admin_accounts (id TEXT PRIMARY KEY, username TEXT NOT NULL UNIQUE, role TEXT NOT NULL CHECK(role IN ('SUPER_ADMIN','ADMIN','DISTRIBUTOR')), distributor_id TEXT REFERENCES distributors(id), status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','disabled')), password_salt TEXT, password_hash TEXT, password_iterations INTEGER, session_epoch INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL, CHECK(role!='DISTRIBUTOR' OR distributor_id IS NOT NULL));
INSERT INTO admin_accounts(id,username,role,created_at) VALUES ('legacy-super','[existing Worker administrator]','SUPER_ADMIN',strftime('%Y-%m-%dT%H:%M:%fZ','now'));
CREATE TABLE admin_scopes (admin_id TEXT NOT NULL REFERENCES admin_accounts(id), scope_key TEXT NOT NULL, PRIMARY KEY(admin_id,scope_key));
CREATE TABLE admin_actions (admin_id TEXT NOT NULL REFERENCES admin_accounts(id), action TEXT NOT NULL, PRIMARY KEY(admin_id,action));
ALTER TABLE users ADD COLUMN plan_id TEXT REFERENCES plans(id);
ALTER TABLE users ADD COLUMN created_by_admin_id TEXT REFERENCES admin_accounts(id);
ALTER TABLE users ADD COLUMN distributor_id TEXT REFERENCES distributors(id);
ALTER TABLE users ADD COLUMN origin_status TEXT NOT NULL DEFAULT 'unknown' CHECK(origin_status IN ('unknown','known'));
ALTER TABLE users ADD COLUMN archived_at TEXT;
ALTER TABLE users ADD COLUMN archive_previous_active INTEGER;
ALTER TABLE users ADD COLUMN purged_at TEXT;
ALTER TABLE users ADD COLUMN revoked_at TEXT;
ALTER TABLE users ADD COLUMN pause_remaining_ms INTEGER;
ALTER TABLE users ADD COLUMN pause_remaining_known INTEGER NOT NULL DEFAULT 0 CHECK(pause_remaining_known IN (0,1));
ALTER TABLE users ADD COLUMN admin_revision INTEGER NOT NULL DEFAULT 0;
-- Explicit legacy conversion; unknown historical premium values remain unresolved.
UPDATE users SET plan_id=CASE WHEN is_premium=0 THEN 'basic' WHEN is_premium=1 THEN 'pro' ELSE NULL END;
-- User-approved remaining-time policy. Existing pauses use their recorded start;
-- missing/invalid historic evidence remains unknown and cannot be auto-resumed.
UPDATE users SET pause_remaining_known=CASE WHEN license_expires_at IS NULL OR (julianday(license_expires_at) IS NOT NULL AND julianday(paused_at) IS NOT NULL) THEN 1 ELSE 0 END,pause_remaining_ms=CASE WHEN license_expires_at IS NULL THEN NULL WHEN julianday(license_expires_at) IS NOT NULL AND julianday(paused_at) IS NOT NULL THEN MAX(0,ROUND((julianday(license_expires_at)-julianday(paused_at))*86400000)) ELSE NULL END WHERE is_paused=1;
CREATE TABLE license_metadata (id TEXT PRIMARY KEY, user_id TEXT NOT NULL UNIQUE REFERENCES users(id), created_by_admin_id TEXT REFERENCES admin_accounts(id), distributor_id TEXT REFERENCES distributors(id), issued_at TEXT, plan_id TEXT REFERENCES plans(id));
INSERT INTO license_metadata(id,user_id,plan_id) SELECT 'license:'||id,id,plan_id FROM users;
CREATE TABLE admin_audit (id TEXT PRIMARY KEY, actor_id TEXT NOT NULL, user_id TEXT, license_id TEXT, operation_id TEXT, action TEXT NOT NULL, details TEXT NOT NULL, created_at TEXT NOT NULL);
CREATE TABLE admin_retention (id INTEGER PRIMARY KEY CHECK(id=1), enabled INTEGER NOT NULL CHECK(enabled IN (0,1)), days INTEGER NOT NULL CHECK(days>=90), updated_by TEXT, updated_at TEXT NOT NULL);
INSERT INTO admin_retention VALUES(1,0,365,NULL,strftime('%Y-%m-%dT%H:%M:%fZ','now'));
CREATE TABLE admin_login_attempts (subject TEXT NOT NULL, window INTEGER NOT NULL, count INTEGER NOT NULL, PRIMARY KEY(subject,window));
CREATE INDEX users_admin_scope ON users(distributor_id,origin_status,purged_at);
CREATE INDEX users_admin_plan ON users(plan_id,license_expires_at);
CREATE INDEX users_admin_creator ON users(created_by_admin_id,created_at);
CREATE INDEX audit_user ON admin_audit(user_id,created_at);
CREATE INDEX audit_operation ON admin_audit(operation_id);
CREATE TRIGGER user_creator_immutable BEFORE UPDATE OF created_by_admin_id ON users WHEN OLD.created_by_admin_id IS NOT NEW.created_by_admin_id BEGIN SELECT RAISE(ABORT,'creator is immutable'); END;
CREATE TRIGGER license_creator_immutable BEFORE UPDATE OF created_by_admin_id,issued_at ON license_metadata WHEN OLD.created_by_admin_id IS NOT NEW.created_by_admin_id OR OLD.issued_at IS NOT NEW.issued_at BEGIN SELECT RAISE(ABORT,'license provenance is immutable'); END;
CREATE TRIGGER audit_no_update BEFORE UPDATE ON admin_audit BEGIN SELECT RAISE(ABORT,'audit is append only'); END;
CREATE TRIGGER audit_no_delete BEFORE DELETE ON admin_audit BEGIN SELECT RAISE(ABORT,'audit is append only'); END;
CREATE TRIGGER premium_to_plan AFTER UPDATE OF is_premium ON users WHEN NEW.is_premium IS NOT OLD.is_premium BEGIN UPDATE users SET plan_id=CASE WHEN NEW.is_premium=0 THEN 'basic' WHEN NEW.is_premium=1 THEN 'pro' ELSE NULL END WHERE id=NEW.id; END;
CREATE TRIGGER plan_to_premium AFTER UPDATE OF plan_id ON users WHEN NEW.plan_id IS NOT OLD.plan_id AND NEW.plan_id IN ('basic','pro') BEGIN UPDATE users SET is_premium=CASE NEW.plan_id WHEN 'pro' THEN 1 ELSE 0 END WHERE id=NEW.id; END;
CREATE TRIGGER license_projection AFTER UPDATE OF plan_id,distributor_id ON users BEGIN UPDATE license_metadata SET plan_id=NEW.plan_id,distributor_id=NEW.distributor_id WHERE user_id=NEW.id; END;
CREATE TRIGGER user_revision AFTER UPDATE OF username,hwid,license_key,is_premium,plan_id,distributor_id,is_active,is_paused,is_blocked,license_expires_at,archived_at,purged_at,revoked_at,pause_remaining_ms,pause_remaining_known ON users BEGIN UPDATE users SET admin_revision=admin_revision+1 WHERE id=NEW.id; END;
