# VINI 3L-A — Auditoría de transacciones

## Alcance

Auditoría estática únicamente. No se ejecutaron `apply`, `restore`, `resetToAppliedState`, ni operaciones sobre aplicaciones de terceros. Backend y fuente de targets permanecen en `vini-v2-api` y `VINIProductionStore`.

## APIs verificadas

- `PatchTransactionReceipt`: identificadores locales `id`/transaction ID, `projectID` y `journalURL`.
- `PatchTransaction.latestReceipt(projectID:backupRoot:)`: lectura del último journal con estado `prepared` o `applied`.
- `PatchTransaction.journalSnapshot(receipt:)`: lectura del estado del journal, archivos y directorios.
- `PatchTransaction.requiredBundleIdentifiers(for:)`: lectura de bundles requeridos.
- `PatchTransaction.inspectRestore(receipt:containerResolver:)`: inspección read-only de cambios actuales; no restaura.
- `PatchTransaction.verifyState(receipt:original:containerResolver:)`: verificación read-only de estado aplicado/original.
- `DevicePatchService.latestReceipt(projectID:)`, `inspectRestore`, `verifyState` y `withExistingContainerAccess`: fachadas públicas de lectura, aunque las dos últimas requieren resolver contenedores reales.
- `VINIDualBackupStore.loadRecord`, `allRecords`, `receipt`, `verifiedManifest`, `bestB` y `diagnostic`: lectura/validación de operación y manifest; las rutinas de sellado/reparación/rotación no deben invocarse en 3L-A.
- `PatchProjectLibrary.load/readPackage/revalidate` permiten comprobar paquete importado; `delete` bloquea eliminación cuando existe receipt activo.

## Hallazgos

`PatchTransaction` distingue `prepared`, `applied`, `rolledBack` y `restored` dentro del journal. `VINIOperationRecord` añade `preparing`, `prepared`, `applied`, `restoreStaging`, `restoring`, `restored` y `recoveryRequired`, además de `transactionID`, `previousTransactionID`, `operationID`, digest y reglas planeadas.

La asociación disponible entre target dinámico y transacción es `projectID`/package project identity. `targetID` existe en `VINIOperationRecord`, pero `PatchTransactionReceipt` no lo contiene; por tanto no puede inferirse un target remoto solo desde un receipt. El adaptador futuro debe exigir coincidencia del registro local `targetID`, `projectID` y digest del paquete.

## Resultado

Hay APIs read-only suficientes para detectar receipt, journal `prepared`/`applied` y cambios de restore. No existe una API pública única que enumere de forma segura todos los `restorePending` por target dinámico sin leer/validar cada `VINIOperationRecord`, manifest y journal. No se modificaron motores, journals, backups ni transacciones.
