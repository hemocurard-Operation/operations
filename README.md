# HemoCura Operations v0.5.0

Etapa: Ventas operativas.

## Fuentes reales
- `daily_sales`
- `vw_sale_lines_editable`
- `branches`
- RPC `adjust_sale_line`

## Cadena
#sales
→ views.js
→ sales.js
→ sales-data.js
→ supabase.js
→ Supabase

## Funciones
- filtros por período, sucursal y estado;
- totales de unidades, ingresos, costo y margen;
- detalle por producto/cliente;
- origen de la venta;
- ajuste controlado de unidades;
- motivo obligatorio;
- refresco después del ajuste.

No se crea venta manual todavía.
