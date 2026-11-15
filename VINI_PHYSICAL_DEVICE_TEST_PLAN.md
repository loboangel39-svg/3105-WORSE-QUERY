# Plan de aceptación en iPhone físico

Estado: PENDIENTE, no ejecutado. Dispositivo indicado por el usuario: iPhone 13 Pro Max; versión iOS comunicada: 27.2.1, pendiente de comprobar en Ajustes. No se ejecutó CoreSimulator, simctl ni emulador. No se generó una IPA nueva.

## Requisito previo

La rama actual no incorpora una conexión de login/catálogo VINI APP a este staging. La copia histórica externa sí contiene LoginManager/RemotePatchService, pero apunta a vini-v2-api productivo y no es la IPA de este checkout. No instalar ni usar esa copia para ensayos staging suponiendo que cambió su servidor.

Antes de preparar una IPA: autorizar explícitamente una fase de integración cliente, fijar todos los endpoints en el staging autorizado y verificar las URLs del artefacto. Debe conservar Bundle ID, App Group, entitlements y firma autorizada; no sustituir identidad para evitar conflictos. Preparar respaldo según el flujo existente antes de reemplazar una instalación con esa misma identidad. La IPA deberá bloquear cualquier fallback automático a producción. No modificar Apply/Restore ni aplicarlos sobre datos reales.

## Preparación de datos

Usar dos licencias ficticias nuevas, BASIC con siete días y PRO con cuatro, un patch BASIC asignado, otro PRO asignado y uno no asignado. Sin claves productivas ni paquetes reales. El propietario accede a staging mediante su acceso DPAPI ya entregado; no pegar contraseñas/tokens en el chat. Mantener el fixture de transporte solo para importación/inspección, nunca Apply.

## Secuencia y aceptación

| Prueba | Evidencia y resultado requerido |
|---|---|
| Origen API | Logs sanitizados confirman únicamente vini-admin-plans-staging-2b; ningún request de negocio productivo |
| Login BASIC/PRO | Nombres/planes y estado correctos; isPremium coherente; no exponer licencia en capturas |
| Fecha/saldo | Hora servidor y licenseExpiresAt separados de expiración de sesión/lease; siete/cuatro días independientes |
| Catálogo | BASIC sin PRO; PRO solo asignados; sin paquete no asignado |
| Descarga/importación | SHA256 del fixture coincide; codec nativo inspecciona/importa v3; ninguna operación Apply/Restore |
| Interrupción | Cortar internet durante descarga; archivo parcial no se importa; reintento completo conserva hash |
| Pausa | Individual, distribuidor y global; acceso online rechazado; saldo visual permanece congelado |
| Superposición | Reactivación global conserva pausa individual/distribuidor; solo última liberación reanuda contador |
| Relanzamiento | Cerrar y abrir app sin perder estado válido ni ejecutar acciones duplicadas |
| Sesión | Relogin/auto-login almacena token nuevo; no depender de X-New-Token inexistente; probar 401 por caducidad |
| Sin red y retorno | Mostrar política offline acordada; recuperación no inventa autorización ni cambia saldo |
| Reset HWID | Sesiones/activaciones anteriores rechazadas online; nueva autenticación válida según licencia; otras licencias intactas |
| Lease | Firma y exp comprobados; un lease anterior puede valer hasta caducar offline, sin prometer borrado remoto |

Caducidad de sesión y lease puede probarse con credenciales de ensayo controladas o esperando sus tiempos; no cambiar el reloj global del dispositivo ni duración de leases productivos. Bloqueo/revocación de licencia deben distinguirse de un simple error de red.

Registrar versión/hash de IPA, modelo/iOS real, hora servidor, caso, esperado/observado y captura/log saneado. No incluir Bearer, contraseñas, content keys, claves de licencia ni datos personales. El usuario enviará esos resultados; solo entonces se evaluará aceptación física. Ninguna casilla se considera aprobada con la evidencia de Edge o workerd.

Detener si aparece un endpoint productivo, identidad distinta, paquete no asignado, saldo consumido durante pausa, importación parcial o modificación real de archivos. No autorizar producción hasta revisar los resultados y los pendientes de VINI_PRODUCTION_READINESS.md.
