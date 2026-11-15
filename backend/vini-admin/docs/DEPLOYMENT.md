# Procedimiento posterior de despliegue — NO ejecutado

Requiere autorización explícita antes de tocar producción. No hay workflows de
deploy, migraciones automáticas al arrancar ni configuración con IDs productivos.
El staging probado en esta entrega es local, con datos sintéticos y navegador de
escritorio; todavía NO se ha validado un despliegue Cloudflare remoto de la ampliación.

## Preparación y revisión

1. Revisar Worker/panel generados, migraciones, permisos y resultados. Verificar
   hashes de snapshots y del paquete de entrega. Volver a comprobar la versión
   productiva: si cambió desde f1e869fd, reconciliar esa diferencia antes de desplegar.
2. Crear un staging Cloudflare separado cuando se autorice, con Worker, D1 y R2
   propios y datos de ensayo. La configuración incluida usa nombre de staging y
   un UUID deliberadamente no productivo; no es una configuración de producción.
3. Configurar credenciales de ensayo por el flujo seguro de Cloudflare; no pegarlas
   en chats/Git. Ejecutar build/tests con las versiones fijadas en package-lock.json.
4. Probar carga y límites D1 representativos sin copiar clientes reales. Revisar
   los históricos con plan/saldo/procedencia desconocidos antes de asignar derechos.

## Migración explícita en staging

El comando `wrangler d1 migrations apply --local` de Wrangler 4.129.0 dividió los
triggers y falló con incomplete input. NO usarlo ni asumir que ese camino está
validado. Se entrega y prueba un migrador de statements completos vía DB.batch.

1. Publicar el bundle experimental únicamente en staging, con DB/R2 de staging.
   Mantener ADMIN_PLANS_ENABLED desactivado inicialmente.
2. Habilitar ADMIN_MIGRATIONS_ENABLED=1 para la ventana controlada. Obtener una
   sesión del principal administrativo existente mediante su login normal.
3. GET /api/admin-v2/migrations/preview. Revisar manifiesto, checksums y pendientes.
   POST /apply con manifestHash exacto y confirm=true. No recibe SQL del cliente.
4. Cada archivo SQL y su entrada de ledger se aplican en un batch atómico.
   Una interrupción permite repetir: el checksum verificado evita repetir DDL.
   Si aparece un checksum distinto o esquema inesperado, detener y recuperar;
   no borrar tablas ni forzar el ledger.
5. Deshabilitar ADMIN_MIGRATIONS_ENABLED. Activar ADMIN_PLANS_ENABLED=1 solo tras
   verificar ambas migraciones. Validar panel, APP legacy y controles con ensayos.

Entre migración y activación se bloquean escrituras administrativas/catalogo del
modelo preparado para no permitir bypass. Planificar esa ventana de mantenimiento.

## Producción: una fase futura

Solo tras aprobar staging remoto y recibir autorización: tomar un punto de
recuperación/backup D1 autorizado y copia verificable de Worker y objeto HTML R2;
no se ha exportado una base real en esta tarea. Revisar costes/límites y clientes
legacy. Aplicar el mismo procedimiento controlado con configuración productiva
revisada, nunca reutilizando ciegamente la de staging. No tocar vini-patch-db.

Mantener el panel anterior guardado: el bundle ampliado sirve el panel generado
en las rutas existentes, sin necesitar sobrescribir el objeto R2. El principal
legacy sigue autenticándose; desde él se crean cuentas nominales con permisos
mínimos. No hay contraseñas nuevas predeterminadas ni cuentas de distribuidor
precreadas en migraciones.

Antes de cerrar la ventana: probar login APP anterior, perfil, paquetes asignados,
reversión de una pausa de ensayo, recuperación de job y modo ADMIN_READ_ONLY.
No se proponen comandos productivos para ejecutar automáticamente esta fase.
