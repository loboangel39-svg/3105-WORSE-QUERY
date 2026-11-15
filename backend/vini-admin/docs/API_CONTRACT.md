# Contrato API experimental

No desplegado. Las rutas nuevas solo funcionan con `ADMIN_PLANS_ENABLED=1`, tras
las migraciones. JSON, Bearer, respuestas sin caché. APIs administrativas rechazan
Origin ajeno; no usan cookies. No enviar tokens/claves a logs ni informes.

## APP

POST `/api/app/validate-license` conserva entrada y campos anteriores, incluido
`isPremium`, y añade `plan`, `licenseStatus`, `serverTime`. `expiresAt` es sesión;
`licenseExpiresAt` es licencia. No se cambia el codec de token anterior.

GET `/api/app/me`, con Bearer APP, devuelve exclusivamente:

```json
{"username":"nombre","plan":"basic","licenseStatus":"active","licenseExpiresAt":null,"serverTime":"fecha ISO 8601 del servidor"}
```

Plan histórico sin clasificación = null. Las sesiones/licencias no válidas reciben
401 según el verificador existente, sin datos administrativos ni de terceros.
No existe un nuevo refresh: permanece el contrato anterior de revalidación.
Las rutas anteriores de catálogo/detalle/descarga se conservan; patches inscritos
en política requieren la intersección de plan, asignación, disponibilidad,
revocación, compatibilidad declarada y ámbito del distribuidor.

## Administración `/api/admin-v2`

| Método/ruta | Contrato |
|---|---|
| POST /login | username/password de cuenta nominal; token administrativo de 1 h |
| GET /me | actor, rol, acciones y ámbitos; nunca hash/sal de contraseña |
| GET /users | group=all/direct/unknown/distributor, distributorId, plan, status, search, creator, expiresBefore/After, createdBefore/After; limit 1–200 y offset |
| POST /users | username, plan basic/pro, distributorId opcional, licenseExpiresAt ISO o null; devuelve licencia emitida una vez |
| PATCH /users/:id | username/plan; rechaza creador y campos que necesitan operaciones dedicadas |
| POST /users/:id/renew | licenseExpiresAt; restoreArchived=true explícito para desarchivar y renovar con permisos renew + reactivate |
| POST /users/:id/transfer | distributorId o null; solo SUPER_ADMIN, historial sin reescribir creador |
| GET/POST /distributors | lista con conteos exclusivos por estado / creación de distribuidor |
| PATCH /distributors/:id | status active/suspended; controla acceso administrativo, no pausa clientes implícitamente |
| GET/POST /administrators | solo SUPER_ADMIN; creación con role, actions, scopes y distributorId cuando corresponda |
| POST /administrators/:id/disable | invalida sesiones; no permite deshabilitarse a sí mismo ni bootstrap |
| GET /plans | basic/BASIC y pro/PRO |
| GET/PUT /patch-policies | solo SUPER_ADMIN; patchId,targetId,capabilityId,distributorId opcional,enabled,revoked,compatible,compatibilityDescription |
| GET/PUT /retention | solo SUPER_ADMIN; enabled booleano y days 90–3650; no lanza limpieza |
| GET /audit?userId=... | historial del usuario dentro del ámbito permitido |

Históricos con creador desconocido siguen NULL. El servidor decide creador y
pertenencia, nunca los acepta como atribución arbitraria del cliente.
Las vistas globales legacy quedan reservadas a SUPER_ADMIN. Se mantienen sus
rutas, con creación adaptada y borrado sustituido por archivado de expirados.

## Operaciones confirmadas

POST `/operations/preview`:

```json
{"action":"pause","selection":{"group":"distributor","distributorId":"UUID"},"reason":"manual","idempotencyKey":"ID único del intento"}
```

Acciones: pause, pause_individual, resume_individual, reverse_pause, archive,
revoke, purge. Reversión requiere revertOf con ID de pausa masiva original.
Selección manual: group=selected e ids (hasta 50 por request); ámbitos completos
se congelan mediante SQL sin truncar el conjunto. Se aplican también los filtros
del listado. Motivos son códigos: manual, maintenance, distributor_pause,
expired_cleanup, license_revocation, support; no texto libre con claves privadas.

Devuelve id, ámbito, cantidad exacta, caducidad de preview (15 min) y
confirmationToken. No modifica licencias. GET `/operations/:id/members` permite
revisar el snapshot, 100 registros por página y offset.

POST `/operations/:id/execute` requiere confirmationToken, procesa hasta 10 usuarios
en una transacción D1 y devuelve estado/resultados. Repetir la misma operación no
repite efectos. La revisión de cada usuario y los permisos se comprueban en SQL;
renovaciones o transferencias concurrentes se informan como conflict.

GET `/operations`, GET `/operations/:id`: informes. SUPER_ADMIN ve todas; otros
actores solo las propias. Solo su creador puede ejecutar/reanudar pendientes.
POST `/operations/:id/reconfirm` recupera confirmación para el creador sin cambiar
usuarios; exige nueva revisión administrativa en el panel. POST `/cancel` cancela
pendientes, conservando y permitiendo revertir lo ya aplicado.

Estados: preview, running, completed, cancelled. Resultados: pending, applied,
conflict. Un applied en reactivación individual no significa «sin ninguna pausa»:
otras causas pueden seguir activas, y el usuario permanece pausado.

## Migración y errores

GET `/migrations/preview` y POST `/migrations/apply` requieren
`ADMIN_MIGRATIONS_ENABLED=1` y token del principal legacy verificado. Apply exige
manifestHash y confirm=true; solo aplica los dos SQL empaquetados, no SQL arbitrario.
No aceptar tokens APP ni nominales para bootstrap.

400/415 solicitud inválida; 401 sesión inválida; 403 acción/ámbito/confirmación
insuficiente; 404 recurso no visible; 409 estado/revisión/caducidad conflictiva;
429 rate limit; 503 mantenimiento o fallo de servicio. No se devuelven SQL ni
datos de credenciales en errores. `ADMIN_READ_ONLY=1` bloquea escrituras admin
conservando autenticación APP y controles de catálogo.
