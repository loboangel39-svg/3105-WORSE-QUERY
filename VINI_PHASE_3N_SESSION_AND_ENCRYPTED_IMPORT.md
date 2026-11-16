# VINI 3N — Sesión e importación cifrada

## Sesión

`Sesión conservada · conexión pendiente` se origina en
`VINIProductionStore.refresh` cuando una revalidación de foreground devuelve
`offline`, `rateLimited` o `stale`. Ese estado ya no invalida la sesión válida;
se conserva `.authorized`, el perfil y el deadline. La renovación 401 sigue
pasando por `VINIStagingClient.profile(forceRevalidation: true)` y un rechazo
real del Worker continúa denegando acceso.

## Descarga

`VINIStagingHTTP` ya no usa `VINIStagingEnvironment.fixtureSize` para paquetes
de producción. Las descargas tienen un límite general de 64 MiB, además de
validación posterior de `fileSize` autorizado y SHA-256.

## Clave autorizada

El snapshot local del Worker principal confirma `X-Content-Key` en la respuesta
de `/api/app/patches/:id/download`, derivado de `content_key` autorizado. El
cliente conserva las cabeceras de esa respuesta y decodifica únicamente un
valor hexadecimal de exactamente 32 bytes. El coordinador valida la huella con
`PatchKeyStore.store`, que exige que SHA-256 de la clave coincida con el
fingerprint del paquete, y después reutiliza
`PatchPackageCodec.decode(data, contentKey:)`.

No se usa `X-Patch-Password`, no se registran claves, no se guardan en
UserDefaults/caché y no se modifica el codec.

## Dashboard vacío

El snapshot del Worker devuelve actualmente `patches` básicos desde D1. La
consulta une `user_patches`, exige `p.active = 1` y entrega `id`, nombre,
versión, password/content_key y fechas, pero no entrega `targetID`, `projectID`,
SHA-256 ni `fileSize`. `VINIRemotePackageCoordinator` descarta correctamente
cada entrada sin `target`; por eso no puede crear targets reales. El endpoint
sin autorización responde 401, así que no se consultaron datos de cuentas.

Esto requiere que el Worker principal desplegado exponga los metadatos
enriquecidos 3G–3I (o un endpoint autorizado equivalente). No se modifica ni
despliega el Worker en esta fase.
