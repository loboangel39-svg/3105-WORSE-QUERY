# Procedencia y auditoría previa

Rama de partida: `experiment/vini-cloudflare-integration`, `b858469`.
Se leyeron los cuatro informes de Fase 1. La nueva rama conserva los commits
anteriores: `experiment/vini-admin-plans-distributors`.

Al iniciar Fase 2A se volvió a consultar el despliegue de `vini-v2-api`:
deployment `05f14b14-fdaa-44d9-9123-4643650f8dfe`, versión al 100 %
`f1e869fd-59d7-4367-a04a-d2186e25c647`. Coincide con la copia auditada.

| Copia verificable | SHA-256 |
|---|---|
| upstream/worker.snapshot.mjs | f58e27e36f41219d68f7ed3469fcb75c0d88d2fbf6b209ce4deb592920906122 |
| upstream/admin.snapshot.html | 0ab22a9f361e6a2ba0547778488574440af278d47e10ecf9e2cc6e8d66d516c7 |

El panel se obtuvo mediante GET `/admin` del Worker actual, cuyo handler solo
lee `admin-panel/index.html` en R2. No se invocó login ni ningún endpoint que
registre descargas, dispositivos, activaciones o licencias en producción.
Los archivos snapshot se guardan sin conversión de fin de línea y el build
rechaza cambios en cualquiera de sus hashes.

## Comportamiento anterior comprobado

- Panel de una sola identidad administrativa: POST `/api/admin/login` con
  credenciales del entorno, token HS256 tipo admin y autorización global.
- Usuarios/licencias creados por POST `/api/users`; licencia en `users.license_key`,
  premium booleano y vencimiento en el mismo registro. No había creador ni dueño
  administrativo por distribuidor. El antiguo formulario editaba esos campos.
- Panel con Dashboard, Usuarios, Patches, Accesos, Mensajes, Estadísticas,
  Actividad y Configuración. La ampliación conserva esas vistas para SUPER_ADMIN
  e incorpora las nuevas secciones; no sirve el panel productivo durante pruebas.
- Pausa anterior: `is_paused`/`paused_at`; al reanudar añadía días completos desde
  el inicio de pausa. La nueva política de saldo exacto fue solicitada expresamente
  por el usuario durante esta fase: 7 días/4 días deben conservarse por separado.
- APP usa el login de licencia y Bearer existentes; v1 usa activación, challenge
  y lease. Ambos protocolos se conservaron en el snapshot y se prueban realmente.

El build solo añade exportaciones nominales a una copia generada del snapshot
para reutilizar sus verificadores. No cambia sus implementaciones ni las claves
productivas. El panel generado cambia su URL API fija por `location.origin` para
que staging nunca envíe requests al backend productivo.

No se copió ninguna fila de D1 ni valores de secretos. `tests/baseline.sql` se
genera de la metadata de columnas ya auditada y contiene solo estructura; las
filas de ensayo se generan aparte. No contiene identificadores de bases reales.
