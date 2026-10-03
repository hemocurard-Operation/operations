# Implementación v0.11.0

Requisito: v0.10.0 funcional.

## Nuevos
- hemocura-core/settings-data.js
- hemocura-core/settings.js

## Modificados
- hemocura-core/views.js
- hemocura-core/layout.js
- css/app.css
- VERSION.json

## Validación
1. Abrir #settings.
2. Confirmar perfil actual.
3. Confirmar roles visibles según RLS.
4. Confirmar sucursales y productos.
5. Ver modo operativo si Producción Caliente está instalado.
6. Ver feature flags.
7. Ejecutar Diagnóstico central.
8. Copiar reporte.
9. Si un objeto marca ERROR, corregir solamente ese subsistema.

## Seguridad
No administrar auth.users desde GitHub Pages.
La creación de usuarios debe hacerse desde Supabase Dashboard/backend seguro.
