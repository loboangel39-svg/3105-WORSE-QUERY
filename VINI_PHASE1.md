# VINI — Fase 1 visual

Base conservada: `18d3694`. Rama: `experiment/3105-visual-redesign`.

La pantalla inicial es `VINIDashboardView`. Reutiliza la paleta, tarjetas y tipografías del rediseño existente y presenta VINI, versión real de la app, licencia de preview, categorías Combat/Visuals/Offsets, tarjetas con switches y datos del sistema.

## Contratos de presentación

- `VINIDashboardPresentation.preview`: datos ilustrativos explícitos, 10 IDs con prefijo `preview.`, sin asociaciones a paquetes.
- `VINITargetPresentation`: targetID, packageID opcional, categoryID, disponibilidad y estado del patch. En preview packageID es nil y el estado real del patch permanece unknown.
- `VINILicensePresentation`: usuario/plan de preview y duración verificada opcional. No hay autenticación, servidor ni temporizador. La pantalla muestra Sin verificar cuando no existe una duración verificada.
- `VINITargetCard`: binding a una selección local en @State. Cambiar un switch no aplica ni restaura un patch, no escribe archivos y no se persiste.
- `VINISystemInfoCard`: modelo, versión/build de iOS y arquitectura reportados por el sistema y la compilación; el estado general es Vista previa local.

Los dos switches inicialmente seleccionados son datos de demostración. No representan patches aplicados. Los nombres y descripciones ilustran las tarjetas de la referencia, no capacidades conectadas.

## Código funcional conservado

Instalados, Archivos, Buscar, editores y gestión de paquetes permanecen en el proyecto y en el target compilado. Su navegación anterior no se presenta en este dashboard de Fase 1. Una interfaz secundaria queda fuera de esta fase.

Se conserva la inicialización preexistente de la app y sus servicios. Los motores de acceso, identidad, caché, Auto Refresh y operaciones no se modifican. La nueva vista no consume estos motores.

Se conservan la preferencia de idioma, español predeterminado, identidad, App Group y entitlements. El nombre de instalación y el icono originales no se cambian; VINI es el encabezado del dashboard.

## Validación permitida

El workflow activo sólo compila arm64 para iPhone físico y realiza análisis estático, comprobaciones de recursos/licencias/preservación, sintaxis y enlace de dependencias con el SDK iphoneos. No ejecuta binarios de iOS ni pruebas funcionales.

Los archivos de pruebas y utilidades históricas se conservan como código previo; no se ejecutan en el workflow de esta fase. Los resultados históricos no son evidencia de validación del dashboard VINI.

La comprobación funcional y visual corresponde exclusivamente al iPhone físico del usuario. No se afirma compatibilidad o fidelidad comprobada en dispositivo antes de recibir sus capturas y registros.

## Revisión física pendiente

1. Firmar la IPA conservando el App Group existente e instalarla.
2. Confirmar inicio en VINI, badge PREVIEW y licencia Sin verificar.
3. Revisar colores, jerarquía, safe areas y distribución vertical respecto al HTML de referencia.
4. Cambiar entre Combat, Visuals y Offsets.
5. Cambiar switches de demostración y comprobar su apariencia y selección local al cambiar de categoría.
6. Confirmar ausencia de buscador, navegación principal antigua, onboarding y avisos internos de escaneo/reintento.
7. Revisar texto grande, VoiceOver y áreas táctiles.
8. Enviar capturas y registros con los problemas observados.

No se comienza Fase 2 ni Fase 3 al terminar esta entrega.
