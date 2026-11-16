# VINI 2.0 RC3 — Apply and Restore

Apply and Restore use the existing `DevicePatchService`, `PatchTransaction`, journal and `VINIDualBackupStore` paths. Normal Apply and Restore confirmations were removed; exceptional changed-target recovery remains guarded. Apply is disabled when a persisted receipt exists and Restore is enabled until recovery completes, so the lock is not only visual state.

Protected native components were not modified. Physical tests for normal Restore, alternate A/B recovery and corrupt-backup rejection remain pending.
