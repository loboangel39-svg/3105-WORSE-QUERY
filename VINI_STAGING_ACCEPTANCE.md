# VINI — aceptación Fase 2C

Fecha: 2026-11-15. Base: 482997b01a0cf6d36eca68fc316e717c771ce9ba.
Rama: experiment/vini-admin-plans-distributors. No se creó otra rama.

## Resultado

Aceptación técnica del backend y panel con evidencia satisfactoria; aceptación integral y paso productivo **condicionados**, no aprobados todavía. Faltan ejecución física, importación con el codec nativo y acuerdo de renovación de sesión del cliente. No se generó una IPA supuestamente conectada. No se reconstruyó el Worker ni se cambiaron sus fuentes, panel, algoritmos o migraciones.

El usuario autorizó expresamente añadir R2 y ensayar reversión exclusivamente en staging. La primera solicitud de despliegue fue rechazada automáticamente por la ambigüedad de «no desplegar nada»; no se ejecutó. Solo se continuó después de recibir esa autorización específica. Producción no se modificó.

## Identificadores

| Recurso | Identificador |
|---|---|
| Worker staging | vini-admin-plans-staging-2b |
| Panel | https://vini-admin-plans-staging-2b.loboangel39.workers.dev/admin |
| D1 staging | vini-admin-plans-staging-2b-db |
| UUID D1 | cd4adf09-e968-455b-8825-5832bc5ed2c5 |
| R2 exclusivo de prueba | vini-admin-plans-staging-2c |
| Versión final staging, 100 % | 410e07e5-80b2-4b90-81e0-432c83410da4 |
| Deployment final | 1736b6fe-2468-465a-b1c3-ea8dd48f8375 |

Rutas productivas ausentes en config; DB y R2 están fijados por allowlist del guard. Bootstrap permanece cerrado (404). No se copiaron filas, paquetes o secretos productivos. Datos TEST2C y anteriores TEST2B son sintéticos. Se conserva evidencia para revisión; no se borraron recursos ni licencias originales.

## Evidencia reutilizada sin repetir

Entrega 2B: 54 grupos locales workerd/D1 y 18 casos remotos aprobados; panel Edge real aprobado para SUPER_ADMIN y DISTRIBUTOR, navegación por ámbito, estados, confirmación y restricciones visuales. Las fuentes y HTML del panel no cambian en 2C y su hash servido volvió a comprobarse. Incluyen BASIC/PRO, manipulación de IDs ajenos, pausa global/distribuidor/individual, superposición, idempotencia, renovación en pausa, archivado, reset HWID y auditoría.

## Evidencia nueva

acceptance-2c-results.json contiene diez grupos aprobados (el décimo prepara el objeto ausente; su 404 se comprueba en el probe separado). Seis se reutilizaron al continuar desde la prueba séptima. Cobertura: campos históricos, plan, sesión caducada, revalidación, ausencia X-New-Token, estados diferenciados, separación APP/admin, Origin, entrada inválida, rate limits, lease firmado y replay, bancos siete/cuatro días, R2/autorizaciones, descarga íntegra e interrupción.

probe-2c-before-rollback.json: objeto ausente 404 y dos bancos intactos. probe-2c-rolled-back.json: dos bancos intactos después de reversión real del Worker. probe-2c-restored.json: última reactivación con hora servidor e idempotencia para ambos saldos. post-rollback-2c-results.json: panel/404 bootstrap, aislamiento de directos y R2 íntegro tras restauración. Ningún fallo final en estos informes.

Dos errores del ensayo se corrigieron sin tocar el servidor: reloj local distinto al servidor y referencia servidor demasiado antigua antes de medir el banco. Se usó exp=1 para sesión inequívocamente caducada y serverTime reciente para cada licencia. Los grupos ya aprobados no se repitieron.

## Límites de aceptación

No se ejecutaron simuladores ni pruebas físicas. El transporte .3105 conserva bytes y un fixture sintético tiene estructura/criptografía compatibles con el código inspeccionado; falta decodificarlo con Swift en iPhone. La copia anterior del cliente apunta a producción y su helper de verificación no guarda el token emitido: no se presenta como renovación transparente resuelta. Ver los otros cinco informes para controles, criterios de parada y procedimiento físico.

La entrega contiene JSON originales, fixture, manifest SHA256, ZIP fuente y rutas absolutas en ENTREGA.md. Este documento no autoriza producción.
