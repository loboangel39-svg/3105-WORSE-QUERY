# VINI 2.0 RC4 — Rendimiento

## Hallazgos de código

- Se eliminó la sincronización duplicada al abrir Installed.
- La carga de biblioteca continúa fuera del hilo principal en `PatchProjectStore`.
- Apply/Restore directos ejecutan trabajo en `Task.detached` y publican solo el resultado.
- Se añadieron mediciones no sensibles para catálogo, sync, Apply y Restore mediante `systemUptime`.

## Tabla

| Flujo | RC3 | RC4 | Estado |
|---|---|---|---|
| Catálogo inicial | Dos entradas de sync | Una entrada | Verificado por inspección de flujo |
| Refresco de catálogo | Sin ciclo activo | 45 s en foreground | Implementado |
| Apply/Restore UI | Alertas de éxito | Estado y recarga | Implementado |
| Latencia real en iPhone | No medida | Pendiente | Requiere dispositivo |

No se afirma una mejora numérica de latencia sin medición física. Los logs solo registran duraciones y conteos, nunca tokens, licencias o claves.
