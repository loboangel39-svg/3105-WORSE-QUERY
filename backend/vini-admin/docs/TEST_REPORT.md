# Informe de pruebas — Fase 2A experimental

Fecha: 2026-11-15 (America/Lima). Resultado final: **36 grupos aprobados**.
Los 23 casos solicitados están cubiertos por los grupos numerados; se añadieron
13 grupos de concurrencia, recuperación, política de pausas y UI.

Entorno: Node, esbuild 0.28.1, Wrangler 4.129.0, Miniflare 5.20260903.0-alpha,
runtime workerd local con binding D1/SQLite, datos y claves sintéticos generados
para cada ejecución. Edge de escritorio headless con perfil independiente para
el test del panel. No son pruebas de iPhone ni de Cloudflare remoto.

## Recuperación de la sesión interrumpida

Se conservó la rama experiment/vini-admin-plans-distributors basada en b858469
con todos los archivos sin commit. Se recuperó evidencia anterior de 35 grupos
aprobados. Había cambios posteriores en autorización, auditoría y presentación que
invalidaban esa evidencia para el estado final; por ello se ejecutó una suite
final sobre esos cambios y se añadió la comprobación numérica de pausas superpuestas.
No se reinició la implementación ni se restablecieron archivos.

## Resultado de cada grupo

- APROBADO — 15. Incremental migration, unknown creators, legacy plans and restart ledger
- APROBADO — 1. BASIC user and license provenance
- APROBADO — 2. PRO user preserves isPremium projection
- APROBADO — 3. Direct clients exclude unknown historical origin
- APROBADO — 4. Distributor clients and scoped account creation
- APROBADO — 5. Distributor cannot inspect or mutate another owner; no UI-only security
- APROBADO — 6. Scoped ADMIN and denied actions
- APROBADO — 7. Individual pause and reactivation
- APROBADO — 8. Distributor pause snapshots exact owned IDs
- APROBADO — 9. Global pause only SUPER_ADMIN and expiration unchanged
- APROBADO — 10. Reversing bulk pause preserves earlier and overlapping individual pauses
- APROBADO — 11. Expired license status and old login rejection
- APROBADO — 12. Archive only expired users, logical deletion retains row
- APROBADO — 13. Renewal after expiration and renewal-vs-archive race
- APROBADO — 14. Append-only history, immutable creators, audited transfers and no raw license keys
- APROBADO — 16. Both directions of isPremium compatibility without dropping old field
- APROBADO — 17. Existing APP login and strict administrative separation
- APROBADO — 18. Existing patch catalog requires individual assignment and active package
- APROBADO — 19. Existing session verifier checks current revocation state
- APROBADO — 20. New profile has server time, nominal plan and distinct license expiry
- APROBADO — 21. Admin filters and distinct counts
- APROBADO — 22. BASIC/PRO authorization is intersection, not blanket PRO access
- APROBADO — 23. Bulk idempotency, concurrent execution and durable resume
- APROBADO — Extra: no confirmation, stale ownership, insufficient retention and renewed purge protection
- APROBADO — Extra: built panel retains original sections and has no production transport URL
- APROBADO — Extra: approved remaining-time policy preserves 7 days and 4 days per user, including historical pause
- APROBADO — Extra: archive renewal is explicit and purge retains only owned minimal license metadata
- APROBADO — Extra: original v1 activation, one-time challenge and real signed lease remain compatible
- APROBADO — Extra: named SUPER_ADMIN keeps original views while APP tokens cannot enter them
- APROBADO — Extra: migration batch rollback and manifest confirmation
- APROBADO — Extra: operation resumes after actual workerd shutdown without repeating committed batches
- APROBADO — Extra: real desktop browser panel login, roles, navigation, preview and confirmed action
- APROBADO — Extra: canceled batches stay canceled and can be reverted; reconfirm does not mutate users
- APROBADO — Extra: overlapping bulk and individual pauses preserve the same numeric balance until the final release
- APROBADO — Extra: BASIC capability, disabled/revoked package, and denied download has no side effects
- APROBADO — Extra: maintenance keeps APP authentication but blocks administrative writes

## Evidencias materiales

