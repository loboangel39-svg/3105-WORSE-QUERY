# VINI 3U — correcciones mínimas

## Corregidas

1. `ThreeOneOSFive/helpers/VNIRemotePackageCoordinator.swift`: se eliminó
   `try! VINIRemotePackageCache(...)` de ambos inicializadores. La cache ahora
   es opcional; si Application Support no puede crearse, el flujo verificado
   continúa sin cache en vez de cerrar por excepción no recuperable.
2. El mismo archivo: la persistencia de categoría es best-effort después de
   guardar/importar bytes verificados. Un fallo de clasificación local no
   convierte un paquete importado en fallo de codec ni lo elimina.
3. `ThreeOneOSFive/views/VINIStagingAccountView.swift`: `toggle` usa
   `profile.stableUserID`, igual que el coordinador y el store de categorías,
   evitando mezclar `username` con `userID` en asociaciones de transacción.

## No modificadas

No se tocaron `PatchPackageCodec`, `PatchTransaction`, `DevicePatchService`,
`VINIDualBackupStore`, journals, backups, motores, Files, Worker, D1/R2,
Bundle ID, App Group o entitlements.

## Validación

Las correcciones están publicadas en `563201ad72b38ea6462e1b62d3e28e65a49bdaac`
y requieren el CI `43899153420`. No se declara compilación local porque el host
disponible es Windows sin `swiftc`/Xcode. El IPA disponible es histórico y
pertenece a `7f5b50c`, no a este commit.
