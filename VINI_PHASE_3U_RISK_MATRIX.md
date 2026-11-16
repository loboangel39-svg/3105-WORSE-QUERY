# VINI 3U — matriz de riesgos

| ID | Subsistema | Defecto/riesgo | Evidencia | Severidad | Reproducibilidad | Corrección/estado |
|---|---|---|---|---|---|---|
| R1 | CI/IPA | No hay IPA del HEAD actual; run `43897324178` quedó queued al auditar | GitHub run JSON | Alta | Confirmado en CI | Pendiente de runner macOS |
| R2 | Coordinador | Cache init usaba `try!`; una Application Support inaccesible podía cerrar la app | `VNIRemotePackageCoordinator.swift` init, HEAD anterior | Alta | Riesgo potencial | Corregido en working tree: `try?` y cache opcional |
| R3 | Catálogo | Legacy importado sin categoría no aparece en dashboard | `preparedPresentations` lines 177–187 | Media | Confirmado en código | Intencional; falta UI mínima de clasificación |
| R4 | Catálogo | `refresh` consulta catálogo dos veces | Store lines 73–76 + coordinator lines 39 | Media | Confirmado en código | Pendiente; no es crash |
| R5 | Estado | Si catálogo falla se conservan rows preparadas anteriores | Store lines 85–100 | Media | Confirmado en código | Pendiente decisión de UX; no autoriza Apply por sí solo |
| R6 | Identidad | Store usaba username para transacciones mientras categoría usa stableUserID | Store line 141 vs coordinator/profile | Media | Confirmado en código | Corregido en working tree |
| R7 | Sesión | `Task` de refresh puede ser cancelada por logout; requiere prueba de carrera | Client lines 206–235 | Media | Riesgo potencial | Cubierto conceptualmente; falta fixture físico |
| R8 | Dashboard | Preview contiene targets ficticios, aunque producción usa `profile != nil` y lista preparada | Dashboard lines 40–60; store lines 177–179 | Media | Confirmado en código | No usar preview en sesión autorizada; verificar en dispositivo |
| R9 | Clave | Clave inválida no crea target; diagnóstico puede quedar genérico | coordinator decode path; store lines 82–84 | Media | Reproducido en fixtures previas | Conservado seguro; mejorar diagnóstico sin secretos |
| R10 | Apply/Restore | Interrupciones reales y recovery journal no se probaron en iPhone | DevicePatchService/PatchTransaction | Crítica | Sin evidencia suficiente | SKIPPED; probar solo fixtures propios |
| R11 | Files | Proveedores `WQAccess`, `bad_query`, `worse_query` dependen de acceso físico y símbolos nativos | ContainerAccessCoordinator lines 27–57 | Alta | Sin evidencia física actual | No modificar; prueba física requerida |
| R12 | Persistencia | Category store escribe JSON atómico, pero no cifra metadata | `VINIPackageCategoryStore` | Baja | Confirmado en código | No contiene secretos; revisar privacidad posteriormente |
| R13 | Entitlements | IPA actual no disponible para verificar firma/entitlements | CI omitió build | Alta | Confirmado | SKIPPED |
| R14 | Paquetes | Legacy no usa cache remota y puede redescargar/reimportar | coordinator legacy path | Media | Confirmado en código | Pendiente integración de cache sin alterar autorización |
| R15 | Background | No existe coordinador explícito de descarga con scenePhase; refresh ocurre al foreground | App/AuthRoot | Media | Confirmado en código | Probar suspensión durante descarga |

No se observó evidencia de corrupción de backups o modificación de motores
protegidos en esta auditoría. R10/R11 son riesgos de operación física, no
crashes confirmados.
