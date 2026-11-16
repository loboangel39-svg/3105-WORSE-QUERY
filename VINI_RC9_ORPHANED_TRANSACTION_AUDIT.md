# VINI 2.0 RC9 — Orphaned transaction audit

RC8 stored `recoveryRequiredIDs` only in `PatchProjectStore` memory. After process termination or reinstall with preserved Application Support, the receipt could still exist while the UI no longer had its recovery marker. `latestReceipt` alone also cannot establish that A/B manifests and the operation record remain valid.

RC9 reconstructs the marker during every asynchronous library load. It uses the existing persisted `VINIOperationRecord`, deterministic project digest, receipt/journal lookup and read-only `VINITransactionStateReader`. It does not match by display name, delete receipts, or remove backups. A new revision with a mismatched digest is conservatively marked for review.
