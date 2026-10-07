-- =====================================================================
-- HemoCura · C13-H · DEFAULT PRIVILEGE GOVERNANCE CANDIDATE
-- Version objetivo: 0.44.15
--
-- Evidencia real previa (owner postgres + schema public):
--   anon:          8 table + 3 sequence + 1 function privileges default
--   authenticated: 8 table + 3 sequence + 1 function privileges default
--
-- Objetivo:
--   evitar que futuras tablas, secuencias y funciones vuelvan a nacer con
--   exposición directa a anon/authenticated por DEFAULT PRIVILEGES.
--
-- Este patch NO modifica objetos existentes, datos, RLS, service_role,
-- storage/auth/graphql/realtime ni feature flags clínicas.
-- =====================================================================

begin;

-- Gate: primero debe haberse cerrado la superficie anónima existente y
-- reconciliado grants de escritura actuales.
do $$
begin
  if not exists(
    select 1 from public.app_migrations
    where migration_code='C13E_ANON_SURFACE_HARDENING_v0_44_12'
  ) then
    raise exception 'C13-H BLOQUEADO: falta C13E_ANON_SURFACE_HARDENING_v0_44_12';
  end if;

  if not exists(
    select 1 from public.app_migrations
    where migration_code='C13G_GRANT_POLICY_RECONCILIATION_v0_44_14'
  ) then
    raise exception 'C13-H BLOQUEADO: falta C13G_GRANT_POLICY_RECONCILIATION_v0_44_14';
  end if;
end
$$;

-- 1. Nuevas tablas/views/materialized views creadas por postgres en public:
--    ningún privilegio automático para navegador.
alter default privileges for role postgres in schema public
  revoke all privileges on tables from public, anon, authenticated;

-- 2. Nuevas secuencias: ningún USAGE/SELECT/UPDATE automático.
alter default privileges for role postgres in schema public
  revoke all privileges on sequences from public, anon, authenticated;

-- 3. Nuevas funciones: bloquear EXECUTE automático. Esto obliga a cada
--    migración a conceder explícitamente EXECUTE solo a los roles requeridos.
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

-- service_role queda intacto. Los objetos futuros del frontend deberán
-- declarar GRANT explícito en la misma migración que crea el objeto.

insert into public.app_migrations(
  migration_code,version,description,applied_by,notes
)
values(
  'C13H_DEFAULT_PRIVILEGE_GOVERNANCE_v0_44_15',
  '0.44.15',
  'Cierra privilegios default de anon/authenticated/PUBLIC para futuros objetos public creados por postgres',
  auth.uid(),
  'No altera objetos existentes ni service_role. Futuras migraciones deben declarar GRANT explícito.'
)
on conflict(migration_code) do nothing;

commit;
