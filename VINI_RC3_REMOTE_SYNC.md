# VINI 2.0 RC3 — Remote synchronization

- Automatic synchronization remains on the existing Worker path through `PatchManager`, `PatchDownloadService`, `PatchStorage` and `PatchSyncManager`.
- Installed no longer renders a remote catalog or download controls. Successful downloads are copied into the existing native library location.
- Existing package/version checks prevent unchanged downloads; the existing per-package and global sync guards prevent duplicate work.
- Integrity, authorized keys and atomic storage remain in the original services.
- Temporary network failures are logged and do not trigger revocation cleanup.

## Evidence

- Commit: `97afe1e6a39ff82d25c0ece5d46730e5ad0d347d`
- CI: run `43941094506` — SUCCESS

Physical login/catalog/import testing remains pending on a real authorized device.
