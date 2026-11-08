# Seguimiento humano de agentes · 0.60.0

Los hallazgos de los seis agentes incorporan Preparar seguimiento para cuentas con Agenda por área habilitada y permisos WORK_AGENDA_VIEW/WRITE. Preparar, consultar personas o cerrar el diálogo no crea tareas. Solo Guardar seguimiento, después de la revisión humana, invoca CREATE de work_task_action.

El diálogo consulta sucursales/áreas autorizadas y work_agenda_people. Las personas elegibles son calculadas por el servidor según área, sucursal y facultad del llamador. El hallazgo de sucursal conserva su sucursal; una señal global requiere seleccionar explícitamente la sucursal responsable del seguimiento. La tarea registra responsable, vencimiento en Santo Domingo, prioridad, resultado esperado, revisión independiente y una referencia estable al origen del agente. No modifica el registro operativo que generó la señal.

Se reutilizan las validaciones, RLS, auditoría, historial y ciclo de ejecución/evidencia/revisión de la Agenda existente. No se añaden SQL ni permisos. Ante respuesta incierta se congelan los datos revisados y se conserva request_id para reintentar la misma solicitud idempotente. Volver a abrir consulta hasta 20 tareas recientes y visibles del mismo origen/sucursal; crear otra exige confirmación explícita. Esto no impide a un usuario autorizado crear otra tarea intencionalmente ni revela seguimientos fuera de su ámbito.

Los enlaces a Agenda incluyen sucursal e ID. La pantalla acepta la sucursal únicamente si está en sus opciones autorizadas y abre la tarea solo si aparece entre las tareas devueltas para esa sucursal. Parámetros desconocidos no amplían el ámbito ni consultan una tarea ajena por ID.

Validación local con datos ficticios: 8 casos de dominio, 14 comprobaciones de seguimiento y 22 de Agenda, incluidos reintento tras respuesta perdida, confirmación de otra tarea, responsables tardíos, permisos, negativa del servidor, móvil y enlaces de ámbito. CI añade Chromium/Firefox/WebKit y regresión PostgreSQL completa reutilizando fixtures aisladas. No se crean tareas de prueba en producción.
