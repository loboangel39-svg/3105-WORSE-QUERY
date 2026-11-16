# VINI 2.0 RC1 — Remote Patch Flow

1. Production authentication obtains and persists the Worker token and HWID.
2. `RemotePatchService` requests `/api/app/patches` with that token.
3. `PatchDownloadService` requests `/api/app/patches/:id/download`, retries bounded failures, checks bytes and retains `X-Content-Key`.
4. `PatchStorage` writes atomically under `Documents/RemotePatches`.
5. `PatchManager` stores the authorized key through the existing `PatchKeyStore` after codec inspection.
6. `PatchSyncManager` mirrors only compatible package bytes into native `Application Support/PatchProjects`.
7. `PatchProjectLibrary` remains the authority used by Installed and original Apply/Restore actions.

No `categoryID`, `entry.target` or generated target identifiers are required by this flow.
