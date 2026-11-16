# VINI 2.0 RC9 — Concurrency validation

The existing detached library load remains the sole background loader and publishes through the `@MainActor` store. RC9 does not introduce a second writer, parallel destination mutation, or a detached closure over mutable transaction state. Apply/Restore and A/B coordination remain unchanged and serialized by their existing service locks.

The reconciler performs only read-only receipt/journal/manifest inspection in the background. UI state (`items`, `recoveryRequiredIDs`, `isBusy`) is assigned on the main-actor store after the worker completes.
