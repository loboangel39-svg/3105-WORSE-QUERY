# VINI Fase 3I — Compatibilidad y rollback

- La respuesta antigua `{ "patches": [...] }` permanece intacta.
- `target` sólo se añade cuando existe una asociación completa y autorizada.
- `content_key` y contraseñas no se incluyen en logs del arnés.
- Las rutas `/api/app/validate-license`, `/api/app/patches`, detalle y descarga conservan su forma.
- `enabled/revoked` son estados adicionales; `active/authorization_status` se mantienen para compatibilidad.

Rollback local: revertir el cambio de `src/index.js` y eliminar las filas de `patch_targets`/patches de la D1 aislada. No se ejecutó ninguna migración ni despliegue productivo.

Riesgo residual: el cambio de estado entre catálogo y descarga se maneja rechazando la descarga, pero no existe una transacción distribuida D1/R2; esto debe conservarse como comportamiento seguro.
