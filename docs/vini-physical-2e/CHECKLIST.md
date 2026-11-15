# Checklist físico — todos los casos pendientes

Ningún caso está aprobado con evidencia del iPhone. Usar exclusivamente staging, cuentas ficticias y el fixture autorizado. No tocar interruptores ni ejecutar Apply/Restore. La versión iOS comunicada por el usuario aún debe comprobarse en Ajustes; compatibilidad documentada no es funcionamiento confirmado.

| ID | Prueba y acción | Resultado a comprobar |
|---|---|---|
| P01 | Firma/instalación | Identificador y App Group conservados; perfil/certificado válidos; instalación sin sustituciones |
| P02 | Inicio | Dashboard visible, sin cierre inesperado ni alteraciones visuales |
| P03 | Login BASIC-A de staging | Sesión válida, BASIC y ausencia de PREVIEW; ninguna clave real |
| P04 | Nombre de usuario | Coincide localmente con el panel staging; exportar solo identity_matches, no el nombre |
| P05 | Login PRO-A | Plan PRO real; cambiar de cuenta sin recuperar la anterior por error |
| P06 | Fecha/tiempo restante | Comparar duración con vencimiento/hora del panel; registrar solo tiempos. La fecha absoluta no se muestra actualmente en el dashboard: ese subcriterio queda not_observable, no aprobado |
| P07 | Cierre y reapertura | Recupera la sesión por servidor; no depende de una sesión simulada o datos PREVIEW |
| P08 | Renovación de sesión | Tras caducidad, revalidación única y token nuevo guardado; sin bucle. La UI no muestra tokens ni HTTP: no afirmar renovación solo por ver Activa |
| P09 | Pérdida de internet | Comprobar sesión: estado sin verificar/offline; no se inventa autorización |
| P10 | Recuperación | Restablecer red y comprobar sesión tras el intervalo; recupera estado vigente sin pulsaciones repetidas |
| P11 | Pausa individual de PRO-A | Panel confirma operación; cliente deja de mostrar autorización vigente al comprobar y deniega descarga |
| P12 | Reactivación individual | Solo última pausa reanuda saldo; recuperación con hora servidor y saldo propio |
| P13 | Pausa por distribuidor de DIST-A | Solo licencias ficticias de ese distribuidor; directos/otro distribuidor no cambian |
| P14 | Reactivación por distribuidor | Retira solo su pausa masiva; conserva global/individual |
| P15 | Pausa global | SUPER_ADMIN, preview/confirmación y ventana coordinada exclusivamente en staging |
| P16 | Reactivación global | Retira solo pausa global; no elimina individuales/de distribuidor, revocaciones ni bloqueos |
| P17 | Superposición y saldo | Individual + distribuidor/global; liberación parcial conserva saldo; última liberación restituye saldos distintos, sin fecha común |
| P18 | Reset HWID individual | Confirmación y auditoría del panel; sesiones/activaciones anteriores inválidas online; ninguna otra licencia afectada |
| P19 | Catálogo/descarga de prueba | BASIC sin fixture PRO; PRO asignado lo ve y verifica hash/codec; no asignado/revocado denegado. No importar a targets ni aplicar |

## Preparación administrativa, todavía sin ejecutar operaciones

Las dos cuentas de la entrega 2D son **clientes directos**, no un distribuidor. P13/P14 y la variante de P17 necesitan primero un distribuidor ficticio independiente y una licencia DIST-A. Prepararlos en el panel staging con permisos explícitos; no transferir licencias reales ni suponer pertenencia por el nombre. Registrar esos casos como blocked mientras falte el fixture. No se creó ni transfirió ninguna cuenta en 2E.

Para P15/P16, coordinar una ventana sin otras pruebas concurrentes. Comprobar el dominio staging, el número exacto de licencias y distribuidores del preview y la confirmación antes de ejecutar; la operación global afecta a todo ese staging, no solo a la cuenta del teléfono. Si aparecen datos que no sean ficticios, detenerse. No ejecutar estas operaciones en producción.

El cliente consulta estado al abrir/recuperar la app y mediante Comprobar sesión; no recibe notificaciones instantáneas de cambios del panel. Tras cada operación, esperar al menos quince segundos y comprobar. Después de un fallo de revalidación, esperar treinta segundos antes del siguiente intento.

No alterar el reloj del iPhone, TTLs o Worker para acelerar P08. El token APP tiene su expiración propia, distinta de licencia y lease. El ensayo automatizado de token caducado de 2D no se cuenta como prueba física. Puede necesitarse una observación prolongada o una credencial de ensayo controlada por el responsable; si no existe evidencia, queda pending/not_observable.

## Interpretación de HWID y pausas

Un reset no rota la clave de licencia. El cliente conserva esa clave y puede reautenticarse/revincularse: seguir mostrando Activa después de una revalidación no demuestra que el token anterior siguiera válido. P18 necesita correlación temporal con la auditoría y resultados saneados del servidor; no extraer tokens ni HWID completo. Un lease firmado offline previo no se invalida retroactivamente.

El API deniega el perfil mientras la licencia está pausada: la app no expone el banco administrativo de milisegundos. Comparar saldos en el panel con aliases; no inventar el saldo congelado desde una etiqueta sin verificar. El resultado denegado puede ser ambiguo entre inactividad, revocación y dispositivo no autorizado.

Tras cada caso anotar fecha/hora con zona, estado visible, resultado y tiempos. Mantener result=pending hasta realizarlo; usar not_observable si falta observabilidad, blocked si falta una precondición. Incluso pass es un resultado declarado por el usuario hasta revisar evidencia, no una aprobación automática.
