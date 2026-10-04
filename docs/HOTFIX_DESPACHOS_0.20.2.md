# Hotfix Despachos v0.20.2

## Errores corregidos

1. `dispatches.reference` no existe.
2. `dispatches.updated_at` no existe.
3. `dispatch_lines.customer_id` no existe.
4. `dispatch_lines.unit_price` no existe.
5. `dispatch_lines.total_amount` no existe.
6. `dispatch_lines.notes` no existe.
7. `vw_dispatch_vs_sale` no existe.
8. filtro `.order('date')` no corresponde al esquema.

## Esquema real usado

### dispatches
- id
- dispatch_date
- branch_id
- customer_id
- shift
- dispatch_type
- status
- notes
- created_by
- created_at
- confirmed_at

### dispatch_lines
- id
- dispatch_id
- product_id
- units
- is_sale
- sale_generated
- created_at

### conciliación
`vw_dispatch_sales_reconciliation`

Campos:
- dispatch_date
- branch_id
- product_id
- dispatched_sale_units
- recognized_sale_units
- difference_units

No requiere ejecutar SQL nuevo.
