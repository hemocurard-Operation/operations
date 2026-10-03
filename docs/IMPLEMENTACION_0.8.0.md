# Implementación v0.8.0

Requisito: v0.7.0 funcional.

## Nuevos
- hemocura-core/costs-data.js
- hemocura-core/costs.js

## Modificados
- hemocura-core/views.js
- hemocura-core/layout.js
- css/app.css
- VERSION.json

## GitHub.com
Use preferiblemente el PATCH.

No reemplace:
- js/config.js
- auth.js
- supabase.js
- login.html

## Validación
1. Abrir #costs.
2. Confirmar períodos.
3. Confirmar vw_monthly_product_costs.
4. Confirmar price_versions.
5. Abrir período.
6. Ver entradas.
7. En período editable, probar Recalcular costos.
8. Confirmar que los costos se actualizan.
9. Verificar que precio bajo costo quede resaltado.

## Alcance
No aprueba ni cierra períodos desde la UI.
