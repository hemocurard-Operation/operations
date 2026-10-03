# Diagnóstico v0.7.0

Esperado:
[HEMOCURA_ROUTER] inventory
[HEMOCURA_VIEW] inventory
[HEMOCURA_INVENTORY] vw_inventory_status
[HEMOCURA_INVENTORY] inventory_policies
[HEMOCURA_INVENTORY_MOVEMENTS]
[HEMOCURA_INVENTORY] módulo OK

Conteo:
[HEMOCURA_INVENTORY_COUNT]

Error:
[HEMOCURA_INVENTORY_ERROR]

Interpretación:
- relation does not exist → objeto SQL faltante.
- permission denied → RLS/grants.
- physical_inventory_counts write denied → rol sin permiso.
- físico no cambia → revisar fecha/sucursal/producto y upsert.
