# Matriz de permisos

Los filtros visuales no conceden acceso. Cada request verifica la sesión y carga
la cuenta administrativa vigente. Las mutaciones por lotes vuelven a comprobar
estado de cuenta, acción, ámbito y estado del distribuidor dentro de SQL.
Tokens APP no sirven para administración. Los tokens RBAC tienen dominio de
firma y `kid` independientes de APP y del admin legacy.

| Acción | SUPER_ADMIN | ADMIN | DISTRIBUTOR |
|---|---|---|---|
| Leer usuarios/licencias | global | ámbitos asignados + read | propios + read |
| Crear usuario/licencia BASIC/PRO | global | ámbitos + create | propio distribuidor + create |
| Renovar | global | ámbitos + renew | propios + renew |
| Pausar individual/seleccionados/ámbito | global | ámbitos + pause | propios + pause |
| Pausa global, incluso con filtros | sí | no | no |
| Reactivar individual/revertir pausa | global | ámbitos + reactivate | propios + reactivate |
| Revocar/archivar | global | ámbitos + acción explícita | propios + acción explícita |
| Transferir distribuidor | sí | no | no |
| Crear/suspender distribuidores | sí | no | no |
| Crear/deshabilitar administradores | sí | no | no |
| Perfil APP | sesión APP propia | sesión APP propia | sesión APP propia |
| Configurar permisos de patches | sí | no | no |
| Retención/purga | sí, confirmada | no | no |
| Ver operaciones | todas | propias | propias |
| Ejecutar/reanudar operación existente | su creador autenticado | su creador | su creador |
| Cancelar pendientes de una operación | todas | propias | propias |
| Migraciones bootstrap | principal legacy verificado y flag explícito | no | no |

Un SUPER_ADMIN puede revertir los efectos ya aplicados de otra operación mediante
una nueva operación autorizada; no ejecuta pendientes impersonando a su creador.
Los ámbitos ADMIN son `direct` o `distributor:UUID`. No existe un comodín para
distribuidores. Los clientes con origen histórico desconocido solo están visibles
globalmente a SUPER_ADMIN hasta una clasificación explícita.

Las cuentas DISTRIBUTOR no reciben acciones por defecto. La pertenencia se toma
de la cuenta autenticada, no de `distributorId` del cuerpo. Una suspensión del
distribuidor impide iniciar/usar su sesión administrativa; no revoca las licencias
de sus clientes automáticamente: esa acción es una operación independiente.

El principal anterior se representa como `legacy-super` solo para acciones NUEVAS.
No se utiliza para atribuir creaciones históricas desconocidas. No se almacena
su contraseña en D1. Los nuevos administradores usan sal y PBKDF2/SHA-256, token
de una hora y verificación de estado/epoch en cada request. La deshabilitación
incrementa epoch y bloquea inmediatamente nuevas operaciones autenticadas.

Las vistas globales originales siguen disponibles únicamente para SUPER_ADMIN.
Un SUPER_ADMIN nominal usa delegación interna breve al verificador original;
ese token de transporte no se devuelve al navegador. Ningún rol inferior puede
usar esas vistas ni recibir ese transporte.

BASIC/PRO no son ámbitos administrativos. PRO incluye las capacidades BASIC,
pero la autorización de un patch incorporado a política requiere simultáneamente
licencia activa, plan/capacidad, asignación individual, paquete activo, política
habilitada/no revocada, compatibilidad declarada y distribuidor permitido.
