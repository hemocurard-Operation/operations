# Diagnóstico v0.4.0

Cadena correcta:
[HEMOCURA_BOOT] OK
[HEMOCURA_ROUTER] dashboard
[HEMOCURA_VIEW] dashboard
[HEMOCURA_DASHBOARD] consultando vw_command_center_today
[HEMOCURA_DASHBOARD] consultando vw_open_management_alerts
[HEMOCURA_DASHBOARD] datos OK

Errores:
- `[HEMOCURA_DASHBOARD_ERROR] command center`
- `[HEMOCURA_DASHBOARD_ERROR] alerts`

Interpretación:
- relation does not exist → SQL/vista faltante.
- permission denied → grant/RLS.
- Failed to fetch → red/conexión/config.
- 401 → sesión/Auth.
- 403 → RLS/permisos.
