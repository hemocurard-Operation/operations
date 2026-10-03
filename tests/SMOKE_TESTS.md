# Smoke Tests v0.4.0

1. Login válido.
2. Dashboard abre.
3. Console muestra HEMOCURA_DASHBOARD.
4. vw_command_center_today responde.
5. vw_open_management_alerts responde.
6. Si no hay datos, Dashboard muestra 0 sin fallar.
7. Si alertas falla, Command Center puede seguir mostrando datos.
8. Botón Actualizar funciona.
9. Cambiar a Ventas y volver a Dashboard recarga datos.
10. RLS limita sucursales visibles.
11. Logout funciona.
