# HemoCura Operations v0.4.0

Etapa: Dashboard operativo conectado a Supabase.

## Fuentes reales

- `vw_command_center_today`
- `vw_open_management_alerts`

## Cadena

index.html
→ js/app.js
→ bootstrap.js
→ auth.js
→ layout.js
→ views.js
→ dashboard.js
→ data.js
→ supabase.js
→ Supabase

## Regla de diagnóstico

Si el layout abre pero Dashboard falla:
1. F12 → Console.
2. Buscar `[HEMOCURA_DASHBOARD_ERROR]`.
3. Revisar Network.
4. Confirmar que las vistas existen.
5. Confirmar grants y RLS.

Los demás módulos siguen como placeholder.
