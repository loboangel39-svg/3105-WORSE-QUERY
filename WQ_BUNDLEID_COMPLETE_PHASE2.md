# WQFiles Bundle ID — Fase 2

Rama: `experiment/wqfiles-bundleid-complete`  
Base: `experiment/wqfiles-launchservices` (`d394991`)

## Componentes revisados

| Referencia WQFiles | Función | Tratamiento en 3105 |
| --- | --- | --- |
| `WQLaunchServices.m/.h` | CSStore2, layouts, caché, nombres y rutas | Reutilizado/adaptado en `WQLaunchServicesPhase1` |
| `WQAccess.m/.h` | App Group, sandbox extensions, enumeración por inodos y lectura privilegiada | No integrado; fuera del alcance permitido |
| `WQHealth.m/.h` | Orquestación de checks de acceso, fuentes y nombres | Reimplementado como diagnóstico seguro |
| `WQCache.m/.h` | Limpieza y operaciones de caché | No integrado |
| `WQApps.m/.h` | UI, backups, restauración e iconos | No integrado |

## Dependencias seleccionadas

La identificación usa `WQLaunchServicesPhase1`, el puente MCM existente,
`ContainerStore`, `WQFilesIdentityResolver` y el nuevo
`WQBundleIdentityCoordinator`. No se incorporaron WQAccess, tokens, extensiones
de sandbox, certificados, perfiles ni técnicas nuevas de acceso.

## Descubrimiento y estados

Se inspeccionan únicamente la ruta persistida `WQLaunchServicesStore`, el cache
del contenedor `com.apple.lsd` obtenido por el puente MCM existente y los caches
del sistema si el proceso puede listarlos. Se selecciona el candidato regular
más reciente, se valida `bdsl` y se comparan sus metadatos antes y después de la
lectura.

Los estados distinguen `not_found`, `unavailable`, `located_unreadable`,
`incompatible` y `valid`. Una ruta recordada no prueba que el archivo exista ni
que sea legible.

## Identidad y Files

Se aceptan únicamente Bundle IDs válidos, rutas UUID de contenedores de
aplicaciones y asociaciones no ambiguas. Extensiones, grupos y daemons no se
convierten en aplicaciones. Un conflicto conserva la identidad previamente
verificada y solo se registra.

Las identidades adicionales se incorporan a Files solo si la fuente completa es
válida, la ruta pertenece a un contenedor de aplicación UUID descubierto por
3105 y no existe una identidad verificada previa. La identificación no concede
acceso ni modifica lectura, escritura, Patches, Apply/Restore o `.3105`.

## Diagnóstico y pruebas

`WQBundleIdentityCoordinator` registra App Group, contenedores, fuente, bytes,
layout, registros, Bundle IDs, UUID asociados, nombres, coincidencias,
conflictos y adicionales, sin registrar contenidos privados ni tokens.

Las pruebas portables de la Fase 1 cubren cabeceras, layouts iOS 26/27,
Unicode, corrupción, duplicados, ambigüedades, caché y ausencia de fuentes.
El proyecto no tenía un target XCTest independiente, por lo que se conservan
como fixture portable y no se incluyen en el binario.

Si el dispositivo continúa con `access_denied`, los contadores permanecen en
cero y el diagnóstico identifica la operación bloqueada sin atribuirlo al
parser.
