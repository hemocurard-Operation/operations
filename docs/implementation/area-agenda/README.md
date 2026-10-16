# Mi jornada, agenda por área y seguimiento gerencial

El sistema añade un espacio de trabajo que organiza responsabilidades y pendientes. La ruta `#areaagenda` y el resumen de Mi trabajo están disponibles dentro del control de ventanas por rol. El catálogo pasa de 62 a 63 ventanas; el Super Usuario conserva todas y puede desactivar la nueva ventana para otros roles.

## Vistas y utilidad directa

| Vista | Información y acción | Mejora para la empresa |
| --- | --- | --- |
| Mi jornada | Tareas propias, próximos vencimientos, lista de comprobación y evidencia | El responsable empieza por sus compromisos reales, además de sus accesos a módulos |
| Agenda por área | Responsable, fecha, prioridad, estado y vínculo al registro original | Cada compromiso tiene dueño y plazo; las tareas vencidas siguen visibles |
| Seguimiento de Operaciones | Carga por área, vencimientos, bloqueos, revisión pendiente y fuentes operativas | Permite asignar trabajo, resolver dependencias y coordinar entregas con información trazable |
| Seguimiento de Calidad | Evidencias enviadas, revisión independiente, devoluciones, cancelaciones y cumplimiento | Separa ejecución de validación y deja constancia de qué se revisó, por quién y cuándo |

Las responsabilidades sugeridas cubren Operaciones, Laboratorio, Donantes y citas, Inventario, Compras, Comercial, Finanzas, Calidad y Sistemas. Son guías editables: deben adaptarse a los procedimientos vigentes y a las responsabilidades reales de cada puesto.

Los supervisores ven exclusivamente las áreas y sucursales de su ámbito. Calidad puede revisar evidencia de otras áreas autorizadas; gestionar su planificación exige además permisos gerenciales de esa área. El responsable elegido debe estar activo, tener un rol del área, permiso de ejecución y asignación a la sucursal; el Super Usuario puede actuar en todas. Los perfiles de Consulta y Socio conservan consulta, sin ejecución.

## Flujo

1. Elegir sucursal y área; crear una tarea con responsable, resultado esperado, fecha y prioridad. Se puede usar la guía del área como lista de comprobación.
2. Planificar una sola ocurrencia o un lote de hasta 31 tareas diarias o semanales. Cada ocurrencia queda creada con fecha e historial propios. El lote es atómico y un reintento con el mismo identificador no duplica tareas.
3. Iniciar la tarea, registrar avances o documentar el bloqueo y la ayuda requerida.
4. Completar los puntos de comprobación y adjuntar una referencia de evidencia; enviar a revisión.
5. Otra persona autorizada valida y cierra, o devuelve para corregir con su observación. Una nueva presentación limpia los marcadores de revisión anterior. El ejecutor no puede revisar su propia evidencia, incluso si tiene un rol gerencial.
6. Una tarea cerrada no permite sobrescribir su ejecución. La gerencia puede reabrir con motivo; se conserva el historial y se solicita nueva evidencia. Reprogramar mantiene el vencimiento original. Reasignar limpia la evidencia de ejecución del responsable anterior.

Las tareas de Calidad y las críticas siempre requieren revisión independiente. Para una tarea administrativa normal, la gerencia puede decidir al crearla que no requiera una segunda revisión; el empleado no puede eximir sus propias tareas nuevas. La evidencia y la lista siguen siendo obligatorias para completar.

## Indicadores y fuentes

Los indicadores acumulan los registros visibles de la sucursal: abiertos, vencidos, bloqueados, por revisar y cancelados. Se muestran por separado el porcentaje de envíos y de cierres a tiempo. Ambos usan la fecha original, evitando que reprogramar o demorar la revisión oculte la historia del compromiso. El acumulado no representa un indicador mensual de toda la empresa si no se han cargado todas sus tareas.

Las vistas gerenciales consultan, según los módulos habilitados, pedidos operativos, órdenes de compra, calidad diaria, no conformidades, acciones integradas y citas de donación. Presentan cantidades de registros pendientes y vencidos/por cerrar, con acceso al módulo correspondiente. Un error de lectura aparece como no disponible y no como cero. No se extraen nombres de pacientes o donantes para estos contadores.

Estos registros de origen no se copian ni cambian al cerrar una tarea. La agenda permite documentar su seguimiento; **no sustituye el cierre de CAPA, la revisión clínica, la liberación de sangre, la recepción de compras ni los controles de los módulos originales**. Los procesos conservan sus autorizaciones y evidencias propias.

El reporte CSV exporta el seguimiento actualmente filtrado, con responsable, vencimiento original y actual, estado, evidencia, revisión y cierre. Las celdas de texto se protegen contra fórmulas de hojas de cálculo. Las horas de la pantalla son de Santo Domingo; los timestamps exportados conservan su zona UTC.

## Alcance de recordatorios y rutinas

Las alertas se muestran dentro del sistema. No se envían correos, mensajes ni notificaciones externas. Las repeticiones son lotes finitos explícitos, no un calendario que genere tareas indefinidamente: al finalizar el período planificado debe programarse el siguiente. La cobertura depende de registrar los compromisos y parametrizar las rutinas vigentes; el sistema no puede detectar responsabilidades que no se hayan registrado.

No se insertan tareas ficticias ni se asigna trabajo real durante el despliegue. La gerencia debe seleccionar responsables y validar las guías antes de poner las rutinas en marcha.

## Seguridad y verificación

- RLS y actor activo en todas las tablas nuevas; ámbitos por área y sucursal en la base.
- Vistas `security_invoker`; la API de acciones ejecuta con los permisos del llamante.
- Los dos ayudantes públicos con privilegios elevados son consultas autorizadas y limitadas: comprobación booleana de ámbito y listado mínimo de responsables elegibles. Las funciones de validación, elegibilidad y auditoría son privadas y no ejecutables por el cliente.
- La escritura directa tampoco evita estados, evidencias, segregación ni campos de trazabilidad. El historial no admite cambios del cliente.
- Revisiones optimistas y bloqueo de fila evitan sobrescribir cambios concurrentes.
- Pruebas en PostgreSQL desechable con el esquema operativo completo y navegador con SDK local y datos sintéticos. No se ejecutan acciones clínicas de prueba en producción.

Comandos: `node tests/area-agenda/domain.test.mjs`, `python tools/workflow_postgres_runner.py --allow-external-prerequisite-fixture`, `node tools/area_agenda_browser_runner.cjs`.
