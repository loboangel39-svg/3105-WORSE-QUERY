# VINI 2.0 — Auditoría forense del error persistente de Apply

Fecha de auditoría: 2026-11-16  
Rama auditada: `integration/vini-2.0-regression-fix`  
HEAD: `7f8e238`  
Dispositivo declarado: `iPhone14,3`, iOS `27.2.1`

## Conclusión ejecutiva

El texto **«No se pudo aplicar el parche. Se revirtieron las escrituras
anteriores» no demuestra que un estado antiguo haya sobrevivido**. En el
código actual es un mensaje de pérdida de información:

1. `PatchTransaction.apply` convierte numerosos errores distintos de
   preparación, escritura, verificación y rollback en
   `PatchPackageError.applyFailed` (`PatchTransaction.swift:320-364`).
2. `PatchProjectStore.directApply` captura cualquier `Error`, incluido
   `projectAlreadyApplied`, `targetOccupied`, `targetAppUnavailable`,
   `VINIPatchFailure` y errores de acceso, y siempre muestra
   `patch.error.apply` (`PatchProjectStore.swift:78-99, 138-143`).
3. `PatchProjectsView.apply` tiene la misma pérdida para errores que no son
   `PatchPackageError` (`PatchProjectsView.swift:920-933`).

Por tanto, el error observado puede ser producido por un fallo nuevo en cada
intento. Con el código y los logs disponibles **no se puede establecer cuál
fue el primer error del iPhone**, porque la causa se descarta antes de llegar
a la interfaz y `PatchTransaction` también descarta la causa del rollback.

Sí está demostrado que existe una ruta de persistencia que puede bloquear
Apply: `latestReceipt` considera activos los journals `prepared` y `applied`.
También está demostrado que un rollback fallido conserva el journal preparado.
No está demostrado que esos archivos hayan sobrevivido a la desinstalación en
el dispositivo indicado.

## A. Secuencia real del fallo

### Ruta de la lista Installed (`directApply`)

1. `PatchProjectStore.directApply(projectID:)` rechaza silenciosamente la
   operación si el gestor está ocupado, no puede decodificar el paquete, hay
   `recoveryRequiredIDs`, o `DevicePatchService.latestReceipt` devuelve un
   receipt (`PatchProjectStore.swift:78-83`).
2. Para paquetes schema 2, sincroniza primero el workspace mediante
   `PatchProjectLibrary.synchronizeWorkspace`; esto puede fallar antes de
   crear un receipt (`PatchProjectStore.swift:87-90`).
3. `DevicePatchService.apply` resuelve los contenedores y adquiere acceso de
   escritura (`DevicePatchService.swift:226-249`). Un fallo aquí es
   `targetAppUnavailable`.
4. En la rama actual se consulta `latestReceipt` antes de guardar un nuevo
   `VINIOperationRecord` (`DevicePatchService.swift:10-20`). Si existe un
   journal `prepared`/`applied`, el error correcto es
   `projectAlreadyApplied`.
5. Se crea el registro `.preparing` y se guarda en el índice VINI.
6. `PatchTransaction.apply` valida proyecto, paths, destinos, ocupación de
   targets y crea el directorio de transacción (`PatchTransaction.swift:142-247`).
7. Copia los originales y, para paquetes públicos, guarda las sustituciones
   en el directorio de transacción (`PatchTransaction.swift:261-298`).
8. Escribe el journal `prepared` y llama a `beforeMutation`.
9. El callback VINI cambia el registro a `.prepared`, crea/verifica los
   respaldos A/B y valida roots (`DevicePatchService.swift:25-36`,
   `VINIDualBackupStore.swift:164-191`).
10. Se escriben las reglas en los contenedores de destino y se verifica cada
    digest (`PatchTransaction.swift:320-345`).
11. Si falla cualquier escritura o verificación, se intenta `restoreRecords`.
    Si el rollback termina, el journal queda `rolledBack`; si falla, se
    conserva el journal preparado (`PatchTransaction.swift:346-364`).
12. En ambos casos la función lanza `PatchPackageError.applyFailed`; el error
    original no se devuelve.
13. En la rama VINI actual, el `catch` de `DevicePatchService.apply` guarda el
    registro como `.recoveryRequired` aunque el rollback haya terminado,
    pero el receipt sólo sigue activo si el journal es `prepared` o `applied`
    (`DevicePatchService.swift:50-58`, `PatchTransaction.swift:549-554`).
14. `directApply` descarta toda la excepción y presenta el mensaje genérico.

### Ruta de detalle

La función privada `PatchProjectsView.apply` ejecuta esencialmente el mismo
flujo (`PatchProjectsView.swift:907-935`). Conserva errores que sean
`PatchPackageError`, pero convierte cualquier otro error en el mensaje
genérico. Antes del commit `7f8e238`, también se perdía la causa en la ruta
`directApply`; esa ruta aún conserva el problema genérico en el código
auditado.

## B. Persistencia y supervivencia

