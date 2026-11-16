# VINI 3O — Compatibilidad y pruebas

## Resultado local

**PASS — 54 grupos** mediante `npm test` en `backend/vini-admin`.

Cubierto con datos sintéticos:

- Login APP válido y separación administrativa.
- Catálogo sin asignación y catálogo con `user_patches`.
- BASIC/PRO como intersección de plan y asignación, no acceso global.
- Parche deshabilitado/revocado y descarga denegada sin efectos secundarios.
- Rutas antiguas de autenticación, catálogo y descarga.
- Reinicio de Miniflare y persistencia D1/R2 aislada.
- No exposición de credenciales en auditoría.

## Pendiente/BLOCKED

- `patch_targets` en D1 productiva: **BLOCKED**, no existe según evidencia
  previa y no se ejecutó migración.
- Catálogo autorizado real del Worker: **BLOCKED**, GET sin sesión responde 401.
- Backfill de paquetes R2 reales: **SKIPPED**, requiere claves/identidad autorizadas.
- Compatibilidad contra despliegue actual autenticado: **SKIPPED**, no se usaron
  credenciales reales.

## Hashes protegidos

No se modificaron motores, codec, transacciones, backups, journals, Bundle ID,
App Group ni entitlements. La migración y el Worker solo están preparados en
fuentes locales; no hay cambio productivo que reportar.

## Autorización requerida

Antes de ejecutar migración o despliegue se necesita autorización explícita
para: D1 `vini-v2-db`, R2 `vini-patches`, backfill de cada paquete verificado y
publicación del Worker `vini-v2-api`.
