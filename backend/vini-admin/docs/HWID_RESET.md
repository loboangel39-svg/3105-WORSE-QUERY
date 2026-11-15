# Reset HWID individual: contrato y límites

El administrador identifica una sola licencia en su ámbito y confirma la acción.
No existe selector masivo para hwid_reset; cambiar IDs no evade permisos. APP
Bearer no concede administración. La acción requiere hwid_reset, además del ámbito.

El mismo batch transaccional que reclama el miembro:

1. Vacía HWID de ese usuario e incrementa users.device_epoch.
2. Elimina sus challenges de las activaciones anteriores.
3. Revoca sus activaciones, sin modificar las de otra licencia.
4. Registra actor, licencia lógica, operación y fecha sin copiar el HWID ni clave.

Al repetir la MISMA operación completada no incrementa otra vez el epoch. Una
sesión nueva adquirida después del reset sigue siendo válida tras ese retry.

## Sesiones APP y compatibilidad

El login existente conserva campos, codec y caducidad de sesión. El token añade
un claim interno deviceEpoch; el cliente puede seguir tratándolo como opaco.
Tokens antiguos sin claim equivalen a epoch 0 y se aceptan mientras el usuario
no haya sufrido un reset. Tras incrementarlo, todos los tokens previos fallan
en TODAS las rutas APP, incluso config/listado/detalle/descarga. Además, para
epochs posteriores a reset se exige concordancia con el vínculo HWID vigente.
No basta comprobar solo `/me` y dejar rutas heredadas abiertas.

Una nueva autenticación con la clave de licencia válida puede volver a vincular
el dispositivo según el contrato anterior. Reset NO rota la clave de licencia
ni constituye una prohibición permanente de reautenticación de su poseedor.
Una carrera entre vínculos no concede un token cuyo HWID difiera del actual.

Activaciones v1 revocadas no pueden pedir nuevos challenges ni convertir un
challenge antiguo en otro lease. No se cambia el protocolo P-256/Ed25519 ni iOS.

## Límite offline comunicado antes de confirmar

Un lease firmado y ya entregado a un cliente OFFLINE no puede retirarse a distancia
sin cambiar el cliente o esperar su caducidad. El reset revoca sesiones y capacidad
de operar/renovar ONLINE; no promete borrado de leases offline ya emitidos.
El panel muestra este límite. El staging usa TTL de lease de 300 segundos;
no se ha modificado el TTL productivo ni se ha leído su secreto de firma.

Si se necesita revocación offline instantánea, habrá que acordar otro contrato de
cliente/conectividad en una fase autorizada. No se simula esa capacidad ni se
presenta una prueba online como validación offline.
