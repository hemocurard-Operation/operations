# Super Usuario: acceso completo y administración exclusiva

El Super Usuario recibe todos los permisos activos, incluidos los de módulos futuros, y acceso global a sucursales. ACCESS_ADMIN deja de ser efectivo para otros roles, incluso ante una asignación errónea. El servidor exige identidad autenticada, perfil activo y rol SUPER_USUARIO para administrar cuentas, claves y roles. Los permisos operativos restantes y los alcances existentes de otros roles se conservan.

Usuarios y roles incluye cambio de clave con confirmación y 12–128 caracteres. La clave no se guarda en auditoría y se borra del formulario al cerrar o finalizar. Se registra la solicitud antes de modificar Auth; un fallo inicial de auditoría bloquea el cambio. Si falla la auditoría posterior, se informa que la clave sí cambió. Cambiar una clave no promete invalidar automáticamente sesiones existentes.

Se protege la cuenta global contra retiro de roles propios y contra un segundo titular Super Usuario. No se cambiaron claves reales ni se crearon cuentas durante el despliegue. No se desactivaron controles clínicos o de calidad.

Validación: 47 casos del servidor con SDK simulado, 22 pruebas en PostgreSQL aislado y 6 pruebas de navegador. Verificación en producción: 93 permisos activos y 93 asignados al Super Usuario; cero asignaciones ACCESS_ADMIN a otros roles; un titular global; todas las sucursales accesibles y vista de permisos segura. La prueba autenticada de permisos se ejecutó con rollback, sin cambiar datos de usuarios.
