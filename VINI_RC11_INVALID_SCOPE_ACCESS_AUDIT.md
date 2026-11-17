# VINI 2.0 RC11 — Auditoría de `Invalid scope`

Fecha: 2026-11-16  
Rama: `integration/vini-2.0-rc11`  
HEAD auditado: `9fccd5d76e6a25e5f16cd3598d3431820e49edfe`

## Conclusión

El error `Invalid scope` **no lo genera la adquisición de acceso**. En el
fuente RC11, `VINIPatchFailure.invalidScope` sólo aparece en
`VINIDualBackupStore.swift` y en el fixture aislado. Las comprobaciones
relevantes son:

- `VINIDualBackupStore.validateScope` (`VINIDualBackupStore.swift:142-163`).
- `VINIDualBackupStore.assertSafe` (`VINIDualBackupStore.swift:480-493`).
- `VINIDualBackupStore.treeBytes` y validaciones de recuperación
  (`VINIDualBackupStore.swift:510-517` y `407-415`).
- `VINIIsolatedFixture` (`VINIIsolatedFixture.swift:23-27, 46-57, 72-75`),
  que no es la ruta productiva.

`ContainerAccessCoordinator.acquire()` nunca lanza `VINIPatchFailure.invalidScope`.
Devuelve un `NSError` de dominio `ContainerAccess`, códigos 1 o 2
(`ContainerAccessCoordinator.swift:22-57`). Después,
`DevicePatchService.withResolvedContainers()` convierte cualquier error de
adquisición en `PatchPackageError.targetAppUnavailable(bundleID)` y descarta
el dominio/código original (`DevicePatchService.swift:241-254`).

Por tanto, si la alerta dice literalmente `Invalid scope`, el primer origen
demostrable está en la validación VINI de rutas, alcance o manifest, no en la
selección de `worse_query`. Si la alerta es el error localizado de contenedor,
la causa puede ser acceso, pero hoy queda oculto y no puede distinguirse sin
instrumentación.

## 1. Flujo de APPLY y puntos exactos

1. `DevicePatchService.apply` obtiene los bundle IDs del proyecto y llama a
   `withResolvedContainers` (`DevicePatchService.swift:5-10`).
2. `withResolvedContainers` llama a
   `ContainerStore.resolveAppContainerPath(bundleID:)` (`DevicePatchService.swift:241-244`).
3. Si encuentra una ruta válida, solicita **`.write`** a
   `ContainerAccessCoordinator.acquire` (`DevicePatchService.swift:246-249`).
4. La sesión se guarda en un array local `sessions` y todo el Apply se ejecuta
   dentro de `withExtendedLifetime(sessions)` (`DevicePatchService.swift:238-257`).
5. Se crea el registro VINI y se ejecuta `PatchTransaction.apply`.
6. Durante `beforeMutation`, `VINIDualBackupStore.preparePair` lee el journal,
   valida el alcance planificado y crea A/B (`DevicePatchService.swift:24-31`,
   `VINIDualBackupStore.swift:164-191`).
7. `validateScope` puede producir `invalidScope` si el journal y el registro
   VINI no describen exactamente los mismos archivos, reglas, directorios,
   IDs, paths o fingerprints (`VINIDualBackupStore.swift:142-163`).
8. `assertSafe` puede producirlo si una ruta sale del root esperado, si falta
   un componente no permitido o si aparece un enlace simbólico
   (`VINIDualBackupStore.swift:480-493`).

## 2. Selección real de proveedores

`ContainerStore.resolveAppContainerPath` no selecciona directamente
`worse_query`:

1. Valida que el bundle ID sea canónico (`ContainerStore.swift:93-96`).
2. Intenta `MCMActivateContainerPath` (`ContainerStore.swift:97-105`).
3. En iOS 26+, carga WQFiles y enumera rutas mediante `wq_ls_container_paths`;
   compara `wq_bundle_id_for_container(path)` con el bundle ID
   (`ContainerStore.swift:106-113`).
4. Finalmente intenta el escaneo de metadatos del filesystem
   (`ContainerStore.swift:116-145`).

Después, `ContainerAccessCoordinator.acquire` tiene otra cascada distinta:

1. Canonicaliza la ruta y exige que empiece por `/`.
2. En iOS 26+, intenta primero `wq_grant(expected)` y prueba acceso efectivo.
   Si funciona, el provider registrado es `WQAccess`, con handle `-1`
   (`ContainerAccessCoordinator.swift:23-30`).
3. Intenta MHA-C2 si la ruta coincide (`:31-35`).
4. Intenta `bad_query` con `write=false` incluso cuando Apply pidió `.write`
   (`:37-44`). El acceso se valida después mediante un probe de escritura.
5. Intenta `WQAccessProviderAcquire`, que es la ruta denominada
   `worse_query`, y vuelve a probar acceso efectivo (`:46-53`).

La política `VINICompatibility` clasifica iOS 27.2.1 como `worseQuery`
(`VINICompatibility.swift:70-71`), pero esa clasificación es de presentación
y compatibilidad; `ContainerAccessCoordinator` no la consulta para escoger el
proveedor. La cascada anterior se ejecuta de forma fija.

## 3. Comparación con Files

`FileBrowserView.load()`:

- Usa la ruta ya disponible en `currentPath`.
- Solicita `ContainerAccessCoordinator.acquire(... operation: .read)`
  (`FileBrowserView.swift:1175-1193`).
