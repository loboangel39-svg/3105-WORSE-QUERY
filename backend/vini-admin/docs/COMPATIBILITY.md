# Compatibilidad y política de conversión

No se elimina ni reconstruye `users` ni `is_premium`. Dos migraciones incrementales
añaden relaciones, metadata y tablas. No se utiliza `vini-patch-db`.

## Usuarios existentes

| Valor histórico | plan_id preparado | Campo anterior |
|---|---|---|
| is_premium = 0 | basic | se conserva 0 |
| is_premium = 1 | pro | se conserva 1 |
| otro valor / NULL | NULL, sin verificar | no se interpreta ni sobrescribe |

No se atribuye creador, fecha de emisión de licencia ni pertenencia directa sin
evidencia. Las filas anteriores reciben `origin_status=unknown`, creador NULL y
metadata de licencia vinculada a su user_id, sin una segunda clave/licencia.
Clasificar explícitamente la pertenencia después no modifica el creador original.

`license_metadata.id = license:user_id` identifica establemente la licencia del
modelo existente. La clave sigue en `users.license_key`; rotar credenciales en
una vista legacy no crea otra cuenta para representar un distribuidor. La
metadata separa creador de usuario/creador de licencia y conserva emisión cuando
es conocida. Los triggers impiden reescribir esos datos de procedencia.

Actualizaciones legacy de `is_premium` se proyectan a `plan_id`; cambios nuevos
de plan actualizan el booleano para clientes anteriores. Los derechos de paquetes
ya asignados se conservan mediante grandfathering explícito: sin una fila en
`patch_policies` sigue aplicándose el control anterior de asignación + paquete
activo. Incorporar un paquete a la nueva política es una acción explícita de
SUPER_ADMIN; entonces se exige la intersección completa de controles. Nunca se
concede una asignación por ser PRO ni se deduce plan de Combat/Visuals/Offsets.

## Contratos APP y servidor

Se conserva POST `/api/app/validate-license` y sus campos `valid`, `token`,
`expiresAt`, `username`, `isPremium`, `licenseExpiresAt`. Se añaden campos sin
quitar los anteriores. `expiresAt` sigue siendo sesión; no se confunde con licencia.
El nuevo `/api/app/me` usa el verificador APP original y no expone propietarios,
IDs administrativos ni otros clientes. Lista/detalle/descarga conservan sus rutas;
los paquetes con política explícita añaden sus restricciones de plan.

JWT APP/admin antiguos mantienen su codec, milisegundos y separación original.
Activación P-256, challenge y lease Ed25519 conservan su implementación. Los tests
validan firma real y rechazo de reutilización del nonce con claves sintéticas.
No se implementa ni promete X-New-Token: esa discrepancia anterior sigue documentada.

## Cambio de pausa aprobado expresamente

El usuario indicó conservar el tiempo que le quedaba a cada licencia —7 días a
una y 4 a otra— y reajustar al reactivar. Se reemplaza la antigua compensación
por días completos por saldo de milisegundos del servidor para TODOS los tipos
de pausa. No se altera el vencimiento al pausar. Al liberar la última causa de
pausa se escribe un nuevo vencimiento = hora servidor + saldo guardado.

Pausas anteriores se convierten desde `paused_at` y `license_expires_at` cuando
esas fechas son válidas; sin evidencia queda saldo «No verificado» y no hay
reactivación automática. Una renovación explícita puede fijar un saldo conocido.
Las licencias permanentes mantienen NULL; saldo cero no regala días.

## Límites comprobados

Solo se probó staging LOCAL con estructura auditada y filas sintéticas. No se
afirma validación de datos reales, volumen productivo, región Cloudflare remota
ni de una aplicación instalada en iPhone. El código iOS, su identidad, las bases
reales, R2 real y los mecanismos de acceso no se modificaron.

El lease offline original no limita su exp a la expiración de licencia; no se
modificó ese protocolo en esta fase. No se utiliza un lease aislado para conceder
acceso a nuevos patches: la decisión se hace online por usuario y paquete.
