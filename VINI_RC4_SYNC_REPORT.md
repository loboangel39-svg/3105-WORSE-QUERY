# VINI 2.0 RC4 — Sincronización activa

## Causa

`PatchProjectsView.onAppear` ejecutaba `PatchManager.syncPatches()` y después `PatchSyncManager.syncPatches()`, duplicando catálogo, descarga y copia legacy. No había un ciclo de actualización mientras la app permanecía abierta ni una recarga de `PatchProjectStore` al recibir `patchesDidChange`.

## Cambio

- `PatchSyncManager` es ahora el único punto de entrada de la vista.
- Se añadió actualización controlada cada 45 segundos en foreground.
- Se añadió refresco al volver a foreground mediante `viniForegroundRefresh`.
- `patchesDidChange` recarga Installed sin reconstruir navegación.
- Se conservaron guardas de concurrencia, versionado, integridad y política de revocación.

## Evidencia

- CI arm64 SUCCESS: run `43949919893`.
- Prueba física de asignación/revocación en app abierta: pendiente.
- El Worker no fue modificado.
