# VINI 2.0 RC3 — Revocation

The client removes unavailable, non-applied managed packages only after a successful Worker catalog response. Empty/failed requests are not treated as revocation. Packages with an active `DevicePatchService` receipt remain available for safe Restore, including their legacy copy and recovery key. Manual imports are not selected by the remote ID cleanup path.

Modified: `PatchManager.swift`, `PatchSyncManager.swift`.

Limitation: instant revocation requires a successful subsequent Worker response; offline clients cannot infer server state.
