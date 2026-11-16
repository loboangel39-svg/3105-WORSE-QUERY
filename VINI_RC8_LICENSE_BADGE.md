# VINI 2.0 RC8 — License badge

`ControllerHeader` now reads the existing authenticated `VINIProductionStore.profile` and displays only the authorized `PRO` or `BASIC` value. Unknown or pending plans use `—`; no additional Worker request is made. The badge keeps its existing position, typography, cyan styling and dimensions. The commercial version remains 2.0 in the bundle metadata.

The Information view displays only Usuario, Plan, Tiempo restante, Proveedor and Cerrar sesión. The countdown continues to use the existing server-derived expiration and one-second `TimelineView`.
