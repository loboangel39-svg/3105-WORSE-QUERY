# VINI — informe de esquemas D1 observados

Fecha: 2026-11-15. Introspección remota autorizada; ninguna fila de negocio leída.
Las consultas exitosas devolvieron `changes=0`, `rows_written=0`, `changed_db=false`.
No se exportaron bases, valores por defecto, credenciales ni paquetes.

## Dos modelos distintos

| Base | UUID | Hallazgo |
|---|---|---|
| vini-v2-db | 3f0d818b-0648-43f9-9dbe-3ffca38d2035 | binding DB de vini-v2-api; licencia y estado en users; activaciones y challenges |
| vini-patch-db | d1aaf8bf-fa01-4e2e-8c70-48c3864d1ab7 | usuarios por HWID y tabla licenses; Worker consumidor no confirmado |

La lista de bases de Wrangler mostraba `num_tables: 0` para ambas aunque
sqlite_schema y PRAGMA revelaron tablas reales. Ese metadato de inventario no se
utilizó como prueba de que estuvieran vacías. No se contó ni inspeccionó usuarios.

- **Usuarios:** `users` en ambas; identificador principal id en v2 y hwid en patch.
- **Licencias:** v2 usa `users.license_key`, `license_expires_at`, `is_active`,
  `is_paused`, `is_blocked`; no tiene tabla licenses. Patch sí tiene `licenses`
  con key, expires_at, revoked, paused y tier.
- **Planes:** ninguna tabla plans; booleano is_premium en v2 y tier en patch.
  Los nombres posibles de plan/tier no se consultaron.
- **Dispositivo:** v2 combina users.hwid con device_activations (user_id,
  license_key, public_key, kid, status); patch usa users.hwid / licenses.hwid.
  La coincidencia de nombres no prueba sincronización entre las bases.
- **Expiración:** TEXT para caducidades de licencia/challenge. El formato efectivo
  no se infiere solo del tipo; el Worker v2 interpreta fechas con Date/ISO y
  emite expiraciones ISO. license_attempts.created_at es INTEGER y el código
  escribe milisegundos. Los payloads de lease usan segundos, fuera de D1.
- **Revocación:** indicadores de esquema no bastan para probar enforcement;
  las comprobaciones reales de v2 se describen en el contrato de API.
- **Asignación:** user_patches une usuario/patch en v2; user_patch_access une
  hwid/patch en patch. No existe targetID explícito en las tablas inspeccionadas.
- **Material sensible:** hay columnas denominadas content_key/password y
  password_hash. Solo se obtuvieron sus nombres/tipos, nunca valores. No se
  afirma cómo están codificados o protegidos a partir del nombre de la columna.
- **Journal remoto:** patch_journal es una tabla del servidor; no reemplaza el
  journal transaccional local de 3105 ni demuestra que sus backups sean equivalentes.

## Relaciones declaradas e inferidas

PRAGMA confirmó dos claves foráneas en `vini-v2-db.user_patches`:
patch_id → patches.id y user_id → users.id, ambas ON DELETE/UPDATE NO ACTION.
No devolvió claves foráneas para users, device_activations y device_challenges.
En patch no devolvió claves para users, licenses ni user_patch_access.
No se comprobó la integridad de las filas ni se ejecutó foreign_key_check.

Relaciones por campos/nombres que NO se certifican como FK declaradas:
users.id → device_activations.user_id → device_challenges.activation_id;
users.hwid → licenses.hwid y user_patch_access.hwid en la otra base.
No se probaron relaciones entre bases ni se proponen migraciones en esta fase.

## Inventario completo de columnas de aplicación

Se excluyen sqlite_* y _cf_* internos. PK expresa posición en la clave primaria;
NOT NULL reproduce el flag PRAGMA, no todos los efectos implícitos de una PK.
No se consultaron valores por defecto ni se reconstruyó SQL CREATE para ejecutar.

## vini-v2-db — 19 tablas de aplicación

### activity_log

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | INTEGER | 1 | 0 |
| action | TEXT | 0 | 1 |
| details | TEXT | 0 | 0 |
| created_at | TEXT | 0 | 1 |

### blocked_devices

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| device_id | TEXT | 1 | 0 |
| reason | TEXT | 0 | 0 |
| created_at | TEXT | 0 | 1 |

### config

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| key | TEXT | 1 | 0 |
| value | TEXT | 0 | 1 |
| updated_at | TEXT | 0 | 1 |

### daily_status

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | TEXT | 1 | 0 |
| user_id | TEXT | 0 | 1 |
| patch_id | TEXT | 0 | 1 |
| status | TEXT | 0 | 1 |
| report_date | TEXT | 0 | 1 |
| created_at | TEXT | 0 | 1 |

