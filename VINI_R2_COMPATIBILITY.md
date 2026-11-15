# R2 y formato .3105 — aceptación 2C

Bucket creado: vini-admin-plans-staging-2c. Binding R2 exclusivo del Worker staging. No se descargó ni modificó vini-patches productivo. El bucket se añadió con autorización expresa, desplegando el artefacto existente sin reconstruir las fuentes.

## Resultados remotos

| Caso | Resultado |
|---|---|
| PRO con asignación y política vigente | Descarga 200 |
| Sin Bearer/licencia | 401 |
| PRO sin asignación | 403 |
| BASIC con asignación a patch de política PRO | 403; tampoco aparece en catálogo |
| Detalle histórico de patch autorizado | 200, ID esperado |
| Objeto eliminado únicamente del bucket sintético | 404 File not found in storage |
| Interrupción de stream después de leer primer fragmento | Cancelación del reader; siguiente GET completo íntegro |
| Range bytes=1024- | 200 completo, sin Content-Range; no hay contrato de reanudación parcial |
| Reversión y restauración staging | R2 vuelve a descargar los mismos bytes |

Fixture: TEST2C-transport.3105, 2.098.157 bytes.
SHA256: 92e0aa294e16bfd9ca417f121d162cdeecf46cbae0ab3ca89a2e24a7cf6bb222.
Patch sintético: c0df8b65-a64d-4dca-b262-f12b39831768.
Los bytes recibidos se compararon por SHA256 con los enviados y con Content-Length. La descarga es opaca: no convierte ni vuelve a cifrar paquetes. No se registraron content keys ni contraseñas.

## Compatibilidad comprobada y límite nativo

tests/fixture-2c.mjs genera exclusivamente un proyecto ficticio com.example.vini.acceptance, nunca aplicado. Sigue PatchPackageCodec.swift: magic 3105PATCH seguido de NUL, plist binario, envelope schemaVersion=3, packageID UUID, clave pública de contenido de 32 bytes, fingerprint SHA256 y AES-GCM combinado nonce/ciphertext/tag; AAD 3105PATCH/v3/payload/UUID. Payload plist con project y replacementDigests. Se comprobó roundtrip criptográfico independiente en Node y se usa plistlib de Python, sin instalar dependencias.

Esto demuestra integridad de transporte y correspondencia estructural con el código, **no ejecución del decodificador Swift**. Importar/inspeccionar en iPhone, sin Apply/Restore, sigue pendiente. No se generaron paquetes v1/v2 ni fixtures con contraseña en esta fase; el transporte conserva bytes sin interpretar versión. No se declara probada compatibilidad nativa de todas las versiones.

La prueba de interrupción es cancelación real del consumidor HTTP, no desconexión física de red. No hay soporte demostrado de 206/Range; un cliente debe reiniciar y verificar el archivo completo antes de importarlo. El contador downloads se registra al servir la respuesta, no prueba que el cliente terminara de recibirla. La prueba física debe comprobar que un archivo parcial no se importa y que el reintento descarta ese parcial.

Los paquetes sin fila patch_policies conservan el contrato histórico de asignación + active. Para ofrecer exclusividad PRO en producción es necesario registrar la política explícita; ser PRO por sí solo nunca asigna paquetes. Inventariar políticas antes de autorizar producción.
