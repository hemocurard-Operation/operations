# HemoCura Operations v0.7.0

Etapa: Inventario agregado y conteo físico.

## Fuentes reales
- vw_inventory_status
- inventory_policies
- inventory_movements
- physical_inventory_counts
- branches
- products

## Cadena
#inventory
→ views.js
→ inventory.js
→ inventory-data.js
→ supabase.js
→ Supabase

## Funciones
- stock teórico;
- último conteo físico;
- variación físico vs teórico;
- mínimo configurado;
- semáforo de stock;
- movimientos recientes;
- registro/actualización de conteo físico.

## Alcance
No implementa FEFO clínico por unidad.
Ese módulo sigue en STAGING/SHADOW.
