# VINI Fase 3J-CI — plan de evidencia

Estado actual: **PASS PARCIAL**.

Este workflow experimental añade `push` únicamente para
`experiment/vini-remote-import-ci`; no modifica `main` ni otros workflows.

## Qué ejecutará

- `swiftc -parse` del contrato, cliente y coordinador: **syntax check**, no prueba funcional.
- `Tests/VINIContracts/main.swift`: pruebas de contrato/metadata, cuando se compilen mediante el workflow existente; no se declara aquí como coordinador runtime.
- `Tests/VINIStaging/main.swift`: **native macOS runtime fixtures** con transporte sintético, Keychain macOS, codec original sin modificar y fixtures propios. Incluye sesión, renovación 401, cambio de cuenta y round-trip del codec; el workflow marca explícitamente los escenarios live Worker/R2/licencias como `SKIPPED` porque no usa secretos de producción.
- `xcodebuild` para `iphoneos`, `ARCHS=arm64`, firma deshabilitada y verificación `lipo -info`.

## Límites de la evidencia

El coordinador `VNIRemotePackageCoordinator` se compila sintácticamente en este cambio, pero el arnés `Tests/VINIStaging/main.swift` existente ejercita `VINIStagingClient` y no invoca todavía `prepareAuthorizedPackages()` directamente. Por tanto, un PASS de `swiftc -parse` o de las pruebas de staging no se etiquetará como PASS del coordinador remoto completo.

## Resultado

## Ejecución CI verificada

- Run: `43802759627`
- URL: https://github.com/loboangel39-svg/3105-WORSE-QUERY/actions/runs/43802759627
- Commit: `ad3e784` (`ad3e784` completo en el run)
- Evento/rama: `push` / `experiment/vini-remote-import-ci`
- Runner: `macos-15` (job `133086586381`)
- Xcode observado: `/Applications/Xcode_26.3.app`
- Syntax coordinator: **PASS**
- Fixtures nativos macOS: **PASS**; las pruebas live Worker/R2/licencias: **SKIPPED** explícitamente por ausencia de secretos de producción.
- Compilación `iphoneos` unsigned: **PASS**.
- Arquitectura: `Non-fat file ... is architecture: arm64`.
- Artefacto: `VINI-3J-native-evidence`, con logs y evidencia de build.

No se declara PASS del flujo completo de `VNIRemotePackageCoordinator.prepareAuthorizedPackages()`: el coordinador tuvo validación sintáctica, pero el arnés nativo existente no lo invoca directamente. Tampoco se ejecutaron operaciones contra producción ni CoreSimulator/simctl.
