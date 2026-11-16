# VINI 2.0 RC9 — Layout root cause

The persistent gap was structural: the compact layout already owns the header and tab navigation in `ContentView`, while both tab roots added an unnecessary inner `NavigationStack`. Installed also used `List(.insetGrouped)` and Information used `Form` with the default grouped insets. Their empty navigation titles still reserved navigation/layout space.

RC9 removes the redundant stacks from `PatchProjectsView` and `SettingsView`, uses a plain list style for the two tab roots, and removes the empty navigation-title modifiers. No negative padding, offset, unsafe-area override or fixed-height workaround was added. Existing sheets and exceptional recovery presentation remain available.
