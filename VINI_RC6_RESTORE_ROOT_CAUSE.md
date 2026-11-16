# VINI 2.0 RC6 — Restore root cause

`Algunos archivos han cambiado` originates in `PatchTransaction.changedTargets`, called by `inspectRestore` and `restore`. A target is reported when it is missing or its digest no longer equals the recorded replacement digest. `resolvedRecords` separately verifies container identity and the original backup digest; those failures become `restoreFailed`.

Therefore the message identifies an externally changed target, not corruption of the original backup. RC6 keeps the safe refusal and exposes `REVISAR`; it does not force `allowChangedTargets` or overwrite possible legitimate changes.

Audit result: production `DevicePatchService` is backed by `PatchTransaction` journals and per-file original backups. `VINIDualBackupStore` has A/B recovery APIs used by `VINIIsolatedFixture`, but no production `VINIOperationRecord` is linked to the DevicePatchService receipts. Connecting it would require a new write path, so no unsafe parallel recovery was introduced.
