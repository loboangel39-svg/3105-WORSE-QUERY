# VINI 2.0 RC11 — Apply overwrite

Apply continues to use `PatchTransaction`. Its transaction directory captures
the exact bytes present immediately before each write (`.original`) and verifies
their digest before the transaction is considered prepared. A different
pre-existing digest is input to the new backup, not a reason to reject Apply.

An active `prepared`/`applied` receipt still blocks a second operation for the
same project. This preserves transaction exclusivity. If only a stale VINI
record remains and no active receipt exists, the new Apply replaces that stale
association with a fresh transaction and fresh backup.
