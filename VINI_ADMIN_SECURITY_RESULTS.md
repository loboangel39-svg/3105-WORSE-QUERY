# Seguridad administrativa — resultados 2C

## Matriz efectiva

| Acción | SUPER_ADMIN | ADMIN | DISTRIBUTOR |
|---|---|---|---|
| Usuarios, crear BASIC/PRO, renovar | Global | Ámbitos y acción asignados | Propios y acción asignada |
| Pausar/reactivar individual | Sí | Ámbito + pause/reactivate | Propios + pause/reactivate |
| Pausar/reactivar directos | Sí | direct + acción | No |
| Pausar/reactivar distribuidor | Sí | Distribuidor asignado + acción | Solo propio + acción |
| Pausa/reactivación global | Sí | No | No |
| Baja lógica / HWID individual | Sí | Ámbito + archive/hwid_reset | Propios + archive/hwid_reset |
| Administradores, transferir, seguridad global | Sí | No | No |

Los tokens APP no conceden administración. BASIC/PRO son planes de cliente, no roles administrativos. No existen reset HWID masivo ni permisos implícitos de distribuidor. La matriz de detalle 2B se mantiene en backend/vini-admin/docs/PHASE_2B_PERMISSIONS_PAUSES.md.

## Pruebas y controles

- Evidencia 2B: Edge oculta administración global al distribuidor; Worker rechaza IDs manipulados, pertenencias falsas y reversión de pausas globales desde rol inferior. ACL se vuelve a comprobar dentro del batch, junto con revisión del usuario. Las vistas antiguas globales requieren SUPER_ADMIN.
- 2C: APP rechazado en admin-v2, Origin externo rechazado, username con markup y cuerpo inválido rechazados. No se devolvieron stacks ni secretos en las respuestas verificadas. No es una prueba de penetración exhaustiva de todas las rutas heredadas.
- Rate limit nominal: diez credenciales incorrectas producen 401; la undécima, 429. APP: veinte licencias ficticias incorrectas producen 401; la vigésima primera, 429. No se agotaron límites de usuarios reales.
- Preview, snapshot, confirmación, cinco miembros por batch e idempotency key impiden repetir efectos confirmados. Revisión concurrente produce conflicto. Historial y denegaciones se prueban en 2B; no se incluyen cuerpos ni claves en admin_security_events.
- Reset individual borra vínculo solo de esa licencia, incrementa device_epoch, elimina challenges y revoca activaciones anteriores en el mismo batch. Todas las rutas APP verifican epoch. Repetir la misma operación no vuelve a invalidar la nueva sesión. Los tokens antiguos sin epoch son compatibles únicamente mientras epoch sea cero.
- Nuevo ensayo remoto verifica firma Ed25519 real, desafío P-256 y rechazo de replay. Tras reset, la firma del lease offline ya emitido sigue verificándose: no existe revocación retroactiva de ese documento firmado. TTL staging comprobado: 300 segundos. TTL productivo no leído ni alterado.

## Secretos y límites

Credenciales staging suministradas por stdin desde DPAPI de Windows; no quedan tokens, contraseñas, claves privadas ni licencias válidas en informes/Git. El fixture no tiene contraseña ni datos reales; usa una clave de contenido pública según el formato público existente. El acceso anterior de staging sigue cifrado fuera del repositorio.

Reset no rota la clave de licencia ni prohíbe que su poseedor se autentique de nuevo. Revocación, bloqueo y baja lógica son acciones diferentes. No se aplicó ningún reset a producción.

Pendiente: ensayar con el cliente físico almacenamiento seguro, reacción a 401/429 y vencimiento real del lease. No se afirma revocación offline instantánea ni seguridad productiva completa a partir de staging. La discrepancia X-New-Token se detalla en VINI_PRODUCTION_READINESS.md.
