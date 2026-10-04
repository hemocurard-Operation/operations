# Smoke Test Despachos

1. Abrir #dispatches.
2. No debe aparecer `dispatches.reference does not exist`.
3. No debe aparecer `vw_dispatch_vs_sale`.
4. Lista de despachos carga.
5. Filtros fecha/sucursal/estado funcionan.
6. Detalle abre sin columnas inexistentes.
7. Conciliación usa `vw_dispatch_sales_reconciliation`.
8. Diferencia 0 muestra OK.
9. js/config.js no se modifica.
