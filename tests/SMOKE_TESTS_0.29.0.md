# Smoke Tests v0.29.0

1. SQL 29 instala.
2. Usuario ADMIN ve todas las rutas.
3. Usuario CONSULTA no ve rutas críticas.
4. Navegar manualmente a una ruta no autorizada muestra Acceso denegado.
5. `vw_my_security_context` devuelve usuario/roles/permisos.
6. `vw_my_access` devuelve permisos efectivos.
7. `access_events` registra allowed/denied.
8. `has_permission()` responde según asignación.
9. user_roles sin profile debe reflejar readiness=false.
10. SAFE PATCH no contiene js/config.js.
