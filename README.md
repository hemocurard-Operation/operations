# HemoCura Operations v0.10.0

Etapa: Planificación, Plan vs Real y Forecast.

## Fuentes reales
- operational_plans
- operational_plan_lines
- forecast_snapshots
- vw_plan_vs_actual_status
- RPC refresh_forecasts(date)

## Cadena
#planning
→ views.js
→ planning.js
→ planning-data.js
→ supabase.js
→ Supabase

## Funciones
- planes DAILY/WEEKLY/MONTHLY;
- metas por métrica;
- Plan vs Real;
- semáforo GREEN/YELLOW/RED;
- forecast 7/15/30 días;
- refresco del forecast;
- creación de plan DRAFT + primera línea.

## Forecast
Modo: SHADOW.
Método inicial: media móvil de 30 días y stock menos forecast.
No usar para decisiones clínicas automáticas.
