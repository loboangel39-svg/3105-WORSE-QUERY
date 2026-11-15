# Preparación productiva — NO-GO condicionado

Fecha: 2026-11-15. Este informe no autoriza despliegue ni migraciones productivas.

## Estado observado

| Elemento | Estado |
|---|---|
| Worker productivo actual | vini-v2-api |
| Versión productiva intacta | f1e869fd-59d7-4367-a04a-d2186e25c647 |
| Deployment productivo intacto | 05f14b14-fdaa-44d9-9123-4643650f8dfe |
| DB productiva auditada, sin escrituras 2C | vini-v2-db, 3f0d818b-0648-43f9-9dbe-3ffca38d2035 |
| DB secundaria, sin cambios | vini-patch-db |
| Candidato probado | Binario experimental 2B, ampliación sobre snapshot productivo |
| SHA256 binario existente, sin rebuild 2C | 590d11619ef434b796a13f41849a06a6b5692cacd018ff275745d268ba8b0d24 |
| Versión staging con R2 | 410e07e5-80b2-4b90-81e0-432c83410da4 |
| Main remota intacta | afa5a48c96b9b8d72729f10726a274101e480592 |

Identificadores productivos se comprobaron mediante metadata. No se consultaron secretos ni paquetes productivos. No se crearon ramas main locales ni se hizo push.

## Rutas y compatibilidad