| Dato | Ruta/identificador | Creación | Eliminación | Reinicio | Reinstalación | Puede bloquear Apply |
|---|---|---|---|---|---|---|
| Paquete `.3105` | `Application Support/PatchProjects/*.3105`, identificado por UUID interno | Importación/guardado | `PatchProjectLibrary.delete` | Sí | Normalmente no se puede afirmar desde este repo; depende del ciclo de vida del contenedor iOS | Indirectamente, por proyecto/targets |
| Workspace | `Documents/Patches`, `projectID` y manifiesto `.3105-project.plist` | `ensureWorkspace`/importación | `deleteWorkspace` | Sí | Normalmente pertenece al contenedor de VINI | Puede alterar el proyecto sincronizado, no crea receipt |
| Journal/receipt | `Application Support/PatchProjects/Backups/<projectUUID>/<transactionUUID>/journal.plist` | `PatchTransaction.apply`, status `prepared` o `applied` | Sólo rotación terminal de VINI; `delete` del paquete no lo borra | Sí | No hay código que lo borre al desinstalar | Sí: `latestReceipt` bloquea |
| Registro VINI | `Application Support/VINISilentPatches/Targets/<projectUUID>.json` y `Transactions/<projectUUID>/<tx>/state.json` | `DevicePatchService.apply` | No lo borra `PatchProjectLibrary.delete`; rotación sólo elimina generaciones terminales | Sí | No hay evidencia de supervivencia tras desinstalación; no se limpia por delete | Indirectamente; Restore/recovery lo necesita |
| Backup A | `VINISilentPatches/Transactions/<projectUUID>/<tx>/A-*.json` más engine journal | `preparePair`/`sealApplied` | Rotación sólo tras operación terminal segura | Sí | No demostrable con fuente | No directamente; respalda recuperación |
| Backup B | misma transacción, subdirectorio `B/` | `preparePair`/`sealApplied` | Igual que A | Sí | No demostrable con fuente | No directamente; puede conservar ocupación vía journal |
| Recovery copies | `VINISilentPatches/Recovery/<projectUUID>/<recoveryUUID>` | `preserve` | Retención/quota; no por delete del paquete | Sí | No demostrable con fuente | No directamente |
| Keychain de paquete | servicio `com.apple.mobile.MobileHouseArrest.patch-keys`, cuenta `<packageUUID>.<fingerprint>` | Importación protegida | `PatchProjectLibrary.delete` intenta borrarlo | Sí | El keychain puede sobrevivir a reinstalación; el código no prueba lo contrario | Sólo desbloquea/decodifica; no es el receipt |
| App Group | `group.pigtjing.top` | Sólo comprobación diagnóstica/resolución | No usado por `VINIDualBackupStore` | Sí | Propiedad separada | No se encontró persistencia VINI allí |
| Destino | Contenedor de cada app `/var/mobile/Containers/Data/Application/...`, resuelto por bundle ID | Ya existe antes de Apply; Apply escribe allí | No lo elimina VINI | Sí | Reinstalar VINI no reinstala las apps destino | Sí: drift, permisos, acceso, contenido y digest |

La ruta VINI usa `FileManager.url(for: .applicationSupportDirectory, in:
.userDomainMask)` (`VINIDualBackupStore.swift:91-98`); no usa el App Group.
El App Group sólo aparece en `WQBundleIdentityCoordinator` y en los
entitlements (`group.pigtjing.top`), para identidad/diagnóstico.

## C. Qué ocurre al borrar y reimportar

`PatchProjectLibrary.delete` elimina el `.3105`, workspace, keychain,
origin metadata y marcador de author copy (`PatchProjectLibrary.swift:282-300`).
No elimina deliberadamente Backups, journals ni registros VINI. Esto explica
por qué borrar el paquete no equivale a borrar una transacción.

Al importar otra vez, RC10 inspecciona el UUID del paquete. Si no hay URL
existente pero sí existe `DevicePatchService.latestReceipt` para el UUID
antiguo, `PatchProjectStore.installImportedInstance` asigna un UUID nuevo y
reconstruye el paquete (`PatchProjectStore.swift:516-541`). Esto evita el
bloqueo por `projectAlreadyApplied` para esa instancia nueva, pero no elimina
ni restaura los archivos del destino. Tampoco elimina journals o backups
antiguos.

Por ello:

- Para el mismo UUID: el journal `prepared/applied` puede bloquear Apply.
- Para el UUID nuevo: ese receipt no bloquea por identidad, pero el destino
  sigue siendo el mismo y se vuelve a resolver en `DevicePatchService`; los
  conflictos físicos, acceso, paths, ocupación de otro proyecto o verificación
  pueden volver a fallar.
- Otros paquetes pueden fallar independientemente por `targetOccupied`,
  acceso al contenedor, proyecto inválido, escritura/verificación o por sus
  propios journals.

## D. Comparación con la versión anterior

