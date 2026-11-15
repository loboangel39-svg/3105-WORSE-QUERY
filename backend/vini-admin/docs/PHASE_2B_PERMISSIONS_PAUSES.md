# Permisos y pausas — ampliación 2B

Esta matriz complementa PERMISSIONS.md; para controles nuevos prevalece este documento.

| Operación | SUPER_ADMIN | ADMIN | DISTRIBUTOR |
|---|---|---|---|
| Pausar/reactivar individual | Sí | Ámbito + pause/reactivate | Propios + pause/reactivate |
| Baja lógica individual | Sí | Ámbito + archive | Propios + archive |
| Reset HWID individual | Sí | Ámbito + hwid_reset | Propios + hwid_reset |
| Pausa/reactivación de directos | Sí | Ámbito direct + acción | No |
| Pausa/reactivación de distribuidor | Sí | Distribuidor asignado + acción | Solo propio + acción |
| Pausa/reactivación global | Sí | No | No |
| Eventos de seguridad | Sí | No | No |

Ningún token APP autoriza administración. Worker vuelve a verificar cuenta, ámbito, acción y estado del distribuidor; no confía en botones ni IDs enviados. No hay HWID reset masivo. Las acciones denegadas del API nuevo se guardan sin cuerpos, claves ni HWID en admin_security_events. Los controles sin permiso aparecen deshabilitados.

## Política comprobada

La primera pausa guarda milisegundos restantes por licencia. Claims globales, de distribuidor, directos e individuales pueden coexistir. Una pausa adicional no recalcula ni consume el banco. Reactivar un ámbito retira solo los claims correspondientes capturados en el preview: no los de otros orígenes ni los añadidos después. La última liberación establece expiración = hora del servidor + saldo individual. Antes de ella, el contador sigue congelado.

Saldos de siete y cuatro días se mantienen separados. Renovar en pausa actualiza el saldo individual. Reactivar no retira bloqueos, revocaciones ni baja lógica. El archivado por fecha rechaza licencias con banco congelado; una baja lógica individual explícita preserva el banco y auditoría. El historial registra actor, motivo, origen, operación y hora.

Los previews persisten miembros/revisiones y claims exactos. La confirmación es obligatoria; ejecución en lotes de cinco, idempotente y auditable. Repetir la misma operación no duplica pausas ni reset de epoch. Cambios concurrentes de revisión producen conflicto en vez de sobrescribir estado nuevo.
