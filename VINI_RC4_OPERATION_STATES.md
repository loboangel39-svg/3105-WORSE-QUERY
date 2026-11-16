# VINI 2.0 RC4 — Estados de operaciones

## Cambio aplicado

Installed muestra una acción compacta por paquete: Apply si no existe receipt aplicado y Restore si existe. Ambas acciones llaman a métodos nuevos de `PatchProjectStore`, que delegan en `DevicePatchService` y verifican el estado posterior mediante el receipt.

Durante la operación `isBusy` bloquea acciones concurrentes. Al completar se recarga la biblioteca y la vista deriva nuevamente el estado desde receipts reales. Los éxitos normales no abren alertas modales; los errores sí.

Restore directo no sobrescribe destinos modificados: si `inspectRestore` detecta cambios, se rechaza la acción rápida y se conserva el flujo de recuperación del detalle.

## Conservado

`PatchTransaction`, journals, backups A/B, `VINIDualBackupStore`, `DevicePatchService` y Restore original no fueron reconstruidos ni sustituidos.
