# VINI Fase 3A — coordinación sin reconstrucción

## Estado implementado

`VINIEnginePresentationStore` separa el método documentado del resultado de ejecución. Para iOS 27.2.1, `VINICompatibilityResolver` selecciona `worse_query`; el dashboard puede mostrar `worse_query · Seleccionado`. No se fabrica `Activo`: el resultado efectivo no se expone hoy como callback público por `ContainerAccessCoordinator`, que permanece intacto y protegido.

Compatibilidad, autenticación Cloudflare, licencia, catálogo, fixture y Apply/Restore aislado conservan sus rutas existentes. No se modifican motores, permisos, entitlements, Bundle ID, App Group ni producción.

## Propuestas Apply/Restore para targets

### A — Asignación completamente remota

Cloudflare entrega `targetID → remotePatchID → packageID → projectID`. Ventaja: control central. Riesgos: dependencia online, cambios remotos que alteren la UI y mayor superficie de autorización. No recomendada sin un contrato de target versionado.

### B — Catálogo remoto con proyectos locales

Cloudflare autoriza y entrega el paquete; `PatchPackageCodec`, `PatchProjectStore`, `DevicePatchService`, `PatchTransaction` y `VINIDualBackupStore` mantienen proyectos/recibos locales. Ventaja: recuperación offline y reutilización directa del motor. Requiere una asignación explícita y firmada por target. Recomendable para una primera integración.

### C — Modelo híbrido

Cloudflare administra identidad, permisos y revisiones; el dispositivo administra transacciones, respaldos, receipts y Restore. Es la opción recomendada: conserva la autoridad del servidor sin acoplar la UI a los journals locales.

## Próxima fase

Agregar un adaptador externo, sin modificar `ContainerAccessCoordinator`, que permita publicar resultados reales de una sesión ya obtenida. Hasta disponer de esa interfaz, el indicador debe permanecer neutral/seleccionado y los interruptores no deben ejecutar Apply/Restore real para los targets visibles.
