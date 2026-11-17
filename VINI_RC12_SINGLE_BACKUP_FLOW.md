# VINI 2.0 RC12 — Single backup flow

`PatchTransaction.apply` captures each existing target as `<rule>.original`
inside the new transaction directory before any target write. It verifies the
copy digest, writes the `prepared` journal, performs the Apply writes, verifies
replacement digests, and commits the journal as `applied`.

Restore reads only that transaction's `.original` files. It may overwrite
changed or missing current targets after the existing UI confirmation. The
backup is never treated as factory-original merely because it was captured.
