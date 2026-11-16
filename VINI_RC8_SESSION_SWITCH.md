# VINI 2.0 RC8 — Session switching

Cerrar sesión continues to call the existing `VINIProductionStore.logout()` and `VINIStagingClient.logout()` implementation. It clears the active local session state and returns `VINIAuthenticationRoot` to the login phase; a subsequent license is authenticated through the existing Worker contract. No expiry, HWID, D1/R2 data, patch files or recovery backups are modified by the UI changes.

The authentication root still gates ContentView on the authorized phase, so the badge and four Information values refresh from the newly authenticated profile.
