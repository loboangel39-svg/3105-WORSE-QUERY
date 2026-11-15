# Pausas, archivado y retención

## Política confirmada por el usuario

Al pausar se guarda el saldo restante de CADA licencia con hora del servidor.
Al liberar su última pausa, vencimiento = hora actual del servidor + ese saldo.
Una conserva sus 7 días y otra sus 4 días. No se suma una duración global, no se
redondea a días completos y el reloj del dispositivo no extiende la licencia.

El vencimiento almacenado no cambia al pausar. `pause_remaining_ms` y
`pause_remaining_known` son el saldo autoritativo durante la pausa; NULL conocido
significa licencia sin caducidad. Saldo cero no concede días. Fechas históricas
inválidas dejan saldo desconocido y bloquean reactivación automática: el operador
debe efectuar una renovación explícita con evidencia del vencimiento deseado.

Cada pausa conserva causa, actor y operación en pause_claims. Revertir una pausa
masiva solo libera sus claims. Una pausa individual anterior o posterior, u otra
masiva superpuesta, sigue activa: ni se consume ni se recalcula el saldo hasta
liberar la última. No se permite archivar/purgar usuarios pausados por una fecha
canónica que haya pasado mientras su saldo estaba congelado.

Renovar mediante una fecha explícita estando pausado establece el saldo respecto
a esa nueva fecha y la hora del servidor. Renovar por días desde el endpoint
legacy toma como base el saldo congelado, no una fecha antigua ya pasada.

## Archivado primero

No existe borrado automático por expiración. Archive requiere vencimiento real,
ausencia de pausa, confirmación de alcance y revisión optimista vigente. Marca
archived_at e inactiva, conserva cuenta, licencia, creador, vínculos e historial.
Una renovación entre preview y ejecución invalida el miembro y evita archivarlo.
Renovar/desarchivar requiere restoreArchived=true, permisos explícitos y una
licencia vigente; conserva bloqueo, revocación y pausas, sin reactivación indiscriminada.

## Purga administrativa

Deshabilitada por defecto. Solo SUPER_ADMIN puede configurar retención (mínimo
90 días) y ejecutar purge con preview/confirmación. Requiere archivo suficientemente
antiguo, licencia aún vencida, ausencia de pausa y revisión sin cambios. Se ejecuta
por lotes con informe; una licencia renovada no se purga aunque ya estuviera en
el snapshot. No hay cron ni llamada automática al modificar la política.

La purga implementada es anonimización irreversible de la fila operativa y
revocación de acceso, no DROP/DELETE del historial: elimina nombre/HWID/credencial
actual, referencias personales previstas y asignaciones; invalida y limpia material
de activaciones. Conserva IDs mínimos, procedencia, fechas y auditoría necesarios
para trazabilidad y claves foráneas. No se guarda la clave completa en auditoría.

No se promete eliminación exhaustiva de texto histórico en activity_log u otros
sistemas heredados: requiere una política de privacidad específica y revisión de
datos, que no se hizo sobre clientes reales. Esta fase no implementa borrado físico
de usuarios que destruya historial. Los registros append-only no se sobrescriben
ni borran para «cumplir» una cuota.

## Interrupciones y concurrencia

Preview congela IDs/revisiones; ejecución reclama cada miembro con un attempt_id
en el mismo batch transaccional que los cambios y su evento. Un fallo revierte
todo ese lote. Una respuesta perdida o reinicio permite reanudar sin repetir lotes
confirmados. Se revalida ámbito en cada lote; trasladar un cliente o revocar un
administrador evita que se actúe usando un permiso antiguo.

Cancelar conserva lo ya aplicado; no equivale a reactivar. Para liberar pausas
ya aplicadas se crea una reversión explícita por operación. El administrador
principal puede inspeccionar y revertir operaciones de distribuidores sin
impersonar sus sesiones ni modificar su creador original.
