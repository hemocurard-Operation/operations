# Ventanas por rol y área

La activación de ventanas complementa los permisos funcionales existentes. La barra lateral, Mi trabajo y las etapas enlazadas de Ruta operativa utilizan la configuración efectiva del usuario. Antes de abrir una ruta se vuelve a consultar la política del servidor; una ruta desactivada no abre desde el menú ni desde su enlace directo en la aplicación. No se permite por defecto una ruta desconocida ni se ignora un error al leer la política.

## Distribución inicial

| Perfil | Ventanas disponibles con sus permisos actuales | Trabajo priorizado |
| --- | ---: | --- |
| Super Usuario | 62 | Todos los módulos y administración exclusiva |
| Asistente de Operaciones | 19 | Donantes, pedidos, recepción, suministros, clientes y comercial |
| Laboratorio | 19 | Reporte diario, donantes, tamizaje, disponibilidad y calidad |
| Encargada de Laboratorio | 24 | Laboratorio, seguimiento, calidad y recepción autorizada |
| Inventario | 16 | Insumos, catálogo, requisiciones, compras, sangre y transferencias |
| Finanzas | 12 | Ventas, cobranza, economía, clientes y compras |
| Calidad | 22 | SGC, calidad diaria, auditorías, acciones y controles |
| Gerencia Operativa | 31 | Coordinación de la operación y seguimiento |
| Gerencia General | 21 | Resultados, clientes, gestión y revisión |
| Administrador | 51 | Gestión amplia; controles de identidad siguen exclusivos del Super Usuario |
| Socio | 9 | Resumen, ventas, resultados y documentos autorizados |
| Médico / Gerente Técnico | 21 | Procesos clínicos y servicio hiperbárico autorizado |
| Sucursal | 17 | Operación diaria de su ámbito |
| Consulta | 9 | Consulta y documentos autorizados |
| TI | 1 | Capacitación; no se otorgan permisos técnicos nuevos |

La lista exacta inicial se encuentra en `contracts/role-module-defaults.json`. Los conteos corresponden a la intersección de los módulos iniciales con los permisos existentes al desplegar; pueden cambiar al configurar roles. Las personas con varios roles combinan sus ventanas habilitadas. Las sucursales siguen sujetas a las restricciones de datos existentes.

## Ajustar la distribución

El Super Usuario entra a **Seguridad y Acceso → Módulos por rol**, selecciona un rol, busca el módulo, marca o desmarca su activación y guarda los cambios. El editor indica cuándo el rol no tiene el permiso de datos necesario. Activar una ventana no concede ese permiso ni permite crear usuarios o asignar roles.

El Super Usuario conserva todas las ventanas. Su configuración está bloqueada en la interfaz y en la base de datos; Usuarios y Seguridad no pueden habilitarse para otro rol. La API de guardado es `SECURITY INVOKER` y sus cambios están sujetos a RLS y a un trigger interno que verifica al actor activo. Cada cambio guarda antes/después, responsable y fecha. Los conflictos de revisión revierten todo el lote y su auditoría; no se descartan silenciosamente los cambios pendientes del editor.

La nueva configuración se aplica en la siguiente comprobación de navegación. Las otras sesiones deben recargar para reconstruir su menú. Si Mi trabajo está desactivado, el inicio lleva a la primera ventana disponible. Las rutas de las ventanas no constituyen una revocación de los permisos de datos: la política no modifica `role_permissions`, `has_permission`, los controles de las tablas clínicas ni los permisos que usan las API existentes. El acceso a datos y acciones continúa protegido por esos controles.

No se crean cuentas, no se cambian contraseñas ni asignaciones de usuario y no se modifica la base de donantes. Se utilizan vistas con `security_invoker=true` y tablas con RLS. El historial de configuración no admite cambios desde el cliente.

## Pruebas

- `python tools/module_views_postgres_runner.py`: autorización real de ventanas, RLS, permisos separados, exclusividad del super, auditoría y lotes atómicos.
- `node tools/module_views_browser_runner.cjs`: menú/tareas por área, enlaces directos, revocación sin reiniciar caché, configuración y móvil.
- `python tools/workflow_postgres_runner.py --allow-external-prerequisite-fixture`: compatibilidad con el esquema completo.
- Regresiones de navegador existentes de donantes, coordinación, operación y 77 controles generales de interfaz.

Todas las pruebas locales usan registros sintéticos y bases desechables sin red; no ejecutan operaciones clínicas de prueba en producción.
