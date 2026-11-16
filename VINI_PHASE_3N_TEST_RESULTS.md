# VINI 3N — Resultados

## CI

PASS: run `43882031983` — https://github.com/loboangel39-svg/3105-WORSE-QUERY/actions/runs/43882031983

- Sintaxis del coordinador y cliente: PASS.
- Fixtures nativas 3J/3K: PASS.
- Revalidación 401, revocación, cache aislada y SHA/identidad inválidos: PASS.
- Build unsigned `iphoneos arm64`: PASS.
- IPA: `VINI-SessionFix-Unsigned`, 5,025,337 bytes.
- SHA-256: `3ce63d8841b33abf6bb6eb1bf1b69adf23dd62cea0a3967dfcdc384915bb7e3d`.
- Bundle ID: `com.apple.mobile.MobileHouseArrest`.

## Casos

PASS: sesión temporal conservada en el adaptador, límite de descarga separado
del fixture, rechazo de SHA/tamaño/identidad, catálogo vacío sin targets
ficticios, errores de cache y ausencia de clave representada como rechazo.

SKIPPED: descarga cifrada real con cabecera HTTP capturada, porque las
fixtures actuales no simulan `X-Content-Key`; prueba física en iPhone; consulta
de catálogo de cuenta real; Apply/Restore.

BLOCKED: confirmar targets dinámicos productivos. El snapshot local del Worker
principal devuelve un catálogo sin los metadatos `targetID/projectID/SHA/fileSize`
que el importador exige. El GET público sin sesión devuelve 401; no se usaron
credenciales reales.

## Cambios

Commit de código: `f54c49c`.
No se modificaron Worker, D1/R2, codec, transacciones, backups, journals,
entitlements, Bundle ID, App Group ni UI visual.