### device_activations

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | TEXT | 1 | 0 |
| license_key | TEXT | 0 | 1 |
| user_id | TEXT | 0 | 1 |
| public_key | TEXT | 0 | 1 |
| kid | TEXT | 0 | 1 |
| status | TEXT | 0 | 0 |
| created_at | TEXT | 0 | 1 |
| last_seen_at | TEXT | 0 | 0 |
| last_lease_at | TEXT | 0 | 0 |

### device_challenges

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | TEXT | 1 | 0 |
| activation_id | TEXT | 0 | 1 |
| nonce | TEXT | 0 | 1 |
| created_at | TEXT | 0 | 1 |
| expires_at | TEXT | 0 | 1 |
| used | INTEGER | 0 | 0 |

### device_seen

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| device_id | TEXT | 1 | 0 |
| first_seen | TEXT | 0 | 1 |
| last_seen | TEXT | 0 | 1 |

### downloads

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | TEXT | 1 | 0 |
| user_id | TEXT | 0 | 1 |
| patch_id | TEXT | 0 | 1 |
| created_at | TEXT | 0 | 1 |

### license_attempts

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | INTEGER | 1 | 0 |
| scope | TEXT | 0 | 1 |
| subject | TEXT | 0 | 1 |
| created_at | INTEGER | 0 | 1 |

### messages

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | TEXT | 1 | 0 |
| title | TEXT | 0 | 1 |
| content | TEXT | 0 | 1 |
| type | TEXT | 0 | 0 |
| target_hwid | TEXT | 0 | 0 |
| active | INTEGER | 0 | 0 |
| created_at | TEXT | 0 | 1 |
| updated_at | TEXT | 0 | 1 |

### patches

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | TEXT | 1 | 0 |
| name | TEXT | 0 | 1 |
| description | TEXT | 0 | 0 |
| version | TEXT | 0 | 0 |
| type | TEXT | 0 | 0 |
| file_key | TEXT | 0 | 0 |
| active | INTEGER | 0 | 0 |
| created_at | TEXT | 0 | 1 |
| updated_at | TEXT | 0 | 1 |
| content_key | TEXT | 0 | 0 |
| password | TEXT | 0 | 0 |

### permanence_rewards

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | TEXT | 1 | 0 |
| user_id | TEXT | 0 | 1 |
| milestone_months | INTEGER | 0 | 1 |
| reward_granted | INTEGER | 0 | 0 |
| created_at | TEXT | 0 | 1 |

### rate_limits

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| key | TEXT | 1 | 0 |
| count | INTEGER | 0 | 1 |
| window_start | INTEGER | 0 | 1 |

### referrals

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | TEXT | 1 | 0 |
| referrer_id | TEXT | 0 | 1 |
| referred_id | TEXT | 0 | 1 |
| confirmed | INTEGER | 0 | 0 |
| reward_granted | INTEGER | 0 | 0 |
| created_at | TEXT | 0 | 1 |
| confirmed_at | TEXT | 0 | 0 |

### rewards_points

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | INTEGER | 1 | 0 |
| user_id | TEXT | 0 | 1 |
| points | INTEGER | 0 | 1 |
| created_at | TEXT | 0 | 1 |

### rewards_transactions

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | TEXT | 1 | 0 |
| user_id | TEXT | 0 | 1 |
| type | TEXT | 0 | 1 |
| points | INTEGER | 0 | 0 |
| days_added | INTEGER | 0 | 0 |
| description | TEXT | 0 | 0 |
| created_at | TEXT | 0 | 1 |

### trust_reports

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | TEXT | 1 | 0 |
| user_id | TEXT | 0 | 1 |
| patch_id | TEXT | 0 | 1 |
| status | TEXT | 0 | 1 |
| created_at | TEXT | 0 | 1 |

### user_patches

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| user_id | TEXT | 1 | 1 |
| patch_id | TEXT | 2 | 1 |
| created_at | TEXT | 0 | 1 |

### users

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | TEXT | 1 | 0 |
| username | TEXT | 0 | 1 |
| hwid | TEXT | 0 | 0 |
| license_key | TEXT | 0 | 0 |
| is_premium | INTEGER | 0 | 0 |
| is_active | INTEGER | 0 | 0 |
| is_paused | INTEGER | 0 | 0 |
| is_blocked | INTEGER | 0 | 0 |
| permissions | TEXT | 0 | 0 |
| created_at | TEXT | 0 | 1 |
| updated_at | TEXT | 0 | 1 |
| license_expires_at | TEXT | 0 | 0 |
| platform | TEXT | 0 | 0 |
| points | INTEGER | 0 | 0 |
| referral_code | TEXT | 0 | 0 |
| referred_by | TEXT | 0 | 0 |
| paused_at | TEXT | 0 | 0 |

