# Internal refresh, based on b506cb9

This document supersedes the inline scan UI described in WQFILES_SCAN_UX.md.

Files has no scan banner, consent controls, retry button, spinner, progress
bar, percentage, scan counter or transient-error message. The added UIKit
banner is removed. Native directory, Apps and Cache screens suppress scan
status/progress and automatic health-failure presentations when embedded.
Explicit user file operations, backup/restore and cleaning keep their safety
prompts and behavior. The standalone WQFiles presentation remains available.

SilentAppDataRefresh owns the existing App Data discovery sequence outside
the SwiftUI view. It preserves its published rows and avoids duplicate work
across navigation. Opening Files requests a refresh with a 60-second cooldown;
foreground return can recover an interrupted refresh. Existing valid engine
cache is retained. Partial results merge with displayed rows. The final list
replaces prior rows only after a readable, non-blocked, non-transient result.
Unknown, denied or empty results retain the previous rows.

Retries use delays of 2, 8 and 30 seconds, with at most three attempts. Only
EINTR, EAGAIN, EBUSY and ETIMEDOUT are considered transient. Denied permissions,
unknown failures and scopes requiring consent do not trigger automatic retries.
Native retry owners are weak and pending retries are deduplicated. Work only
starts while the application is active; native callbacks also require the
screen to remain visible. No new background execution is requested.

Full-scan callbacks accept only prior valid consent: same scope and iOS major,
seven-day lifetime, maximum 50% growth. No automatic code grants or renews
consent. Missing, expired or enlarged-scope consent is logged and skipped.
There is deliberately no permission request UI in the normal Files flow.
Effective access and App Group requirements remain enforced by WQAccess.

WQAccess, worse_query, bad_query, LaunchServices/CSStore2, identity helpers,
entitlements, App Group, app identity and patch/restore code are unchanged.
The manifest in scripts/silent-refresh-protected.json pins 81 protected files
to their b506cb9 contents. Native UI-only adaptations are conditional on the
embedded policy. No parser, scan algorithm, access query or recovery format
is changed. Background entry uses the original cancellation API; interrupted
markers are recovered and the original cache lifecycle governs retry.

Checks include protected-file hashes, absence of refresh presentation in the
SwiftUI view and embedded host, original regressions, arm64 packaging, consent
expiry/scope/growth, refusal of automatic consent writes, cancellation and
ownership reuse, and simulator execution of the actual 2/8/30-second native
retry scheduler with duplicate rejection and a finite budget. The simulator
also checks that no refresh controls or modal appear before or after retries.

Visual comparison, search/navigation responsiveness during a real authorized
scan, process suspension/force-close recovery and the 291-app/Bundle-ID result
still require validation on the user's iPhone. Those results are not inferred
from compilation or from local-file simulator fixtures.
