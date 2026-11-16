# VINI 2.0 RC6 — Operation states

Installed derives the normal action from persisted receipts: no receipt gives `APPLY`; a receipt gives `RESTORE`; an in-flight Store operation gives `PROCESANDO`; a changed-target refusal persists a `REVISAR` marker until recovery succeeds. Direct operations continue to call `DevicePatchService`, verify the post-operation state, reload the library and block concurrent work.

Normal success alerts remain removed. Restore conflicts and integrity failures remain visible. A failed Restore does not re-enable Apply or delete journals/backups.
