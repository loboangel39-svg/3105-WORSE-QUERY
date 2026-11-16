# VINI 2.0 — Auditoría de rendimiento localizada

## Cuellos de botella encontrados

- `PatchProjectLibrary.load()` decodifica cada `.3105`, comprueba claves y puede materializar workspaces. Ejecutarlo directamente al finalizar una operación bloqueaba el `MainActor`.
- `PatchProjectStore.finishDirectOperation`, `finishWorkspaceSynchronization` y `finishOperation` llamaban a `reload()` síncrono.
- `PatchProjectsView` también recargaba síncronamente después de Apply, Restore, sincronización de workspace y al aparecer la pestaña.
- La lista ya usa `List` y `PatchLibraryItem` ya tiene un identificador estable (`summary.packageID`); no se sustituyó por índices ni se añadió una reconstrucción paralela.
- Las rutas de transacción, hash, contenedores y backups A/B permanecen fuera de este cambio.

## Cambios aplicados

- `PatchProjectStore.reload()` ahora delega en `reloadAsync()`.
- Las finalizaciones de operaciones publican el estado ocupado inmediatamente y cargan la biblioteca mediante el worker existente (`Task.detached` ya usado por `reloadAsync`), con publicación final en `@MainActor`.
- Las vistas de Installed y detalle usan `reloadAsync()` después de sincronización, Apply, Restore y workspace.
- No se modificaron `DevicePatchService`, `PatchTransaction`, `VINIDualBackupStore`, codec, autenticación, Worker ni motores nativos.

## Instrumentación y límites

El código conserva mediciones de duración de sincronización y operaciones existentes. No se ejecutaron Instruments Time Profiler, Hangs, SwiftUI, Animation Hitches o Allocations en este entorno Windows, ni se dispone de un iPhone físico; por tanto no se inventan métricas de FPS, memoria o tiempo de bloqueo. La validación cuantitativa queda pendiente en un runner macOS/dispositivo.

## Regresión esperada

La carga se publica de forma asíncrona tras la escritura confirmada. Receipts, journals, hashes, Apply/Restore y A/B no cambian; sólo se evita leer/decodificar la biblioteca dentro del callback de UI.
