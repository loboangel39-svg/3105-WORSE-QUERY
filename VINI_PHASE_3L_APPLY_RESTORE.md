# VINI 3L-D — Apply/Restore

## Resultado

**BLOCKED — no se integró Apply/Restore y no se generó un IPA funcional.**

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

No se modificaron `PatchTransaction`, `DevicePatchService`, backups, journals,
codec, motores, UI visual ni Worker. No se ejecutó Apply ni Restore.
