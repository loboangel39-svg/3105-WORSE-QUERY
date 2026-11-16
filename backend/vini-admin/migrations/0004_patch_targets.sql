-- Fase 3G: target dinámico para el Worker principal.
-- Ejecutar únicamente en una D1 aislada durante esta fase.
CREATE TABLE IF NOT EXISTS patch_targets (
  id TEXT PRIMARY KEY,
  patch_id TEXT NOT NULL REFERENCES patches(id) ON DELETE CASCADE,
  target_id TEXT NOT NULL,
  project_id TEXT NOT NULL,
  package_id TEXT NOT NULL,
  revision INTEGER NOT NULL CHECK (revision > 0),
  sha256 TEXT NOT NULL CHECK (length(sha256) = 64 AND sha256 NOT GLOB '*[^0-9A-Fa-f]*'),
  file_size INTEGER NOT NULL CHECK (file_size > 0),
  category TEXT NOT NULL CHECK (category IN ('combat','visuals','offsets')),
  required_plan TEXT NOT NULL CHECK (required_plan IN ('basic','pro')),
  authorization_status TEXT NOT NULL DEFAULT 'authorized'
    CHECK (authorization_status IN ('authorized','revoked')),
  enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0,1)),
  revoked INTEGER NOT NULL DEFAULT 0 CHECK (revoked IN (0,1)),
  active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE (target_id, revision),
  UNIQUE (package_id)
);

CREATE INDEX IF NOT EXISTS patch_targets_patch_idx ON patch_targets(patch_id);
CREATE INDEX IF NOT EXISTS patch_targets_lookup_idx ON patch_targets(target_id, active, authorization_status);
CREATE UNIQUE INDEX IF NOT EXISTS patch_targets_one_active_revision
  ON patch_targets(target_id)
  WHERE active = 1 AND authorization_status = 'authorized';