- Mantiene el objeto en `accessSession` durante el bloque de trabajo y luego
  lista archivos con `ContainerStore.listFiles`.

Apply:

- Vuelve a resolver la ruta por bundle ID mediante `resolveAppContainerPath`.
- Solicita `.write`, no `.read` (`DevicePatchService.swift:241-249`).
- `verifyEffectiveAccess(.write)` crea y elimina un archivo probe
  (`ContainerAccessCoordinator.swift:70-80`).
- Mantiene todas las sesiones en un array hasta que termina toda la operación
  gracias a `withExtendedLifetime` (`DevicePatchService.swift:239,257`).

No son solicitudes equivalentes: Files demuestra lectura; Apply exige crear y
eliminar un archivo en el root del contenedor. Que Files funcione no demuestra
que el acceso de escritura sea válido. La duración de la sesión de Apply sí es
suficiente en el código: la sesión no se libera antes de `PatchTransaction` ni
antes de los callbacks VINI. El `deinit` libera handles de `bad_query` y
`worse_query` (`ContainerAccessCoordinator.swift:15-18`).

## 4. Qué componente puede producir exactamente `Invalid scope`

### Caso demostrado 1: mismatch VINI/journal

`preparePair` toma el snapshot del journal y ejecuta `validateScope`. El error
aparece cuando:

- el número de archivos del journal no coincide con `plannedRules`;
- faltan o sobran IDs de reglas;
- bundle ID/path/digest esperado no coincide;
- un path no es canónico;
- el fingerprint del contenedor no tiene 32 bytes;
- un directorio del journal no está en `plannedDirectories`.

Estos guards están en `VINIDualBackupStore.swift:143-163`.

### Caso demostrado 2: path fuera del root o symlink

`assertSafe` compara el path canónico con `root` y rechaza escapes,
componentes inexistentes no permitidos y symlinks (`:480-493`). Esto puede
afectar la raíz VINI, la raíz engine o staging de manifests; no es un error de
`worse_query`.

### Caso no demostrado: adquisición

Si `wq_grant`, MHA-C2, `bad_query`, `WQAccessProviderAcquire` o el probe de
escritura fallan, el resultado actual es un `NSError` de `ContainerAccess`.
`withResolvedContainers` lo transforma en `targetAppUnavailable`. No hay ruta
que lo transforme en `VINIPatchFailure.invalidScope`.

## 5. Pérdida de evidencia actual

La instrumentación actual no cumple el diagnóstico solicitado:

- `ContainerAccessCoordinator` registra la ruta completa en el mensaje de
  fallo (`:55-57`), y no registra bundle ID, dominio/código separado ni el
  resultado de cada proveedor.
- `DevicePatchService` registra sólo `shared container access failed` y el
  `localizedDescription`, después reemplaza el error por
  `targetAppUnavailable` (`:251-254`).
- No queda registrado si `wq_grant` fue verdadero, si el probe `.write`
  funcionó, qué proveedor ganó ni si el handle fue liberado.
- La UI posterior puede volver a convertir los errores en mensajes genéricos.

Así, no es posible demostrar desde el log actual si Apply llegó a iniciar la
transacción o falló antes, durante la adquisición.

## 6. Causa más probable según la evidencia disponible

Si el texto recibido es realmente `Invalid scope`, la hipótesis primaria es
una inconsistencia de scope en la capa VINI: el registro calculado por
`makeOperationRecord` no coincide con el journal o con alguna ruta de staging,
o una ruta contiene un componente no permitido/symlink. Debe comprobarse el
primer guard que falla.

Si el usuario describe como “Invalid scope” el mensaje de acceso, entonces la
hipótesis es distinta: Files sólo tuvo `.read`, mientras Apply requiere `.write`;
el probe de escritura pudo fallar aunque la enumeración de Files funcionara.
El código actual oculta esa diferencia.

No hay evidencia fuente para atribuir el error directamente a `worse_query`.

## 7. Corrección mínima recomendada, sin aplicarla en esta auditoría

1. Instrumentar `resolveAppContainerPath` por fase y bundle ID anonimizado,
   sin registrar paths completos.
2. Instrumentar cada rama de `acquire` con proveedor, operación (`read/write`),
   resultado booleano, dominio/código si existe y estado del handle.
3. En `withResolvedContainers`, conservar el error original como causa
   (`NSError` dominio/código y provider), no convertirlo automáticamente a
   `targetAppUnavailable`.
4. Instrumentar `VINIDualBackupStore.validateScope` y `assertSafe` con un
   código de guard estable, root lógico (`engine`, `vini`, `transaction`) y
   bundle ID anonimizado; nunca incluir rutas privadas completas.
5. Comparar en el dispositivo la fase del último log: si falla antes de
   `withExtendedLifetime`, es acceso; si llega a `preparePair`, es scope VINI.

No se recomienda cambiar el proveedor, permisos, entitlements, exploits ni
la duración de la sesión antes de obtener esa evidencia.

## Limitación

Esta auditoría es estática. No se recibió un log del iPhone con dominio/código,
proveedor elegido, bundle ID y fase. Por ello identifica el origen posible y
la diferencia exacta Files/Apply, pero no puede seleccionar entre mismatch de
scope VINI y fallo de escritura del proveedor como causa final del incidente
real sin instrumentación en el dispositivo.
