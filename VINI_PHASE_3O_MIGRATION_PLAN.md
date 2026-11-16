# VINI 3O — Plan de migración (pendiente de autorización)

## SQL preparado

El archivo existente `backend/vini-admin/migrations/0004_patch_targets.sql`
contiene:

```sql
CREATE TABLE IF NOT EXISTS patch_targets (
  id TEXT PRIMARY KEY,
  patch_id TEXT NOT NULL REFERENCES patches(id) ON DELETE CASCADE,
  target_id TEXT NOT NULL, project_id TEXT NOT NULL, package_id TEXT NOT NULL,
  revision INTEGER NOT NULL CHECK (revision > 0),
  sha256 TEXT NOT NULL CHECK (length(sha256)=64 AND sha256 NOT GLOB '*[^0-9A-Fa-f]*'),
  file_size INTEGER NOT NULL CHECK (file_size > 0),
  category TEXT NOT NULL CHECK (category IN ('combat','visuals','offsets')),
  required_plan TEXT NOT NULL CHECK (required_plan IN ('basic','pro')),
  authorization_status TEXT NOT NULL DEFAULT 'authorized',
  enabled INTEGER NOT NULL DEFAULT 1, revoked INTEGER NOT NULL DEFAULT 0,
  active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  UNIQUE(target_id, revision), UNIQUE(package_id)
);
```

También crea índices por patch y target y una única revisión activa/autorizada.

## Backfill seguro

No existe un backfill automático seguro desde nombres de archivo. Cada fila debe
ser generada por un proceso autorizado que lea el objeto R2, verifique SHA-256,
inspeccione el paquete con `PatchPackageCodec` y confirme `packageID` y
`projectID`. La asociación de usuario permanece separada en `user_patches`.

Si un paquete no tiene identidad interna verificable, clave autorizada o tamaño
consistente, queda fuera del backfill y no aparece como target.

## Cambio mínimo del Worker

1. Ejecutar la migración en una D1 aislada.
2. Añadir un `LEFT/INNER JOIN patch_targets` condicionado a target activo,
   autorizado, no revocado, compatible con `patches.active` y el plan del
   usuario.
3. Serializar `target` solo cuando la fila esté completa.
4. Mantener campos y rutas antiguas.
5. Mantener `X-Content-Key` solo en descarga autenticada y nunca incluir
   contraseña en JSON/logs.

## Rollback

No desplegar hasta validar fixtures. El rollback es revertir el código del
handler y eliminar únicamente filas/tablas de la D1 aislada. En producción,
la migración requiere snapshot/export y autorización explícita; no se ejecutó.
