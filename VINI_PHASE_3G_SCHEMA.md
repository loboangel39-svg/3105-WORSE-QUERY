# VINI Fase 3G — Esquema aislado

Estado: **DISEÑO LOCAL AISLADO**. Fase 3F continúa `BLOCKED` por falta de ejecución CI.

## Tabla propuesta

`patch_targets` relaciona una fila existente de `patches` con un target dinámico. No reemplaza `patches` ni `user_patches`.

- `target_id` identifica la tarjeta estable (`vini.esp_box`, por ejemplo).
- `project_id` y `package_id` son identidades verificadas por el importador; no se derivan del nombre del archivo.
- `(target_id, revision)` es único.
- Un índice único parcial impide más de una revisión autorizada/activa por target.
- `sha256` exige exactamente 64 caracteres hexadecimales.
- `file_size` exige un tamaño positivo.
- `patch_id` referencia `patches(id)` con borrado en cascada controlado.
- `ON DELETE CASCADE` elimina asignaciones cuando se elimina físicamente un patch; no se usa para revocar ni cambiar de revisión. Revocación y selección de revisión usan `authorization_status`/`active`, preservando historial.

## Migración

SQL: `backend/vini-admin/migrations/0004_patch_targets.sql`.

Es aditiva, no altera columnas existentes y no contiene datos productivos. No se ejecutó contra D1 principal.

## Rollback aislado

En una copia aislada, eliminar primero índices y después `patch_targets`. En producción se requiere una migración de rollback revisada y una ventana controlada; no se propone ejecutarla automáticamente.

## Riesgos

- SQLite/D1 debe soportar índices parciales (el motor usado por D1 sí los soporta, pero debe verificarse en el runner aislado).
- La unicidad de `package_id` evita asignar el mismo paquete a dos targets.
- La autorización final sigue dependiendo de `user_patches`, licencia/HWID y `active`; esta tabla no concede acceso por sí sola.
