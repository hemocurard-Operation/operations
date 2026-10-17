# Gestión del Laboratorio

Ruta: `index.html#laboratory`, dentro de Laboratorio y Sangre. La ventana reúne Mi turno, Unidades en proceso, Controles, Equipos y reactivos, Cadena de frío, Equipo y agenda, Informe gerencial e Historial. No crea registros clínicos de demostración en producción.

## Jornada de la encargada

1. Seleccionar sede, fecha operativa y turno. Los pendientes son el estado actual, no una reconstrucción histórica del turno seleccionado.
2. Revisar prioridades y asignar seguimiento con responsable, plazo y evidencia. La agenda mantiene la revisión independiente y los vencimientos originales.
3. Registrar métodos pendientes, verificación con criterios y resultados, y revisión independiente antes de aprobar el método. Configurar límites y frecuencia IQC según el procedimiento aprobado; registrar resultados. La clasificación de fuera de control utiliza esos límites y requiere investigación humana.
4. Registrar programa y evento EQA/PT, luego el informe del proveedor. Un resultado no satisfactorio exige investigación y no se cierra automáticamente.
5. Registrar servicios y certificados de equipos. Un servicio no conforme deja el equipo fuera de servicio; uno conforme actualiza la próxima fecha aplicable, sin devolver automáticamente equipos fuera de servicio a operación.
6. Registrar lotes pendientes; otro revisor autorizado documenta su aprobación, rechazo o cuarentena. Un lote vencido no puede aprobarse.
7. Registrar dispositivos y lecturas térmicas, salida y recepción de transportes. La recepción fuera de rango o no conforme queda en cuarentena. Las lecturas históricas no se borran al resolver su seguimiento.
8. Revisar competencias y carga asignada antes de distribuir tareas técnicas. El relevo es una tarea de Laboratorio con evidencia y revisión por otra persona.
9. Consultar el informe gerencial y asignar compromisos. Si alguna fuente falla o está deshabilitada, se identifica la ausencia y se impide exportar un informe completo.

## Liberación y registros históricos

La liberación requiere usuario activo, sede autorizada y UNIT_RELEASE, justificación y evidencia. APTO exige pruebas registradas validadas/no reactivas, independencia respecto del ejecutor identificado y componentes con vencimiento informado y vigente. El sistema no define ni certifica una batería clínica completa: el revisor debe comprobarla contra el procedimiento vigente antes de confirmar. No hay liberación automática. Una nueva prueba pendiente o reactiva devuelve unidades disponibles o reservadas a cuarentena. La escritura directa de APTO en inventario exige una decisión técnica vigente.

Los registros históricos no reciben autores inventados. La validación de pruebas o aprobación de lotes antiguos sin autor identificado no se ofrece como revisión independiente; deben regularizarse con evidencia y el procedimiento aplicable. Los resultados indeterminados permanecen fuera de una decisión APTO. El permiso técnico UNIT_RELEASE sigue siendo suficiente para el revisor autorizado, sin exigirle administración de inventario.

## Permisos y seguridad

El rol ENCARGADA_LABORATORIO obtiene DISPATCH_VIEW, APPROVAL_VIEW, QUALITY_WRITE y QUALITY_DAILY_REVIEW. Son permisos operativos; no incluyen administración de cuentas ni roles. Se mantiene el acceso total del Super Usuario. La nueva visibilidad por rol se administra con el editor existente. Los módulos deshabilitados no se consultan desde esta ventana.

La API lab_operation usa SECURITY INVOKER y las políticas de las tablas validan identidad activa, permiso de lectura/escritura y sede canónica, incluyendo hijos por su padre. No se utiliza SECURITY DEFINER para superar errores de permisos. La función privada de auditoría es solo de trigger, tiene search_path fijo y EXECUTE revocado a clientes. Conserva antes/después, actor, entidad y fecha en lab_event_log; los clientes tienen solo SELECT. Las revisiones de método, lotes y pruebas requieren otra persona; las actualizaciones de formularios existentes comparan la copia anterior para evitar sobrescritura silenciosa.

Las listas de los módulos de sangre, control analítico, recursos y frío recorren todas las páginas del servidor, avanzando por el tamaño realmente recibido. Los totales no se limitan silenciosamente a los primeros 300/500 registros. La vista presenta lotes progresivos para facilitar su uso.

## Validación

Pruebas en PostgreSQL aislado: permisos del rol real, sedes, lectura/escritura, autoría inmutable, autovalidación, método y revisión, IQC, lotes, EQA, equipos, transporte, liberación, cuarentena y auditoría. Pruebas de navegador con datos ficticios: 512 pruebas, formularios, errores conservando borrador, relevo, exportación completa/parcial, lectura por rol y vista móvil. Regresiones de la ruta operativa y Calidad; sintaxis, contratos, fuente de verdad y linter de migraciones. Los informes locales no equivalen a validación clínica ni acreditación.
