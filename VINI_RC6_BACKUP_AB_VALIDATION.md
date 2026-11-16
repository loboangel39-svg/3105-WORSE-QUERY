# VINI 2.0 RC6 — Backup A/B validation

The existing A/B implementation was inspected without modification. `preparePair` creates and verifies A plus an independent protected B; `sealApplied` requires matching committed manifests and digests; `bestB` only returns a verified committed/prepared B; `repairPrimary` verifies B, quarantines the old primary and preserves recovery material; `sealRestored` records terminal state.

The production DevicePatchService path currently does not create the `VINIOperationRecord` required by `VINIDualBackupStore`. Consequently RC6 does not claim automatic A/B recovery in production. The safe behavior for changed targets or invalid manifests is to preserve journals/backups and require review. Fixture-only A/B recovery remains covered by `VINIIsolatedFixture`.

Physical and destructive fixture execution for corrupted-primary, intact-B and corrupted-both scenarios remains pending.
