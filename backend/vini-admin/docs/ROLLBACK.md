# Reversión y recuperación

No se ejecutó ninguna reversión productiva: no hubo despliegue ni migración allí.
Las siguientes decisiones requieren operador autorizado y datos de recuperación.

## Software

- Antes de aplicar migraciones o activar nuevas operaciones, puede conservarse
  el Worker original verificado y el objeto HTML R2 anterior como copia de retorno.
- Después de incorporar planes/claims/propietarios NO volver ciegamente al Worker
  original con escritura habilitada: ignoraría esos controles y la nueva política
  de saldo, y podría levantar pausas o saltarse restricciones de paquetes.
- Mantenimiento seguro: conservar el bundle de la ampliación y permisos activos,
  establecer ADMIN_READ_ONLY=1. Bloquea escrituras administrativas y migraciones;
  mantiene autenticación APP y restricciones de catálogo. No despausa clientes.
- ADMIN_PLANS_ENABLED=0 no es el rollback normal tras migrar: el router bloquea
  catálogo y escrituras administrativas de un modelo ya preparado para evitar
  concesiones de derechos por la caída al handler antiguo.
- Preparar un hotfix o versión anterior de la ampliación que preserve dichos
  controles. No rotar secretos ni cambiar identidad del cliente como workaround.

## SQL

No se entregan DROP TABLE/columnas destructivos como «down migration» automática.
Cada migración y checksum son atómicos por archivo: antes del commit de ese batch
no hay cambios parciales; después, el ledger permite continuar con el siguiente.
Repetir el migrador con el mismo manifiesto no vuelve a ejecutar los ya aplicados.
Una inconsistencia de checksum/esquema requiere investigación, no reset forzado.

Si fuera necesaria restauración completa, usar el backup/punto D1 autorizado en
una ventana de mantenimiento y reconciliar renovaciones/operaciones producidas
desde ese punto antes de reabrir. Restaurar un snapshot antiguo sin reconciliación
perdería historial y derechos: no es un procedimiento automático aceptable.

## Operaciones administrativas

Una pausa masiva se revierte por revertOf en una NUEVA operación confirmada. Solo
libera sus claims; otras pausas conservan estado y saldo. Cancelar pendientes no
deshace lotes ya aplicados. SUPER_ADMIN puede inspeccionar cualquier operación;
el creador puede reanudar una existente con reconfirmación mientras conserve sus
permisos. Una cuenta deshabilitada no puede continuar un job antiguo.

Archivado es baja lógica. Renovar/desarchivar es explícito y preserva bloqueos y
causas de pausa. La purga anonimiza de forma irreversible ciertos campos; no hay
botón de «deshacer purga» inventado. Un backup real puede ser necesario, con la
política de privacidad y retención correspondiente.