La versión anterior a `b7815ee` hacía que `DevicePatchService.apply` delegara
directamente en `PatchTransaction.apply` y no creaba `VINIOperationRecord`, ni
backups A/B, ni validación de roots/manifests. El receipt/journal de
`PatchTransaction` seguía existiendo.

`b7815ee` introdujo:

- `VINIDualBackupStore.live()` y el índice VINI.
- Registro `.preparing` antes de llamar al motor.
- Callback `beforeMutation` que crea/verifica A/B.
- Verificación post-Apply y `recoveryRequired`.
- Coordinación VINI durante Restore.

La regresión de orden de escritura está demostrada históricamente: el nuevo
registro se guardaba antes del preflight interno de `PatchTransaction`, por lo
que un `projectAlreadyApplied` podía reemplazar la asociación anterior. Esa
regresión fue corregida en `7f8e238`, pero no corrige un journal preparado
real, un fallo de destino ni la pérdida de causa en `directApply`.

La eliminación que antes rechazaba receipts activos se quitó en RC10
(`63743c4`), pero se mantuvo la evidencia transaccional por diseño. La
versión anterior no tenía ese índice VINI adicional ni la lógica de identidad
de reimportación.

## E. Clasificación: A, B o C

### A — El mismo estado persistió

Posible y técnicamente sustentado sólo si existe todavía en el dispositivo un
journal `prepared/applied` bajo el mismo `projectUUID`, o si el rollback dejó
un journal preparado. La fuente demuestra cómo bloquearía Apply, pero no aporta
una captura del filesystem del iPhone ni un log con ese UUID.

### B — El estado fue eliminado pero se reconstruyó incorrectamente

Posible para la reimportación: RC10 conserva backups/journals antiguos y
reconstruye un nuevo paquete con UUID nuevo. Eso evita el bloqueo por UUID,
pero no cambia el estado de los archivos destino. No hay evidencia de que
`VINITransactionStateReader` reconstruya receipts: es explícitamente read-only
(`VINITransactionStateReader.swift:7-9`) y sólo clasifica registros existentes.

### C — El estado se eliminó y el fallo vuelve a producirse

También posible y, con el mensaje actual, indistinguible de A/B. Un acceso
fallido, target ocupado, path inválido, escritura, digest o rollback puede
producir exactamente el mismo texto. Para paquetes distintos, esta hipótesis
gana fuerza porque el UUID/receipt del paquete anterior no debería ser la
causa directa; aun así, `appliedTargetKeys` puede detectar transacciones
activas de otros proyectos si sus backups siguen presentes
(`PatchTransaction.swift:567-595`).

## F. Evidencia que falta para afirmar la causa definitiva

No existe en el repositorio una captura del estado de:

- `Application Support/PatchProjects/Backups` en el dispositivo.
- `Application Support/VINISilentPatches/Targets` y `Transactions`.
- status real del journal (`prepared`, `applied`, `rolledBack`).
- resultado de `restoreRecords` y si falló el rollback.
- bundle ID, path y digest del primer target que falló.
- error de `ContainerAccessCoordinator` o `FileManager` original.
- comportamiento real del iOS al eliminar el contenedor de VINI y conservar
  el keychain/App Group.

Los logs existentes incluyen mensajes de acceso y un diagnóstico textual de
transacciones, pero `directApply` no los adjunta a la alerta y
`PatchTransaction` no conserva la excepción interna del rollback. Por eso no
es técnicamente válido afirmar ahora “es caché” o “es el mismo estado” como
hecho demostrado.

## G. Corrección mínima recomendada (no aplicada en esta auditoría)

1. Mantener el preflight de `7f8e238` antes de guardar el registro VINI.
2. Cambiar `directApply` para conservar y mostrar el error concreto; al menos
   distinguir `projectAlreadyApplied`, `targetOccupied`, acceso,
   `VINIPatchFailure` y `applyFailed`.
3. Separar `applyFailed` de rollback fallido: conservar un código/causa de
   rollback sin borrar el journal preparado.
4. Añadir instrumentación estructurada con project UUID, transaction UUID,
   journal status, etapa y error subyacente, sin registrar contenido sensible.
5. No borrar journals/backups ni declarar Restore cuando sólo hubo rollback.

La corrección exacta no debe elegirse hasta capturar el primer error real en
un fixture controlado o en el iPhone.

## H. Limitaciones y pruebas necesarias

Esta entrega es una auditoría; no modifica código ni genera IPA. Para cerrar
la causa se necesita un fixture propio que registre después de cada etapa:

`IMPORT → APPLY → error → journal status → rollback result → uninstall →
reinstall → IMPORT → APPLY`, incluyendo UUIDs, rutas VINI y hashes de targets.

Debe repetirse con: (1) rollback exitoso, (2) rollback inyectadamente fallido,
(3) destino modificado externamente, (4) paquete con target solapado y (5)
paquete totalmente distinto. Sólo así puede distinguirse A, B y C en el
dispositivo real sin borrar evidencia.
