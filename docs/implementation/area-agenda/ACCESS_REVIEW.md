# Alcance de autorización para la agenda por área

Estado: alcance autorizado explícitamente por el usuario el 16 de octubre de 2026. Migración aplicada en producción como `20261016234508_area_task_agenda`. Publicación de la interfaz autorizada en `hemocurard-Operation/operations` y GitHub Pages.

## Nuevos permisos y áreas

| Roles | Consulta | Crear/ejecutar | Asignar y reprogramar | Revisar evidencia ajena |
| --- | --- | --- | --- | --- |
| Super Usuario, Administrador, Gerencia Operativa, Gerencia General | Todas las áreas, con sucursal autorizada; Super en todas | Sí | Todas las áreas de su ámbito | Sí, sin autorrevisión |
| Calidad | Todas las áreas de su ámbito | Tareas propias | Solo Calidad | Sí, en las áreas autorizadas y sin autorrevisión |
| Encargada de Laboratorio | Laboratorio, Donantes, Calidad | Sí | Esas áreas | Sí, sin autorrevisión |
| Inventario | Inventario y Compras | Sí | Esas áreas | No |
| Finanzas | Finanzas | Sí | Finanzas | No |
| Médico / Gerente Técnico | Laboratorio y Calidad | Sí | Esas áreas | Sí, sin autorrevisión |
| Asistente de Operaciones | Operaciones, Donantes, Compras y Comercial | Tareas propias | No | No |
| Laboratorio | Laboratorio y Donantes | Tareas propias | No | No |
| Sucursal | Operaciones, Laboratorio, Donantes e Inventario | Tareas propias | No | No |
| TI | Sistemas | Tareas propias | No | No |
| Consulta y Socio | Todas las áreas dentro de su acceso a sucursales | No | No | No |

La consulta de una tarea no permite cambiar su evidencia. Ejecutar exige ser su responsable. El listado de posibles responsables muestra solo perfiles activos con rol de área, permiso de ejecución y asignación a la sucursal; quien no puede asignar trabajo ve únicamente su propio perfil elegible.

Los nombres técnicos de los permisos son `WORK_AGENDA_VIEW`, `WORK_AGENDA_WRITE`, `WORK_AGENDA_MANAGE` y `WORK_AGENDA_REVIEW`. Se añade la ventana `areaagenda` al control de módulos por rol, inicialmente activa para los roles existentes y ajustable por el Super Usuario. Se crean cuatro tablas (`work_areas`, `work_area_roles`, `work_tasks`, `work_task_history`), tres vistas con seguridad del llamante y las funciones de consulta, ejecución, validación y auditoría descritas en la migración.

El historial conserva el contenido de cada cambio, su responsable y la fecha. Los responsables y revisores deben ser cuentas reales activas. No se crean cuentas, se cambian claves ni se asignan roles de usuario. No se habilitan privilegios de identidad a otros roles ni se cambia `has_permission`.

## Efectos excluidos

No se alteran donantes, pedidos, compras, CAPA ni resultados clínicos. No se crean tareas ficticias ni se asignan compromisos reales durante el despliegue. No se envían mensajes o correos ni se configura generación indefinida de tareas. Las repeticiones solo se crean cuando un usuario autorizado planifica un lote finito.

La gerencia deberá validar sus guías, elegir responsables y programar los compromisos vigentes. La agenda no puede detectar tareas que no hayan sido registradas.

## Verificación completada

- 114 comprobaciones de PostgreSQL sobre una reconstrucción desechable del esquema, incluyendo edición concurrente, RLS, independencia de la revisión y permisos por área/sucursal.
- 20 comprobaciones del navegador para jornada, rutina semanal, revisión, reprogramación, exportación, fallos de origen y móvil.
- 13 comprobaciones de reglas y exportación.
- Regresiones operativas, de donantes/comunicación y navegación general; controles de sintaxis, fuente de verdad y tamaño dentro de presupuesto.
