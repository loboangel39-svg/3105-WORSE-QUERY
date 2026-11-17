# VINI 2.0 RC12 — Dual backup removal

The productive `DevicePatchService` path no longer creates or reads
`VINIOperationRecord`, `VINIDualBackupStore`, A/B manifests, `preparePair`,
`sealApplied`, `bestB`, `repairPrimary` or `sealRestored`. Apply and Restore
delegate directly to the existing `PatchTransaction` journal and its original
copies.

Legacy VINI source and on-device files are not deleted by this change. They are
not consulted by new productive Apply/Restore operations, preserving old
recovery material for a separate read-only migration decision.
