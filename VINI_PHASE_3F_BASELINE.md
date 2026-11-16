# VINI Fase 3F — Baseline del Worker principal

Fecha: 2026-11-15  
Resultado: **BLOCKED**

## Motivo del bloqueo

La auditoría local confirma el Worker, sus bindings y el contrato de rutas. La consulta estructural de D1 quedó verificada mediante Cloudflare Dashboard en modo lectura. Wrangler continúa bloqueado con `spawn EPERM` en Windows. La comprobación de ejecuciones GitHub Actions para el SHA exacto `8f0e1d5` devolvió cero ejecuciones y cero estados asociados; no existe evidencia CI reutilizable de macOS/arm64, por ello no se declara `PASS` global.

## Estado del checkout iOS

- Ruta: `work/3105-integration`
- Rama: `experiment/vini-session-patch-cache`
- Commit: `8f0e1d5` — `Await actor-isolated stored identity check`
- Estado local: limpio al inicio de la auditoría.

El checkout separado del Worker (`work/cloudflare-audit-private/vini-v2-api`) no contiene `.git`; por tanto no se puede atribuirle una rama/commit Git local.

## Evidencia D1 remota (Cloudflare Dashboard, lectura)

La consola mostró el breadcrumb `vini-v2-db` y el UUID solicitado `3f0d818b-0648-43f9-9dbe-3ffca38d2035`, confirmando que corresponde al binding `DB` configurado para `vini-v2-api`.

Consulta ejecutada:

```sql
SELECT name, sql FROM sqlite_master
WHERE type IN ('table', 'index', 'view')
  AND name NOT LIKE 'sqlite_%'
ORDER BY type, name;
```

Resultado estructural relevante:

- Tablas: `patches`, `user_patches`, `users`, `downloads`, `activity_log`, `config`, `messages`, `device_activations`, `device_challenges`, `device_seen`, `blocked_devices`, `daily_status`, `license_attempts`, `permanence_rewards`, `rate_limits`, `referrals`, `rewards_points`, `rewards_transactions`, `trust_reports`.
- Índices observados: `idx_device_activations_license`, `idx_device_activations_user`, `idx_device_challenges_activation`, `idx_license_attempts_lookup`.
- No apareció `patch_targets`.
- No apareció `patch_policies`.

Estructuras verificadas mediante `pragma_table_info`:

`patches`: `id TEXT PRIMARY KEY`, `name TEXT`, `description TEXT`, `version TEXT`, `type TEXT`, `file_key TEXT`, `active INTEGER`, `created_at TEXT`, `updated_at TEXT`, `content_key TEXT`, `password TEXT`.

`user_patches`: `user_id TEXT` (parte de PK), `patch_id TEXT` (parte de PK), `created_at TEXT`.

No se consultaron filas de usuarios, licencias, HWID, tokens ni contraseñas.

## Worker y bindings verificados localmente

Archivo: `work/cloudflare-audit-private/vini-v2-api/wrangler.jsonc`

```text
name = vini-v2-api
main = src/index.js
DB  = D1 database 3f0d818b-0648-43f9-9dbe-3ffca38d2035
R2  = bucket vini-patches
```

No se encontró binding alternativo en ese archivo.

## Endpoints observados en `src/index.js`

Autenticación y sesión:

- `POST /api/app/validate-license`
- autenticación posterior mediante `verifyAppAuth`

Catálogo y distribución:

- `GET /api/app/patches`
- `GET /api/app/patches/:id`
- `GET /api/app/patches/:id/download`

El catálogo filtra por `patches.active = 1` y por la relación `user_patches`. La descarga vuelve a comprobar autorización y obtiene el objeto mediante `env.R2.get(patch.file_key)`.

## Esquema local disponible

En las migraciones del backend experimental aparecen `patches`, `user_patches` y `patch_policies`, pero esa evidencia no sustituye el esquema remoto. La consulta D1 del Dashboard confirmó que `patches` y `user_patches` existen y que `patch_targets` y `patch_policies` no existen en la base principal. La consulta remota necesaria fue:

```sql
SELECT name, sql
FROM sqlite_master
WHERE type = 'table'
ORDER BY name;
```

No se repite mediante Wrangler: el acceso equivalente de solo lectura ya fue realizado en Dashboard. El error local de Wrangler se conserva únicamente como incidencia del entorno Windows.

## Compatibilidad con targets dinámicos

El contrato iOS ya contiene `targetID` en `VINIRemoteContract`, pero el cliente de staging actual sólo conoce el fixture fijo y el dashboard mantiene los targets de presentación. No existe evidencia local de que el Worker principal devuelva todavía `targetID`, `packageID`, `projectID` o `sha256` para cada entrada.

Conclusión: el contrato actual permite autorización por `patches.id` y `user_patches`, pero no basta para publicar targets dinámicos con integridad verificable.

## Hashes SHA-256 de componentes protegidos

Calculados sin modificar archivos:

