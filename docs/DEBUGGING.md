# Diagnóstico v0.8.0

Esperado:
[HEMOCURA_ROUTER] costs
[HEMOCURA_VIEW] costs
[HEMOCURA_COSTS_PERIOD]
[HEMOCURA_COSTS] vw_monthly_product_costs
[HEMOCURA_PRICING] price_versions
[HEMOCURA_COSTS] módulo OK

Recalcular:
[HEMOCURA_COSTS_RECALC]

Errores:
[HEMOCURA_COSTS_ERROR]

Interpretación:
- permission denied → rol financiero/gerencial o RLS.
- relation does not exist → objeto SQL faltante.
- function calculate_monthly_product_costs does not exist → RPC no instalada.
- no hay costos → período no calculado o sin entradas.
- precio bajo costo → revisar price_versions y costo mensual.
