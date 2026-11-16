# VINI — Corrección de login del Worker principal

## Causa

`VINIProductionStore.refresh(licenseKey:)` llamaba a `VINIStagingClient.login`,
que enviaba correctamente `POST /api/app/validate-license`, pero intentaba
decodificar la respuesta 200 también como `VINIStagingProfile`. Ese modelo
exigía `plan`, `licenseStatus` y `serverTime`, aunque el contrato principal
puede devolver únicamente `valid`, `token`, `expiresAt`, `username`,
`userID`, `isPremium` y `licenseExpiresAt`. La licencia válida terminaba como
`invalidResponse` y nunca llegaba a `.authorized`.

## Corrección mínima

`VINIStagingClient.fetchProfile` ahora decodifica un modelo específico de
validación del Worker. Exige `valid == true`, token no vacío, username válido y
expiry posterior al server time; deriva únicamente el plan permitido (`pro`
si `isPremium == true`, en otro caso `basic`) y construye el perfil interno.
HTTP 401/403, licencia inválida, expirada, error de JSON y Keychain siguen
siendo rechazos; no existe bypass de autenticación.

No se modificaron el Worker, licencias, HWID del servidor, UI, dashboard,
transacciones, backups, journals, entitlements ni Bundle ID.

## Pruebas

CI PASS: run `43818064515` — https://github.com/loboangel39-svg/3105-WORSE-QUERY/actions/runs/43818064515

La fixture de coordinación usa ahora el contrato mínimo del Worker principal
sin `plan`, `licenseStatus` ni `serverTime`, y conserva pruebas de revalidación,
401, revocación, SHA inválido y catálogo vacío. No se usaron credenciales
productivas ni se realizó una prueba física de dispositivo.

## IPA unsigned

- Artefacto: `VINI-ApplyRestore-Unsigned`
- Tamaño: `5,017,562` bytes
- SHA-256: `a3503733147eba1d7b98b20af3e39de2c87d709c8d6bae7c76056b63befdbbfc`
- Bundle ID: `com.apple.mobile.MobileHouseArrest`
- Arquitectura: `arm64`
- Commit de código/login: `d16f877`
