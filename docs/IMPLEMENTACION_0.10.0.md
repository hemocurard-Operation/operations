# Implementación v0.10.0

Requisito: v0.9.0 funcional.

## Nuevos
- hemocura-core/planning-data.js
- hemocura-core/planning.js

## Modificados
- hemocura-core/views.js
- hemocura-core/layout.js
- css/app.css
- VERSION.json

## SQL requerido
Debe estar instalado el módulo de planificación v7:
- operational_plans
- operational_plan_lines
- forecast_snapshots
- vw_plan_vs_actual
- vw_plan_vs_actual_status
- refresh_forecasts(date)

## GitHub.com
Use preferiblemente PATCH.

No reemplazar:
- js/config.js
- auth.js
- supabase.js
- login.html

## Validación
1. Abrir #planning.
2. Verificar planes.
3. Verificar Plan vs Real.
4. Presionar Actualizar forecast.
5. Confirmar snapshots 7/15/30.
6. Crear un plan DRAFT.
7. Confirmar primera línea.
8. Revisar RLS por sucursal.

Forecast continúa en SHADOW.
