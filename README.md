# HemoCura Operations v0.11.0

Etapa: Configuración, permisos y diagnóstico central.

## Fuentes
- profiles
- roles
- user_roles
- branches
- products
- services

Opcionales si Producción Caliente está instalada:
- system_operating_mode
- app_feature_flags
- deployment_releases
- deployment_events
- production_healthcheck()

## Cadena
#settings
→ views.js
→ settings.js
→ settings-data.js
→ supabase.js
→ Supabase

## Seguridad
El panel es de consulta.
NO crea usuarios de auth.users.
NO usa service_role.
NO cambia roles desde el navegador.

## Diagnóstico central
Prueba individualmente los objetos principales para identificar:
- OK
- ERROR
- objeto no instalado
- RLS/permisos
