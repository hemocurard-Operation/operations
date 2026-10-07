# C13-E · Anonymous Data Surface Hardening · v0.44.12

## Evidencia real

Preflight contra Supabase `tiothqiljipdamgudvcb`:

- 224 relaciones `public` con algún privilegio directo para `anon`.
- 8 grants de secuencia `public` para `anon`.
- 0 tablas `public` con RLS deshabilitado.
- `authenticated` conserva SELECT en `branches`, `vw_my_access` y `vw_app_migration_readiness`.
- `anon` no tiene CREATE sobre schema `public`.
- El flujo de login del repositorio usa `supabase.auth.signInWithPassword()` y no requiere leer tablas `public` antes de autenticarse.

## Decisión

C13-E retira a `anon` todos los privilegios de tablas/views/matviews y secuencias en `public`, y endurece los default privileges del owner `postgres` para que futuros objetos no vuelvan a exponerse automáticamente.

No modifica:

- `authenticated`;
- `service_role`;
- RLS/policies;
- funciones/RPC;
- datos;
- `js/config.js`;
- clinical flags ni `system_operating_mode`.

## Hallazgo adicional corregido

Durante la revisión se confirmó que varias funciones legacy conservan `EXECUTE` heredado desde `PUBLIC`. Por ello se corrigieron los candidates C13-C1 y C13-D para revocar `PUBLIC, anon` y reotorgar explícitamente `authenticated` solo donde corresponde.

## Archivos

- `sql/C13E_00_PREFLIGHT_ANON_SURFACE.sql`
- `sql/C13E_01_ANON_SURFACE_HARDENING_CANDIDATE.sql`
- `sql/C13E_90_VALIDATE_ANON_SURFACE.sql`

## Gate

Estado: **GENERADO / NO APLICADO**.

No aplicar C13-E antes de estabilizar las iteraciones anteriores y ejecutar su preflight inmediatamente antes del cambio.
