# VINI 3M — Diagnóstico y correcciones

## Problema A — Staging visible

La UI usaba literales de producción incorrectos en:

- `VINIAuthenticationRoot.swift:68,104`: `STAGING v` y `CLOUDFLARE · STAGING`.
- `VINIDashboardView.swift:158`: `STAGING · v` para la presentación autenticada.
- `VINIStagingAccountView.swift:188`: etiqueta de cuenta.

Se sustituyeron por `VINI` y `CLOUDFLARE · VINI`, conservando layout,
tipografía, espaciado y flujo. El cliente ya tenía
`VINIProductionEnvironment.base` como URL efectiva; no se encontró una
llamada productiva a la URL staging. Las referencias históricas de fixtures
permanecen aisladas.

## Problema B — Sesión al volver de background

`VINIAuthenticationRoot` fuerza `store.refresh(force: true)` al volver a
foreground. `VINIProductionStore.refresh` cambiaba inmediatamente a
`.checking` y, ante `offline`, `rateLimited` o `stale`, ponía `verified = false`,
`authorizationDeadline = 0` y navegaba al login. Una interrupción temporal se
interpretaba como logout.

La corrección conserva `.authorized`, identidad, perfil y deadline durante esos
tres errores transitorios. 401 sigue usando la renovación autorizada existente
en `VINIStagingClient.authorized`; rechazo, expiración o revocación confirmados
siguen invalidando acceso. `logout()` continúa siendo el cierre voluntario y
borra el token conservando el HWID.

El Keychain ahora usa el servicio de producción
`com.apple.mobile.MobileHouseArrest.vini.session.v1` y lee el registro legado
`vini.staging.session.v1` sin eliminarlo automáticamente; al guardar se migra
la sesión al servicio de producción. No se crea un HWID nuevo durante la
migración.

## Problema C — EXIT

Solo se ajustó el botón existente en `VINIDashboardView.swift`: icono de 14pt,
color cian, fondo/contorno sutiles y área 36x36. Mantiene posición, acción,
accesibilidad y `onExit`; no se creó otro control ni se cambió el dashboard.

## Problema D — Patches

El endpoint productivo `/api/app/patches` responde `401` sin Authorization,
por lo que no es posible observar el catálogo de una cuenta real desde este
entorno. No se modificó Worker, D1 ni R2. El cliente productivo consulta
`/api/app/patches` solo después de una sesión válida y el coordinator exige
descarga, SHA-256, identidad y decodificación antes de importar.

Se añadió diagnóstico no sensible en `VINIProductionStore`:
cantidad de patches autorizados, cantidad preparada/importada y tipo de fallo
de catálogo. Catálogo vacío produce cero targets deliberadamente; no hay
fallback a `preview.targets`.

Las fixtures nativas mantienen cobertura de catálogo vacío, identidad/SHA
incorrectos, revocación y cache aislada. La cantidad real de patches asignados
requiere una sesión válida del usuario en dispositivo; no se usaron credenciales
productivas en CI.

## CI e IPA

CI PASS: run `43878375961` — https://github.com/loboangel39-svg/3105-WORSE-QUERY/actions/runs/43878375961

- Commit de código: `edaa537`
- Commit final de informe: `PENDING`
- IPA: `VINI-SessionFix-Unsigned`
- Tamaño: `5,021,206` bytes
- SHA-256: `45242d946c460579f9780accf1c78e5ff348d18eb75d347add8983d51f0db533`
- Arquitectura: `arm64`
- Bundle ID: `com.apple.mobile.MobileHouseArrest`

CI nativo no sustituye una prueba física de ciclo background/foreground. Apply/
Restore permanece sin validación funcional completa y no se presenta como tal.
