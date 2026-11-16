# VINI 3K — Targets dinámicos en el dashboard original

## Arquitectura

La integración definitiva usa únicamente `VINIProductionEnvironment.base`:
`https://vini-v2-api.loboangel39.workers.dev`.

`VINIProductionStore` consume `VINIRemotePackageCoordinator`, que conserva la caché validada, consulta el catálogo autorizado, verifica SHA-256/identidad con `PatchPackageCodec` e importa exclusivamente mediante `PatchProjectLibrary`. El store transforma solo los resultados `VINIRemotePreparedPackage` que todavía coinciden con la entrada autorizada del catálogo en `VINIDashboardPresentation`.

No se usan targets de `VINIDashboardPresentation.preview` cuando existe sesión de producción. Un catálogo vacío produce cero tarjetas, conservando pestañas y estructura. `prepared` no activa el interruptor: `patchState` permanece `unknown` porque no existe una transacción `applied` confirmada.

## Cambios

- `VINIStagingClient.swift`: los valores predeterminados de transporte apuntan al Worker principal; no se cambió el contrato HTTP ni la renovación 401.
- `VINIStagingAccountView.swift`: `VINIProductionStore` conecta catálogo/preparación con la presentación; la vista de dashboard conserva la misma jerarquía visual.
- `VINIAuthenticationRoot.swift`: inyección del store de producción.
- No se modificaron `VINIDashboardView` ni `VINITargetCard`.

## Limitaciones

Las APIs públicas actuales no permiten reconstruir `restorePending` de forma segura. No se modificaron `PatchTransaction`, journals, recibos, backups ni Apply/Restore. La validación CI usa transporte sintético compatible con el contrato del Worker; no es despliegue ni validación productiva.
