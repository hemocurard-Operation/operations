# Smoke Tests — v0.2.0

1. `/operations/login.html` carga.
2. Sin configuración, muestra advertencia visible.
3. Con configuración, muestra `Supabase conectado`.
4. Login inválido muestra error visible.
5. Login válido redirige a `/operations/`.
6. Index muestra usuario autenticado.
7. Recargar index conserva sesión.
8. Logout elimina sesión.
9. Console no muestra `HEMOCURA_BOOT_ERROR`.
