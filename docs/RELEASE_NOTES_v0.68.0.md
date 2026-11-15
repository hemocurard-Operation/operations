# HemoCura 0.68.0 — operaciones y consulta administrativa

ADMIN y SUPER_USUARIO disponen de **Administración → Pantallas por usuario**. Pueden buscar perfiles, consultar menús y tareas asignados y abrir las pantallas operativas con sus propios permisos. La consulta de metadatos se registra en el servidor. No asume la identidad del usuario ni reproduce su sesión, sus formularios privados o los datos que solo él puede consultar. La administración de cuentas y contraseñas continúa reservada al SUPER_USUARIO.

Se aplicaron nueve migraciones a HEMOCURA (`tiothqiljipdamgudvcb`): limpieza y verificación independiente, metadatos de predicciones, estados de donantes, contadores de equipos, reglas clínicas sin aprobar, clasificación de visitas, habilitaciones, reporte de donantes y consulta administrativa. Los archivos usan las versiones reales del historial de Supabase.

Las limpiezas validan equipo, plan y sucursal. El servidor identifica ejecutor y verificador; el ejecutor no puede verificar su trabajo y el verificador no puede modificarlo. Los contadores se serializan por equipo, rechazan lecturas fuera de orden y usan la lectura más reciente después de un reinicio documentado.

## Pendientes reales

- `regulatory_matrix_ready`: confirmación de la herramienta vencida; no aplicada. Incluye aislamiento por sucursal y revisión independiente.
- `operational_forecasts_ready`: confirmación de la herramienta vencida; no aplicada. Incluye expediente de equipos y proyecciones operacionales sobre `vw_inventory_status`, sin métricas monetarias.
- Las reglas clínicas requieren firma médica; la matriz normativa requiere revisión legal. No se han firmado aprobaciones automáticas.
- Cuentas por pagar, caja, presupuestos y proyección de gastos se trasladaron a `supabase/deferred/financial`, fuera del despliegue normal. La revisión automática rechazó la conciliación financiera por contradecir el alcance operacional; se retiró de la migración y se aplicó únicamente el reporte de donantes. Los borradores financieros conservan limitaciones de autorización y moneda y requieren una revisión propia si el negocio decide retomarlos.

## Validación y límites

708 comprobaciones en PostgreSQL aislado con el esquema integrado y datos sintéticos; 19 comprobaciones de navegador en Chromium. Firefox y WebKit se verifican en CI, que instala sus binarios. Los antiguos fixtures parciales contenían nombres de columnas, UUID y consultas inválidos; los ejecutores ahora usan la reconstrucción integrada. Las pruebas de módulos también se ejecutan contra ese esquema.

No se copiaron registros clínicos a las pruebas. La validación en producción usa historial de migraciones y metadatos; no se realizaron operaciones clínicas, pagos ni movimientos reales para probar.

El antiguo workflow manual de despliegue usaba un historial distinto de Supabase y buscaba servidores regionales por tanteo. Ahora genera solo el plan con hashes, sin credenciales ni cambios directos en producción. El despliegue se hace mediante el conector de migraciones con su historial canónico.
