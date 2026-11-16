# VINI 2.0 RC9 — State recovery

The reconciler maps valid persisted states to the existing UI behavior: `.applied` remains RESTORE and `.restored` remains available for APPLY after the normal library state is reloaded. `.prepared`, `.restorePending`, `.failed` and `.unknown` with an active receipt become REVISAR. This prevents a false APPLY unlock after interruption, missing records, changed package identity or invalid manifests.

Normal recovery remains delegated to `DevicePatchService` and `PatchTransaction`; if A is invalid, their existing RC7 B validation/primary-repair path is used. Destination conflicts still cannot force `allowChangedTargets`.
