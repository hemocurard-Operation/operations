-- =====================================================================
-- HemoCura · C13-E · ANONYMOUS DATA SURFACE HARDENING CANDIDATE
-- Version objetivo: 0.44.12
--
-- Propósito:
--   1) retirar acceso directo del rol anon a relaciones y secuencias public;
--   2) preservar el acceso de authenticated y service_role;
--   3) endurecer privilegios por defecto para nuevos objetos creados por postgres;
--   4) NO tocar Auth, RLS, funciones, clinical flags ni datos.
--
-- Aplicar SOLO después de C13E_00_PREFLIGHT_ANON_SURFACE.sql favorable.
-- =====================================================================

begin;

-- El login de HemoCura usa Supabase Auth; no necesita leer tablas public
-- antes de que exista una sesión autenticada.

-- 1. Retirar privilegios directos de anon sobre tablas, views y matviews.
revoke all privileges on all tables in schema public from anon;

-- 2. Retirar privilegios de secuencias public para anon.
revoke all privileges on all sequences in schema public from anon;

-- 3. Evitar que objetos futuros creados por postgres vuelvan a heredar
--    exposición directa al rol anon.
alter default privileges for role postgres in schema public
  revoke all privileges on tables from anon;

alter default privileges for role postgres in schema public
  revoke all privileges on sequences from anon;

-- 4. Defensa explícita del schema. Mantener USAGE para compatibilidad de
--    resolución PostgREST, pero sin CREATE ni privilegios de objetos.
revoke create on schema public from anon;
grant usage on schema public to anon;

-- 5. Registrar la iteración. No toca ninguna feature clínica.
insert into public.app_migrations(
  migration_code,version,description,applied_by,notes
)
values(
  'C13E_ANON_SURFACE_HARDENING_v0_44_12',
  '0.44.12',
  'Retira privilegios directos de anon sobre relaciones y secuencias public y endurece defaults',
  auth.uid(),
  'No modifica authenticated/service_role, RLS, funciones ni clinical flags.'
)
on conflict(migration_code) do nothing;

commit;
