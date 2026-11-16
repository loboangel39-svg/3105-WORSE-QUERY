# VINI 3U — plan de pruebas en iPhone físico

Usar solamente una cuenta de prueba, aplicaciones propias y paquetes propios.
Capturar `LogView`, hora, commit instalado y resultado; no registrar tokens,
claves ni contenido de `X-Content-Key`.

| Caso | Preparación y pasos | PASS | FAIL/recuperación |
|---|---|---|---|
| Login | Instalar IPA del mismo SHA; login válido, cerrar/reabrir | authorized, usuario correcto | Si login falla, exportar solo mensajes HTTP/status; logout y reintentar |
| Reinicio | Con sesión válida, terminar app y abrir | sesión revalidada sin perder HWID | Si queda login, no borrar Keychain; comprobar expiry |
| Background | Iniciar catálogo/descarga, bloquear 30s, volver | tarea termina o falla sin target falso | Reintentar desde cuenta; conservar archivo parcial |
| Red | Cambiar Wi‑Fi/datos durante refresh | sesión permanece; muestra conexión pendiente | Esperar red y pulsar comprobar sesión |
| 401 | Usar token expirado en fixture autorizada | una revalidación y petición repetida | Logout seguro si Worker rechaza |
| Catálogo legacy | Asignar un paquete antiguo autorizado | importado; pendiente si no hay categoría | No debe desaparecer de biblioteca |
| Cifrado | Paquete propio con clave autorizada | decode e identidad UUID correctas | Clave incorrecta: rechazo sin tarjeta |
| Categoría | Asignar 1,2,3 y reiniciar | cada tarjeta en pestaña correcta | No modificar bytes ni estado Apply |
| Duplicado/revisión | Repetir sync y luego versión nueva | sin tarjetas duplicadas; revisión nueva verificable | No borrar revisión con receipt |
| Files | Acceder a contenedor propio, leer/escribir/copiar | provider y path verificados | No ejecutar limpieza; guardar log de provider |
| Apply | Fixture propia, OFF→ON | receipt confirmado y tarjeta ON | Si interrumpe, no reintentar ON; inspeccionar receipt |
| Restore | ON→OFF con app destino propia | inspectRestore y original confirmado | Mantener recovery pendiente; no borrar journal |
| Interrupción | Interrumpir solo fixture durante apply/restore | recovery detecta journal/receipt | Usar `inspectRestore`, no modificar manualmente backups |

### Evidencia requerida

- Versión/commit del IPA.
- Arquitectura y Bundle ID desde `Info.plist`.
- Estado visible antes/después.
- Mensajes `catalogDiagnostic`, `packageResult`, `fixtureState`.
- Resultado de `DevicePatchService.verifyState` y receipt ID, sin contenido sensible.

La auditoría actual no ejecutó ninguna de estas pruebas en un iPhone.
