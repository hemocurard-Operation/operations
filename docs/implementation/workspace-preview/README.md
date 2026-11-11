# Áreas de trabajo por usuario · 0.57.0

En Usuarios y roles, el Súper Usuario abre **Ver áreas de trabajo** junto a una cuenta. La vista permite seleccionar otra persona, revisar sus módulos agrupados y las tareas priorizadas de Mi trabajo, consultar el permiso de entrada de un área y actualizar la configuración. Cerrar conserva la sesión y la pantalla administrativa.

Cada apertura/actualización consulta el endpoint administrativo existente: este valida en servidor actor activo, rol SUPER_USUARIO y ACCESS_ADMIN. La interfaz verifica además la identidad del administrador devuelta. Las lecturas posteriores usan su JWT y las RLS existentes para catálogo de módulos, configuración por rol, permisos activos y asignaciones de permisos. Consulta todos los lotes de 500 y falla sin mantener una vista previa obsoleta si hay un error. No añade permisos SQL, RPCs, usuarios, contraseñas ni suplantación de sesión.

La proyección reproduce la unión de permisos y módulos de varios roles, los permisos activos, el perfil activo, las rutas del cliente y las excepciones administrativas. Las tareas comparten la función de ordenación utilizada por Mi trabajo. Las sucursales mostradas son las asignadas a roles; no se presenta esa lista como evaluación completa de can_access_branch y sus alcances heredados.

Es una **vista previa de navegación y tareas**, no una sesión operativa del empleado: no abre formularios, registros ni indicadores con las credenciales del Súper Usuario fingiendo que pertenecen a otra cuenta. Agenda personal, resultados, botones de mutación y restricciones por registro se verifican en la sesión real. Los perfiles inactivos o sin configuración no heredan los accesos del administrador.

Validación: tests de combinación de roles/exclusividad, perfiles inactivos y permisos deshabilitados; navegador con selección, aislamiento de rutas, actualización/revocación, errores, escape HTML, restricción del llamador y móvil; CI Chromium/Firefox/WebKit. Todas las capturas de prueba usan personas y sucursales ficticias.
