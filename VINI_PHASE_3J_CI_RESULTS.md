# VINI Fase 3J-CI — plan de evidencia

Estado antes de la ejecución: **PENDING**.

Este workflow experimental añade `push` únicamente para
`experiment/vini-remote-import-ci`; no modifica `main` ni otros workflows.

## Qué ejecutará

- `swiftc -parse` del contrato, cliente y coordinador: **syntax check**, no prueba funcional.
- `Tests/VINIContracts/main.swift`: pruebas de contrato/metadata, cuando se compilen mediante el workflow existente; no se declara aquí como coordinador runtime.
- `Tests/VINIStaging/main.swift`: **native macOS runtime fixtures** con transporte sintético, Keychain macOS, codec original sin modificar y fixtures propios. Incluye login, renovación 401, cambio de cuenta, catálogo/descarga aislados y Apply/Restore sobre fixtures; no es ejecución sobre aplicaciones de terceros.
- `xcodebuild` para `iphoneos`, `ARCHS=arm64`, firma deshabilitada y verificación `lipo -info`.

## Límites de la evidencia

El coordinador `VNIRemotePackageCoordinator` se compila sintácticamente en este cambio, pero el arnés `Tests/VINIStaging/main.swift` existente ejercita `VINIStagingClient` y no invoca todavía `prepareAuthorizedPackages()` directamente. Por tanto, un PASS de `swiftc -parse` o de las pruebas de staging no se etiquetará como PASS del coordinador remoto completo.

## Resultado

Se completará después del run generado por el push. Debe registrar ID, URL, SHA, runner macOS-15, versión Xcode, salida nativa, log de compilación iPhone, arquitectura `arm64` y artefactos. Los estados válidos serán únicamente `PASS`, `FAIL` o `SKIPPED` con evidencia adjunta.
