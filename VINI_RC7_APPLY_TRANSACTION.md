# VINI 2.0 RC7 — Apply transaction

The original `DevicePatchService → PatchTransaction` path remains the only destination writer. RC7 uses the existing `beforeMutation` and `beforeRollback` callbacks, the original journal/receipt, `VINIDualBackupStore.preparePair`, `sealApplied`, and `PatchTransaction.verifyState`.

The record uses `package.<project UUID>` as the existing target identity, the actual receipt transaction UUID, resolved `VINIRootIdentity` values, project rules and derived parent directories. No artificial transaction is created. A failed preparation occurs before any destination write.
