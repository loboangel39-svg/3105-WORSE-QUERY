# VINI Fase 3I — Autorización y distribución

Estado: **PASS LOCAL AISLADO**. Fase 3F continúa `BLOCKED` por CI.

La autorización conserva token, licencia, HWID, `patches.active` y `user_patches`. Además exige `patch_targets.active = 1`, `enabled = 1`, `revoked = 0`, estado `authorized` e identidad completa. Se añadió la comprobación del HWID al validar cada token de aplicación.

El catálogo y la descarga comparten la misma selección de revisión autorizada. La descarga vuelve a consultar D1 inmediatamente antes de leer R2 y verifica tamaño/SHA-256; el cliente nunca elige una clave R2 arbitraria.

No se concede acceso global a usuarios PRO: siguen siendo obligatorios `user_patches` y las condiciones de licencia/HWID.
