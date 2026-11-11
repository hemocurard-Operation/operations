# Agenda comercial integrada y reservas entre orígenes

La Agenda Comercial agrega las visitas de `crm_weekly_visits` a sus fuentes anteriores. Cada evento conserva tabla de origen e ID: no se insertan copias en `commercial_visits`. Los estados históricos y cancelados se conservan; consultar el calendario no confirma citas ni registra visitas realizadas.

## Contrato y alcance

`commercial_agenda(p_branch uuid)` es un wrapper público SECURITY INVOKER sobre una implementación privada. Requiere el mismo acceso comercial por sucursal del CRM. Devuelve `enabled` y una lista de visitas CRM con nombre profesional, centro, especialidad y responsable. Exige que el contacto pertenezca a esa sucursal o esté explícitamente compartido. No incorpora identificadores de pacientes ni notas clínicas.

El flag `commercial_agenda_union` está apagado por defecto y controla la agregación visible. Si la fuente del mapa falla, la interfaz debe advertir que la agenda está incompleta y conservar las fuentes disponibles. Un resultado de carga incompleta no equivale a cero visitas.

La nueva vista de lectura enlaza al editor de origen para el mapa. Las acciones de cliente, proyectos y red médica continúan usando sus contratos y permisos existentes. Las fechas con hora se interpretan en Santo Domingo; una fecha sin hora de lanzamiento/actividad conserva su fecha de negocio.

## Integridad de reservas

Dos triggers BEFORE, uno por tabla, comparten una función privada de restricción. Adquieren el mismo bloqueo transaccional por responsable que usa el planificador CRM. En comandos separados después del bloqueo comprueban reservas activas de ambas tablas; la función es VOLATILE para usar un snapshot actualizado en READ COMMITTED.

- Commercial: las visitas REALIZADA o CANCELADA no reservan tiempo futuro.
- CRM: únicamente PLANIFICADA reserva tiempo.
- Intervalos `[inicio, fin)`: citas adyacentes son válidas.
- La exclusión de la propia fila considera tabla e ID; un mismo UUID en otra fuente no se ignora.
- El control se aplica a todas las sucursales de un responsable.
- Cambios que no alteran la reserva y transiciones a estado final no invalidan registros históricos.
- No se modifican firmas, parámetros ni retornos de las RPC existentes.

La validación de reservas está activa al instalar la migración, independientemente del flag visual. Apagar la vista integrada no elimina la protección ni ningún registro. En nuevas colisiones el trigger devuelve SQLSTATE 23P01; el precontrol existente del planificador puede devolver P0001. La interfaz presenta el motivo del servidor sin declarar éxito.

## Despliegue y pruebas

Aplicar la migración después de pruebas aisladas; publicar y verificar los archivos de la interfaz antes de activar el flag LIVE_LIMITED. No se crean citas de demostración en producción. Si existieran solapes previos, se conservan para revisión humana; la migración no los reprograma ni cancela automáticamente.

Pruebas: suite de regresión PostgreSQL, casos negativos con SQLSTATE explícito y sesiones concurrentes reales en un contenedor desechable sin red; además, pruebas de navegador con fuentes sintéticas, orígenes/IDs, estados, carga parcial, permisos, horario RD y móvil. La aceptación de este flujo comercial no sustituye aprobación clínica.

Validación final: 623 comprobaciones PostgreSQL sobre 99 archivos, incluidas cinco intercalaciones sincronizadas entre sesiones, y 29 pruebas de navegador con datos ficticios. Se conservó la publicación concurrente de cotizaciones de proveedores. Los lanzamientos corporativos tienen alcance global autorizado y se rotulan para distinguirlos de las visitas por sucursal.
