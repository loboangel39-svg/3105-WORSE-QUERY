# VINI 3K — Resultados de pruebas

CI de cierre: commit probado `500b016`, run `43810614609` — **PASS**. URL: https://github.com/loboangel39-svg/3105-WORSE-QUERY/actions/runs/43810614609

PASS: catálogo vacío sin targets ficticios; target autorizado/preparado; filtrado por identidad completa; categorías `combat`, `visuals`, `offsets`; paquete pendiente no visible; revocación cubierta por regresión 3J; `prepared` no equivale a `applied`.

SKIPPED: ejecución visual en dispositivo, Apply/Restore y reconstrucción de `restorePending`, por ausencia de API pública autorizada.

La regresión 3J se ejecutó en `macos-15`, junto con compilación unsigned `iphoneos arm64` y comprobación de hashes protegidos. No se realizó ejecución visual en dispositivo ni despliegue productivo.
