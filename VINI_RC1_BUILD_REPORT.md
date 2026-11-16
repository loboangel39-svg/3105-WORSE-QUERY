# VINI 2.0 RC1 — Build Report

- Required artifact: `VINI-2.0-RC1-Unsigned.ipa`
- Bundle ID: `com.apple.mobile.MobileHouseArrest`
- Requested architecture: `arm64`
- CI run: **PENDING** — this Windows workspace cannot execute Xcode/macOS.
- IPA SHA-256: **PENDING** until GitHub Actions succeeds.
- Exact commit: `daa6db20c344b346d2ef9e1644530073e82142df`.

The macOS workflow builds `iphoneos`, forces `ARCHS=arm64`, disables signing, validates Bundle ID and native object presence, packages the exact build output, and uploads the required artifact name.

Tests performed locally: source/tree audit, protected-file comparison, project-file source membership audit, and `git diff --check`.
Pending: CI SUCCESS, real iPhone login, authorized download, codec import, Installed display, Files access, and physical Apply/Restore/backup verification.
