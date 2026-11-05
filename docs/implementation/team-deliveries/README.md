# Entregas del equipo

Módulo aditivo: supervisor asigna y propone relevo; el nuevo conductor acepta; los conductores consultan las entregas del equipo en sus sucursales y ejecutan solo las propias. Laboratorio de destino registra verificación logística independiente. No existen tomas libres de entregas.

Los traslados se seleccionan desde transport_events activos; el conductor debe tener DELIVERIES_DRIVE tanto en origen como en destino. La interfaz no expone notas clínicas, pacientes ni incentivos. La cuenta personal autentica cada acción, con revisión optimista, idempotencia y bitácora atómica. No se crean ni se reasignan usuarios automáticamente.

La recepción logística NO modifica transport_events, no constituye recepción clínica ni libera hemocomponentes. Una temperatura fuera del rango del traslado genera INCIDENCIA_RECEPCION en la coordinación; el laboratorio conserva su obligación de registrar y gestionar la recepción clínica en Cadena de frío. Los incentivos siguen en Viajes fuera de horario.

## Activación y reversión
La migración instala team_delivery_coordination apagado. Activación piloto: habilitar la bandera y team_delivery_pilot solo para la sucursal de origen Santiago. Las entregas hacia otras sucursales autorizadas pueden completarse. Sin piloto habilitado no hay mutaciones. Apagar la bandera bloquea nuevas acciones y mantiene la consulta/historial; no eliminar tablas ni datos para revertir.

## Permisos
DELIVERIES_VIEW: roles de logística, laboratorio, encargada y superusuario. DELIVERIES_ASSIGN: supervisor y superusuario. DELIVERIES_DRIVE: conductores, logística, supervisor y superusuario; un conductor elegible debe estar asignado a ambos extremos. DELIVERIES_RECEIVE: laboratorio, encargada y superusuario; el conductor no puede recibir su propia entrega. Todos requieren perfil activo.

Funciones públicas SECURITY INVOKER; implementación privilegiada en esquema privado, con comprobaciones de usuario, permisos y sucursal. RLS en las tres tablas; ningún acceso anónimo ni mutaciones directas del navegador.

## Validación
28 comprobaciones PostgreSQL aisladas con usuarios ficticios, incluyendo carrera de reasignación y reintentos; 13 comprobaciones de navegador; nueve pruebas de regresión de incentivos. No equivalen a UAT clínica.

Ejecutar tools/team_delivery_postgres_runner.py (Docker PostgreSQL17 con red desactivada y datos en tmpfs) y tools/team_delivery_browser_runner.cjs (Chromium/Playwright local con SDK ficticio).
