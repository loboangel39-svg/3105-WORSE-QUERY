# VINI 3Q–3T — integración de catálogo legacy y targets dinámicos

## Cambios reales

- Se corrigió el inicializador de `VINIProductionTargetDescriptor` en
  `VINIProductionTargetModel.swift`: `categoryID` precede a `name`.
- `VNIRemotePackageCoordinator` conserva el flujo enriquecido y añade una rama
  legacy para entradas autorizadas sin `entry.target`.
- La rama legacy descarga mediante `VINIStagingClient`, aplica el límite de
  tamaño del transporte, inspecciona y descifra con `PatchPackageCodec` y
  `PatchKeyStore`, valida el proyecto obtenido del paquete y guarda mediante
  `PatchProjectLibrary`.
- El target legacy usa una identidad local explícita formada por cuenta,
  `remotePatchID`, UUIDs del paquete/proyecto, SHA-256 y revisión. No falsifica
  un `targetID` del Worker.
- `VINIPackageCategoryStore` admite clasificación pendiente (`categoryID=nil`)
  y asignación posterior por identidad exacta. La categoría no concede acceso
  ni modifica Apply/Restore.
- `VINIProductionTargetModel` admite targets enriquecidos y legacy. Un legacy
  importado sin categoría permanece fuera del dashboard; no se elimina.
- El artefacto CI se denomina `VINI-DynamicImport-Unsigned.ipa`.

## Componentes preservados

No se modificaron Worker productivo, D1/R2, `PatchPackageCodec`, motores,
transacciones, `DevicePatchService`, backups, journals, Restore, Bundle ID,
App Group, entitlements ni importación manual.

## Referencia VINI-IPA

Se revisaron `RemotePatchService`, `PatchDownloadService`, `PatchManager`,
`PatchStorage` y `PatchSyncManager`. Solo se adaptó el principio de separar
catálogo/descarga/almacenamiento; el transporte autorizado y el almacenamiento
original del proyecto actual continúan siendo la fuente efectiva.

## Pruebas

Las fixtures nativas cubren IDs numéricos, separación de nombre, clasificación
legacy explícita, estado pendiente sin categoría, integridad, identidad de
proyecto, caché y revalidación 401. La validación física de iPhone, cuentas
productivas, sesión background/foreground y Apply/Restore reales quedan
`SKIPPED` hasta disponer de dispositivo y credenciales de prueba.

El último CI anterior (`43891690334`) fue cancelado por capacidad de runner
macOS y no cuenta como PASS. El siguiente run debe verificar compilación,
fixtures, hashes protegidos, arm64 unsigned y el IPA renombrado.
