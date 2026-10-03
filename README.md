# HemoCura Operations v0.8.0

Etapa: Costos, precios y rentabilidad.

## Fuentes reales
- monthly_cost_periods
- monthly_cost_entries
- vw_monthly_product_costs
- price_versions
- products
- branches
- RPC calculate_monthly_product_costs(uuid)

## Cadena
#costs
→ views.js
→ costs.js
→ costs-data.js
→ supabase.js
→ Supabase

## Funciones
- períodos mensuales;
- costo unitario por producto;
- comparación contra costo previo;
- precio vigente;
- margen unitario y %;
- señal de precio bajo costo;
- detalle de entradas de costo;
- recálculo del período vía RPC.

## Importante
Esta versión NO aprueba ni cierra períodos.
La aprobación financiera sigue siendo una acción separada.
