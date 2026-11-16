# VINI 3J-F — Matriz de pruebas

Resultado CI de referencia: commit `1b88d73`, run `43807344571` — **PASS** (macOS-15, Swift nativo y build unsigned `iphoneos arm64`).

La prueba nativa existente seguirá invocando literalmente `VINIRemotePackageCoordinator.prepareAuthorizedPackages()` con transporte aislado, paquete generado por `PatchPackageCodec` y usuario sintético. Se ampliará para comprobar reutilización íntegra, rechazo de bytes alterados, revisión anterior conservada, usuario diferente, reinicio mediante lectura de metadatos y revocación/ausencia del catálogo.

PASS: descarga/importación real, reutilización válida, alteración de bytes, reemplazo fallido conservando revisión previa, aislamiento por usuario, recuperación de metadatos tras recrear el adaptador y renovación HTTP 401.

SKIPPED: revocación posterior al catálogo, contador de descarga explícito, fixture de interrupción de transporte y verificación de backups/journals por filesystem. Apply/Restore permanecen fuera de alcance.
