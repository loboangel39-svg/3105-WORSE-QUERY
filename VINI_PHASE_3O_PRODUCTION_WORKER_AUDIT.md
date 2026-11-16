# VINI 3O — Auditoría del Worker principal

## Estado

**PREPARADO LOCALMENTE / NO DESPLEGADO.** No se modificaron Cloudflare, D1 ni
R2 productivos.

El GET público de
`https://vini-v2-api.loboangel39.workers.dev/api/app/patches` devuelve `401`
sin credenciales. Por tanto no se inspeccionaron filas, licencias, usuarios,
HWID, tokens ni claves reales. La respuesta no permite comparar filas
autorizadas del despliegue sin una sesión válida.

## Diferencia encontrada

El snapshot local del Worker (`backend/vini-admin/upstream/worker.snapshot.mjs`)
implementa `/api/app/patches` con:

```sql
SELECT p.id, p.name, p.description, p.version, p.type, p.file_key,
       p.password, p.content_key, p.created_at, p.updated_at
FROM patches p
INNER JOIN user_patches up ON up.patch_id = p.id
WHERE p.active = 1 AND up.user_id = ?
```

Su JSON conserva `patches`, pero no incluye `targetID`, `packageID`, `projectID`,
SHA-256, tamaño, revisión ni categoría enriquecida. El cliente VINI descarta
esas entradas sin target, de forma segura; resultado: cero targets.

La descarga sí entrega `X-Content-Key` cuando `content_key` existe y comprueba
usuario/asignación/`active` antes de leer R2. La contraseña original también
aparece en el snapshot como `X-Patch-Password`; VINI no la consume ni debe
exponerla.

## D1

La evidencia previa de lectura para `vini-v2-db` confirma `patches` y
`user_patches`, pero no `patch_targets` ni `patch_policies`. La migración local
preparada `backend/vini-admin/migrations/0004_patch_targets.sql` crea
`patch_targets`, índices y unicidad de revisión activa, pero no se ha ejecutado
en producción.

Las asignaciones actuales se conservan mediante `user_patches`; no se propone
asignar automáticamente paquetes a BASIC/PRO.

## Contrato objetivo compatible

Mantener `{ patches: [...] }` y añadir `target` solo cuando exista una fila
completa y autorizada de `patch_targets`. La descarga y el detalle mantienen sus
rutas y autorización actuales; el detalle/catálogo pueden incluir el mismo
objeto target enriquecido sin retirar campos antiguos.

## Pruebas

`npm test` local pasó **54 grupos** con Miniflare, D1/R2 aislados y datos
sintéticos. Incluye login APP, asignación individual, BASIC/PRO, revocación,
descarga denegada y compatibilidad de rutas. No prueba producción ni modifica
datos reales.
