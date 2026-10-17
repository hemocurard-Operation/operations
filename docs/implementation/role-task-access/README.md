# Accesos por responsabilidad

La navegación se combina con permisos funcionales y sucursales asignadas. El Super Usuario mantiene todas las ventanas y permisos activos; solo él administra cuentas, claves, roles y la configuración de ventanas. Esta entrega no modifica personas ni sus asignaciones de roles o sucursales.

## Distribución preparada

- Administrador: coordinación administrativa; se retiran capturas clínicas, liberación técnica, laboratorio detallado y administración de capacitación.
- Gerencia Operativa: planificación y seguimiento; conserva información técnica de consulta, sin capturar controles analíticos, cadena de frío, hemovigilancia, recursos o liberar unidades.
- Gerencia General: consulta de aprobaciones e indicadores; se retira el laboratorio detallado.
- Calidad: conserva SGC, auditorías, documentos, CAPA y controles de calidad; la liberación clínica requiere un rol técnico adicional.
- Laboratorio: captura producción y consulta requisiciones; no libera unidades ni abre Despachos.
- Encargada de Laboratorio: gestiona requisiciones, realiza evaluaciones externas de personal técnico de su sucursal y participa en aprobaciones técnicas. No recibe administración de cuentas, puestos o programas de capacitación.
- Médico / Gerente Técnico: consulta producción sin escritura de inventario; puede intervenir en aprobaciones técnicas independientes. No recibe Despachos o Requisiciones.
- Inventario: conserva inventario y abastecimiento; la captura de producción tiene un permiso técnico separado.
- Finanzas: conserva funciones económicas y liquidación de incentivos; se retira Comercial.
- Asistente de Operaciones: registra visitas y compromisos comerciales; no recibe liberación clínica ni cobros.
- Sucursal y Consulta: se retira la implementación del SGC por defecto. Sucursal puede consultar Clientes.
- Socio: indicadores, desempeño y documentos; se retiran Cobranza y Economía detalladas.
- TI: diagnóstico, auditoría y continuidad de consulta; no administra usuarios.
- Logística: conserva Mi trabajo y Viajes fuera de horario.

Las ventanas siguen siendo ajustables por el Super Usuario. Activar una ventana no otorga automáticamente permisos de datos. Las cuentas con varios roles combinan sus atribuciones. Para validar un puesto debe usarse una cuenta sin Super Usuario.

## Controles de datos

Producción, inventario sanguíneo, requisiciones y proveedores requieren permisos de función. Producción separa PRODUCTION_VIEW y PRODUCTION_WRITE; requisiciones usan REQUISITION_VIEW y REQUISITION_WRITE. La pertenencia a una sucursal ya no basta para modificar esos registros. Los borrados de estas cuatro tablas se limitan al Super Usuario; las anulaciones operativas existentes siguen disponibles.

El ámbito de sucursales se obtiene de las asignaciones explícitas y la sucursal del perfil activo. Los roles gerenciales heredados ya no implican acceso automático a futuras sucursales. El Super Usuario conserva acceso global.

Las vistas que dependen de las tablas protegidas se ejecutan con los permisos del usuario. Los informes quedan sujetos al ámbito de datos autorizado; un rol con varios permisos combina su información accesible.

La liberación técnica no permite cambiar la identidad, el componente o los datos de inventario. Se preservan la revisión independiente, las pruebas validadas, la evidencia y los bloqueos clínicos. La captura de producción no autoriza por sí misma disponibilidad clínica. Un resultado nuevo pendiente o reactivo mantiene la cuarentena mediante un trigger privado de seguridad, incluso si el ejecutor no administra inventario.

## Aprobaciones

Las solicitudes, decisiones y políticas no admiten escritura directa desde el cliente. Las tres APIs públicas conservan SECURITY INVOKER; delegan exclusivamente las transacciones controladas a funciones privadas con permisos explícitos. Estas comprueban perfil activo, permiso funcional, sucursal y segregación. Las decisiones requieren APPROVAL_DECIDE y el permiso de la acción; la ejecución requiere APPROVAL_EXECUTE, el permiso funcional, decisiones reales y un ejecutor distinto del solicitante. Las políticas no se cambian desde el navegador.

La liberación clínica se reserva a Encargada de Laboratorio, Médico / Gerente Técnico y Super Usuario. Tener varios roles no permite autoaprobarse. La identidad del evaluador de competencias proviene de su sesión. COMPETENCY_ASSESS permite nuevas evaluaciones externas de personal técnico asignado a la sucursal; no permite editar catálogos, puestos, evaluaciones históricas ni personal de otras áreas.

## Validación

Pruebas locales: 324 escenarios PostgreSQL, 45 de ventanas y acciones, y 23 del editor. La aplicación en producción requiere autorización específica; no está realizada en esta entrega preparada.

- Reconstrucción PostgreSQL desechable con datos ficticios: escenarios permitidos y denegados, sucursales, aprobaciones, evaluaciones y regresión clínica.
- Navegador local: ventanas de los 16 roles, acciones de consulta/captura, independencia y editor exclusivo del Super Usuario.
- Linter SQL, sintaxis y contrato de fuente canónica.
- Auditoría de metadatos de producción posterior a la migración, sin crear operaciones o cuentas de prueba reales.

El fixture `tests/role-tasks/catalog-prerequisite.sql` reconstruye los catálogos históricos que precedían al repositorio. Es exclusivamente local y nunca se aplica como migración de producción. El contrato actual es `contracts/role-task-access-defaults.json`; el contrato histórico de la migración inicial de ventanas se conserva por separado.
