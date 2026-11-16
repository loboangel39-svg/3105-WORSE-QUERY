# VINI 2.0 RC10 — State policy

Installed now exposes only APPLY and RESTORE. `PROCESANDO` is the label used while the existing store operation is busy; it is not a third persisted action. If persisted evidence is inconsistent, the existing action remains disabled and the existing error/recovery records are preserved. The `REVISAR` control and its ordinary navigation were removed without deleting the reconciler or integrity checks.
