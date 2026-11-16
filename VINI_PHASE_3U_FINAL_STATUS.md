# VINI 3U — estado final verificable

## Funciona según código/fixtures

- El arranque crea `VINIAuthenticationRoot` y `VINIProductionStore`.
- Keychain, HWID persistente, login, revalidación 401 y logout están conectados.
- El transporte usa exclusivamente el Worker principal para producción.
- El límite package es 64 MiB; SHA, tamaño, codec, clave autorizada y UUIDs se
  validan antes de presentar un target.
- Catálogo enriquecido y rama legacy están implementados.
- IDs 1/2/3 y asociación local Codable están implementados.
- Apply/Restore sigue pasando por `DevicePatchService` y `PatchTransaction`.
- Las fixtures previas cubrieron integridad, cache, identidad y sesión temporal.

## Parcial o no validado

- No existe IPA verificable para HEAD `f244692` ni para las correcciones 3U.
- CI `43897324178` estaba `queued` al realizar la auditoría; no es PASS.
- El build arm64, arquitectura, estructura ZIP, firma y entitlements del IPA
  quedan `SKIPPED`.
- No se probó iPhone físico, background real, Files real ni Apply/Restore real.
- La UI existente no expone todavía una acción visible para asignar categoría a
  un paquete legacy pendiente; existe API de store/coordinador, pero la conexión
  de presentación está incompleta.
- La sincronización no tiene un `PatchSyncManager` dedicado ni recuperación de
  descarga en background; evita duplicados solo mediante `busy` en el store y
  actor del cliente.

## Riesgos prioritarios

1. Obtener un runner macOS y compilar el HEAD corregido.
2. Ejecutar fixtures y revisar cualquier error Swift antes del IPA.
3. Probar catálogo real autenticado sin cambiar Worker productivo.
4. Probar clasificación pendiente/assignación en UI.
5. Probar Files y transacciones únicamente con fixtures propios.

## Conclusión

VINI no debe considerarse estable para producción ni validada físicamente. La
integración de sesión, importación y transacciones está conectada en código,
pero la evidencia CI/IPA del HEAD actual y la validación del dispositivo aún
faltan. Los runs cancelados o queued no se cuentan como PASS.
