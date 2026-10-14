# Creación y activación de cuentas

Se corrige el modo administrativo con clave temporal: la cuenta queda habilitada inmediatamente (email_confirm=true) y se preservan los caracteres exactos de la clave. La interfaz explica que ese modo no envía correo y conserva el mensaje de resultado tras refrescar la lista. El modo invitación solicita un correo y utiliza el enlace HTTPS de HemoCura, que permite definir la clave y entrar. Se eliminan tokens/códigos de la URL tras inicializar la sesión y se borran los campos de clave al finalizar.

La autorización por sucursal reconoce las asignaciones explícitas de roles y conserva los alcances globales existentes. Tener una segunda sucursal no otorga ACCESS_ADMIN. La administración de usuarios continúa siendo exclusiva del Super Usuario activo.

La configuración de Auth apunta al sitio real y permite el callback de activación. El registro público permanece cerrado. La cuenta afectada se habilitó mediante la API administrativa, sin modificar su clave ni sus roles. No se publican datos personales en este informe.

El envío fiable de correos requiere un proveedor SMTP configurado. La configuración actual no dispone de SMTP propio; esta dependencia se comunicó al usuario y no se afirmó entrega de correos.

Validación: 49 pruebas del servidor con SDK simulado; 25 comprobaciones PostgreSQL aisladas; 11 pruebas del navegador para administración y activación. Se comprobó en producción que el rol de operaciones accede a sus tres sucursales asignadas y no recibe privilegios administrativos. No se intentó adivinar contraseñas ni se registraron claves o enlaces privados.
