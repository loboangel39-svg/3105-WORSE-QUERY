# VINI 2.0 RC3 — Worker compatibility

Worker: `https://vini-v2-api.loboangel39.workers.dev`.

No Worker, D1, R2, authentication, HWID or stored expiry data was changed. The existing validation contract is consumed, including `licenseExpiresAt`, `expiresAt`, `serverTime`, `username` and `plan`; commercial countdown uses `licenseExpiresAt` when present. Confirmed HTTP 401 responses continue to emit the existing session-invalidation notification.

No backend deployment was performed.
