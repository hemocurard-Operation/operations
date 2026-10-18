# Roles de Logística

| Código | Nombre | Funciones |
| --- | --- | --- |
| LOGISTICA_CONDUCTOR | Conductor de Logística | Registrar y consultar viajes propios, corregir devueltos y anular pendientes con motivo. |
| LOGISTICA_SUPERVISOR | Supervisor de Logística | Registrar sus viajes y revisar los de otros colaboradores de las sucursales autorizadas; autorizar importe, pedir corrección o rechazar. No puede aprobar sus propios incentivos. |
| LOGISTICA_CONSULTA | Consulta de Logística | Consultar y descargar viajes e historial del equipo por sucursal, estado y mes. Sin captura, aprobación o liquidación. |

Los tres roles muestran únicamente Mi trabajo y Viajes fuera de horario. No reciben administración de cuentas ni permisos de liquidación. Finanzas conserva la inclusión en liquidación; esta no representa una transferencia ni certificación bancaria de pago.

Se mantiene LOGISTICA para las cuentas existentes. No se crean cuentas ni se asignan los nuevos roles a personas automáticamente. El Super Usuario los asigna desde Usuarios y Roles indicando las sucursales. No se modifica la PR #42 ni su migración general pendiente de autorización.

TRIPS_READ_ALL agrega exclusivamente SELECT para consulta de equipo. El historial sigue la visibilidad del viaje. Las políticas de escritura y los triggers de revisión y liquidación no cambian. El Super Usuario conserva todos los permisos activos. Una persona con varios roles combina sus atribuciones.

Validación: reglas de viajes con conductor y supervisor nuevos, consulta sin escritura ni aprobación, límites por sucursal, independencia, historial y controles de interfaz móvil. Todas las pruebas usan datos ficticios en PostgreSQL desechable y un navegador local. La reconstrucción de pruebas fija America/Santo_Domingo para que las fechas de servicio sean consistentes con las validaciones operativas cerca de medianoche UTC.
