# VINI 3L-A — Mapeo de estados

| Estado dashboard | Evidencia mínima | Fuente auditada | Acción 3L-A |
|---|---|---|---|
| `loading` | consulta en curso | `VINIProductionStore` | diseñar solamente |
| `prepared` | paquete autorizado, digest/identidad verificados e importación completada | `VINIRemotePreparedPackage` + `PatchProjectLibrary` | no activa toggle |
| `unavailable` | no hay resultado preparado válido para el catálogo actual | catálogo/coordinador | no mostrar como listo |
| `revoked` | target ausente/withdrawn del catálogo actual, sin operación local terminal | catálogo Worker | impedir nueva descarga |
| `error` | error verificable de catálogo, integridad o importación | errores del coordinador | conservar evidencia local |
| `applied` | journal `applied`, receipt válido, manifest comprometido y `verifyState(... original:false)` | `PatchTransaction`/`VINIDualBackupStore` | único estado que puede encender |
| `restorePending` | operación aplicada con restore requerido, estado local no terminal y evidencia válida | `VINIOperationRecord` + journal/manifest | mantener visible aunque catálogo cambie |

`prepared` nunca se convierte automáticamente en `applied`. `VINIDashboardPresentation` actual usa `patchState == .active` para el binding, pero 3L-A no cambia ese binding ni inventa una transacción.

## Restore pendiente

Puede detectarse parcialmente mediante `VINIDualBackupStore.allRecords/loadRecord`, `VINIOperationRecord.phase`, `transactionID`, `lastVerifiedEnabled`, `desiredEnabled`, `PatchTransaction.journalSnapshot` y manifests A/B. Sin embargo, la reconstrucción completa exige resolver contenedores y validar roots, scope, digests y estado vivo. No existe aún una fachada pública estable que devuelva un estado agregado por target remoto.

Conclusión: se requiere un adaptador read-only futuro, no una modificación de `PatchTransaction`, journals o `VINIDualBackupStore`. Si el adaptador no puede validar todas las invariantes, debe devolver `error`/`restorePending` conservadoramente, nunca `applied`.
