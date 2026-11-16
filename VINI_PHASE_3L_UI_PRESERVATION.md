# VINI 3L-B — Preservación UI

`VINITargetCard` y `VINIDashboardView` permanecen intactos. El único binding conectado es el existente: `patchState == .active`. El lector no cambia estilos, categorías, layout, toggle, login, navegación ni botón EXIT.

Un paquete preparado no enciende el interruptor. Si el lector no puede demostrar la asociación exacta y el journal/manifest aplicado, el estado permanece `unknown` y el toggle no se habilita por una suposición.

CI: commit `017ea41`, run `43813500959` (**PASS**). No se modificaron `VINIDashboardView.swift` ni `VINITargetCard`; la evidencia de preservación es estática/diff, no una validación visual en dispositivo.
