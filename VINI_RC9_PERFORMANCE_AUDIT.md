# VINI 2.0 RC9 — Performance audit

The RC8 optimization is retained and extended. Library loads and post-operation reloads execute through the existing `reloadAsync()` worker path. The UI now avoids nested navigation containers and grouped list/form insets, reducing layout work before the first row. Reload publication is skipped when item IDs, summaries, projects and recovery markers are unchanged.

No claim of sustained 60/120 FPS is made. Instruments (Time Profiler, Hangs, SwiftUI, Animation Hitches, Allocations) and physical iPhone measurements were unavailable in this Windows environment. Physical validation remains `PENDIENTE DE VALIDACIÓN FÍSICA`.
