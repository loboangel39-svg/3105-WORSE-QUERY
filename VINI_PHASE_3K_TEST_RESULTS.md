# VINI 3K — Resultados de pruebas

Estado inicial: **PENDING CI**.

PASS esperado del modelo: catálogo vacío sin targets ficticios; target autorizado/preparado; filtrado por identidad completa; categorías `combat`, `visuals`, `offsets`; paquete pendiente no visible; revocación y cambio de revisión excluyen la entrada no preparada; `prepared` no equivale a `applied`.

SKIPPED: ejecución visual en dispositivo, Apply/Restore y reconstrucción de `restorePending`, por ausencia de API pública autorizada.

La regresión 3J debe seguir ejecutándose en `macos-15`, junto con compilación unsigned `iphoneos arm64` y comprobación de hashes protegidos.
