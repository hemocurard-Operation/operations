# Diagnóstico v0.6.0

Esperado:
[HEMOCURA_ROUTER] dispatches
[HEMOCURA_VIEW] dispatches
[HEMOCURA_DISPATCH] dispatches
[HEMOCURA_DISPATCH_RECON]
[HEMOCURA_DISPATCH] módulo OK

Detalle:
[HEMOCURA_DISPATCH_DETAIL]

Error:
[HEMOCURA_DISPATCH_ERROR]

Interpretación:
- relation does not exist → objeto SQL faltante;
- permission denied → grants/RLS;
- lista carga pero conciliación falla → vista vw_dispatch_vs_sale no disponible;
- detalle falla → revisar dispatch_lines.
