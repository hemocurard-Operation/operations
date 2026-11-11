# Filtros de seguimiento · 0.62.0

Después de Consultar seguimiento de este agente, se habilitan los filtros de hallazgos con tareas vencidas, por revisar y con mis tareas activas. La búsqueda por título de tarea o responsable usa los datos ya consultados, con debounce local de 200 ms y conservación del foco. Filtrar no realiza nuevas consultas ni escrituras.

Mis tareas compara owner_id con el identificador de la cuenta del contexto de seguridad propio; no compara nombres ni correos. Excluye tareas completadas y canceladas. Sin identificador válido, la opción se deshabilita y la regla devuelve cero coincidencias. Las tareas vencidas usan la misma definición de la Agenda: activas con vencimiento pasado.

El filtro elige hallazgos con coincidencias y sus detalles muestran las tareas que coinciden. Se conserva el resumen total del hallazgo y se explica la cantidad de coincidencias. Todos los hallazgos, sin búsqueda, incluye aquellos sin seguimientos visibles. Los resultados se describen como datos consultados, no como un inventario completo: la advertencia de muestras parciales de 0.61 sigue vigente.

Cambiar agente o sucursal, actualizar las señales, volver a consultar o guardar una tarea invalida/restablece los filtros. Las búsquedas pendientes no se aplican a otro ámbito ni interrumpen la preparación de tareas. Cambiar filtros locales conserva la selección y el contenido de la revisión de cotizaciones del agente de Proveedores.

No cambia roles, RLS, credenciales o esquema. Se añade owner_id a la proyección explícita de work_tasks, bajo las políticas existentes. Los filtros son comodidad de consulta y no sustituyen autorización server-side.

Validación local: 8 casos de reglas y 15 verificaciones de navegador (estados, propietario por ID, búsqueda, foco, intersecciones vacías, ausencia de consultas adicionales, cambios de ámbito, conservación del widget de cotizaciones, móvil y ausencia de escrituras). Se conserva la regresión de consulta y preparación de seguimientos. CI Chromium/Firefox/WebKit.
