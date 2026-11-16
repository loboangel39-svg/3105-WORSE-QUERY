# VINI 2.0 RC7 — Backup integration

`DevicePatchService.apply` now creates a `VINIOperationRecord` from the real project, resolved container identities, planned rules/directories and a deterministic digest of the decoded project. Before destination mutation it assigns the real `PatchTransactionReceipt.id`, persists the record, and calls `VINIDualBackupStore.preparePair` against the real prepared journal. Apply is aborted if either copy or manifest verification fails.

After the original transaction reports `applied`, RC7 verifies the applied state, calls `sealApplied`, and persists the applied phase. Backup B remains write-once at the application layer and is never rebuilt from applied data. Failure leaves the record and journal in recovery-required state.