Se conservan POST /api/app/validate-license, GET /api/app/patches, GET /api/app/patches/:id, GET /api/app/patches/:id/download y /v1/activations, /v1/challenges, /v1/verifications. Se añaden /api/app/me y /api/admin-v2/* para permisos, operaciones, planes y auditoría. El panel experimental usa location.origin. Las rutas heredadas globales quedan limitadas a SUPER_ADMIN; se requiere aceptar ese endurecimiento antes de migrar clientes administrativos.

Login conserva valid, token, expiresAt, username, isPremium, licenseExpiresAt; añade plan, licenseStatus y serverTime. deviceEpoch es opaco al cliente y revoca sesiones previas al reset. No se cambia codec JWT histórico ni protocolo de leases. Nuevas políticas de paquetes son explícitas: los paquetes sin política mantienen autorización histórica, no se convierten silenciosamente en PRO.

## Sesión, licencia, lease y X-New-Token

| Concepto | Contrato vigente |
|---|---|
| Sesión APP | exp en milisegundos, login emite 24 horas; token caducado recibe 401 |
| Licencia | licenseExpiresAt; puede ser permanente; expirada/pausada/revocada/bloqueada deniega autorización online |
| Lease | exp en segundos, firmado Ed25519; staging TTL=300 s; no confundir con expiresAt del login |
| Pausa | Banco congelado; no autoriza catálogo mientras quede activa |
| Revocación/bloqueo | Estados diferentes; reactivar una pausa no los retira |

Resolución del contrato de servidor: no hay refresh endpoint ni X-New-Token; la operación histórica de revalidación/login emite token nuevo. Se verificó que rechaza sesión caducada y entrega una nueva por validate-license. No se añadirá emisión automática como función nueva de esta fase.

Límite del cliente encontrado por lectura en C:/Users/ANGEL/Downloads/NOVA VERSION VINI TOTAL: TokenRefreshManager solo guarda X-New-Token si aparece; el servidor no lo emite. LoginManager.tryAutoLogin llama login, mientras verifyLicense actualiza LicenseStateStore pero **no guarda el token del JSON**. Por ello verifyLicense no equivale a renovar una sesión almacenada. La sesión transparente durante uso prolongado sigue pendiente de resolver/validar en una futura integración cliente autorizada o de aceptar explícitamente el relogin. No se afirma corregida en iPhone.

Un lease ya emitido puede conservar una expiración posterior a la de la licencia; esa política heredada no se cambió. Su firma sigue verificándose offline tras reset/revocación online. Antes de producción, el propietario debe aceptar ese límite o autorizar otro contrato cliente/servidor. No se cambió ni asumió el TTL productivo.

## Migraciones y riesgos

Orden fijo: 0001_admin_plans.sql, 0002_operations_capabilities.sql, 0003_scoped_controls_hwid.sql. No se añadieron migraciones 2C. Añaden planes, ámbitos, propietarios, metadata inmutable, auditoría, operaciones, claims, bancos, políticas, retención y device_epoch; conservan users/is_premium. Los triggers sincronizan plan y valor histórico. La conversión de creadores/orígenes desconocidos no inventa identidad. Pausas heredadas sin fechas fiables quedan sin saldo verificable y exigen revisión explícita.

Cada archivo es una transacción independiente, con checksum en vini_admin_migrations y un apply por request. No existe una transacción conjunta de los tres archivos; un fallo exige detenerse y comprobar ledger, no ejecutar ALTER a ciegas. No aplicar baseline.sql a producción. D1 Free obliga lotes de cinco miembros; staging sintético no demuestra rendimiento al volumen productivo.

Antes de una autorización futura: exportar copia productiva y verificar su restauración en una DB independiente; revisar schema drift, triggers, campos históricos, valores desconocidos, saldos y políticas de cada patch. Las restauraciones de D1 productivo y capacidad de rollback de datos no fueron ensayadas ni se presentan como aprobadas.

## Orden propuesto, aún no ejecutado

1. Aceptación física y cierre/acuerdo de los límites anteriores; aprobar ventana, responsable y rollback.
2. Congelar escrituras administrativas y capturar backup/ledger/versiones/configuración sin guardar secretos en Git. Verificar restauración independiente.
3. Comparar esquema real con baseline auditado. Desplegar candidato con flags administrativos apagados y binding productivo aprobado explícitamente; no reutilizar config ni credenciales de staging.
4. Habilitar bootstrap solo durante migración, con principal original, manifiesto confirmado y comprobación tras cada archivo. Mantener modo administrativo de solo lectura durante aceptación.
5. Cerrar bootstrap; comprobar conteos/planes, pausas, autorización existente y pruebas sintéticas controladas. Habilitar administración únicamente después de conformidad.
6. Vigilar 401/403/429/503, latencia, conflictos e integridad del ledger. No tocar identidades iOS, App Group o entitlements.

Parar ante checksum distinto, esquema inesperado, backup no restaurable, pérdida de filas/saldos, acceso cruzado, sesión anterior válida tras reset, filtración de claves, 5xx persistentes, rechazo de clientes válidos o discrepancias de plan/pausa. No continuar por una compilación o deploy exitoso.

## Rollback probado y alcance

En staging: rollback real 410e07e5 -> 5a80a0ae, comprobación de bancos y login, restauración por versions deploy a 410e07e5; después comprobaron última reactivación, idempotencia, panel y R2. D1/claims no se revirtieron. 5a80a0ae conserva device_epoch; no usar una versión antigua que lo ignore, pues reabriría sesiones reseteadas. La versión 5a80 no tiene binding R2: una reversión a ella suspende descargas hasta restaurar una configuración compatible, límite conocido del ensayo.

Comandos comprobados, SOLO STAGING:

```powershell
wrangler rollback 5a80a0ae-d561-4c1c-a91a-00d0ccc9cfc2 --name vini-admin-plans-staging-2b --yes
wrangler versions deploy '410e07e5-80b2-4b90-81e0-432c83410da4@100' --name vini-admin-plans-staging-2b --yes
```

Para producción futura: detener mutaciones con ADMIN_READ_ONLY, preservar DB/ledger/auditoría y elegir un binario compatible con el esquema y epoch. No hacer DROP, quitar claims, restaurar una DB vieja sobre datos nuevos ni revivir activaciones para aparentar rollback. El Worker productivo anterior a las migraciones no es un rollback seguro tras reset HWID; preparar candidato compatible y ensayarlo primero. Sin autorización no se ejecuta ninguno de estos pasos productivos.
