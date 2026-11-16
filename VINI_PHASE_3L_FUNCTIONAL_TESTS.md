# VINI 3L-D — Pruebas funcionales

## Resultado

| Prueba | Resultado |
|---|---|
| Apply real sobre fixture | BLOCKED: no existe binding funcional autorizado |
| Restore real sobre fixture | BLOCKED: misma limitación |
| Estado ON tras confirmación | BLOCKED; no se simuló |
| Asociación exacta target/transacción | BLOCKED por falta de mapping persistido |
| Regresiones nativas 3J/3K/3L | PASS en run `43813500959` |
| Build unsigned `iphoneos arm64` | PASS en run `43813500959` |
| Apply/Restore en terceros | SKIPPED |
| IPA funcional | NOT GENERATED |

El PASS de CI solo acredita compilación y regresiones existentes; no acredita
operaciones Apply/Restore. No se fabricaron receipts, manifests ni resultados.
