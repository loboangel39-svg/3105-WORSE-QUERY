# VINI 3L-D — Entrega IPA

**No entregado.** El criterio solicitado exige superar primero las pruebas
críticas de Apply/Restore. Como esas pruebas están bloqueadas por la ausencia
de binding funcional y de asociación persistida exacta, no se publicó un
artefacto `VINI-ApplyRestore-Unsigned` ni se presentó la compilación previa
como funcional.

Build de referencia únicamente: run `43813500959`, commit `017ea41`,
https://github.com/loboangel39-svg/3105-WORSE-QUERY/actions/runs/43813500959.

Para desbloquear la fase se necesita una API/adaptador autorizado que persista
la relación exacta del target remoto y exponga operaciones coordinadas de
Apply/Restore sin alterar los formatos protegidos. Después deberán ejecutarse
las pruebas funcionales y recién entonces empaquetarse el IPA.
