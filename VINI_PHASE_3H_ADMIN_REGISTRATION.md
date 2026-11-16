# VINI Fase 3H — Registro administrativo R2

Estado: **PASS LOCAL AISLADO**. Fase 3F continúa `BLOCKED` por CI.

Se añadió al Worker local `vini-v2-api` el endpoint administrativo `POST /api/patches/register-r2`. Reutiliza la autenticación administrativa existente y no cambia el despliegue.

Flujo:

1. Valida clave `.3105` y manifiesto de identidad.
2. Obtiene el objeto exacto desde R2.
3. Calcula SHA-256 y tamaño real.
4. Inserta `patches` inicialmente inactivo.
5. Inserta `patch_targets` con revisión no activa.
6. Aplica `user_patches` explícitos.
7. Activa el patch sólo después de completar las validaciones.
8. Registra la acción mediante `logActivity`.
9. Ante error, elimina las filas parciales.

La operación es idempotente por `file_key`; una revisión activa existente para el mismo `targetID` se rechaza. No se generan IDs a partir del nombre del archivo: `packageID`, `projectID`, `targetID`, revisión y SHA deben provenir del manifiesto autorizado.

Archivos locales modificados:

- `cloudflare-audit-private/vini-v2-api/src/index.js`
- `scripts/test_phase3h_admin_runtime.mjs`

No se modificó el Worker desplegado ni D1/R2 productivos.
