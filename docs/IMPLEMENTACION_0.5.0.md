# Implementación v0.5.0

## Requisito
v0.4.0 funcionando.

## Archivos NUEVOS
- `hemocura-core/sales-data.js`
- `hemocura-core/sales.js`

## Archivos MODIFICADOS
- `hemocura-core/views.js`
- `hemocura-core/layout.js`
- `css/app.css`
- `VERSION.json`

## GitHub.com
Use preferiblemente `Hemocura_v0_5_0_PATCH.zip`.

No reemplace:
- `js/config.js`
- `auth.js`
- `supabase.js`
- `login.html`

## Validación
1. Login.
2. Abrir Ventas.
3. Debe consultar `daily_sales`.
4. Seleccionar filtros.
5. Abrir detalle.
6. Debe consultar `vw_sale_lines_editable`.
7. En BORRADOR/REABIERTO, probar ajuste con motivo.
8. Confirmar que el total se recalcula en Supabase.

## Nota
La RPC `adjust_sale_line()` controla permisos y estado.
Si una venta está CONFIRMADA/CERRADA, el sistema puede rechazar el ajuste según el rol.
