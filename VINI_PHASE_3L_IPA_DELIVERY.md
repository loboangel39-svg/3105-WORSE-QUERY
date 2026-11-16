# VINI 3L-D — Entrega IPA

Se generó el artefacto unsigned después de que compilara la conexión, pero no
se presenta como funcionalmente verificado porque las operaciones dinámicas
Apply/Restore siguen SKIPPED en el harness.

Run: `43815767539`, commit `9e9eed7`,
https://github.com/loboangel39-svg/3105-WORSE-QUERY/actions/runs/43815767539.

Artefacto: `VINI-ApplyRestore-Unsigned`.
Tamaño: `5,012,928` bytes.
SHA-256: `bcc81baa1a46d5c21acb82dcef5aa54de903f07d571fbfc4d4d66df70bf9d8d4`.
Arquitectura: `arm64`; bundle ID verificado por el workflow.

Limitación: el IPA no debe instalarse como entrega Apply/Restore validada hasta
ejecutar las pruebas dinámicas controladas y confirmar receipt, asociación,
rollback y Restore.
