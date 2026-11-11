# CRM compartido y plan semanal de visitas

Ruta: Gestión comercial → CRM → Mapa y plan semanal de visitas. Requiere `COMMERCIAL_VIEW` en la sucursal; escritura requiere `COMMERCIAL_WRITE`. Flag `crm_weekly_planner` desactivado por defecto y activado tras verificar publicación.

Las fichas tienen una sucursal de origen y vínculos explícitos de cartera compartida; no se triplican contactos. `crm_branch_contacts` valida el acceso a la sucursal solicitada y devuelve únicamente sus fichas propias o compartidas. Las fichas compartidas se consultan desde cada sucursal; los datos centrales y actividades del CRM original se mantienen desde la sucursal de origen. Las reglas son comunes; las ubicaciones y visitas planificadas son por sucursal. Las visitas solo se agendan para la propia cuenta.

El mapa usa Leaflet 1.9.4 local. Las teselas de OpenStreetMap se cargan al pulsar el botón del mapa de calles; nombres, teléfonos y notas permanecen en el navegador. No se geocodifican contactos. Una coordenada del centro no identifica la suite del médico; las referencias públicas iniciales se etiquetan como no verificadas. Los centros sin coordenadas aparecen en la lista y pueden ubicarse manualmente con una fuente y verificación explícita.

Filtros: especialidad (sin distinción de acentos), centro, regla, día y tanda. Disponibilidad desconocida, reglas pendientes, cita previa o atención después de pacientes requieren justificación al guardar. El cupo de representantes se informa como regla del médico: no implica conocer reservas de terceros. Los textos originales prevalecen y deben revisarse cuando haya contradicciones. No se confirma ninguna cita ni se calcula una ruta o tiempo de conducción automáticamente.

La agenda bloquea solapes del responsable tanto entre sucursales del planificador como con la agenda comercial anterior. Bloqueos transaccionales por sucursal y responsable, revisiones optimistas de reglas, solicitud idempotente de planificación y cancelación con motivo preservan el historial. Las acciones de reglas, ubicaciones y agenda generan bitácora. Las visitas no se marcan como realizadas desde este planificador; su realización se registra en la ficha central con evidencia y cuenta autenticada.

La migración es aditiva y no modifica decisiones, autorizaciones ni tablas clínicas. La carga asistida conserva procedencia y fechas históricas por separado; no crea visitas realizadas ni modifica tarifas. El responsable de la cartera es custodio, no se presenta como ejecutor de la importación administrativa. No se almacenan archivos de contactos en GitHub ni en Storage público.

Pruebas: 542 comprobaciones PostgreSQL aisladas; 17 de CRM y 15 del mapa en navegador con datos ficticios; filtros/reglas/calendario unitarios. CI conserva los informes como artefactos. La validación técnica no equivale a aceptación clínica.

Reversión: desactivar `crm_weekly_planner`; las tablas y la cartera permanecen. La lectura del CRM compartido depende de `crm_branch_contacts`, por lo que se debe mantener la migración instalada. No revertir mediante borrado de contactos, fuentes, reglas o planes.
