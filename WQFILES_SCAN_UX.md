# WQFiles scan presentation in 3105

Base: bda918597aac6b1fc33c331a82b6f8a76a40fad7.
Branch: experiment/wqfiles-scan-ux.

The embedded runtime registers `WQScanConfirmPresentation` and
`WQScanProgressPresentation` instead of the standalone modal callbacks
`wq_confirm_full_scan` / `wq_full_scan_progress`. The standalone main.m stays
unchanged. WQAccess's `wq_set_full_scan_ui`, `wq_full_scan_begin`,
`wq_full_scan_end`, serial gate, cancellation token and persistent cache are
unchanged. No access or discovery capability is added.

The initial request appears inline above the Files list. It explains the
requested scope, number of file IDs, expected duration category, lack of file
mutation, and consent lifetime. Consent is stored per scope and OS major
version, lasts seven days, and permits up to 50% growth from the approved
bound. A different scope, expired consent or greater growth requires a new
inline decision. No scan waits for a user answer while holding the worker:
an unapproved attempt returns NO through the original gate-release path.
Approval schedules one refresh after any existing refresh finishes.

`WQScanPresentation.inc` owns main-queue presentation state. Progress from
workers is throttled to four updates per second. Files and the embedded UIKit
host show inline progress and Cancel. No progress sheet or alert is presented
by these callbacks. A process-wide refresh guard prevents duplicate Files
refreshes; the original gate still serializes full scans.

`AppDataBrowserView.reload` retains previously shown applications during
preliminary/progressive updates and merges incoming rows by container path.
Search text and navigation are preserved. A completed, non-declined,
non-cancelled refresh publishes its final list. An interrupted or empty result
retains the previous rows. This changes presentation, not identification.

On background entry, the adapter invokes the original cancellation function.
It creates no background task and makes no promise that iOS will keep running.
A durable running marker becomes a stopped/retry state after unexpected
termination. Transient ownership and percentage are never restored as active.
Retry is user-initiated in the foreground, invalidates the shared scan through
the original API and reuses the engine's persistent valid cache. Partial scan
cursors are not newly persisted; the original engine controls cache validity.

Tests: original regression suite (including scan lifecycle/cache/cancellation
and CSStore2), arm64 IPA compilation, and simulator integration. The simulator
adds consent expiry, scope separation, growth bounds, persisted-consent reuse,
interrupted-marker recovery, duplicate refresh rejection, cancellation and
ownership reuse checks using the actual presentation adapter.

Device acceptance still requires checking the inline approval, typing in
search and navigating while a real long scan runs, cancelling, backgrounding,
force-closing and reopening on the user's iPhone. A simulator result cannot
establish those device-specific behaviors or prove the 291-app count persists
on a particular installation. Protected source files are compared to bda9185
to ensure access, entitlements, identification, patches and Apply/Restore are
unchanged.
