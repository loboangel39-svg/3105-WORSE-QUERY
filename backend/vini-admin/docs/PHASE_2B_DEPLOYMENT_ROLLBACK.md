# Staging desplegado y procedimiento de reversión

## Estado entregado

Worker vini-admin-plans-staging-2b, URL https://vini-admin-plans-staging-2b.loboangel39.workers.dev/admin.
D1 vini-admin-plans-staging-2b-db, UUID cd4adf09-e968-455b-8825-5832bc5ed2c5. Versión final 5a80a0ae-d561-4c1c-a91a-00d0ccc9cfc2; deployment 1c4d3857-9cd6-43b5-b326-22b4c1c99489.

El principal de ensayo es staging-owner. Su contraseña se conserva cifrada con DPAPI de Windows fuera de Git; no se incluyen secretos productivos. El archivo de acceso de la entrega contiene solo la contraseña de este principal, cifrada para el usuario Windows actual. No compartir secretos ni guardar archivos descifrados en el repositorio.

## Reproducción de build y despliegue (solo staging)

Desde backend/vini-admin, con dependencias bloqueadas en package-lock.json y sesión Wrangler autorizada:

```powershell
node scripts/build.mjs
node scripts/verify-stage-config.mjs
wrangler deploy --config wrangler.remote-staging.jsonc
```

El guard debe aprobar antes de cualquier deploy. No sustituir nombres, bindings o UUID por producción. La configuración no contiene R2 ni rutas productivas. No importar otra vez baseline ni repetir ALTER TABLE en esta D1: las tres migraciones ya están aplicadas y constan en el ledger. El bootstrap queda desactivado. Una instalación nueva requiere D1 nueva, baseline de esquema sin filas reales, secretos nuevos y bootstrap expresamente habilitado de forma temporal; aplicar cada migración con su manifiesto hasta remaining vacío y cerrar inmediatamente el flag. No ejecutar ese procedimiento contra bases productivas.

## Reversión segura

Primero detener nuevas mutaciones administrativas con ADMIN_READ_ONLY=1 y conservar DB/ledger/auditoría. Para revertir presentación puede desplegarse el artefacto previo compatible con las tres migraciones; la versión backend probada 2fdebded-ef21-42ae-8abb-87cf8e86f4c9 es la referencia. Mantener ADMIN_MIGRATIONS_ENABLED=0. No hacer downgrade a un Worker que ignore device_epoch tras resetear dispositivos, pues permitiría sesiones antiguas. No ejecutar DROP, restaurar una DB anterior sobre la actual ni borrar claims para simular una reversión.

Los efectos ya confirmados se revierten mediante operaciones nuevas autorizadas cuando exista inversa, conservando auditoría. Una baja lógica, revocación o reset no debe deshacerse automáticamente ni reactivar sesiones revocadas. Antes de cualquier eliminación de recursos de staging, exportar evidencia y obtener instrucción del propietario; esta entrega no elimina nada.

## Producción

No desplegada. Un paso productivo requiere autorización explícita, copia de seguridad, revisión de migraciones/contratos y plan de aceptación física. Estos documentos no constituyen autorización para hacerlo.
