# Incidencias y límites de preparación 2E

Estado: **sin evidencia recibida del iPhone; ninguna prueba física completada**.
No se modificó código iOS, Worker, producción, identidad ni entitlements. No se compiló una IPA nueva ni se ejecutó Apply/Restore.

| ID | Hallazgo/precondición | Estado y siguiente paso |
|---|---|---|
| I01 | El usuario indicó certificado de desarrollador, pero no la herramienta firmante ni perfil | Pendiente confirmar en la herramienta la identidad y permisos; no garantizar instalación por el certificado solo |
| I02 | IPA original sin firma/perfil; no se recibió versión firmada | Verificación posterior de firma/Bundle ID/App Group pendiente; no renombrar identidad para instalar |
| I03 | Sin exportación automática de diagnósticos de sesión/códigos HTTP | Límite constatado por inspección. Se entrega observación estructurada manual; no se afirma instrumentación inexistente |
| I04 | Dashboard muestra duración, no fecha absoluta de licencia | Fecha visible en el teléfono no observable en esta IPA; comparar con panel y mantener ese subcriterio pendiente. No cambiar la app sin incidencia/evidencia concreta |
| I05 | Cuentas 2D físicas son directas | Preparar distribuidor/licencia ficticios para P13/P14/P17; no ejecutar pausa de distribuidor sobre una cuenta directa |
| I06 | Renovación y reset pueden ser transparentes; UI no expone tokens/HTTP | Correlación de hora y auditoría saneada necesaria; Activa después de reset puede ser reautenticación legítima |
| I07 | API no publica hashes generales ni asociación con tarjetas | Solo fixture autorizado tiene descarga verificada; no activar targets ni prometer otros paquetes |

## Verificación ya realizada en escritorio

La IPA existente corresponde por SHA256 y procedencia CI a 7864fc3ff5c06d81b05e67fa6a94c40813d4109e; es arm64/iOS físico y conserva Bundle ID. Origen staging presente y origen de autenticación productivo ausente del ejecutable. El cliente no contiene credenciales productivas estáticas ni las utiliza para estas pruebas; no se consultaron secretos productivos. Hashes y resultados se guardan en VERIFICACION-2E.json.

El App Group esperado se tomó del entitlement original; al estar sin firmar no se afirma que ya esté concedido por un perfil. No se dispone de prueba de firma/instalación del usuario. El commit de preparación 2E solo añade documentación/herramientas; el commit compilado continúa siendo 7864fc3.

## Tratamiento de errores físicos futuros

Registrar caso, hora con zona, estado observado y resultado; conservar evidencia saneada. Distinguir firma/instalación, Keychain, red, autenticación, permisos y codec. No diagnosticar un exploit o el motor a partir de un fallo de login. No modificar producción ni aplicar/restaurar archivos para investigar.

Solo ante un defecto concreto demostrado: reproducir con datos ficticios, corregir el módulo mínimo, preservar gráficos y motor, repetir pruebas relacionadas y generar una nueva IPA experimental identificada por otro commit/hash. No sobrescribir ni reutilizar el nombre/hash de la IPA actual para fingir correspondencia. Hasta entonces no hay recompilación autorizada por un defecto supuesto.

La ejecución física, su aceptación y cualquier despliegue productivo siguen pendientes; esta preparación no los aprueba.
