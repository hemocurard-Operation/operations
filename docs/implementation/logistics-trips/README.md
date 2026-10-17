# Viajes fuera de horario de Logística

Ruta: `index.html#extratrips`. Formulario para celular: fecha, origen, destino y motivo; salida/llegada; resumen y Confirmar y enviar. Referencia de entrega y comentario opcionales. No pide cédula, nombre escrito, datos de pacientes ni cálculos al colaborador. La identidad se toma de su sesión.

## Horario autorizado

- Lunes a viernes: 08:00 a 18:00.
- Sábado: 08:00 a 12:00 del mediodía.
- Domingo: sin jornada regular, al no haberse indicado horario dominical.
- Zona: America/Santo_Domingo. Se evalúa la fecha y hora de llegada. Antes de las 08:00 o después del cierre se considera fuera de jornada; exactamente 08:00 y exactamente el cierre están dentro.

Cada viaje conserva HC-LOG-HOR-001-1 y la jornada aplicada como copia inmutable. No se aceptan horas de cierre inventadas desde el cliente. Un cambio futuro de horario necesita una nueva versión, sin modificar el historial. La opción Llegué al día siguiente determina la fecha real de llegada. El mes de seguimiento corresponde a esa llegada local. No se permiten viajes futuros o que no hayan terminado.

## Uso diario

1. El Super Usuario asigna el nuevo rol LOGISTICA a las cuentas correspondientes y su sucursal. Esta entrega no asigna el rol automáticamente a personas reales. El rol muestra Mi trabajo y Viajes fuera de horario.
2. El colaborador registra el viaje y recibe un folio VJ. No se promete un importe al enviar. Puede consultar sus viajes, leer observaciones, corregir los devueltos o anular los pendientes con motivo.
3. Gerencia Operativa o General revisa viajes de otras personas, con observación y autorización del importe en DOP. La tarifa no fue informada, por lo que el sistema no inventa una tasa ni calcula automáticamente el incentivo. La revisión conserva responsable, horario y evidencia escrita de autorización.
4. Finanzas consulta incentivos aprobados y registra su inclusión en liquidación con referencia de nómina/liquidación. No ejecuta transferencias ni certifica pago bancario. El lote es atómico, máximo 200, y conserva importes/revisiones aprobados.
5. Los listados pueden filtrarse por llegada y descargarse. Un fallo de consulta se presenta como no disponible y bloquea exportaciones.

## Facilidad de uso y conexión

Tres pasos, lenguaje directo, campos grandes, botones de al menos 50 px y sin tablas horizontales en el formulario. Hay comprobación de fechas/horas antes de enviar. Un error conserva los datos y la misma clave de envío, evitando duplicados por reintentos. Durante navegación dentro de la aplicación se conserva un borrador solo en memoria, separado por usuario; no se guarda en almacenamiento persistente del navegador. Cerrar o recargar puede perder un borrador; se solicita aviso del navegador cuando hay cambios sin enviar. No es un formulario sin conexión: el comprobante solo aparece después de confirmación del servidor.

## Seguridad y trazabilidad

TRIPS_VIEW/WRITE/REVIEW/SETTLE separan colaborador, supervisor y Finanzas. No se conceden privilegios de administración de usuarios. Super Usuario conserva acceso global, con la misma prohibición de aprobar o liquidar sus propios viajes. Las asignaciones de personas y sedes existentes se preservan.

Dos tablas con RLS: viajes propios para trabajadores; revisión/Finanzas solo dentro de su ámbito canónico de sedes. La API logística usa SECURITY INVOKER. El trigger comprueba todas las transiciones también ante escrituras directas: identidad y horario inmutables, autoría estampada, incentivo positivo autorizado y liquidación sin alterar importes aprobados. El historial solo permite SELECT al cliente; su escritor es un trigger privado con EXECUTE revocado y search_path fijo. No se borran registros: las anulaciones se conservan con motivo.

Se usa una clave de solicitud y huella de datos para reintentos; un bloqueo por colaborador impide viajes simultáneos/superpuestos, incluso con distintas claves. Las correcciones y revisiones usan revisión optimista y bloqueo de fila. Las liquidaciones fallan completas ante cualquier registro no aprobado, ajeno o cambiado. Las pruebas de carreras verifican duplicados y aprobaciones simultáneas.

Los informes adjuntos distinguen pruebas locales con datos ficticios y auditoría del proyecto de producción. No se crean viajes, incentivos, liquidaciones ni cuentas de ejemplo en producción.
