# VINI 3L-B — Lector de estados persistidos

## Adaptador añadido

`VINITransactionStateReader.swift` es un adaptador exclusivamente read-only sobre `VINIDualBackupStore` y `PatchTransaction`. Consulta `allRecords`, `receipt`, `journalSnapshot` y manifests A/B mediante `verifiedManifest`. No escribe, no repara, no elimina y no ejecuta Apply/Restore.

`VINIProductionStore` lo inyecta en `VINIProductionTargetModel.resolve`. Solo un estado `applied` completamente validado podría producir `patchState: .active`; `prepared`, `restored`, `unknown` y cualquier evidencia incompleta permanecen OFF/no accionables.

## Bloqueo verificable

`VINIOperationRecord` valida `targetID == "package." + projectID.uuidString`, mientras el catálogo remoto usa otro `targetID`. Como `PatchTransactionReceipt` tampoco contiene `targetID`, el lector rechaza la atribución si no hay coincidencia exacta. Esto evita encender un target por un receipt de otro target.

Por la misma razón, `restorePending` no puede conservarse asociado a un target remoto cuando el catálogo desaparece sin una tabla local autorizada `targetID → projectID → digest`. El lector devuelve `unknown`; no inventa visibilidad ni estado.
