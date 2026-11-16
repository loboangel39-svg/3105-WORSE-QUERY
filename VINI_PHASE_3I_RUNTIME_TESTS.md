# VINI Fase 3I — Pruebas runtime

Arnés: `scripts/test_phase3g_worker_runtime.mjs`, que ejecuta el `fetch` real del Worker local con D1 SQLite y R2 aislados.

Resultado observado: `PASS worker runtime isolated checks: 14/14`.

Casos PASS independientes:

1. BASIC autorizado.
2. PRO autorizado.
3. BASIC sin asignación.
4. PRO con asignación individual.
5. Licencia expirada.
6. HWID incorrecto.
7. Patch inactivo.
8. Target revocado.
9. Target deshabilitado.
10. Revisión activa sin ambigüedad.
11. SHA-256 incorrecto.
12. Tamaño incorrecto.
13. Objeto R2 ausente/revocado no descargable.
14. Descarga válida y catálogo compatible.

La prueba también cubre el cambio de estado entre consultas y descarga: al revocar el target después de una consulta, la descarga es rechazada.
