# Ciclos de ejecución de 12 semanas

Sustituye la integración incompatible de la pantalla `#twelveweek` con un contrato explícito. Los planes operativos existentes (`operational_plans` y `operational_plan_lines`) son de pronóstico, con períodos y métricas diferentes: permanecen intactos. El nuevo módulo usa ciclos y metas propios y enlaza tareas reales de `work_tasks`.

## Flujo

1. Seleccionar sucursal y área autorizadas. El contexto devuelve las combinaciones admitidas; no se consultan perfiles generales para poblar responsables.
2. El gerente crea un ciclo de 84 fechas locales, inicial BORRADOR o ACTIVO. El inicio permanece inmutable. ACTIVO permite nuevas tareas; CERRADO es final y no completa tareas pendientes.
3. Definir una meta por semana, con métrica y valor numérico opcionales. El porcentaje de tareas completadas no se presenta como cumplimiento de la meta.
4. Crear una tarea de la semana con título, instrucciones, responsable elegible, prioridad canónica y vencimiento en Santo Domingo. El servidor verifica el rango semanal.
5. Ejecutar y revisar en Agenda por área. La tarea se crea a través de `work_task_action`, con revisión independiente obligatoria, autor y responsable separados cuando corresponde, historial y referencia al ciclo. No hay acción de completar desde el tablero de ciclos.

## Contrato y acceso

- Tablas aditivas: `twelve_week_cycles`, `twelve_week_goals`, `twelve_week_task_links`, `twelve_week_requests`.
- Wrappers públicos SECURITY INVOKER: `twelve_week_context`, `twelve_week_catalog`, `twelve_week_action`. Implementaciones privadas y búsquedas con ruta controlada.
- Lectura requiere PROJECTS_VIEW y WORK_AGENDA_VIEW, con asignación del mismo rol a la sucursal/área. Gestión añade WORK_AGENDA_MANAGE y WORK_AGENDA_WRITE y capacidad de gerencia del área. Se preserva la excepción de alcance del Super Usuario.
- RLS y revocación de escritura directa para las tablas nuevas. El ledger de solicitudes no tiene lectura de navegador ni políticas: acceso interno deliberado.
- Solo se registra el módulo para roles con PROJECTS_VIEW existente; no se crean usuarios ni se conceden permisos nuevos.
- UUID de solicitud por acción, payload exacto y respuesta persistida impiden repetir una creación al reintentar la misma solicitud. La pantalla retiene UUID y formulario durante reintentos en esa sesión. No se promete recuperación de formulario tras cerrar o recargar la pestaña; la protección de cambios ofrece decisión explícita antes de descartar.
- Revisiones optimistas para ciclos y metas y bloqueo transaccional del ciclo para metas/tareas/cierre. Auditoría de todas las escrituras aceptadas.

## Operación y despliegue

Flag `twelve_week_execution`: OFF por defecto. Aplicar migración después de pruebas aisladas; publicar y comprobar los archivos de la interfaz antes de activar LIVE_LIMITED. No se insertan ciclos, metas ni tareas de demostración en producción.

Reversión de la vista: apagar el flag. Conservar tablas, vínculos e historial. Las tareas existentes continúan en Agenda por área. La aceptación operativa se realiza con usuarios responsables; estas pruebas no crean firmas ni aprobación clínica.

Pruebas automatizadas: casos con roles ficticios, SQLSTATE de denegación, áreas/sucursales y combinaciones de roles, rangos RD, revisión independiente, reintento idempotente, valores numéricos finitos, auditoría, estados de ciclo y navegador de escritorio/móvil. Evidencias en CI y artefactos de la liberación.

Validación de liberación: 595 comprobaciones PostgreSQL (53 específicas de ciclos) sobre 97 archivos y 26 pruebas de navegador, con datos ficticios. La comprobación anónima rechazó los siete endpoints nuevos.
