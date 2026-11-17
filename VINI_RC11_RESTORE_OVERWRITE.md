# VINI 2.0 RC11 — Restore overwrite

The existing UI detects changed or missing applied targets and asks for
confirmation. Confirmed Restore now passes `allowChangedTargets: true` through
`DevicePatchService` into `PatchTransaction`; it still requires the correct
receipt, container fingerprint, contained path, verified backup and final
original digest. The current destination is first copied into a recovery
snapshot so later changes are not silently lost without evidence.
