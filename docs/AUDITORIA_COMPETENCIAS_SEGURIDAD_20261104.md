# Segunda corrección de seguridad · Hemocura

## Estado

**Aplicada y verificada.** Historial Supabase: `20261104162937_audit_criteria_and_competency_authorization`. La comprobación posterior confirmó cero políticas amplias anteriores, seis políticas específicas, dos triggers activos, RLS en ambas tablas, ausencia de SELECT anónimo y DELETE autenticado. La función privada de auditoría no permite ejecución directa autenticada. La primera fase permanece aplicada.

Destino exclusivo: proyecto `tiothqiljipdamgudvcb`. SoFa queda fuera de alcance.

## Alcance del parche

- Sustituye las políticas FOR ALL basadas solo en autenticación de `audit_plan_criteria` y `job_role_competencies`.
- Los criterios exigen actor activo y `INTERNAL_AUDIT_VIEW` para leer o `INTERNAL_AUDIT_WRITE` para crear/editar, además del alcance de la auditoría padre.
- Usa el alcance vigente de `can_access_branch`: los roles globales, incluido Calidad, conservan su alcance; los usuarios limitados a una sucursal no obtienen acceso a otra. Las auditorías globales sin sucursal siguen soportadas para usuarios autorizados.
- La matriz puesto-competencia es un catálogo global, no una asignación personal por sucursal. Se conserva su lectura para personal activo porque la capacitación depende de ella. Crear/editar exige `COMPETENCY_WRITE`.
- Mantiene los contratos de INSERT/UPSERT actuales, las columnas y los registros existentes. No se cambian competencias, niveles ni resultados de auditoría mediante esta migración.
- Retira acceso anónimo y permisos de DELETE/TRUNCATE ordinarios en estas dos tablas.
- Dos triggers registran los cambios en la bitácora de la misma transacción, con actor, referencia, sucursal cuando aplica, valores operativos anteriores/nuevos y lista de campos modificados. No copia el texto libre de notas y observaciones. Una actualización idéntica no duplica la bitácora.
- Si falla la bitácora, falla y se revierte la operación. Los identificadores de registro no pueden sobrescribirse.

## Validación

`python tools/migration_security_linter.py supabase/migrations/20261104162937_audit_criteria_and_competency_authorization.sql`

`python tools/workflow_postgres_runner.py --allow-external-prerequisite-fixture --report-dir /tmp/hemocura-quality-security`

Resultado final: **335 comprobaciones PostgreSQL aprobadas**, reconstruyendo 84 archivos de esquema/migraciones con datos ficticios. Incluye la regresión de operación, laboratorio, agenda, calidad, permisos y la primera corrección, además de 24 comprobaciones nuevas de auditoría y competencias.

Las nuevas pruebas verifican lectura autorizada, edición autorizada, aislamiento de sucursal, lectores sin escritura, capacitación sin permiso de gestión, usuario inactivo, denegación anónima, upsert, reintento sin bitácora redundante, antes/después, fallo de bitácora sin cambio parcial y preservación de auditorías globales.

## Aplicación y comprobación

Aplicada mediante confirmación de Supabase al proyecto indicado. Se verificaron historial, políticas, triggers y RLS sin crear ni modificar registros clínicos reales. La migración es transaccional con lock_timeout de cinco segundos.

Si la herramienta asigna una versión de historial diferente, alinear el nombre del archivo con ese identificador antes de incorporarlo al repositorio, para evitar reaplicaciones bajo otra versión.

Los archivos se incorporan al repositorio mediante la conexión de Hemocura con escritura habilitada. Esta entrega conserva las migraciones ya aplicadas y sus pruebas; la interfaz sigue en 0.49.1 y el sistema permanece LIVE_LIMITED.

## Límites

Esta fase no convierte las vistas heredadas a security_invoker, no modifica la privacidad de cámara hiperbárica, no resuelve todos los privilegios predeterminados ni completa UAT o firmas de liberación. Tampoco cambia los permisos globales de Calidad ni inventa una sucursal en la matriz global.
