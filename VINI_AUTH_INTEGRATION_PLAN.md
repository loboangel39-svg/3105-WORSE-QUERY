# VINI — plan de integración posterior (no ejecutado)

Este documento cierra la investigación. No autoriza ni inicia la Fase 2.
Los contratos existentes se describen en
[VINI_LICENSE_API_CONTRACT.md](VINI_LICENSE_API_CONTRACT.md); no se proponen URLs
como si ya existieran.

## Reutilizar lo existente

- Autoridad encontrada para VINI APP: `vini-v2-api` y su binding a `vini-v2-db`.
  Login por licencia, Keychain/HWID en cliente, catálogo asignado por usuario y
  descarga `.3105` ya tienen implementación anterior.
- Coexiste activación P-256 → challenge → lease Ed25519. No reconstruir ese
  protocolo ni confundirlo con Bearer APP; decidir explícitamente cómo deben
  cooperar y qué valida cada uno antes de conectarlos al dashboard.
- Mantener aparte `vini-patch-db`: contiene otro modelo de licencia por HWID y
  tier. Falta identificar su Worker consumidor. No migrar, fusionar ni dar por
  equivalentes usuarios/licencias de ambas bases.

## Acuerdos que faltan antes de implementar

1. Elegir la identidad canónica y el método de sesión del dashboard, conservando
   el acceso de las otras aplicaciones VINI. Establecer namespace de Keychain y
   reglas de dispositivo sin cambiar identidad/App Group de 3105.
2. Definir un adaptador del contrato real a la presentación de `0959a41`:
   username → usuario; isPremium → nivel booleano conocido, no nombre inventado;
   licenseExpiresAt → expiración de licencia. Nunca usar expiresAt de sesión
   como duración de licencia ni interpretar `null` como ilimitada sin confirmar
   la política de negocio observada en el cliente anterior.
3. Resolver plan nominal, estado completo y hora del servidor verificable:
   actualmente no hay una respuesta única con los cinco datos. Acordar un
   contrato futuro o composición de operaciones existentes sin inventar ahora
   endpoints ni realizar cambios de Worker/D1.
4. Acordar refresh: hoy el cliente espera X-New-Token y el Worker no lo emite.
   Documentar revalidación permitida, errores, límites y expiración. No hacer
   reintentos de login en un bucle de cada tarjeta.
5. Establecer confianza en la clave pública del servidor para los leases,
   separación clara entre sesión/lease/licencia, máximos offline y revocación.
   Corregir en una fase autorizada la posible vigencia de lease posterior a la
   expiración de licencia; `caps: []` no habilita patches.
6. Acordar mapeo autenticado estable targetID → ID remoto → packageID interno
   → projectID → receipt local. Faltan targetID, digest y revisión de catálogo.
   No usar títulos ni asumir UUID para el ID remoto. Definir categoría sin
   deducirla de nombres. Mantener Apply bloqueado hasta verificar asignación,
   bytes del paquete, decodificación, ámbito y permisos efectivos.
7. Entrega de paquetes: reutilizar autorización de usuario y transporte existente;
   no guardar material de descifrado en Git, logs, informes o preferencias. La
   presencia de columnas de clave/contraseña no prueba su formato real. Acordar
   con el servidor el material compatible con el codec `.3105` existente.

## Plan de comprobaciones, aún no realizadas

Con autorización específica para una fase de implementación y datos de prueba:
licencia válida/caducada/pausada/bloqueada; sesión expirada; distinción entre
milisegundos de token y segundos de lease; cambio de HWID y revocación; nonce
reutilizado/caducado; reloj local adelantado/atrasado; caída de red/rate limit;
respuesta sin plan/hora; patch revocado/no asignado; paquete cambiado/cifrado;
preservación de credenciales de otras VINI y UI sin estados ficticios.

No invocar activación/login/descarga como «test de lectura»: escriben. No crear
cuentas de prueba ni sesiones sin autorización de esa fase. La validación
funcional de iOS será únicamente en el iPhone físico del usuario. Nada de ello
se ha ejecutado durante esta auditoría.

## Entrega y parada

Esta rama añade únicamente cuatro informes Markdown. No cambia Swift, JS, SQL,
entitlements, workflows ni dependencias. No compila una IPA, implementa login,
despliega Worker o modifica D1. La Fase 2 debe esperar una instrucción explícita.