| Componente | SHA-256 |
|---|---|
| `ThreeOneOSFive/helpers/PatchTransaction.swift` | `FDF8801B151959EE52AE7CED8CD6D28D327074A078842988A312D308B1531BAA` |
| `ThreeOneOSFive/helpers/DevicePatchService.swift` | `9EF5ED7A1CD061E001106ADCDB7A1933E42B198418BFF9C41445541E1E2FFBDE` |
| `ThreeOneOSFive/helpers/VINIDualBackupStore.swift` | `E30E2D3FF96CA4EA45D36C108F5768069E0A37C2F0CD477D819867B6FD5B39B9` |
| `ThreeOneOSFive/helpers/PatchPackageCodec.swift` | `F84EFD7FB6A066033F82835DB51BD0062716863BED402ACCA6F15E8B472EDFB1` |
| `ThreeOneOSFive/helpers/ContainerAccessCoordinator.swift` | `D737BD4950116D1FBA765F800FB8F07E6229B3A37CEDDF4C08D572E730F98EDD` |
| `ThreeOneOSFive/helpers/ContainerStore.swift` | `0EF53618865FE7562EA8C06EADC337FC4AEF8A541142D81927894B88B8765BED` |
| `Vendor/WQFiles/WQAccess.m` | `ADA42258368F6715D34EC940CCE0227CA2DF2FB0F08B1FB45EF7BDF25EADEF11` |

Los archivos `worse_query.c` y `bad_query.c` no existen con esos nombres en el checkout; no se sustituyen ni se modifican.

## Pruebas

- `swift --version`: no disponible en el entorno Windows; no se ejecutaron pruebas Swift locales.
- Consulta remota D1 con Wrangler: **BLOCKED**, `spawn EPERM`.
- Consulta D1 mediante Dashboard: PASS, sólo metadatos estructurales.
- `PRAGMA`/`pragma_table_info` de `patches` y `user_patches`: PASS.
- Inspección de `wrangler.jsonc`: PASS.
- Inventario de rutas del Worker: PASS.
- GitHub Actions para `8f0e1d5`: **sin ejecuciones** (`workflow_runs: []`) y sin estados asociados; no hay evidencia de runner macOS ni de compilación `iphoneos arm64`.
- Operaciones de escritura: no ejecutadas.
- Producción, D1, R2 y `main`: sin modificaciones.

## Diagnóstico Wrangler en Windows

- Node.js: `v26.13.1`.
- Ejecutable: `C:\Users\ANGEL\AppData\Roaming\npm\wrangler.ps1`.
- Wrangler instalado: `4.129.0` (versión previamente confirmada en esta sesión).
- Error: Node falla al crear el proceso hijo con `spawn EPERM` antes de ejecutar Wrangler.
- No se deshabilitó Defender ni se cambiaron permisos.
- La consulta Dashboard se acepta como evidencia suficiente del esquema remoto.

## Workflows macOS revisados

Existen workflows en `.github/workflows` con `runs-on: macos-15`, incluyendo:

- `validate-vini-staging.yml`
- `validate-vini-contracts.yml`
- `build-unsigned-ipa.yml`
- `build-experimental-appgroup-ipa.yml`

El workflow de staging contiene compilación nativa Swift y `xcodebuild -sdk iphoneos -destination 'generic/platform=iOS'` con `ARCHS=arm64` y firma deshabilitada. También se verificó que `validate-vini-staging.yml`, `validate-vini-contracts.yml` y `build-unsigned-ipa.yml` declaran `workflow_dispatch` y `runs-on: macos-15`. La consulta de GitHub Actions para el commit exacto `8f0e1d5` fue realizada mediante la API de solo lectura y devolvió `total_count: 0`; el estado combinado del commit también devolvió `statuses: []`. La conexión GitHub disponible permite lectura, pero no expone una operación de dispatch manual; tampoco está disponible un navegador Chrome conectado desde este entorno para completar el disparo interactivo. No se modificaron archivos para forzar una ejecución. No se utilizó CoreSimulator ni `simctl`; la evidencia macOS/arm64 queda bloqueada hasta que el propietario ejecute manualmente esos workflows.

### Procedimiento manual requerido

En GitHub: abrir `Actions` → seleccionar `VINI staging native contracts and physical arm64` → `Run workflow` → elegir `experiment/vini-session-patch-cache` → ejecutar. Repetir para `Validate VINI contracts and physical arm64` y, si se desea la IPA general, `Build unsigned 3105 IPA`. En cada ejecución debe verificarse que el paso de checkout registre exactamente `8f0e1d5a6f30a50422e00d1be1cd440e794dd398`. Después deben conservarse la URL, el ID, los logs de `xcodebuild -version`, `architecture.txt`, resultados de pruebas y artefactos.

## Comparación de hashes

Se repitió el cálculo local y coincide con todos los hashes registrados en la sección anterior. No hubo cambios en los componentes protegidos. Las rutas reales de `bad_query` y `worse_query` se determinarán desde el proyecto Xcode/WQFiles; no se asumieron nombres `.c` inexistentes.

## Propuesta 3G (no aplicada)

1. Obtener una consulta D1 de solo lectura mediante Wrangler funcional o Cloudflare Dashboard.
2. Confirmar tablas y columnas reales antes de diseñar migración.
3. Extender el catálogo con identidad de target, `packageID`, `projectID`, digest, tamaño y revisión.
4. Mantener `patches`, `user_patches` y las rutas existentes compatibles.
5. Probar con D1/R2 de ensayo antes de cualquier despliegue.

No se inicia 3G ni se aplican migraciones. Aunque la lectura D1 ya está resuelta, 3F permanece BLOCKED exclusivamente por falta de evidencia CI real del commit auditado.
