# Exportación segura de observaciones físicas

## Qué permite la IPA actual

El cliente 7864fc3 no registra credenciales ni cuerpos de API y no ofrece exportación automática de diagnósticos de sesión. Existe una LogView heredada, pero no está enlazada desde este dashboard; no se inventa un botón para abrirla ni se modificó la IPA para añadirlo. Tampoco muestra códigos HTTP. No se piden sysdiagnose, Keychain, proxies TLS, backups completos, perfiles, HAR o logs crudos como sustituto.

Se entrega un mecanismo **manual, estructurado y sin texto libre**. Registra estados/tiempos observados en el iPhone y códigos únicamente si fueron obtenidos de una fuente saneada. No es telemetría automática ni prueba por sí mismo de ejecución física. La revisión de evidencias sigue pendiente.

## Procedimiento

1. Copiar PLANTILLA-OBSERVACIONES.json a un archivo de trabajo local nuevo. El original deja todos los casos pending y la versión iOS unknown. Anotar el modelo y la versión real observados.
2. Después de cada caso, completar observed_at con zona, por ejemplo 2026-11-15T16:00:00-05:00, result y state según lo visto. No usar el ejemplo como una observación real. account_alias solo admite NONE/BASIC-A/PRO-A/DIST-A; no escribir usuario, clave o ID de licencia.
3. Registrar remaining_minutes y elapsed_seconds solo si se observaron; de lo contrario null. HTTP no visible debe quedar http_status=null y error_code=unknown. No deducir un 401/403 a partir de una etiqueta ambigua. identity_matches registra comparación local mediante true/false, sin copiar el nombre.
4. Ejecutar export-vini-physical-evidence.py con Python 3 mediante el comando absoluto de RUTAS.md. Produce un archivo nuevo; rechaza sobreescritura, entradas grandes, claves desconocidas/duplicadas, valores fuera de enumeraciones y texto libre.
5. Revisar el JSON exportado y compartir únicamente ese archivo. Permanece reviewed=false y source=user_reported_manual_observations hasta correlacionarlo con evidencia. Conservar el original privado en el equipo.

No introducir tokens, claves de licencia, HWID, contraseñas o material de descifrado en ningún campo. Campos nuevos como token, raw_log, username o password provocan rechazo; no se intenta una redacción por expresiones regulares que pudiera dejar secretos. El exportador no hace solicitudes de red, no lee el portapapeles ni el Keychain y no publica nada.

Los estados admitidos son unknown, app_started, active, signed_out, paused, denied, expired, offline, unverified, waiting, verified_download y unchanged. Resultados: pending, pass, fail, blocked, not_observable. Errores: unknown, none, signedOut, paused, denied, expired, offline, rateLimited, invalidResponse, integrity, keychain, stale. No incluir comentarios de texto libre en el JSON.

## Evidencias adicionales

Una captura opcional debe recortarse para mostrar estado/plan/tiempo, ocultando SecureField, nombres, notificaciones, claves y datos personales. La evidencia de nombre se resume como coincidencia booleana. No enviar un vídeo del pegado de una licencia. Si el sistema genera un crash report, conservarlo localmente y comunicar primero solo el momento y el caso; no subirlo completo sin un saneamiento específico.

La auditoría de staging puede confirmar hora/operación sin credenciales. No copiar respuestas de login, headers Authorization, X-Content-Key, X-Patch-Password ni cuerpos de descarga. Si faltan datos para determinar una causa, mantener la incidencia abierta y solicitar solo el dato mínimo, sin inventar códigos.