## vini-patch-db — 11 tablas de aplicación

### licenses

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| key | TEXT | 1 | 0 |
| hwid | TEXT | 0 | 0 |
| device_model | TEXT | 0 | 0 |
| ios_version | TEXT | 0 | 0 |
| expires_at | TEXT | 0 | 1 |
| created_at | TEXT | 0 | 1 |
| bound_at | TEXT | 0 | 0 |
| last_login | TEXT | 0 | 0 |
| revoked | INTEGER | 0 | 0 |
| paused | INTEGER | 0 | 0 |
| tier | TEXT | 0 | 0 |

### logs

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | INTEGER | 1 | 0 |
| level | TEXT | 0 | 1 |
| message | TEXT | 0 | 1 |
| source | TEXT | 0 | 0 |
| created_at | TEXT | 0 | 1 |

### message_acks

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| message_id | TEXT | 1 | 1 |
| hwid | TEXT | 2 | 1 |
| acked_at | TEXT | 0 | 1 |

### messages

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | TEXT | 1 | 0 |
| title | TEXT | 0 | 1 |
| content | TEXT | 0 | 1 |
| type | TEXT | 0 | 0 |
| target_hwid | TEXT | 0 | 0 |
| expires_at | TEXT | 0 | 0 |
| active | INTEGER | 0 | 0 |
| created_at | TEXT | 0 | 1 |

### patch_journal

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | INTEGER | 1 | 0 |
| hwid | TEXT | 0 | 1 |
| patch_id | TEXT | 0 | 1 |
| action | TEXT | 0 | 1 |
| target_file | TEXT | 0 | 0 |
| original_hash | TEXT | 0 | 0 |
| patched_hash | TEXT | 0 | 0 |
| backup_r2_key | TEXT | 0 | 0 |
| metadata | TEXT | 0 | 0 |
| created_at | TEXT | 0 | 1 |

### patches

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | TEXT | 1 | 0 |
| name | TEXT | 0 | 1 |
| bundle_id | TEXT | 0 | 1 |
| version | TEXT | 0 | 1 |
| description | TEXT | 0 | 0 |
| password_hash | TEXT | 0 | 0 |
| created_at | TEXT | 0 | 1 |
| updated_at | TEXT | 0 | 0 |
| downloads | INTEGER | 0 | 0 |
| password | TEXT | 0 | 0 |
| tier | TEXT | 0 | 0 |

### remote_config

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| key | TEXT | 1 | 0 |
| value | TEXT | 0 | 1 |
| updated_at | TEXT | 0 | 1 |
| updated_by | TEXT | 0 | 0 |

### telemetry

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | INTEGER | 1 | 0 |
| hwid | TEXT | 0 | 1 |
| event_type | TEXT | 0 | 1 |
| event_data | TEXT | 0 | 0 |
| created_at | TEXT | 0 | 1 |

### user_patch_access

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| hwid | TEXT | 1 | 1 |
| patch_id | TEXT | 2 | 1 |
| granted_at | TEXT | 0 | 1 |
| granted_by | TEXT | 0 | 0 |

### users

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| hwid | TEXT | 1 | 0 |
| license_key | TEXT | 0 | 0 |
| device_model | TEXT | 0 | 0 |
| ios_version | TEXT | 0 | 0 |
| patches | TEXT | 0 | 0 |
| active | INTEGER | 0 | 0 |
| created_at | TEXT | 0 | 1 |
| last_seen_at | TEXT | 0 | 0 |

### versions

| Columna | Tipo declarado | PK | NOT NULL |
|---|---|---:|---:|
| id | TEXT | 1 | 0 |
| version | TEXT | 0 | 1 |
| min_ios | TEXT | 0 | 1 |
| max_ios | TEXT | 0 | 1 |
| changelog | TEXT | 0 | 0 |
| download_url | TEXT | 0 | 0 |
| force_update | INTEGER | 0 | 0 |
| created_at | TEXT | 0 | 1 |

## Método y limitaciones

Consultas permitidas: SELECT de sqlite_schema, SELECT de pragma_table_info sin
valores por defecto, y PRAGMA foreign_key_list de tablas identificadas. La variante
JOIN pragma_foreign_key_list fue rechazada con SQLITE_AUTH; el PRAGMA directo
funcionó sin ampliar permisos. No se alteró foreign_keys ni query_only.

La evidencia demuestra estructura, no estado de usuarios/licencias ni uso efectivo
de vini-patch-db por una aplicación. No se leyeron config/remote_config ni sus
valores: podrían contener datos sensibles. No se probó un login, refresh o lease.
