# Fase 2B — controles completos y staging Cloudflare

Continuación de `cb98ba7` en `experiment/vini-admin-plans-distributors`.
No se reinició el backend ni se modificó iOS. Los snapshots originales siguen
intactos; la tercera migración es incremental sobre las dos anteriores.

## Entorno separado

- Worker: `vini-admin-plans-staging-2b`.
- URL emitida por Wrangler: https://vini-admin-plans-staging-2b.loboangel39.workers.dev
- D1: `vini-admin-plans-staging-2b-db`.
- UUID confirmado: `cd4adf09-e968-455b-8825-5832bc5ed2c5`.
- Región inicial D1: ENAM. Ningún binding a las bases productivas ni a R2 productivo.
- Esquema inicial: las 19 tablas de metadata auditada, sin una sola fila real.
- Todos los usuarios, administradores y licencias de ensayo se crean con datos
  ficticios. Las claves de staging son nuevas y no proceden de producción.

La configuración exacta está en `wrangler.remote-staging.jsonc`. Un verificador
rechaza cualquier cambio de nombre, UUID, rutas o bindings que apunte fuera del
entorno previsto. El panel usa su propio origen; no llama al API productivo.

## Panel y control individual

Se conservan las vistas del panel administrativo. Clientes directos y cada
distribuidor tienen sus propios botones «Pausar todas» y «Reactivar todas».
Solo SUPER_ADMIN ve administración global, con sus botones globales explícitos.
Cada fila permite renovar, pausar/reactivar individualmente, baja lógica,
reset HWID, asignación BASIC/PRO e historial, siempre bajo permisos del Worker.
El HWID se entrega enmascarado; las rutas de listado no exponen el valor completo.

Las acciones no cambian el estado mostrado hasta recibir respuesta del servidor.
Las operaciones masivas presentan alcance, número de licencias y distribuidores,
cantidad ya pausada y cambios de pausa previstos. La ejecución es por lotes de
cinco para mantenerse dentro de límites D1; no trunca el snapshot global.

## Reactivación por origen

`pause_claims` distingue global, distribuidor, directos, seleccionados e individual.
`resume_scope` congela los IDs de claims correspondientes en el preview y solo
libera esos. No quita pausas añadidas después del snapshot, individuales, globales
desde un distribuidor, ni bloqueos o revocaciones. Una reversión por ID tampoco
permite que un distribuidor retire una pausa global ni la de otro distribuidor.

La primera pausa guarda el saldo por usuario; las pausas superpuestas lo mantienen.
Solo la última liberación recalcula vencimiento con hora servidor + saldo. Se
conservan los saldos independientes de 7 y 4 días; renovación en pausa establece
el saldo nuevo de esa licencia. El archivado por expiración no consume saldos
congelados. Baja lógica individual es una solicitud explícita diferente del
archivado automático por fecha: puede inactivar una licencia conservando su saldo.

## Contratos añadidos al API experimental (no publicados en producción)

Se reutilizan `/api/admin-v2/operations/preview` y `/execute`:

- pause_individual / resume_individual: exactamente un ID seleccionado.
- archive_individual: exactamente un ID; baja lógica incluso antes de caducar.
- hwid_reset: exactamente un ID; requiere acción `hwid_reset`.
- pause con group direct/distributor/all: crea pausa del origen respectivo.
- resume_scope con esos grupos: libera únicamente claims de ese origen.

Global exige SUPER_ADMIN. ADMIN mantiene ámbitos asignados; DISTRIBUTOR usa su
pertenencia verificada. No hay reset HWID masivo. Los intentos rechazados del
API administrativo nuevo se registran en admin_security_events, sin cuerpos,
credenciales, IDs de licencia completos ni HWID. SUPER_ADMIN puede consultarlos
mediante GET `/api/admin-v2/security-events`.

El resumen del preview incluye `summary.distributors`, `alreadyPaused` y
`effectiveChanges`; este último estima transiciones de pausa, no concesión de
acceso ni retirada de bloqueos. El snapshot y la revisión se vuelven a comprobar
en cada lote: una renovación/transferencia concurrente puede producir conflict.

## Migración y entrega

`0003_scoped_controls_hwid.sql` añade epoch de dispositivo, origen de claims,
snapshot de claims a liberar, resumen y eventos de seguridad. No altera los dos
SQL anteriores ni su ledger. El bootstrap aplica ahora un archivo por request,
cada uno completo y atómico, para respetar límites de consultas del plan Free.
El operador repite apply con el mismo manifiesto hasta remaining vacío.

Ver HWID_RESET.md, PHASE_2B_TEST_REPORT.md y los procedimientos previos. Antes de
entregar staging se deshabilita ADMIN_MIGRATIONS_ENABLED. No se despliega a
vini-v2-api, no se aplica SQL en vini-v2-db/vini-patch-db y no se cambia main.
