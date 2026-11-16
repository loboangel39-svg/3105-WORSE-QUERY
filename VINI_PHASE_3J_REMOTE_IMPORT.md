# VINI Fase 3J — Importación remota

Estado: **BLOCKED — SIN TOOLCHAIN SWIFT LOCAL**. Fase 3F continúa `BLOCKED` por CI.

Se añadió `VINIRemotePackageCoordinator.swift`, un adaptador externo que:

1. consulta el catálogo autorizado mediante `VINIStagingClient`;
2. exige un objeto `target` disponible;
3. descarga sólo por `remotePatchID` devuelto por el servidor;
4. verifica tamaño y SHA-256;
5. inspecciona el paquete con `PatchPackageCodec`;
6. valida `packageID` y `projectID` internos;
7. guarda el `.3105` mediante `PatchProjectLibrary`;
8. devuelve estado `VINIRemotePreparedPackage` para la fase 3K.

No ejecuta Apply/Restore ni modifica componentes protegidos. La interfaz visual no fue tocada.

El endpoint definitivo del Worker se mantiene separado del endpoint de staging; el cliente existente todavía tiene una base URL de staging y requiere una inyección de transporte/base URL para el arnés aislado antes de conectarse al Worker principal.

En este entorno Windows no están disponibles `swift` ni `swiftc`; no se ejecutó el coordinador nativo y no se declara `PASS RUNTIME LOCAL — CI BLOCKED`. La validación queda pendiente de un runner macOS autorizado.
