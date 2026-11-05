# Primera corrección de seguridad · Hemocura

Aplicada el 4 de noviembre de 2026 únicamente al proyecto `tiothqiljipdamgudvcb`.
Historial Supabase: `20261104153322_hemovigilance_access_and_anonymous_view_containment`.
La migración se generó con el CLI; el nombre del archivo se alineó después con la versión asignada por la herramienta de aplicación en producción para evitar reaplicarla con otro identificador.

## Cambios activos

- Retira privilegios de `PUBLIC` y `anon` en las 60 vistas públicas que ejecutan con permisos del propietario. Conserva las ACL autenticadas; no convierte en bloque las vistas a invoker.
- Reemplaza la política amplia de detalles de entrega por políticas SELECT/INSERT/UPDATE con actor activo, permiso y sucursal del evento padre.
- Añade políticas restrictivas al evento padre que se combinan con las existentes. Los eventos generales históricos sin sucursal siguen soportados por los roles autorizados; las nuevas NC de entrega requieren sucursal.
- La RPC existente mantiene firma y respuesta, pero comprueba actor activo, HEMOVIGILANCE_WRITE y sucursal explícita.
- Retira DELETE/TRUNCATE ordinario en los detalles y TRUNCATE/DELETE a los roles de navegador en el padre. No elimina filas.
- Dos triggers registran INSERT/UPDATE/DELETE de eventos y detalles en la bitácora de la misma transacción. Conservan actor, sucursal, referencia, campos modificados y valores operativos anteriores/nuevos. No duplican nombres, teléfonos o texto libre de pacientes.
- Evita cambiar la identidad del registro y mover un detalle a otro evento. Los eventos sin cambios reales no generan entradas de auditoría redundantes.

No cambia el estado clínico, flags, tarifas, inventario, modos de operación ni firma de API. La aplicación conserva la versión de interfaz 0.49.1: esta entrega es una migración de base de datos, no una publicación de frontend.

## Pruebas

`python tools/migration_security_linter.py supabase/migrations/20261104153322_hemovigilance_access_and_anonymous_view_containment.sql`

`python tools/workflow_postgres_runner.py --allow-external-prerequisite-fixture --report-dir /tmp/hemocura-security`

Resultado: **311 comprobaciones PostgreSQL aprobadas**, con reconstrucción de 83 archivos de esquema/migraciones en contenedor aislado. Incluye operación, sucursales, permisos, laboratorio, agenda, calidad y las nuevas pruebas de seguridad. No utiliza datos de producción.

Pruebas nuevas: denegación anónima; lector sin escritura; otra sucursal sin lectura; usuario inactivo; RPC sin sucursal; bitácora atómica sin identidad duplicada; fallo de bitácora sin registro parcial; conservación del formulario de evento general; dos sesiones concurrentes con mismo código dejan un evento, un detalle y dos entradas de bitácora. El segundo intento devuelve conflicto de código existente, no éxito idempotente: se conserva el comportamiento de la API anterior.

Comprobaciones reales posteriores: cero vistas del propietario con SELECT para anon; 60 mantienen SELECT autenticado; cuatro políticas restrictivas activas en eventos; política amplia de detalles ausente; dos triggers activos; RPC sin EXECUTE anónimo y con EXECUTE autenticado; función privada de bitácora sin acceso directo autenticado. La API pública del resumen se comprueba con limit=0, sin leer registros de pacientes.

## Operación y reversión

La migración es transaccional y tiene lock_timeout de cinco segundos. Un fallo al aplicar revierte el lote; no debe quedar parcialmente instalado. No hay backfill ni actualización de filas clínicas existentes.

Si aparece una regresión autenticada, diagnosticar primero el permiso y la sucursal del usuario. Preparar una corrección específica y probarla aisladamente. No reabrir vistas a anon ni restablecer políticas FOR ALL por autenticación como una reversión general. Las restricciones no se ocultan tras un feature flag porque son controles de autorización.

## Trabajo pendiente

Esta corrección contiene el acceso anónimo, pero no resuelve el bypass de RLS para usuarios autenticados en las 60 vistas heredadas: requiere revisión vista por vista y de sus dependencias.

Las otras dos políticas amplias se corrigieron en la [segunda fase](AUDITORIA_COMPETENCIAS_SEGURIDAD_20261104.md). Siguen pendientes el aislamiento de datos personales de cámara hiperbárica, los grants y defaults excesivos generales, las funciones sin search_path fijo y las evidencias UAT/firmas de liberación. Los avisos del asesor sobre vistas del propietario siguen presentes por diseño hasta completar esa revisión. La aplicación continúa LIVE_LIMITED.

El SQL está aplicado y registrado en Supabase. Los archivos se incorporan al repositorio mediante la conexión de Hemocura con escritura habilitada, junto con sus pruebas de regresión. No deben reaplicarse con otro identificador de migración.
