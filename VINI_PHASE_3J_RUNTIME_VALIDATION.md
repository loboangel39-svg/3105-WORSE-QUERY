# VINI 3J-D — Validación runtime del coordinador

Estado inicial: **PENDING CI**.

## Backend y dependencia HTTP

La revisión arquitectónica detectó que el coordinador recibía un `VINIStagingClient` configurado por defecto con el endpoint de staging. Se conservó ese cliente únicamente como implementación reutilizable de transporte, sesión, licencia/HWID y renovación 401, pero se añadió configuración explícita de `baseURL`.

La instancia del coordinador de producción y el arnés 3J-D usan `VINIProductionEnvironment.base`: `https://vini-v2-api.loboangel39.workers.dev`. Staging solo queda disponible para llamadas de staging explícitas. No se conecta ningún test al Worker: el transporte sintético intercepta las solicitudes y reproduce el contrato real (`/api/app/patches` y `/api/app/patches/:id/download`).

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

## Evidencia runtime

Run exitoso: `43804849931` — https://github.com/loboangel39-svg/3105-WORSE-QUERY/actions/runs/43804849931

El log registra solicitudes sintéticas al contrato del Worker (`/api/app/validate-license`, `/api/app/patches` y `/api/app/patches/fixture-remote-id/download`) y la llamada literal a `VINIRemotePackageCoordinator.prepareAuthorizedPackages()`. Pasaron el paquete preparado, identidad, tamaño/SHA, importación `PatchProjectLibrary` y decodificación posterior con el codec original. También pasó la renovación 401 sobre `/api/app/patches`.
