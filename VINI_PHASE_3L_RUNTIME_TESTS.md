# VINI 3L-B — Pruebas runtime

Estado: **BLOCKED/PARTIAL**, no se declara PASS de estados ON/Restore.

CI de validación nativa: commit `017ea41`, run `43813500959` — **PASS**: https://github.com/loboangel39-svg/3105-WORSE-QUERY/actions/runs/43813500959. Pasaron el harness nativo, fixtures 3J/3K, compilación unsigned `iphoneos arm64` y publicación de artefactos.

PASS estático: el dashboard consume `VINIProductionStore`; el binding solo activa con estado `applied`; no se modifican `VINITargetCard`, `VINIDashboardView`, transacciones, journals o backups. PASS de compilación del lector queda pendiente del CI de este commit.

BLOCKED: applied verificable, restore pending, restored y cambio de usuario no pueden atribuirse a targets remotos porque falta la asociación persistida exacta requerida. Un receipt incompleto, digest distinto, projectID inconsistente, journal ausente o manifest corrupto produce `unknown`, no ON.

SKIPPED deliberadamente: Apply/Restore, operaciones sobre terceros, ejecución visual en dispositivo y producción Cloudflare. No se fabricaron receipts ni manifests para obtener PASS.

La validación de estados reales continúa **BLOCKED** por la ausencia de una asociación persistida exacta entre `targetID` remoto y la operación local; el CI confirma compilación/regresión, no demuestra ON ni `restorePending` remoto.
