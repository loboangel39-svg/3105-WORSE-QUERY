CREATE TABLE admin_operations (id TEXT PRIMARY KEY, actor_id TEXT NOT NULL REFERENCES admin_accounts(id), idempotency_key TEXT NOT NULL, request_hash TEXT NOT NULL, action TEXT NOT NULL, selector TEXT NOT NULL, reason TEXT NOT NULL, token_hash TEXT NOT NULL, created_at TEXT NOT NULL, expires_at TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('preview','running','completed','cancelled')), revert_of TEXT REFERENCES admin_operations(id), UNIQUE(actor_id,idempotency_key));
CREATE TABLE operation_members (operation_id TEXT NOT NULL REFERENCES admin_operations(id), user_id TEXT NOT NULL REFERENCES users(id), expected_revision INTEGER NOT NULL, state TEXT NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','applied','conflict')), attempt_id TEXT, PRIMARY KEY(operation_id,user_id));
CREATE INDEX members_pending ON operation_members(operation_id,state,user_id);
CREATE TABLE pause_claims (id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id), operation_id TEXT REFERENCES admin_operations(id), actor_id TEXT, source TEXT NOT NULL CHECK(source IN ('legacy','individual','bulk')), active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)), created_at TEXT NOT NULL, released_at TEXT);
INSERT INTO pause_claims(id,user_id,source,created_at) SELECT 'legacy:'||id,id,'legacy',COALESCE(paused_at,strftime('%Y-%m-%dT%H:%M:%fZ','now')) FROM users WHERE is_paused=1;
CREATE INDEX pause_user ON pause_claims(user_id,active);
CREATE UNIQUE INDEX one_individual_pause ON pause_claims(user_id) WHERE active=1 AND source IN ('legacy','individual');
CREATE TABLE capabilities (id TEXT PRIMARY KEY, name TEXT NOT NULL);
CREATE TABLE plan_capabilities (plan_id TEXT NOT NULL REFERENCES plans(id), capability_id TEXT NOT NULL REFERENCES capabilities(id), PRIMARY KEY(plan_id,capability_id));
INSERT INTO capabilities VALUES ('general','Funciones generales'),('patch.basic','Patches BASIC'),('patch.pro','Patches PRO');
INSERT INTO plan_capabilities VALUES('basic','general'),('basic','patch.basic'),('pro','general'),('pro','patch.basic'),('pro','patch.pro');
-- Only explicitly enrolled patches adopt the new policy. Legacy rights are unchanged.
CREATE TABLE patch_policies (patch_id TEXT PRIMARY KEY REFERENCES patches(id), target_id TEXT NOT NULL UNIQUE, capability_id TEXT NOT NULL REFERENCES capabilities(id), distributor_id TEXT REFERENCES distributors(id), enabled INTEGER NOT NULL CHECK(enabled IN (0,1)), revoked INTEGER NOT NULL DEFAULT 0 CHECK(revoked IN (0,1)), compatible INTEGER NOT NULL DEFAULT 0 CHECK(compatible IN (0,1)), compatibility_description TEXT NOT NULL);
