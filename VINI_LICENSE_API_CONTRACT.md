# VINI — contrato de licencias observado, no implementación

Fuente autoritativa examinada: código descargado de `vini-v2-api`, versión
`f1e869fd-59d7-4367-a04a-d2186e25c647`; hash y alcance en
[VINI_CLOUDFLARE_AUDIT.md](VINI_CLOUDFLARE_AUDIT.md).
Base utilizada por el cliente local: `https://vini-v2-api.loboangel39.workers.dev`.
No se enviaron credenciales ni se invocaron los endpoints siguientes.

## Login y validación APP

`POST /api/app/validate-license`, JSON con `licenseKey` y `hwid`.
El código limita el cuerpo a 4096 bytes, recorta strings y limita esos campos a
200 caracteres. Busca `users.license_key`; comprueba activo, bloqueo, pausa,
caducidad y coincidencia del HWID ya asociado. Puede registrar el HWID inicial.
Tiene rate limit y registra actividad: NO es una operación de lectura.

Respuesta de éxito observada en código, líneas 1251–1258:

| Campo | Significado |
|---|---|
| `valid: true` | validación aprobada en ese momento |
| `token` | credencial de sesión; no registrar ni poner en UserDefaults/logs |
| `expiresAt` | caducidad de la SESIÓN, ISO 8601, actualmente ahora + 24 h |
| `username` | nombre del usuario |
| `isPremium` | booleano derivado de `users.is_premium`; no es un nombre de plan |
| `licenseExpiresAt` | caducidad de LICENCIA o null, separada de la sesión |

Errores visibles: 400 solicitud inválida/licencia ausente, 401 licencia inválida,
403 inactivo/bloqueado/pausado/expirado/HWID distinto, 429 límite, 503 configuración
de autenticación no disponible. No se verificaron mediante requests reales.

La sesión es un formato tipo JWT con HS256 y tres segmentos, pero usa `btoa`
y un `exp` en MILISEGUNDOS desde Unix (no el NumericDate en segundos habitual).
No sustituir su codec por un validador JWT estándar sin acuerdo de compatibilidad.
El Worker verifica firma, algoritmo/tipo, expiración y usuario vigente; separa
scope app/admin mediante claves derivadas cuando existe `AUTH_JWT_SECRET`.
La ventana legacy depende de configuración que no se leyó. No se asume activa.

## Renovación y estado de licencia

No se encontró `/refresh` ni una ruta dedicada de renovación de sesión APP.
Repetir la validación existente emite otra sesión y tiene efectos de escritura.
`TokenRefreshManager.swift` del cliente local acepta `X-New-Token`, pero ese
header no se emite en el código desplegado inspeccionado: hay una discrepancia
entre la expectativa del cliente y el servidor. No confundir la operación
administrativa de renovar días de licencia con un refresh de sesión.

El Worker permite obtener usuario, `valid`, `isPremium` y expiración en el login.
No devuelve `plan` nominal ni `serverTime` explícito. El cliente local utiliza
el header HTTP `Date`; su presencia exacta no se comprobó con requests de negocio.
No hay un endpoint de perfil de solo lectura que reúna los cinco datos pedidos.

## Flujo de activación / lease ya desplegado

| Ruta POST | Entrada | Salida relevante | Efectos |
|---|---|---|---|
| `/v1/device-check` | `deviceId` | `blocked` | consulta bloqueos/global_block y actualiza device_seen |
| `/v1/activations` | `key`, `publicKey` | `activationId` | valida usuario y registra/reutiliza activación |
| `/v1/challenges` | `activationId` | `challengeId`, `nonce` | crea desafío de un uso, 5 minutos; actualiza actividad |
| `/v1/verifications` | `activationId`, `challengeId`, `signature` | `status: ACTIVE`, `lease`, `leaseSignature`; o rechazo | consume nonce y actualiza last_lease_at |

Clave de dispositivo P-256, representación pública validada por el servidor;
firma del nonce con ECDSA/SHA-256. El nonce se consume mediante UPDATE condicional
antes de aceptar la prueba. El lease se firma Ed25519 sobre el contexto
`3105-lease-v1` concatenado con sus bytes JSON.

Payload del lease: `v`, `aid`, `kid`, `iat`, `exp`, `caps`. `iat`/`exp` están en
SEGUNDOS. El `kid` identifica la clave del dispositivo; la clave pública de firma
del servidor requiere aprovisionamiento confiable, no se debe derivar de `kid`.
El código emite `caps: []`: no acredita por sí solo un plan ni un patch concreto.
TTL: usa configuración, con default 86400 s, mínimo efectivo 300 y tope 2592000;
el valor configurado no se consultó. El código del lease no limita su `exp` a
`users.license_expires_at`; esto debe resolverse antes de autorizar uso offline.

No existe un endpoint único de «renovar lease»: se obtiene otro mediante nuevo
challenge y verificación. No devuelve username, plan ni la caducidad de licencia.
El `iat` firmado ofrece una referencia temporal, no autorización para extender
la licencia con el reloj del dispositivo.

## Catálogo y paquetes ya existentes

Con Bearer APP: `GET /api/app/patches`, `GET /api/app/patches/:id` y
`GET /api/app/patches/:id/download`. La autorización depende de `user_patches`,
`userId` y `patches.active` (líneas 1270–1355).

Lista: objeto `patches` con `id`, `name`, `description`, `version`, `type`,
`status`, `created_at`, `updated_at`; el servidor también contempla campos de
material de descifrado. Descarga: bytes `.3105`, headers `X-Patch-Id`,
`X-Patch-Version`, `X-Patch-Name` y opcionalmente `X-Content-Key` /
`X-Patch-Password`. No se consultaron sus valores ni archivos. La descarga
registra una fila y por ello no se ejecutó durante la auditoría.

No hay `targetID`, `projectID` explícito, SHA-256 de paquete ni revisión de
catálogo en esa respuesta. `patches.id` es TEXT: no se presume UUID ni igualdad
con packageID interno `.3105`. Tampoco se presume que `type` equivalga a las
categorías Combat/Visuals/Offsets. Estos acuerdos faltan antes de vincular Apply.

## Revocación y dispositivo: límites observados

JWT APP vuelve a comprobar usuario, estado, clave de licencia cuando está en el
payload y caducidad de licencia (1170–1199). No vincula esa comprobación a una
activación P-256 y no compara el HWID de sesión con el HWID actual de usuario.
El reset HWID observado solo vacía `users.hwid` (1607–1610); no equivale por sí
solo a revocar todas las sesiones/activaciones previas.

El flujo v1 verifica estado de activación y usuario antes de cada lease. Borrar
activación borra desafíos asociados. `blocked_devices` y `config.global_block`
se consultan en device-check; no aparecen en `v1UserBlockedReason`, que revisa
usuario. No tratar un device-check aislado como autoridad del flujo completo:
además, ese handler devuelve `blocked: false` ante errores.

Revocación online y validez offline de un lease ya emitido son distintas. No se
ha probado el comportamiento real ni se han alterado estas reglas.
