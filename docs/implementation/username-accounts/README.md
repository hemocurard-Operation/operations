# Usuarios personales y correo compartido

Un usuario de acceso único identifica cada cuenta. El nombre completo y el correo de contacto pueden repetirse. Roles, sucursales y bitácora siguen vinculados al UUID individual; ninguna autorización se deriva del nombre, correo o user_metadata.

## Compatibilidad
Las cuentas existentes conservan su acceso por correo y contraseña. Las cuentas nuevas con username usan un identificador interno reservado bajo login.hemocura.invalid para Supabase Auth, sin correos salientes. La conversión canónica es compartida entre el formulario de acceso y admin-users. No hay un servicio público que revele el correo de una cuenta ni un sistema nuevo de verificación de claves. Auth conserva la validación de contraseñas, sesiones y límites de solicitudes.

user_account_contacts guarda el username único, contacto no único, creador y fecha. Solo el Super Usuario autenticado puede provisionar mediante admin-users. RLS permite consultar únicamente la propia identidad o el catálogo al Super Usuario; no hay escrituras de navegador ni lectura anónima.

## Uso
Crear usuario: nombre completo, usuario de acceso de 3–40 caracteres (letras ASCII, números, punto, guion o guion bajo; comienza con letra), correo de contacto opcional y repetible, rol, sucursales y clave temporal. Estas cuentas usan acceso inmediato sin invitación por correo. Las claves se gestionan con la acción existente del Super Usuario; un correo compartido nunca recibe enlaces de recuperación de estas identidades. La invitación anterior se conserva para cuentas sin username.

Una vez creado, el username no se cambia desde el navegador. Este cambio no migra ni renombra automáticamente cuentas existentes.

## Activación
personal_username_accounts se instala apagado. Primero desplegar la tabla, luego admin-users con ambos archivos index.ts y login-identity.js, después frontend y habilitar la bandera LIVE_LIMITED. Las cuentas existentes no cambian. Para detener nuevas altas por username, apagar la bandera; mantener habilitada la conversión de ingreso para no bloquear cuentas ya creadas. No borrar contactos ni cambiar correos de Auth para revertir.

## Validación
Suite PostgreSQL integrada: 494 comprobaciones sobre 94 archivos, diez nuevas sobre contacto compartido y RLS. Prueba del handler real admin-users con SDK simulado: cuentas distintas, correo repetido, roles distintos, rechazo de duplicados, sesión/permisos, rollback, legado y no registro de contraseñas. Nueve verificaciones de navegador con datos ficticios. Estas pruebas no utilizan contraseñas ni cuentas reales.
