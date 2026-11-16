# VINI Fase 3G — Contrato de catálogo

El contrato mantiene compatibilidad con la respuesta antigua `{ "patches": [...] }`. Las nuevas propiedades son aditivas.

```json
{
  "patches": [{
    "id": "patch-row-id",
    "name": "ESP Box 2D",
    "version": "1.0.0",
    "type": "3105",
    "status": "available",
    "target": {
      "targetID": "vini.esp_box",
      "remotePatchID": "patch-row-id",
      "packageID": "verified-package-id",
      "projectID": "verified-project-id",
      "revision": 1,
      "category": "visuals",
      "requiredPlan": "basic",
      "sha256": "64-hex-chars",
      "fileSize": 1234
    }
  }]
}
```

El servidor debe unir `patches` con `user_patches`, `patch_targets`, `active = 1` y `authorization_status = 'authorized'`. Las categorías son `combat`, `visuals` y `offsets`; `packageID` y `projectID` deben ser UUID válidos para `VINIRemoteContract.swift`, y `sha256` debe ser hex minúsculo. Una fila revocada, sin asignación o sin coincidencia de licencia no se devuelve ni se descarga. La descarga existente sigue usando `/api/app/patches/:id/download`; antes de importar, el cliente verifica bytes, tamaño y SHA-256 mediante los servicios originales.

No se altera todavía `src/index.js`: esta entrega define el contrato y la migración para revisión. La ampliación posterior debe conservar las claves antiguas (`id`, `name`, `version`, `type`, `status`).
