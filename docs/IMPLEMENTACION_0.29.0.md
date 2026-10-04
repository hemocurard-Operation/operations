# HemoCura v0.29.0

## Instalación
1. Confirmar que `js/config.js` real sigue funcionando.
2. Subir SAFE PATCH v0.29.0.
3. Ejecutar `sql/29_ACCESS_GOVERNANCE_v0_29.sql`.
4. Cerrar sesión y volver a entrar.
5. Confirmar que el menú cambia según el rol.
6. Abrir `#security` con usuario ADMIN.
7. Probar con un usuario SUCURSAL/CONSULTA.
8. Confirmar que una ruta sin permiso muestra Acceso denegado.
9. Ejecutar `#releasegate`.
10. Ejecutar `#qa`.

## Importante
La visibilidad del menú es UX. La seguridad real continúa dependiendo de RLS y permisos en Supabase.
