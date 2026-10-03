# Implementación v0.7.0

Requisito: v0.6.0 funcional.

## Nuevos
- hemocura-core/inventory-data.js
- hemocura-core/inventory.js

## Modificados
- hemocura-core/views.js
- hemocura-core/layout.js
- css/app.css
- VERSION.json

## GitHub.com
Usar preferiblemente PATCH.

No reemplazar:
- js/config.js
- auth.js
- supabase.js
- login.html

## Pruebas
1. Abrir #inventory.
2. Confirmar carga de vw_inventory_status.
3. Confirmar políticas.
4. Confirmar movimientos.
5. Abrir Conteo físico.
6. Guardar un conteo.
7. Verificar physical_qty y variance.
8. Validar RLS por sucursal.

## Alcance clínico
FEFO por unidad NO se activa aquí.
