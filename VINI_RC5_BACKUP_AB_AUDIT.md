# VINI 2.0 RC5 — Backup A/B audit

No backup algorithm was changed. Source inspection confirms the existing `VINIDualBackupStore` semantics:

- `preparePair` verifies the transaction scope, creates manifest A and independently copies protected backup B.
- `sealApplied` requires both committed A and B manifests and matching digests.
- `bestB` selects only a verified B manifest, preferring committed over prepared.
- `repairPrimary` verifies B before staging repair, quarantines the old primary and preserves B/quarantine material.
- `sealRestored` writes terminal recovery state without deleting the prior recovery generation.
- `VINITransactionStateReader` reports applied only when receipts, journal status and both committed manifests verify.

The RC5 sync and revocation paths do not delete transaction roots, journals or A/B recovery material. Physical fixture execution for intact-primary, corrupted-primary, corrupted-both and interrupted recovery remains pending; no destructive device test was performed.
