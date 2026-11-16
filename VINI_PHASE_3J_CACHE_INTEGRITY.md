# VINI 3J-F — Integridad y rollback

La publicación de caché exige coincidencia de tamaño y SHA-256 antes de mover el temporal. Un temporal incompleto no tiene metadatos publicados y no puede ser reutilizado. Una entrada corrupta devuelve `nil`, por lo que el coordinador descarga de nuevo tras revalidar el catálogo.

La caché no elimina paquetes anteriores, proyectos importados, backups, journals ni recibos. El rollback de una nueva revisión consiste en mantener la entrada anterior intacta; no se modifica `PatchTransaction` ni `VINIDualBackupStore`.

Estado: **PENDING CI**.
