# VINI 2.0 RC11 — New reference policy

RC11 distinguishes an active engine receipt from an orphaned VINI record. The
former remains protected; the latter is eligible for a new transaction identity
because `latestReceipt` returns no recoverable `prepared` or `applied` journal.
The new operation captures the current destination bytes and never labels them
factory-original. Its Restore returns those captured bytes.

The isolated owned fixture accepts a previously modified regular destination,
validates its root identity, and verifies the new operation's backup. Physical
confirmation flows for a lost history remain pending on-device.
