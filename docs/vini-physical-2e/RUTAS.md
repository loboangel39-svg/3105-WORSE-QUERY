# Rutas absolutas Windows — preparación física 2E

IPA existente, no reconstruida:
C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-iOS-Staging-7864fc3\VINI-Staging-Unsigned.ipa

Código compilado: 7864fc3ff5c06d81b05e67fa6a94c40813d4109e.
SHA256 IPA: c8ddf2110ced0f8232043e5fb83dcbd85dbfceb5a13f260063a76c972c351bf1

Guía de instalación:
C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-Physical-2E\INSTALACION.md

Checklist:
C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-Physical-2E\CHECKLIST.md

Procedimiento de evidencias:
C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-Physical-2E\DIAGNOSTICOS.md

Incidencias y límites pendientes:
C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-Physical-2E\INCIDENCIAS.md

Plantilla original, todos los casos pendientes:
C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-Physical-2E\PLANTILLA-OBSERVACIONES.json

Exportador:
C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-Physical-2E\export-vini-physical-evidence.py

Acceso cifrado a las licencias de prueba ya entregadas:
C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-iOS-Staging-7864fc3\COPIAR-LICENCIA.ps1

Acceso cifrado al panel staging ya entregado:
C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-Admin-2B-482997b\ABRIR-ACCESO-STAGING.ps1

## Abrir la carpeta

```powershell
Invoke-Item -LiteralPath 'C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-Physical-2E'
```

## Registrar y exportar observaciones

Primero copiar la plantilla, sin modificar el original:

```powershell
if (Test-Path -LiteralPath 'C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-Physical-2E\OBSERVACIONES-TRABAJO.json') { throw 'El archivo de trabajo ya existe; conservarlo.' }
Copy-Item -LiteralPath 'C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-Physical-2E\PLANTILLA-OBSERVACIONES.json' -Destination 'C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-Physical-2E\OBSERVACIONES-TRABAJO.json' -ErrorAction Stop
```

Si el archivo de trabajo ya existe, conservarlo en lugar de repetir la copia. Editarlo localmente con estados/tiempos observados. No añadir texto libre ni credenciales. Después:

```powershell
py -3 -X utf8 'C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-Physical-2E\export-vini-physical-evidence.py' 'C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-Physical-2E\OBSERVACIONES-TRABAJO.json' 'C:\Users\ANGEL\Documents\Codex\2026-11-14\instrucci-n-definitiva-integraci-n-completa-2\outputs\VINI-Physical-2E\EVIDENCIA-IPHONE.json'
```

El exportador no sobrescribe un archivo existente. Para una segunda sesión usar otro nombre nuevo de entrada/salida. No enviar la plantilla ni el export de demostración como si fueran resultados reales. Compartir solo el export real saneado y las observaciones mínimas necesarias.
