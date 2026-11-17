# VINI 2.0 RC12 — Apply/Restore validation

- Active receipts still serialize operations for the same project.
- Apply accepts a different current digest and captures that current content.
- A missing active receipt permits a fresh transaction reference; an active
  prepared/applied receipt remains protected.
- Restore validates the transaction receipt, container fingerprint, contained
  paths, backup presence/digest, write result and final original digest.
- Changed targets are warnings, not an authorization to use an incorrect
  container or path.

Physical owned-file tests remain pending.
