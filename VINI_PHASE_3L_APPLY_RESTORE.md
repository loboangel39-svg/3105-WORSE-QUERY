# VINI 3L-D — Apply/Restore

## Resultado

**BLOCKED — no se integró Apply/Restore y no se generó un IPA funcional.**

## APIs verificadas

- `DevicePatchService.apply(project:beforeMutation:beforeRollback:) throws -> PatchTransactionReceipt` — `ThreeOneOSFive/helpers/DevicePatchService.swift:4-23`.
- `DevicePatchService.restore(receipt:allowChangedTargets:validateContainers:preserveCurrentState:beforeWrite:) throws` — `DevicePatchService.swift:41-65`.
- `DevicePatchService.inspectRestore(receipt:validateContainers:) throws -> PatchRestoreInspection` — `DevicePatchService.swift:25-39`.
- `DevicePatchService.latestReceipt(projectID:)` — `DevicePatchService.swift:87-90`.
- `PatchProjectLibrary.load()` returns `PatchLibraryItem` with `summary.packageID`, optional decoded `project`, package URL and origin — `PatchProjectLibrary.swift:3-11,60-121`.

Estas APIs sí permiten ejecutar una operación para un `PatchProject` local y
un receipt local. No exponen, sin embargo, una resolución autorizada desde el
`targetID` remoto hacia ese `PatchProject`, ni un callback de mutación para
actualizar la presentación después de confirmar el receipt.

El binding original del interruptor conserva un setter vacío en
`ThreeOneOSFive/views/VINIDashboardView.swift:129-133`. Las operaciones
existentes están encapsuladas en `DevicePatchService` y `PatchTransaction`.
Conectar el setter requeriría una ruta funcional que identifique el proyecto,
la transacción y el destino exacto, y que coordine operaciones asíncronas;
esa ruta no existe para los targets remotos.

La auditoría previa también confirmó que `PatchTransactionReceipt` no contiene
`targetID` y que el registro local exige `targetID == package.<projectID>`.
Por ello no puede asociarse de forma segura un target remoto a un receipt sin
una tabla persistida autorizada `targetID → projectID → packageDigest`.

El catálogo/cache sí conserva `targetID`, `remotePatchID`, `packageID`,
`projectID`, revisión, SHA-256 y tamaño (`VINIRemoteContract.swift`,
`VINIRemotePackageCache.swift`, `VINIRemotePackageCoordinator.swift`). Esa
identidad termina en `VINIProductionTargetDescriptor`, pero no se persiste
junto al `transactionID` generado por Apply.

No se modificaron `PatchTransaction`, `DevicePatchService`, backups, journals,
codec, motores, UI visual ni Worker. No se ejecutó Apply ni Restore.
