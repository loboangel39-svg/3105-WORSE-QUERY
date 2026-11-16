# VINI 3J — Resultados finales

Estado: **PASS RUNTIME AISLADO — PARCIAL POR ALCANCE**.

Backend definitivo: `vini-v2-api` en `https://vini-v2-api.loboangel39.workers.dev`. La URL `vini-admin-plans-staging-2b.loboangel39.workers.dev` no se utiliza por el coordinador ni por el arnés 3J-D; solo permanece como valor por defecto para consumidores explícitos de staging heredados.

Este informe se actualizará únicamente con evidencia del run que compile y ejecute `Tests/VNIRemoteCoordinator/main.swift`. No se considerará suficiente `swiftc -parse`.

Debe registrar:

- commit SHA, ID y URL del run;
- runner macOS y versión Xcode;
- líneas `PASS`/`FAIL`/`SKIPPED` del arnés real;
- evidencia de `prepareAuthorizedPackages()` y `PatchProjectLibrary.save`;
- compilación `iphoneos arm64` sin firma y salida `lipo -info`;
- hashes protegidos, que deben permanecer sin cambios.

No se declarará PASS global mientras queden pendientes los escenarios que no pueda ejecutar el contrato actual. 3K y 3L siguen bloqueadas.

## Run verificado

- Commit: `374365c` (SHA completo verificado por checkout del run)
- Run: `43804849931`
- URL: https://github.com/loboangel39-svg/3105-WORSE-QUERY/actions/runs/43804849931
- Runner: `macos-15`
- Xcode: `26.3`
- Syntax del coordinador: **PASS**
- Harness real `prepareAuthorizedPackages()`: **PASS**
- Catálogo, descarga y rutas del Worker reproducidas: **PASS**
- Integridad de tamaño y SHA-256: **PASS**
- `packageID`/`projectID`: **PASS**
- Inspección/importación codec original + `PatchProjectLibrary`: **PASS**
- Paquete corrupto: **PASS rechazado**
- Identidad inconsistente: **PASS rechazado**
- SHA inconsistente: **PASS rechazado**
- Renovación HTTP 401 en catálogo: **PASS**
- Compilación `iphoneos` sin firma: **PASS**
- Arquitectura `lipo`: **PASS arm64**
- Artefacto: `VINI-3J-native-evidence`

**SKIPPED/PENDIENTE:** descarga interrumpida, caché alterada, cambio de usuario, revocación posterior al catálogo, respaldos/recibos y Apply/Restore. No se usaron licencias reales ni se conectó producción.
