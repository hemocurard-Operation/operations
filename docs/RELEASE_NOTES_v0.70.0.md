# HemoCura 0.70.0 — reporte de todos los viajes

El módulo se denomina **Reporte de viajes**, conserva su ruta `#extratrips` y permite registrar todos los viajes realizados, incluidos los que empiezan y terminan dentro de la jornada. Se retiró el bloqueo tanto del formulario como de la validación de registro y reenvío en el servidor.

El reporte de Mis viajes y la consulta/revisión del equipo incorporan estos filtros:

- Todos los viajes.
- Inician o terminan fuera de horario (cualquiera de los dos).
- Inician fuera de horario.
- Terminan fuera de horario.
- Inician y terminan fuera de horario.
- Inicio y fin dentro de horario.

Se conserva el horario existente de República Dominicana: lunes a viernes de 08:00 a 18:00, sábados de 08:00 a 12:00 y domingos sin jornada regular. Los límites exactos pertenecen a la jornada. Cada extremo se clasifica con su propia fecha, incluyendo viajes nocturnos y cambios de día.

Los nuevos registros conservan ambas clasificaciones en su evidencia de horario. Los históricos se clasifican en el reporte sin modificar sus filas; para la llegada se respeta la clasificación ya guardada. La descarga CSV usa el mismo filtro visible y agrega las dos clasificaciones al final, conservando las posiciones de las columnas anteriores.

Registrar un viaje continúa siendo distinto de autorizar un incentivo: se mantienen la revisión, la identidad del colaborador, el alcance por sucursal, la auditoría, la prevención de duplicados y las reglas existentes de incentivos. La entrega no realiza pagos ni cambia importes aprobados.

Validación con datos sintéticos: viajes dentro de jornada, salida temprana y llegada dentro de jornada, salida dentro y llegada tardía, sábados/domingo, cambio de día, límites con segundos, filtros y CSV, reintentos, permisos por rol y consulta sin escritura. No se crearon viajes reales para probar.
