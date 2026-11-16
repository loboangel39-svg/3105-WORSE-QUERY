# VINI 2.0 RC2 — Change Report

## Functional changes

- Remote catalog synchronization now runs from Instalados and refreshes the native `PatchProjectStore` after download/import.
- Remote entries show their real Worker state and download action in Instalados.
- Apply invokes the existing verified `DevicePatchService` path directly on one tap; integrity, workspace synchronization and transaction handling remain unchanged.
- Foreground authorization is reused while its server-provided lifetime is valid.
- A confirmed remote 401 emits session invalidation and revalidates the single production session.

## Navigation and presentation

- Visible navigation is limited to Instalados and Información.
- Información shows license, plan, expiration, device, iOS, provider and kernel/access state.
- Cleaner, wallpapers, developer controls and repository navigation are hidden from the RC2 flow.
- Installed search is compact and user-invoked; the import button remains a compact toolbar action.
- Existing appearance preferences remain available; no forced dark mode was introduced.
- Display name and visible version are VINI 2.0 / 2.0.

## Preserved

No changes were made to bad_query, worse_query, WQFiles, ContainerAccessCoordinator, PatchPackageCodec, PatchProjectLibrary, DevicePatchService, PatchTransaction, VINIDualBackupStore, A/B backups, journals, Restore, permissions or the production Worker.

Physical iPhone tests for login, authorized download, Apply/Restore and A/B recovery remain pending until device access is available.
