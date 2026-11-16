# VINI 3L-D — Pruebas funcionales

## Resultado

CI de compilación y regresiones: **PASS**, run `43815767539`, commit
`9e9eed7`: https://github.com/loboangel39-svg/3105-WORSE-QUERY/actions/runs/43815767539.
El harness confirma que el adaptador compila y que las fixtures existentes
siguen pasando. El log existente marca Apply/Restore dinámico como **SKIPPED**;
no se presenta ese resultado como una prueba funcional.

| Prueba | Resultado |
|---|---|
| Apply real sobre fixture dinámico | SKIPPED: falta ejecución controlada del nuevo callback |
| Restore real sobre fixture dinámico | SKIPPED: falta ejecución controlada del nuevo callback |
| Estado ON tras confirmación | BLOCKED; no se simuló |
| Asociación exacta target/transacción | BLOCKED por falta de mapping persistido |
| Regresiones nativas 3J/3K/3L | PASS en run `43813500959` |
| Build unsigned `iphoneos arm64` | PASS en run `43813500959` |
| Apply/Restore en terceros | SKIPPED |
| IPA unsigned compilado | PASS; no equivale a IPA funcionalmente verificado |

El PASS de CI solo acredita compilación y regresiones existentes; no acredita
operaciones Apply/Restore. No se fabricaron receipts, manifests ni resultados.
