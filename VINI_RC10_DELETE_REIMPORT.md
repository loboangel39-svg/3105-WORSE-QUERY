# VINI 2.0 RC10 — Delete and re-import

`PatchProjectLibrary.delete` no longer rejects a package merely because an applied/prepared receipt exists. It removes the package file, workspace, package key, origin metadata and author marker, while leaving transaction journals and recovery backups untouched.

Deletion runs off the main actor. If the same package is imported after deletion and its old project ID still has a receipt, the decoded project is rebased to a fresh UUID before installation. This creates a new management instance and prevents the old receipt from blocking Apply. The old transaction evidence remains separate and is not used as the new package state. A new Apply still uses the normal transaction conflict checks.
