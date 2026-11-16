# VINI 2.0 RC1 — Compatibility Matrix

Base: `3105-WORSE-QUERY`, branch `experiment/vini-remote-import-ci`.
Reference: `VINI-IPA`, branch `main`.

| Component | Source | Decision | Integration |
|---|---|---|---|
| App / ContentView | 3105 | ADAPT | Authorized root now opens native `ContentView`; native navigation remains intact. |
| Authentication / HWID / session | 3105 production flow | CONSERVE | `VINIStagingClient` remains the sole Worker/auth state machine. |
| Keychain adapter | VINI-IPA behavior | REUSE/ADAPT | Added adapter for the production `vini-session` record; no second session store. |
| RemotePatchService | VINI-IPA | REUSE | Production `/api/app/patches` contract. |
| PatchDownloadService | VINI-IPA | REUSE | ID download, retries, size checks and content-key header. |
| PatchManager / PatchStorage | VINI-IPA | REUSE | Remote cache and version checks; no target/category dependency. |
| PatchSyncManager | VINI-IPA | ADAPT | Bridges remote cache to native `Application Support/PatchProjects`. |
| PatchProjectLibrary / Store / Codec / KeyStore | 3105 | CONSERVE | No format, password or Apply/Restore changes. |
| VINIDualBackupStore / Files / WQFiles | 3105 | CONSERVE | No source changes. |
| Target dashboard / categoryID | 3105 history | NO INCORPORAR | Not used by the authorized UI flow. |

Protected native files were not replaced or refactored.
