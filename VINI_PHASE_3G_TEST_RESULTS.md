# VINI Fase 3G — Pruebas locales

Estado: **PASS PARCIAL — VALIDACIÓN LOCAL AISLADA**.

Arnés runtime: `scripts/test_phase3g_worker_runtime.mjs`. Ejecuta el `fetch` real de `vini-v2-api/src/index.js` con D1 SQLite en memoria y un R2 aislado; no sustituye el handler por respuestas preconstruidas.

## Matriz obligatoria

| Prueba | Resultado |
|---|---|
| Crear `patch_targets` sobre copia aislada | PASS |
| FK a `patches` | PASS |
| Unicidad `(target_id, revision)` | PASS (la segunda revisión autorizada/activa fue rechazada) |
| Una sola revisión autorizada/activa | PASS |
| Rechazo de SHA-256 no hexadecimal o longitud incorrecta | PASS |
| Rechazo de `file_size <= 0` | PASS |
| Catálogo antiguo sin `patch_targets` | Pendiente |
| Paquete revocado no visible/descargable | Pendiente |
| Paquete sin `user_patches` no visible/descargable | Pendiente |
| Componentes protegidos sin cambios | PASS (hashes del baseline coinciden) |
| Sintaxis del handler Worker modificado | PASS (`node --check src/index.js`) |
| Campos nuevos ausentes en filas antiguas | PASS por diseño (propiedades `target` omitidas) |
| Catálogo antiguo y autorización `user_patches` | PASS |
| Revocado/inactivo/no asignado no visible | PASS |
| Descarga válida, SHA-256 incorrecto y tamaño incorrecto | PASS |
| BASIC/PRO y endpoints originales | PASS (sesiones sintéticas, handler real) |
| Revisión activa sin ambigüedad | PASS por índice y consulta |

Evidencia: `scripts/test_phase3g_sql.mjs`, ejecutado con Node.js `v26.13.1` y `node:sqlite`; salida `PASS isolated migration and constraints`. No se ejecutó ninguna migración productiva ni se modificó el Worker desplegado.

La ejecución produjo `PASS worker runtime isolated checks: 8/8`. No se ejecutó ninguna migración productiva ni se modificó el Worker desplegado. Queda pendiente únicamente repetir la batería en CI macOS cuando 3F sea desbloqueada.
