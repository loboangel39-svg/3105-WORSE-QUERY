# VINI — planes y distribuidores, experimental

Estado actual: [Fase 2C — aceptación y pendientes de producción](../../VINI_STAGING_ACCEPTANCE.md).
El binario 2B se conserva sin reconstruir; staging añade únicamente R2 de prueba.
[Fase 2B — controles completos](docs/PHASE_2B.md) se conserva como evidencia histórica.
El informe de Fase 2A se conserva como evidencia histórica del commit cb98ba7.

Ampliación del Worker `vini-v2-api` auditado en `b858469`. No es un backend
alternativo ni una migración a `vini-patch-db`. El Worker y el panel originales
se conservan completos en `upstream/`, con hashes verificados durante el build.
La ampliación importa sus verificadores de sesión; no reimplementa los exploits,
la autenticación APP, la criptografía de leases ni Apply/Restore de iOS.

## Contenido

- `src/worker.mjs`: router experimental y compatibilidad con endpoints existentes.
- `src/auth.mjs`: roles nominales y comprobación de ámbitos en consultas/mutaciones.
- `src/domain.mjs`: planes, propiedad, creador, licencias y perfil APP.
- `src/operations.mjs`: snapshot administrativo, confirmación, lotes y pausas.
- `src/migrations.mjs` + `migrations/`: migraciones incrementales transaccionales.
- `panel/admin-extension.js`: extensión del panel R2 existente, mismo origen.
- `scripts/build.mjs`: genera `dist/worker.mjs` y `dist/admin.html`.
- `tests/`: runtime local real de Workers/D1, criptografía y Edge/Chrome de escritorio.

## Reproducir sin Cloudflare de producción

Requiere Node compatible con Wrangler 4.129.0 y Edge o Chrome de escritorio para
el último grupo de pruebas. Desde este directorio:

```powershell
npm ci
npm run build
npm test
```

No requiere login Cloudflare, API token, datos reales ni cuenta de producción.
Las credenciales y claves de ensayo se generan aleatoriamente en memoria.
Las bases persistentes de prueba se crean en un directorio temporal exclusivo;
los tests no leen credenciales de Wrangler ni ejecutan comandos remotos. La red
saliente del Worker de ensayo está bloqueada. El navegador usa un perfil nuevo.
No se crean dispositivos virtuales ni se ejecuta código iOS.

En esta máquina se reutilizaron las dependencias oficiales ya instaladas con
Wrangler, con versiones coincidentes con `package.json`, mediante la variable
local `VINI_WRANGLER_PACKAGE`. No es una credencial ni se necesita con `npm ci`.

## Activación y protección

`ADMIN_PLANS_ENABLED` no está habilitado por defecto. No basta subir este bundle
para activar las nuevas vistas/derechos. Las migraciones requieren otro flag
explícito, autenticación del principal existente y confirmación del manifiesto.
No hay deploy automático, cron ni comando que aplique migraciones al importar.

Después de migrar no se debe apagar el flag como si el esquema siguiera siendo
el antiguo: se bloquean escrituras administrativas y catálogo para evitar
bypasses. Para mantenimiento normal se conserva la ampliación activa y se usa
`ADMIN_READ_ONLY=1`, manteniendo los controles de permisos APP/catálogo.

La política de pausa confirmada por el usuario conserva **el saldo restante de
cada usuario**. Primera pausa: guarda saldo sin alterar el vencimiento; última
reactivación: vencimiento = hora servidor + saldo. Se aplica igual a individual
y masiva. Sustituye expresamente la antigua devolución de días completos.

## Documentación de entrega

- [Contrato API](docs/API_CONTRACT.md)
- [Compatibilidad y conversión](docs/COMPATIBILITY.md)
- [Matriz de permisos](docs/PERMISSIONS.md)
- [Archivado, retención y pausas](docs/RETENTION_AND_PAUSES.md)
- [Pruebas](docs/TEST_REPORT.md)
- [Despliegue posterior, requiere autorización](docs/DEPLOYMENT.md)
- [Reversión/recuperación](docs/ROLLBACK.md)
- [Procedencia del Worker y panel](docs/UPSTREAM_PROVENANCE.md)

Fase 2A se validó localmente. Fase 2B crea exclusivamente un Worker/D1 remotos de
staging separados, con datos ficticios; nunca se valida mediante clientes reales
ni se despliega automáticamente a producción. Véase su informe específico.
