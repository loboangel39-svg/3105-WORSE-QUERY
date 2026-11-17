# VINI 2.0 RC11 — Transaction safety

No native patch engine, WQFiles, bad_query, worse_query, Worker, D1, R2,
ContainerAccessCoordinator, import pipeline, catalog, entitlement or App Group
was changed. Apply/Restore remain serialized by `mutationLock`.

Identity and path validation remain mandatory. Backup A/B manifests and journal
digests remain mandatory. Changed content is a warning/confirmation condition,
not an identity authorization. A failed write or verification still retains
the transaction evidence needed for recovery.
