# VINI 3L-A — Plan de integración

## Diseño futuro, no implementado

1. Mantener `VINIProductionStore` como única fuente de datos del dashboard.
2. Añadir un adaptador read-only separado, por ejemplo `VINITransactionStateReader`.
3. Recibir una asociación explícita `targetID → projectID → packageDigest`; no usar nombres de archivo.
4. Leer records/receipts y validar journal, manifests, roots y digests sin escribir.
5. Resolver estados conservadores: solo `applied` con evidencia completa; `restorePending` si existe operación no terminal; `error` ante evidencia incompleta o inconsistente.
6. Fusionar estados locales con catálogo: una revocación elimina autorización de descarga, pero no elimina una operación local pendiente de restore.
7. Mantener el binding visual actual y cambiar únicamente el valor de estado cuando exista evidencia real.

## Cobertura actual

- Runtime real de 3J y modelo de targets de 3K: cubiertos por CI anterior en transporte sintético compatible con Worker.
- Auditoría de APIs: PASS estática en este documento.
- Ejecución de transacciones reales: SKIPPED deliberadamente.
- Apply/Restore de terceros: SKIPPED y fuera de autorización.
- Prueba runtime de `restorePending`: BLOQUEADA por falta de API pública agregada.
- Validación visual en dispositivo: SKIPPED; solo se verificó preservación por diff/compilación.

## Riesgos y rollback

Riesgo principal: confundir un receipt existente o un paquete preparado con aplicación confirmada. El adaptador debe fallar cerrado. Rollback de 3L-A es eliminar únicamente el adaptador nuevo y sus bindings; no requiere tocar journals, backups, transacciones, UI protegida ni producción Cloudflare.

No se inicia 3L-B ni se despliega Worker, D1 o R2.
