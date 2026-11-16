# VINI 2.0 RC7 — Restore and recovery

Before Restore, RC7 loads the record for the real receipt, validates container identities, verifies committed A and independently verifies B. If A is invalid, `bestB` selects a validated B and `repairPrimary` restores only the transaction backup material, quarantining the damaged primary; it does not write directly to a destination.

Restore still runs through `PatchTransaction.restore`, with `allowChangedTargets` forced to `false` regardless of the legacy caller argument. External destination drift therefore remains a conflict. Afterward RC7 verifies original bytes/existence with `PatchTransaction.verifyState`, calls `sealRestored`, and only then persists the restored phase. Unresolved or failed operations remain recovery-required.
