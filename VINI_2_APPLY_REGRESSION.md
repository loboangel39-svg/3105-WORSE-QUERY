# VINI 2.0 Apply regression

## Cause

The original Apply called `PatchTransaction.apply` directly. Its existing
`latestReceipt` check ran before any VINI operation index was written.

RC7 introduced `DevicePatchService.apply` (`b7815ee`, productive dual-backup
integration). That method saved a new `.preparing` `VINIOperationRecord` before
calling `PatchTransaction.apply`. When an old receipt existed, the transaction
engine correctly threw `projectAlreadyApplied`, but the new record had already
replaced the old project association. This could orphan the record needed by
Restore/recovery and made repeated Apply failures look persistent after a
restart or package re-import.

## Correction

`DevicePatchService.apply` now performs the receipt preflight before creating
or saving a VINI record. The transaction engine, journal format, Apply writes,
Restore, destination checks, and backup retention are unchanged. A rejected
Apply therefore leaves the previous operation record and recovery evidence
untouched.

The Apply and Restore UI also retains the concrete underlying error for errors
outside `PatchPackageError`, rather than converting it to `invalidProject` or a
generic Apply/Restore message.

## Import/delete behavior

RC10's explicit delete/re-import identity reset remains in place: package-only
files and temporary management state are removed, while old journals and
backups remain separate. A re-import receives a fresh project UUID when old
receipt evidence still exists. It does not claim that the destination was
restored; the normal receipt and target-integrity checks still apply.

## Verification

- `git diff --check`: passed.
- Historical comparison: original direct Apply versus RC7+ pre-save ordering.
- CI build already passed for the RC10 baseline (`43980049145`).
- Physical-device Apply/delete/re-import/Restore tests remain pending; these
  require owned destination fixtures and cannot be safely performed against
  production application containers in this environment.
