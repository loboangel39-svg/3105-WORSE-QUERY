# VINI 3L-B — Pruebas runtime

Estado: **BLOCKED/PARTIAL**, no se declara PASS de estados ON/Restore.

PASS estático: el dashboard consume `VINIProductionStore`; el binding solo activa con estado `applied`; no se modifican `VINITargetCard`, `VINIDashboardView`, transacciones, journals o backups. PASS de compilación del lector queda pendiente del CI de este commit.

BLOCKED: applied verificable, restore pending, restored y cambio de usuario no pueden atribuirse a targets remotos porque falta la asociación persistida exacta requerida. Un receipt incompleto, digest distinto, projectID inconsistente, journal ausente o manifest corrupto produce `unknown`, no ON.

SKIPPED deliberadamente: Apply/Restore, operaciones sobre terceros, ejecución visual en dispositivo y producción Cloudflare. No se fabricaron receipts ni manifests para obtener PASS.
