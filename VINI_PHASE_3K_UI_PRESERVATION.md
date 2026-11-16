# VINI 3K — Preservación visual

`VINIDashboardView.swift` y `VINITargetCard` no fueron modificados. No se cambiaron colores, tipografías, iconos, espaciados, sombras, pestañas, animaciones, interruptores, login, navegación ni botón EXIT.

El diff funcional se limita a la fuente de `VINIDashboardPresentation` y a la inyección de `VINIProductionStore`. El binding existente continúa leyendo `target.patchState == .active`; como la preparación no establece `active`, ningún paquete importado enciende un interruptor.

No se afirma validación visual en dispositivo hasta disponer de ejecución física; la preservación se verifica por diff de archivos protegidos.