- Las migraciones se aplican por endpoint de bootstrap autenticado, con manifiesto,
  checksum y ledger; la repetición no vuelve a ejecutar DDL. Un batch con DDL y
  una sentencia inválida se revierte realmente, sin dejar la tabla de ensayo.
- Se verifica la firma Ed25519 de un lease del código original usando una clave
  sintética; se prueba P-256, challenge y rechazo de replay sin mocks del protocolo.
- Se apaga y reinicia workerd tras confirmar 10 de 21 miembros. D1 persiste, el
  resto se reanuda y existen exactamente 21 eventos, sin duplicación de los primeros.
- Edge prueba login, navegación, distinción de roles, ocultación CSS real de
  vistas globales y ejecución de una acción tras el diálogo administrativo.
- Dos saldos distintos (7 y 4 días) sobreviven a la pausa y se recalculan con hora
  del servidor. Una secuencia con dos pausas masivas y una individual mantiene
  exactamente el saldo y el vencimiento durante liberaciones parciales; solo
  la última libera al usuario y restablece el saldo. Se prueba también pausa histórica.
- Las licencias pausadas con saldo congelado no se archivan por una fecha antigua.
- Se prueba la carrera renovación/archivado y renovación/purga; las revisiones
  cambiadas producen conflict, sin borrar ni archivar la licencia renovada.

## Fallos detectados y corregidos durante el desarrollo

1. API de Miniflare 5 requiere conversor de configuración V4 y persistencia por
   resourcePersistencePath. Se adaptó el harness; se usaron rutas temporales cortas
   porque las rutas largas de Windows causaban error interno de almacenamiento.
2. Splitter SQL de Wrangler dividía cuerpos de triggers: incomplete input. La
   aplicación probada usa statements completos, DB.batch atómico y ledger. El
   camino CLI fallido NO se presenta como validado para producción.
3. meta.changes contabiliza triggers y no representa una única fila de negocio.
   Las actualizaciones optimistas usan RETURNING para verificar su resultado.
4. La prueba inicial del panel esperaba datos antes de terminar el fetch. Se
   sincronizó con el contenido real, no con una espera fija.
5. hidden=true no ocultaba realmente elementos con CSS display:flex. Se corrigió
   el display y la prueba verifica getComputedStyle, además de la autorización SQL.

## Compilación y artefactos

La suite final ejecuta el build real de worker.mjs y admin.html, verificando los
hashes de snapshots. No se recompiló iOS, no se generó IPA ni se modificó su código.
Los artefactos de esta fase son Worker/panel/migraciones/documentación y ZIP de fuente.

- `dist/worker.mjs`: 255476 bytes; SHA-256 `7b02d37a2449cbfd95a09eea453a447fbb0cd23fad1a75f2ac68714dd413f866`.
- `dist/admin.html`: 79199 bytes; SHA-256 `d675e1b6ec5216897d2cb4f926abebb40195b31be0c689f3435e93c908048b18`.
- `upstream/worker.snapshot.mjs`: 110479 bytes; SHA-256 `f58e27e36f41219d68f7ed3469fcb75c0d88d2fbf6b209ce4deb592920906122`.
- `upstream/admin.snapshot.html`: 59163 bytes; SHA-256 `0ab22a9f361e6a2ba0547778488574440af278d47e10ecf9e2cc6e8d66d516c7`.

## Pendiente antes de autorizar producción

No se ha creado staging Cloudflare remoto, desplegado Worker, escrito R2 ni
migrado D1 productivo. Se requiere revisión del paquete y staging remoto separado,
validación de volumen/límites/región y observación de clientes legacy autorizados.
No se probaron datos ni credenciales reales. La anonimización no certifica borrado
exhaustivo en logs heredados. El protocolo offline conserva límites señalados en
la auditoría; no se usa para conceder nuevos derechos de paquetes sin comprobación online.

La versión productiva comprobada sigue siendo f1e869fd-59d7-4367-a04a-d2186e25c647.
main remota sigue en afa5a48c96b9b8d72729f10726a274101e480592.
No se realizó ni se declara validación funcional en iPhone; esta fase es de backend.
