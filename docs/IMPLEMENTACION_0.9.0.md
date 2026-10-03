# Implementación v0.9.0

Requisito: v0.8.0 funcional.

## Nuevos
- hemocura-core/quality-data.js
- hemocura-core/quality.js

## Modificados
- hemocura-core/views.js
- hemocura-core/layout.js
- VERSION.json

## GitHub.com
Use preferiblemente PATCH.

No reemplazar:
- js/config.js
- auth.js
- supabase.js
- login.html

## Validación
1. Abrir #quality.
2. Confirmar vw_quality_today.
3. Confirmar incidencias.
4. Confirmar no conformidades.
5. Confirmar CAPA.
6. Confirmar alertas.
7. Crear NC con rol CALIDAD/ADMIN/GERENCIA_OPERATIVA.
8. Crear CAPA.
9. Validar RLS.
10. Confirmar que Riesgos aparece como pendiente de esquema.
