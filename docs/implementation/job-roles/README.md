# Puestos de cámara hiperbárica y asistencia comercial

Se añaden CAMARISTA_HIPERBARICA (Camarista de cámara hiperbárica) y ASISTENTE_COMERCIAL (Asistente comercial) al catálogo. No se crean cuentas, no se asignan personas ni se generan autorizaciones clínicas.

El camarista puede gestionar citas y documentar sesiones con HYPERBARIC_SESSION_WRITE. La función existente exige referencias de autorización clínica, consentimiento y evidencia, fecha válida y sucursal autorizada, y atribuye la sesión a la cuenta que la registra. Estas referencias deben verificarse por el personal responsable; no son una validación automática de habilitación profesional ni una decisión clínica del sistema. Tiene identidad del paciente para la operación clínica autorizada, capacitación y jornada de Cámara hiperbárica. No factura, cobra, administra usuarios ni libera hemocomponentes.

El asistente comercial gestiona visitas, compromisos, oportunidades y calendario, consulta clientes y red médica, y dispone de jornada Comercial y capacitación. No recibe permisos de sesiones, identidad de pacientes hiperbáricos, facturación, cobros ni administración.

Los accesos siguen limitados a las sucursales asignadas a cada cuenta. Varias personas pueden compartir cada rol. El Super Usuario asigna los puestos desde Usuarios y roles a cuentas personales verificadas.

Pruebas: tests/job-roles/business.sql se ejecuta al final de la reconstrucción aislada de tools/workflow_postgres_runner.py. Incluye sesión ficticia válida, rechazo por falta de autorización/consentimiento/evidencia, exclusión de otra sucursal y ausencia de acceso clínico para el asistente. La suite integrada alcanza 484 comprobaciones sobre 93 archivos. No constituye UAT ni aprobación clínica humana.
