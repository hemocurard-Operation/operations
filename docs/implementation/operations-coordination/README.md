# Operaciones, comunicación y agenda — 16 octubre 2026

## Planificación de pedidos

Disponible en Ruta operativa (`#workflow`). Registra referencia, centro solicitante, sucursal, componente, grupo solicitado opcional, cantidad, prioridad, vencimiento, responsable y notas. Los estados avanzan Pendiente → En gestión → Listo → Completado; se permite cancelar con motivo o devolver Listo a En gestión. Los pedidos cerrados se conservan sin edición. El tablero muestra vencidos, urgentes y unidades requeridas en siete días, con filtros y paginación. La actualización compara la revisión recibida para evitar sobrescribir una versión más reciente. La planificación no reserva existencias ni genera ventas, despachos o movimientos de inventario.

Se conceden ORDER_PLAN_VIEW y ORDER_PLAN_WRITE por función operativa, sin agregar privilegios de administración de usuarios. Super Usuario mantiene todos los permisos activos. Las filas se limitan a sucursales autorizadas, con autor y auditoría de cambios.

## Coordinación con donantes

Disponible en Donantes (`#donors`). La cola diferencia seguimientos vencidos, fechas alcanzadas, contactos sin siguiente acción, fechas por verificar, espera de intervalo, citas existentes y la respuesta No desea donar. Esta última se excluye de la cola pendiente y no permite preparar mensajes. Antes de preparar un borrador se vuelve a leer el estado actual para respetar una negativa o reprogramación registrada por otra persona.

Los borradores son editables, se pueden copiar o abrir manualmente en WhatsApp, y no incluyen cédula, grupo sanguíneo ni resultados clínicos. Preparar o copiar no registra un contacto ni demuestra entrega: el resultado real se documenta desde la ficha. No se enviaron mensajes ni se crearon citas o pedidos de donantes reales durante el despliegue. El envío de correos sigue dependiendo del proveedor SMTP pendiente.

## Agenda y cupos

La agenda consulta fechas y estados por centro, muestra pendientes de confirmación y de cierre, y abre la ficha para confirmar, reprogramar o cancelar. El período consultado tiene un máximo de 92 días y horas de República Dominicana. Cada centro define su capacidad real y franjas de 15, 30 o 60 minutos mediante DONOR_AGENDA_CONFIG (Super Usuario, Administrador, Gerencia Operativa y Encargada de Laboratorio). No se inventó una capacidad inicial: sin configuración se informa que no hay control de cupos por franja.

El servidor serializa las reservas para impedir sobrecupos incluso con solicitudes simultáneas. Cuenta las citas que ocupan una franja aunque el origen del donante no sea visible para otro operador; las identidades permanecen protegidas. Bajar la capacidad o cambiar la franja no puede invalidar reservas existentes. Se conserva una única cita activa por donante.

Una fecha de última donación conocida obliga a respetar al menos 84 días; una fecha futura inconsistente bloquea la reserva hasta verificar el antecedente. La ausencia de historial se muestra para revisión y no se trata como prueba de elegibilidad. Asistir a una cita no registra automáticamente una donación ni altera la revisión clínica.

## Validación y alcance

28 pruebas de reglas puras, 31 comprobaciones SQL (incluye concurrencia), 17 flujos de navegador de coordinación, 34 comprobaciones de regresión de Donantes y 71 comprobaciones de integración operativa. Dos tablas nuevas con RLS, dos vistas security_invoker y guardas de cupos privadas sin ejecución directa por authenticated. El asesor de seguridad no añadió advertencias respecto a la línea base del proyecto.

En producción se verificaron 2,742 donantes, cero pedidos o citas generados por la implementación y 96 permisos activos. Los datos originales e historiales se conservaron. Los datos de pruebas fueron sintéticos y se ejecutaron en contenedores y navegador aislados.
