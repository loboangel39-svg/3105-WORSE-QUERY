# VINI Fase 3B — sesión persistente y caché

## Implementado

- `VINIStagingStore.bootstrap()` detecta identidad local en Keychain antes de consultar el servidor.
- Con identidad guardada se muestra únicamente `Conectando con el servidor` mientras la fase es `checking`.
- Licencia ausente, rechazada, pausada, revocada, expirada o HWID no autorizado vuelve al login.
- La desconexión produce estado bloqueado/reintento; no se convierte en revocación.
- `VINIStagingClient.authorized` fuerza una revalidación única ante `401`, guarda el nuevo token en Keychain y reintenta la petición una sola vez.
- El catálogo autorizado prepara asíncronamente el fixture de staging sin habilitar Apply en targets visibles.
- La caché usa `Library/Caches/VINIStagingVerified`, archivos temporales, validación de tamaño/hash/UUID y reemplazo atómico. La caché nunca se considera permiso permanente: la autorización del servidor se comprueba antes de reutilizarla.
- Restore, journals, receipts y backups no se tocan ni se borran por logout, token expirado o error de red.

## Limitación de integridad

El contrato actual sólo expone digest fijado para el fixture de prueba. No se marcan como verificadas otras entradas del catálogo sin hash/firma proporcionados por Staging. La ampliación correcta sería añadir hash, tamaño, versión y firma al contrato del Worker, sin modificar producción en esta fase.

## Componentes protegidos

Los hashes de `Fase3B-protected-hashes-before.txt` permanecen idénticos después de la integración. No se modificaron motores de acceso, permisos, WQAccess, `bad_query`, `worse_query`, `KernelExploit`, Apply/Restore, backups, Bundle ID, App Group ni entitlements.
