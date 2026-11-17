# RC12 Final Fix — Bundle discovery

Files now re-resolves a bundle-backed root on each load using
`ContainerStore.resolveAppContainerPath` on a background queue. This avoids
reusing a stale container UUID after uninstall/reinstall. Apply already uses
the same resolver. Files requests `.read`; Apply requests `.write` and performs
the existing effective-write probe, so discovery and capability remain
distinct.

Acquisition failures preserve the `NSError` domain and code in the patch
diagnostic instead of being silently relabeled as an unavailable application.
