# VINI 2.0 RC3 — License countdown

`VINIProductionStore` derives remaining time from the Worker-provided `licenseExpiresAt` and `serverTime`, then advances it with monotonic `systemUptime`. `SettingsView` presents a single one-second `TimelineView` as `DDd HHh MMm SSs`, clamps at zero, and shows `Licencia expirada` after expiry. No per-second Worker requests are made.

Token lifetime and commercial license expiry remain distinct; authorization still uses the existing client lifetime policy. Offline display uses the last authorized absolute expiry without extending it.

Physical clock-change, renewal and revocation tests remain pending.
