# VINI 3J-D — Validación runtime del coordinador

Estado inicial: **PENDING CI**.

El nuevo arnés `Tests/VNIRemoteCoordinator/main.swift` construye un paquete con `PatchPackageCodec.encodeNew`, sirve respuestas HTTP sintéticas mediante `VINIStagingTransport`, crea un `VINIStagingClient` real e invoca directamente:

```swift
try await VNIRemotePackageCoordinator(client: client).prepareAuthorizedPackages()
```

El coordinador no se reemplaza ni se mockea. La importación se realiza mediante el `PatchProjectLibrary.save` original y se vuelve a decodificar con `PatchPackageCodec` original. Las rutas son fixtures temporales; no se ejecuta Apply/Restore ni se usan licencias productivas.

Casos del arnés:

- catálogo válido, descarga autorizada, tamaño, SHA-256, `packageID`, `projectID`, inspección e importación: ejecutable;
- estado `prepared` y archivo importado recuperable: ejecutable;
- bytes corruptos: ejecutable;
- identidad de proyecto inconsistente: ejecutable;
- SHA-256 inconsistente: ejecutable;
- revalidación HTTP 401 durante el flujo autorizado: ejecutable;
- descarga interrumpida, caché alterada, cambio de usuario, revocación posterior al catálogo y respaldos/recibos: pendiente; no forman parte del coordinador actual sin ampliar el contrato o tocar Apply/Restore.

El resultado final depende de GitHub Actions macOS y se documentará en `VINI_PHASE_3J_FINAL_RESULTS.md`.
