# Diagnóstico v0.5.0

Secuencia:
[HEMOCURA_ROUTER] sales
[HEMOCURA_VIEW] sales
[HEMOCURA_SALES] branches
[HEMOCURA_SALES] daily_sales
[HEMOCURA_SALES] módulo OK

Detalle:
[HEMOCURA_SALES_DETAIL] <uuid>

Ajuste:
[HEMOCURA_SALES_ADJUST]

Errores:
[HEMOCURA_SALES_ERROR]

Interpretación:
- permission denied → RLS/grants.
- relation does not exist → vista/tabla faltante.
- function adjust_sale_line does not exist → función SQL no instalada.
- La venta no está editable → estado/rol impide modificación.
- Sin acceso → usuario sin acceso a sucursal.
