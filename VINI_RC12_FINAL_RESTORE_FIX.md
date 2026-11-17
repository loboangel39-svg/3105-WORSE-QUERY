# RC12 Final Fix — Restore

The Installed action no longer stops after `inspectRestore` reports changed
targets. It delegates to `DevicePatchService.restore(... allowChangedTargets:
true)`, which passes the explicit overwrite authorization to
`PatchTransaction.restore`. The engine still validates the receipt, backup
digest, container identity, contained paths, writes and final restored digest.

The detail flow retains the existing confirmation dialog for changed targets.
No `REVISAR` action or permanent recovery state was added.
