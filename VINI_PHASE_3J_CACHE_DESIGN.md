# VINI 3J-F — Diseño de caché dinámica

`VINIRemotePackageCache` es un adaptador nuevo, separado de `PatchProjectLibrary` y de `VINIDualBackupStore`.

- Directorio: `Application Support/VNIRemotePackageCache`.
- Identidad: usuario estable, `remotePatchID`, `targetID`, `packageID`, `projectID`, revisión, SHA-256 y tamaño.
- La clave de nombre de archivo es un SHA-256 de la identidad serializada; nunca contiene token, licencia ni nombre de archivo remoto.
- Metadatos versionados (`schemaVersion = 1`) y paquete `.3105` independiente.
- Escritura a `.partial`, verificación y publicación atómica del paquete; metadatos atómicos después.
- Revisiones distintas producen entradas distintas y conservan la revisión anterior si falla la nueva.
- El coordinador consulta primero `profile()` y después el catálogo autorizado. La caché nunca concede autorización.
- `PatchProjectLibrary.save` continúa siendo el único importador; la caché no es una segunda biblioteca.
- No se accede a `PatchProjects/Backups`, journals ni recibos.

El backend productivo sigue siendo únicamente `vini-v2-api`; los tests usan respuestas sintéticas del mismo contrato y no conectan producción.
