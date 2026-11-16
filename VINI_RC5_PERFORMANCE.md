# VINI 2.0 RC5 — Performance

## Corrected causes

| Area | RC4 issue | RC5 correction | Evidence |
|---|---|---|---|
| Periodic sync | Task owned by Installed view | Task owned by persistent ContentView | Code audit |
| Library reload | Synchronous `PatchProjectLibrary.load()` on MainActor | `reloadAsync()` uses detached load and publishes on MainActor | Code audit |
| Initial sync | Separate manager calls could duplicate work | One `PatchSyncManager` entry point | Code audit |
| Catalog timing | Limited reason context | Reason, count and duration logs | Instrumentation |

RC5 does not claim numeric latency improvement without physical profiling. Timing logs intentionally exclude tokens, license values and keys.
