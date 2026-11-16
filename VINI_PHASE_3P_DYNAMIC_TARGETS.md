# VINI 3P — Categorías numéricas y targets dinámicos

## Implementación

Se añadieron dos adaptadores pequeños y aditivos:

- `VINIProductionCategoryRegistry.swift`: registro único y estable:
  `1 → Combat`, `2 → Visuals`, `3 → Offsets`. El nombre se resuelve aparte del
  identificador.
- `VINIPackageCategoryStore.swift`: asociación local Codable por cuenta,
  `remotePatchID`, `packageID`, `projectID`, SHA-256, revisión y `categoryID`.
  Se persiste en Application Support y no contiene secretos.

`VINIRemotePackageCoordinator` registra la asociación únicamente después de
validar descarga, tamaño, SHA-256, `packageID`, descifrado y `projectID`. El
campo `categoryID` se deriva de metadata autorizada del catálogo; no se deriva
del nombre del archivo ni modifica el `.3105`.

Paquetes antiguos sin categoría siguen atravesando el codec/importador. Solo
se omiten de las tarjetas dinámicas si no hay una categoría visual inequívoca;
no se borran ni se invalidan.

## Presentación

`VINIProductionTargetModel` conserva la identidad remota y de paquete y añade
el `categoryID` numérico. `VINIProductionStore` lo convierte a las categorías
existentes y sigue entregando `VINITargetPresentation` a
`VINIDashboardView`/`VINITargetCard`. No se modificó `VINITargetCard`, el
layout, pestañas, colores o motores.

El estado del interruptor continúa dependiendo exclusivamente de
`VINITransactionStateReader`; categoría no concede Apply, Restore ni permisos.

## Seguridad y compatibilidad

Se conserva `X-Content-Key`, `PatchKeyStore`, la huella criptográfica y
`PatchPackageCodec`. No se modificaron Worker, D1/R2, codec, transacciones,
backups, journals, Bundle ID, App Group o entitlements.

## Pruebas

Las fixtures nativas comprueban IDs 1/2/3, separación de display name, target
preparado y ausencia de targets ficticios. La compilación iOS y regresiones se
ejecutan en el workflow `validate-vini-remote-import.yml`.

La prueba física de iPhone y el catálogo productivo autenticado siguen fuera
de CI. Si el Worker no entrega target enriquecido, no se fabrica una categoría:
el paquete permanece importable pero no produce tarjeta ambigua.
