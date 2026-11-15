# VINI — auditoría Cloudflare, Fase 1

Fecha: 2026-11-15, America/Lima. Investigación y documentación exclusivamente.

## Procedencia y acceso

La referencia local y remota `experiment/vini-silent-restore-dual-backup` estaba
en `0959a411fdcb383351f1df6a33f1ddec35a08716`: no había commits posteriores en esa
rama al iniciar. Se creó `experiment/vini-cloudflare-integration` desde esa base.
`main` remota estaba en `afa5a48c96b9b8d72729f10726a274101e480592`.

La búsqueda de plugins «Cloudflare Workers D1» no devolvió un conector disponible.
Se utilizó Wrangler oficial instalado, versión 4.129.0, con una sesión OAuth ya
autorizada. No se pidió otro login ni un token. Esa sesión tiene permisos de
escritura preexistentes; no se solicitaron permisos adicionales ni se utilizaron
para modificar infraestructura. La restricción de lectura en esta fase es
operativa, no un nuevo token técnicamente limitado a lectura.

## Worker y API identificados

| Elemento | Evidencia |
|---|---|
| Worker principal identificado | `vini-v2-api`, confirmado por API de despliegues de Wrangler |
| Base API del cliente VINI APP encontrado | `https://vini-v2-api.loboangel39.workers.dev` |
| Panel del mismo Worker | rutas `/admin`, `/admin.html`, `/admin/` en su código |
| Dominio personalizado | no confirmado; configuración descargada sin `routes`, `workers_dev: true` |
| Binding `DB` desplegado | `vini-v2-db`, UUID `3f0d818b-0648-43f9-9dbe-3ffca38d2035` |
| Otro almacenamiento | binding `R2` existente; no se listaron ni descargaron paquetes |
| Deployment observado | `05f14b14-fdaa-44d9-9123-4643650f8dfe`, 2026-11-13T01:11:55.115385Z |
| Versión con 100 % de tráfico | `f1e869fd-59d7-4367-a04a-d2186e25c647` |

La versión se volvió a consultar al terminar la inspección del código y seguía
siendo la misma. No se ejecutaron requests contra endpoints de negocio: su
existencia y contratos se verificaron en el código descargado, no mediante un
login funcional ni con credenciales de un usuario.

## Evidencias examinadas

1. Copia local de VINI APP:
   `C:\Users\ANGEL\Downloads\NOVA VERSION VINI TOTAL`.
   `ThreeOneOSFive/helpers/LoginManager.swift` usa la API anterior y guarda token,
   licencia, usuario y HWID mediante Keychain. `LicenseStateStore` interpreta
   `licenseExpiresAt` y usa el header HTTP `Date` como referencia de reloj.
   `Patches/RemotePatchService.swift` usa Bearer y el catálogo existente.
2. Worker local de esa copia: `vini-v2-cloudflare/worker/index.js`, SHA-256
   `9ca69b091750de61c3ea85cb0dcf8c774050ae6a2461021ff4ea636517d113c8`.
   Es anterior y NO se usó como autoridad del comportamiento vigente.
3. Worker desplegado descargado con
   `wrangler init --from-dash vini-v2-api --delegate-c3=false` en un directorio
   privado de trabajo, fuera del repositorio. Se comprobó previamente que ese
   modo descarga código/configuración, sin delegar a C3, instalar ni desplegar.
   `src/index.js`: SHA-256
   `f58e27e36f41219d68f7ed3469fcb75c0d88d2fbf6b209ce4deb592920906122`.
   Líneas citadas en los informes se refieren a esta copia descargada.
4. Introspección remota de las DOS bases VINI: `sqlite_schema`, columnas sin
   valores por defecto y `PRAGMA foreign_key_list`. No se leyeron filas de negocio.

La copia descargada y su configuración NO se añaden a Git: los informes contienen
solo nombres de campos, rutas, hashes de fuente y metadatos de infraestructura.
No se consultaron valores de secretos ni se exportaron usuarios, claves de
licencia, contraseñas, tokens, HWID, claves de paquetes o registros de actividad.

## Funciones existentes y pendientes

| Función | Resultado de la inspección |
|---|---|
| Login / validación de licencia APP | existe `POST /api/app/validate-license` |
| Login administrador | existe `POST /api/admin/login`; separado de APP, no usar en el iPhone |
| Sesión APP | token firmado, expiración de sesión de 24 h en el código |
| Renovación de token | revalidación de licencia puede emitir otro token; no se encontró ruta dedicada de refresh |
| Refresh por header | el cliente espera `X-New-Token`, pero el Worker vigente no contiene esa emisión |
| Activación ligada a clave de dispositivo | existe `/v1/activations`, con claves públicas P-256 |
| Challenge y lease firmado | existen `/v1/challenges` y `/v1/verifications`; firma Ed25519 del lease |
| Revocación y expiración | verificadas en el código, con diferencias entre JWT, lease y bloqueo global |
| Catálogo y descarga `.3105` | existen lista, detalle y descarga bajo `/api/app/patches` |
| Descripción de patch | existe en `patches.description` y en respuesta del catálogo |
| Tabla de planes | no existe en ninguna de las dos bases inspeccionadas |
| Plan | `users.is_premium` en v2; `licenses.tier` en la otra base. No son un catálogo unificado de planes |
| Perfil con usuario + plan nominal + estado + expiración + hora explícita | no se encontró una respuesta que reúna los cinco campos |
| Contrato propuesto en 3105 | `VINIRemoteContract.swift` es inerte y no coincide directamente con la API vigente |

`vini-patch-db` también contiene usuarios y licencias. No está enlazada al binding
DB del Worker v2 examinado. Su Worker consumidor y su vigencia funcional no se
confirmaron; no se deduce un nombre de Worker a partir del nombre de la base.
No se deben combinar identidades o derechos de ambas bases por coincidencia de
nombres. El esquema por sí solo no prueba qué aplicación usa cada registro.

## Límites y seguridad de la inspección

Los endpoints de login, activación, challenge y verificación escriben estado;
incluso `GET /api/app/patches/:id/download` inserta una fila de descarga. Por ello
no se invocaron, tampoco con licencias ficticias. Las consultas D1 exitosas
devolvieron `changes: 0`, `rows_written: 0`, `changed_db: false`.

Una consulta de claves foráneas con función table-valued fue rechazada por D1
con `SQLITE_AUTH`/7500. No se elevaron permisos: se usó el `PRAGMA` de lectura
documentado, que funcionó. No hubo migraciones, exportaciones, SQL de escritura,
deploy, creación de recursos, cambios de configuración ni compilación de iOS.

Los hallazgos de contratos y riesgos son de revisión de fuente/esquema. No se
certificó la autenticación con un dispositivo, el contenido efectivo de variables
secretas ni el estado de licencias reales. Final de Fase 1; Fase 2 no iniciada.

## Referencias oficiales de metodología

- [Introspección SQL D1](https://developers.cloudflare.com/d1/sql-api/sql-statements/).
- [Recursos Workers API](https://developers.cloudflare.com/api/resources/workers/).
- [Metadatos de scripts](https://developers.cloudflare.com/api/resources/workers/subresources/scripts/subresources/settings/methods/get/).

Estas referencias explican las herramientas; la evidencia específica de VINI
proviene de la sesión autorizada y del código/esquema observados.
