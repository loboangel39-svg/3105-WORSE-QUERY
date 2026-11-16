# VINI 3J — Resultados finales

Estado: **PENDING CI**.

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
