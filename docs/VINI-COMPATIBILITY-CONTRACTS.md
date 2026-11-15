# VINI: compatibilidad y contratos, complemento del respaldo dual

Esta fase conserva el dashboard de `a89d075`. No modifica el motor de acceso,
la política original `ExploitSupportPolicy`, el formato `.3105`, el App Group,
el Bundle ID ni los entitlements. La política de presentación se centraliza en
`VINICompatibilityResolver`; no se utiliza para ejecutar exploits.

## Compatibilidad

Se aplica la matriz solicitada: 17.0–17.7 y 18.0–18.7.1 con
`kexploit_opa334`; 26.0–26.6.1 con `bad_query` y fallback `worse_query`;
26.6.2–26.7.2 con `worse_query`; 27.0 beta 1–4 con `bad_query` y fallback;
27.0 desde beta 5 hasta 27.2.1 con `worse_query`; 27.3 beta 1 con
`worse_query`. Los límites no se extienden a versiones posteriores.

El dato `27.2.1 (24B156)` proporcionado en la especificación se clasifica bajo
`worse_query`. Es cobertura de política, no evidencia de ejecución correcta.
Las versiones finales exigen un build de formato final y la familia de build
correspondiente. Esto no autentica la procedencia de un sistema operativo.

Para distinguir seeds, se reutilizan los cuatro builds beta existentes en
`ExploitSupportPolicy`. No se deduce el número de beta por la versión numérica
ni por el sufijo del build. El resolver admite metadatos explícitos de etapa
para una futura fuente autoritativa; el dashboard no los inventa. Por tanto,
una beta 5 o 27.3 beta 1 cuyo build aún no figure en el registro aparece como
«No verificado» en el dispositivo. Faltan sus correspondencias verificables
build → etapa → número de beta. Los tests con builds sintéticos prueban la
política al recibir esa etapa explícita, no certifican builds reales.

## Textos, bindings y asignaciones

Se mantienen exactamente los diez nombres, sus iconos, categorías, tarjetas,
tipografías, espaciados y panel. Se eliminan los subtítulos demostrativos en
los cuatro idiomas. Sin descripción asociada se muestra «Sin patch asignado».
Los campos de usuario y plan muestran «—», sin sesión ni licencia ficticia;
el tiempo continúa sin verificar. La presentación conserva sus bindings de
licencia para una futura integración autenticada.

Los IDs `vini.aim_drag`, etc. son estables y no dependen del título traducido.
No son asignaciones reales. Las tarjetas actuales permanecen deshabilitadas y
no mantienen selecciones optimistas. Importar un paquete tampoco lo asigna a
una tarjeta. `VINIPackageCatalog` valida archivos disponibles y decodificables,
rechaza identidades duplicadas y vuelve a comprobar el hash antes de usar un
proyecto. El catálogo local no contacta con el servidor.

`VINIRemoteCatalog` y `VINIRemoteTarget` preparan el contrato propuesto:
`schemaVersion`, revisión del catálogo, targetID, categoría, nombre, descripción
opcional, packageID, projectID, revisión del paquete, SHA-256 de sus bytes,
disponibilidad y plan requerido opcional. El hash no reemplaza autenticación.
`VINIRemoteSession` reserva identidad de usuario/licencia, plan, hora del servidor,
caducidad y revisión de catálogo. Las fechas JSON deberán acordarse con el Worker;
no existe aún un decodificador de sesión que acepte una fecha como autorización.

Decodificar estos DTO no habilita Apply. La cadena prevista es:

```mermaid
flowchart LR
  A[Worker autenticado] --> B[Asignación targetID]
  B --> C[packageID + revisión + hash]
  C --> D[Proyecto decodificado projectID]
  D --> E[Coordinador de respaldo dual]
  E --> F[transactionReceipt verificado]
```

Faltan el código y contrato real del Worker: URL/operaciones existentes, mecanismo
de autenticación, validación de respuesta y revisión, vínculo cuenta/licencia,
protección contra repetición, política de expiración y refresh, y entrega del
paquete o material de descifrado compatible con el codec existente. No se crean
endpoints, servidor, migraciones D1 ni llamadas de red ficticias. Tampoco se
modifica la autenticación de otras aplicaciones VINI. No hay reloj local que
pueda extender una licencia.

## Estado del trabajo principal

Se conservan las extensiones pendientes de `PatchTransaction` y
`DevicePatchService`, y `VINIDualBackupStore`. Son trabajo en curso, todavía sin
coordinador conectado al dashboard. No se declara terminada la restauración
silenciosa, la recuperación tras interrupción ni la rotación transaccional.
En particular, la limpieza/repair reanudable y su validación física siguen
pendientes. No se activarán mediante datos de demostración para probarlas.

## Verificación

`scripts/verify-vini-contracts.py` compara con `a89d075` los componentes gráficos,
todos los archivos versionados de WQFiles, la política de acceso original,
codec/biblioteca, identidad y ajustes de compilación. Solo permite las adiciones
de archivos al target y los cambios de texto/estado descritos.

`Tests/VINIContracts/main.swift` comprueba lógica pura de metadatos en el host de
compilación. No ejecuta la aplicación iOS ni acceso a contenedores. El workflow
`validate-vini-contracts.yml` compila exclusivamente con `iphoneos`, destino físico
genérico y `arm64`, sin firma; comprueba símbolos nativos y empaqueta una IPA.
Los checks antiguos de Phase 1 exigen literalmente controles de demostración y
ya no son una validación válida para este complemento; no se eliminan.

Ninguno de estos resultados constituye validación funcional en iPhone. Quedan
pendientes en el iPhone la fidelidad visual, navegación, estado dinámico y los
catorce escenarios del documento principal, cuando el coordinador y la fuente
autoritativa estén conectados. No se utilizan dispositivos virtuales.
