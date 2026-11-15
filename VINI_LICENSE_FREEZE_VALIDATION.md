# Congelación de licencia — validación 2C

Se mantiene la política individual aprobada, sin cambios de código en 2C.

1. La primera pausa guarda saldo de milisegundos del servidor.
2. Claims individuales, de distribuidor, directos y globales se superponen sin recalcular el saldo.
3. Reactivar un ámbito retira únicamente los claims de ese origen congelados en su preview. No elimina claims posteriores o de otro origen.
4. Mientras quede cualquier claim, el banco permanece congelado.
5. La última liberación fija vencimiento = hora servidor + saldo propio. Licencias permanentes mantienen NULL.
6. Renovar una licencia pausada actualiza su banco individual. Un banco desconocido exige resolución explícita; no se inventan días.

## Evidencia

Se reutilizan los casos 2B de pausa/reactivación individual, distribuidor y global, superposiciones, repetición, saldos siete/cuatro días, renovación pausada y protección contra archivado por fecha. El test local anterior cerró realmente workerd, abrió de nuevo la misma persistencia y completó lotes sin repetir miembros; se conserva esa evidencia.

En 2C se crearon nuevas licencias sintéticas con hora servidor reciente:

| Licencia de prueba | Días iniciales | Banco tras primera pausa |
|---|---|---|
| 7ab8fdd3-77b8-40d3-9554-8842e334ab3b | 7 | 604796833 ms |
| 3c4a8d45-d85e-4fd2-93ae-13d5d3ffe83e | 4 | 345596802 ms |

Los pocos segundos entre creación y pausa explican la diferencia respecto a días exactos. Los bancos se compararon por igualdad exacta antes de revertir staging, tras activar la versión 5a80a0ae-d561-4c1c-a91a-00d0ccc9cfc2 y después de volver a 410e07e5-80b2-4b90-81e0-432c83410da4. No hubo pérdida de saldo ni clasificación como expired mientras estaban pausadas.

La última reactivación de ambas se verificó contra HTTP Date del servidor con tolerancia de 15 segundos por tránsito; vencimientos diferentes, acordes con cada banco. Repetir la misma operación completada mantuvo idéntico vencimiento. Los JSON probe-2c-before-rollback, rolled-back y restored guardan esos resultados.

La reversión/versionado prueba persistencia entre versiones e instancias remotas; Cloudflare no permite afirmar que todas las instancias globales se reiniciaron. Se distingue de la terminación/reapertura local de workerd ya probada. No se sustituyó una prueba por un mock.

El archivado por fecha protege saldos congelados aunque la fecha canónica aparente ser antigua; la baja lógica individual explícita es distinta y preserva saldo/historial. Ninguna reactivación elimina bloqueo, revocación o baja lógica. El catálogo exige autorización vigente, no un saldo mostrado en la UI.

Pendiente físico: presentación y avance del contador, cambios de conectividad, relanzamiento y estado recuperado del cliente. No se consumieron licencias reales.
