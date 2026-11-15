# VINI 2E — instalación con certificado de desarrollador

Esta fase utiliza la IPA existente. No se recompiló el proyecto ni se modificó el Worker.

## Artefacto identificado

- Código de la IPA: 7864fc3ff5c06d81b05e67fa6a94c40813d4109e.
- Run aprobado: https://github.com/loboangel39-svg/3105-WORSE-QUERY/actions/runs/43760563603.
- SHA256: c8ddf2110ced0f8232043e5fb83dcbd85dbfceb5a13f260063a76c972c351bf1.
- Plataforma: iOS físico, arm64. IPA sin firma ni perfil embebido.
- Bundle ID: com.apple.mobile.MobileHouseArrest.
- App Group de la configuración original: group.pigtjing.top.
- Único Worker de autenticación/catálogo: https://vini-admin-plans-staging-2b.loboangel39.workers.dev.

La comprobación combina hash del archivo, commit.txt del artefacto CI, headSha del run y presencia del origen staging en el ejecutable; no se infiere el commit a partir del nombre del archivo. No contiene la URL de autenticación productiva. El cliente recibe credenciales de prueba mediante Keychain; no incorpora credenciales productivas. La versión firmada tendrá otro hash: el hash anterior identifica exclusivamente la IPA original sin firmar.

## Procedimiento existente de firma

El usuario indicó «certificado de desarrollador». No indicó la aplicación firmante; por eso no se inventan nombres de botones ni un procedimiento propio de una herramienta determinada.

1. Conservar los datos de la instalación actual mediante el procedimiento de respaldo ya utilizado. La identidad coincide con la aplicación existente; no desinstalarla ni borrar su Keychain para esta prueba.
2. En la herramienta habitual con soporte de App Group, seleccionar la IPA indicada en RUTAS.md, el certificado de desarrollador vigente y su perfil de aprovisionamiento correspondiente. No enviar el certificado, P12, contraseña, clave privada o perfil completo al chat.
3. Conservar el Bundle ID exacto y los entitlements originales, incluido group.pigtjing.top. Desactivar cualquier opción que renombre la app, cambie el identificador, reemplace grupos o inyecte código. No elegir un grupo alternativo para hacer que la instalación pase.
4. Verificar que el perfil realmente autoriza esa identidad y App Group para el dispositivo. Tener un certificado por sí solo no lo demuestra. Si la herramienta/perfil no permite conservarlos, detener la instalación y registrar P01 como blocked; no modificar el proyecto ni el perfil para evadir la incompatibilidad.
5. Firmar e instalar con el procedimiento ya autorizado de esa herramienta. Si iOS solicita confianza en ese desarrollador o habilitación para una app de desarrollo, seguir únicamente el flujo oficial mostrado por iOS y la herramienta habitual. No confundirlo con el antiguo ajuste Developer Mode de la interfaz de Files.
6. Revisar en el resumen de firma que se preservan identificador y App Group. No se afirma que el perfil o la firma del usuario ya hayan sido validados: todavía no se han proporcionado evidencias.
7. Abrir VINI sin tocar interruptores, importar paquetes reales ni ejecutar Apply/Restore. Empezar por P02 y P03 del checklist.

## Login y cuentas

Tocar la tarjeta de licencia existente para abrir Cuenta. Copiar la licencia de prueba desde COPIAR-LICENCIA.ps1 de la entrega 2D y pegarla en el SecureField. BASIC y PRO tienen cuentas separadas; no usar claves productivas ni enviarlas con las evidencias. Las credenciales están cifradas para el usuario Windows actual mediante DPAPI, fuera del ZIP fuente y de la IPA.

La licencia BASIC recibió siete días y la PRO cuatro al crearse en 2D: no se reinició su vigencia en esta fase. Revisar el vencimiento en el panel staging antes de probar. No renovar ni activar cuentas automáticamente para aparentar un resultado.

La UI limita refrescos a quince segundos y revalidaciones a treinta. Si indica espera, respetar ese intervalo; no pulsar login repetidamente. Un login válido debe sustituir PREVIEW por STAGING y mostrar los datos devueltos por el servidor.

Los estados de red, firma o Keychain no deben corregirse cambiando Bundle ID, App Group o mecanismos de acceso. Registrar primero el caso y su evidencia saneada.
