# VINI 2.0 RC5 — Live sync audit

## Root cause

RC4 owned the periodic task inside `PatchProjectsView`. Changing tabs could cancel that view task, so the active sync loop was not application-scoped. Store reload notifications were also tied to the visible Installed view.

## Correction

- `ContentView` now owns the authorized foreground sync task and observes the shared `PatchProjectStore`.
- `PatchSyncManager` remains the only remote-to-library coordinator and prevents overlapping attempts.
- The flow is Worker catalog → existing download/revocation logic → legacy library copy → async Store reload → SwiftUI publication.
- Foreground and authorized-login reasons are logged without credentials.
- Interval remains 45 seconds; transient errors do not invoke revocation cleanup.

## Files/functions

- `ContentView.body`: persistent lifecycle task and shared Store publication.
- `PatchSyncManager.syncPatches(reason:)`: single sync entry point and timing logs.
- `PatchProjectStore.reloadAsync()`: library load off MainActor.
- `PatchProjectsView`: manual Installed refresh retained without owning the periodic loop.

Physical live assignment/revocation testing on iPhone remains pending.
