# Resultados Fase 2B — 2026-11-15

## Evidencia ejecutada

- 54 grupos locales aprobados, cero fallos finales: workerd + D1, criptografía real, persistencia y navegador Edge. Incluyen las 36 regresiones anteriores y los 18 casos nuevos. Evidencia: test-results.json en la entrega.
- 18/18 casos aprobados contra Worker y D1 remotos separados de Cloudflare. Evidencia: remote-test-results.json. Versión probada: 2fdebded-ef21-42ae-8abb-87cf8e86f4c9.
- Panel final probado en Edge real contra staging: login, roles, navegación por ámbito, ausencia de controles globales para distribuidor, estados y acción confirmada. HTML remoto idéntico al artefacto; SHA256 56995cf52d22dc927be61ff2f627dfe65728b78158e4d693b6c63e65a74b698f. Evidencia: remote-panel-results.json y captura.
- Versión final staging: 5a80a0ae-d561-4c1c-a91a-00d0ccc9cfc2. Respecto al backend probado solo cambian presentación de estados/permisos y cierre del bootstrap. GET /api/admin-v2/migrations/preview devuelve 404. No se repiten 54/18 pruebas por cambios exclusivamente visuales/documentales.
- Migraciones 0001, 0002 y 0003 aplicadas en staging, manifiestos verificados por el runner. Cada archivo completo es una transacción independiente; bootstrap queda deshabilitado.

## Cobertura remota (18 casos)

Pausa individual; reactivación individual; pausa y reactivación por distribuidor; pausa y reactivación global; superposición de orígenes; saldos independientes de siete y cuatro días; baja lógica; reset individual HWID; rechazo de sesiones y activaciones previas; rechazo de IDs ajenos; idempotencia masiva; auditoría; login compatible; BASIC/PRO; renovación en pausa; protección frente a archivado por fecha.

El conjunto local también comprueba recuperación después de cerrar workerd, ejecución concurrente, cambios de revisión, retención, permisos de paquetes y leases firmados. Se reutilizó la evidencia aprobada; no se ejecutaron simuladores iOS.

## Incidencias resueltas

El límite de consultas D1 Free exigió lotes de cinco miembros y aplicar una migración completa por request. Las pruebas remotas finales aprueban esos límites. La salida de progreso de importación de Wrangler no era JSON puro: se comprobó el esquema importado sin repetir la importación. No quedan pruebas fallidas en los informes finales.

## Límites y pendientes

No hay validación en iPhone ni despliegue productivo. La compatibilidad APP se demuestra a nivel de protocolo, no con una instalación física. Staging no tiene binding R2: no se valida descarga real de paquetes productivos. No se afirma revocación instantánea de leases offline ya emitidos; ver HWID_RESET.md. Falta la aceptación manual del propietario y cualquier autorización futura de producción.

## Protección

Datos ficticios y secretos nuevos de staging. Sin cambios iOS ni a snapshots originales. Producción conserva versión f1e869fd-59d7-4367-a04a-d2186e25c647 y despliegue 05f14b14-fdaa-44d9-9123-4643650f8dfe, comprobados por lectura. No se escribieron vini-v2-db ni vini-patch-db. La rama main permanece intacta.
