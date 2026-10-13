# Agenda de próxima donación: 12 semanas

La ruta `#donors` integra una agenda con búsqueda, filtros por estado y rango de fecha, orden cronológico, paginación y apertura directa de la ficha para contacto y programación de visitas.

Cada ficha recibe una fecha calculada igual a su última donación válida más **84 días naturales**. Se toma la más reciente entre las fechas declaradas del Excel y las donaciones efectivas registradas en HemoCura. Una nueva donación registrada recalcula automáticamente la referencia. La fecha es de planificación administrativa: no modifica elegibilidad clínica, no confirma una visita, no inventa hora ni crea unidades sanguíneas.

Las fechas alcanzadas se conservan para gestionar contacto; no se desplazan silenciosamente a hoy. Sin una última donación válida no se asigna fecha. Fechas imposibles se ignoran; si la última fecha se encuentra en el futuro, la ficha se marca para verificación. Todos los cálculos usan fecha local de Santo Domingo; sumar días a `date` evita desplazamientos por hora o cambio de mes/año.

La vista `vw_donor_next_donation` utiliza `security_invoker=true`, los permisos y RLS de donantes/donaciones. No concede acceso anónimo. El listado consulta la vista calculada y no descarga la procedencia completa del Excel. El JSON original de importación permanece protegido y sin reescritura.

Verificación de la base al 13 de octubre de 2026: 2,742 fichas de Santiago; 1,789 fechas calculadas (1,782 alcanzadas y 7 próximas); 953 sin fecha de última donación. El 100% de las fechas calculadas cumple `última fecha + 84`. La generación no creó visitas confirmadas.

Pruebas: 37 comprobaciones de PostgreSQL aislado, incluidos año bisiesto, cambio de año, fechas inválidas, actualización desde una nueva donación, ausencia de fecha, fechas futuras y aislamiento por sucursal; 26 pruebas de navegador con datos ficticios, filtros de agenda, búsqueda y diseño móvil. Se conservan las comprobaciones operativas generales.

Migración: `supabase/migrations/20261013194849_donor_twelve_week_agenda.sql`. Los datos personales y del Excel no se publican en el repositorio.
