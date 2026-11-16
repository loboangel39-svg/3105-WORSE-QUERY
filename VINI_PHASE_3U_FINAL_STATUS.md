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

- HEAD actual tras las correcciones 3U: `563201ad72b38ea6462e1b62d3e28e65a49bdaac`.
- CI asociado: `43899153420`, `queued` al cierre de esta auditoría; no es PASS.
- El último IPA existente es histórico: artifact `VINI-SessionFix-Unsigned`, run
  `43884312448`, commit `7f5b50c`; no corresponde al HEAD actual.
- IPA histórico: 5,025,339 bytes, SHA-256
  `4649B834DD97193D11AF809EA920B40391524083442DCA0D216D7C566BF9D0D8`,
  unsigned (`_CodeSignature` ausente), Bundle ID visible en plist:
  `com.apple.mobile.MobileHouseArrest`; el plist declara `arm64` como capacidad
  requerida, pero la arquitectura del binario no se confirmó con `lipo` en el
  host Windows. No se usa para validar HEAD.
- No existe IPA verificable para `563201a`.
- El build arm64 actual, arquitectura, estructura ZIP, firma y entitlements del
  HEAD quedan `SKIPPED`.
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
