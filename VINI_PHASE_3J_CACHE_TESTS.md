# VINI 3J-F — Matriz de pruebas

Resultado CI de cierre: commit probado `12ff554`, run `43808493475` — **PASS** (macOS-15, Swift nativo y build unsigned `iphoneos arm64`). URL: https://github.com/loboangel39-svg/3105-WORSE-QUERY/actions/runs/43808493475

La prueba nativa existente seguirá invocando literalmente `VINIRemotePackageCoordinator.prepareAuthorizedPackages()` con transporte aislado, paquete generado por `PatchPackageCodec` y usuario sintético. Se ampliará para comprobar reutilización íntegra, rechazo de bytes alterados, revisión anterior conservada, usuario diferente, reinicio mediante lectura de metadatos y revocación/ausencia del catálogo.

PASS: descarga/importación real, reutilización válida, alteración de bytes, revocación posterior al catálogo sin descarga, descarga parcial rechazada antes de publicación, revisión previa conservada, reintento completo, aislamiento por usuario, recuperación de metadatos tras recrear el adaptador y renovación HTTP 401.

SKIPPED: cambio de usuario, auditoría de backups/journals por filesystem, Apply/Restore y autorización productiva. El transporte de interrupción es fixture HTTP sintético: se reciben bytes parciales y el coordinador real los rechaza.
