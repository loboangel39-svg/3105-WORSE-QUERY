# VINI 3J-F — Matriz de pruebas

Estado inicial: **PENDING CI**.

La prueba nativa existente seguirá invocando literalmente `VINIRemotePackageCoordinator.prepareAuthorizedPackages()` con transporte aislado, paquete generado por `PatchPackageCodec` y usuario sintético. Se ampliará para comprobar reutilización íntegra, rechazo de bytes alterados, revisión anterior conservada, usuario diferente, reinicio mediante lectura de metadatos y revocación/ausencia del catálogo.

Los escenarios Apply/Restore permanecen fuera de alcance. Los journals y backups se verifican solo como rutas no tocadas; no se invoca ninguna operación de transacción.
