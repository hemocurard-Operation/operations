# HemoCura 0.69.0 — cierre técnico operacional

Se aplicaron las dos migraciones que estaban pendientes y una migración de navegación. Las versiones de los archivos coinciden con el historial real de Supabase; las cinco vistas nuevas mantienen `security_invoker=true`. La auditoría de seguridad no añade hallazgos respecto de la verificación previa; los avisos existentes no se declaran resueltos por esta entrega.

## Pantallas disponibles

- **Previsión operativa:** cobertura de insumos con nombres de producto, estimación de donantes, expediente de equipos y alertas de contadores. Consulta por sucursal, paginación y limpieza de cifras al cambiar de sucursal o fallar una fuente.
- **Matriz regulatoria:** requisitos en borrador y evaluación por sucursal; captura de evidencia y verificación independiente. La evaluación operativa no firma la aprobación legal de una norma.
- **Habilitaciones sanitarias:** acceso desde el menú según permiso y sucursal.
- **Metas operativas:** métricas implementadas de actividad, sin opciones monetarias; los datos sin cálculo se muestran como tales y las metas en borrador se identifican.
- **Pantallas por usuario:** permite abrir los componentes y formularios reales con los permisos del perfil seleccionado. La simulación usa un marco de origen opaco (`sandbox=allow-scripts`), un adaptador sin conexión, CSP sin conexiones de datos ni envío de formularios y guardado deshabilitado. No carga registros reales ni usa tokens de ese usuario. El acceso a las pantallas originales con la sesión propia del administrador continúa separado y rotulado.

Los roles y alcances siguen validándose en el servidor. La simulación describe disponibilidad de pantallas y formularios; los controles que dependan del estado de un registro requieren comprobar ese registro con una cuenta autorizada. Las pantallas de cuentas, claves y configuración se consultan en su vista original; no se simulan operaciones administrativas sensibles.

## Cierres que requieren responsables o configuración externa

- Siete reglas clínicas siguen sin firma médica; no entran en vigor automáticamente.
- Once requisitos normativos siguen sin aprobación legal. Su existencia en la matriz no los convierte en dictamen jurídico.
- Los dos últimos respaldos programados consultados estaban omitidos. Este entorno no contiene las cuatro configuraciones necesarias. El workflow ahora valida su presencia antes de instalar o exportar y nunca imprime valores. El procedimiento está en `ACTIVAR_RESPALDOS_PRIVADOS.md`. Falta configurar destino y credenciales, comprobar copia cifrada y realizar restauración aislada; no se ha marcado una recuperación real como verificada.

Finanzas continúa fuera del despliegue. No se realizaron pagos, cambios clínicos ni movimientos de inventario reales para probar.

## Validación

Pruebas con esquema integrado en PostgreSQL desechable; pruebas de navegación, aislamiento de formularios, denegación de escritura, paginación y captura regulatoria con datos sintéticos. Los archivos aplicados se contrastan mediante SHA256 y la publicación se verifica contra los archivos locales. `js/config.js` permanece intacto.
