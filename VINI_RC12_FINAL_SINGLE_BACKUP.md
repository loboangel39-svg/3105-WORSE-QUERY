# RC12 Final Fix — Single backup

`DevicePatchService` has no productive dependency on `VINIDualBackupStore`,
`VINIOperationRecord`, A/B manifests, `preparePair`, `sealApplied`, `bestB`,
`repairPrimary` or `sealRestored`. New Apply/Restore operations use only the
per-transaction original copies and journal owned by `PatchTransaction`.

Legacy VINI files are not deleted by package removal; they are not consulted
by new operations.
