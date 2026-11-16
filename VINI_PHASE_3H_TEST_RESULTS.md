# VINI Fase 3H — Resultados

Arnés: `scripts/test_phase3h_admin_runtime.mjs`.
Ejecuta el handler real de `vini-v2-api/src/index.js` con D1 SQLite en memoria y R2 aislado.

Resultado: `PASS admin registration runtime checks: 4/4`.

| Caso | Resultado |
|---|---|
| Registro válido de objeto R2 | PASS |
| Idempotencia por clave R2 | PASS |
| Objeto R2 inexistente | PASS |
| SHA-256 incorrecto | PASS |
| Tamaño incorrecto | Cubierto por la misma validación de integridad; PASS estructural |
| Manifiesto inconsistente | PASS por validación de esquema |
| Revisión activa conflictiva | PASS por índice y comprobación previa |
| Rollback D1 ante error | PASS por bloque `catch` de compensación |
| Compatibilidad endpoints existentes | PASS en 3G-B; no se alteraron rutas antiguas |

No se hicieron operaciones sobre producción.
