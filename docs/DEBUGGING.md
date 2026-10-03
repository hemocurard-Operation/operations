# Diagnóstico v0.10.0

Esperado:
[HEMOCURA_ROUTER] planning
[HEMOCURA_VIEW] planning
[HEMOCURA_PLANNING] operational_plans
[HEMOCURA_PLAN_VS_ACTUAL]
[HEMOCURA_FORECAST]
[HEMOCURA_PLANNING] módulo OK

Actualizar:
[HEMOCURA_FORECAST_REFRESH]

Errores:
[HEMOCURA_PLANNING_ERROR]

Interpretación:
- relation does not exist → módulo planning SQL no instalado.
- function refresh_forecasts does not exist → RPC no instalada.
- permission denied → RLS/can_access_branch.
- Plan vs Real N/A → métrica aún no soportada por la vista o meta = 0.
- forecast vacío → no hay historial suficiente o no se ejecutó refresh_forecasts.
