# VINI Fase 3H — Auditoría de seguridad

- Autenticación: reutiliza `verifyAuth`; no crea un segundo sistema de login.
- Autorización: `user_patches` sigue siendo requisito para el catálogo y la descarga.
- Integridad: SHA-256 y tamaño se calculan sobre los bytes obtenidos de R2.
- Identidad: UUID, target, categoría, revisión y plan se validan; no se infieren del nombre de archivo.
- Estado: el registro permanece inactivo hasta completar todas las inserciones.
- Revisión: no se permiten dos revisiones autorizadas activas para el mismo target.
- Rollback: se eliminan `patch_targets` y `patches` si falla la fase de registro.
- Auditoría: se registra `patch_registered_r2` mediante el mecanismo existente.
- Producción: no hubo despliegue, migración ni escritura en D1/R2 productivos.

Riesgos restantes: la compensación secuencial no sustituye una transacción D1 nativa si una caída ocurre entre operaciones; debe revisarse antes de producción. La validación del manifiesto representa la identidad ya obtenida por el codec autorizado, pero el Worker no ejecuta el codec iOS.
