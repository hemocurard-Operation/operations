-- =====================================================================
-- HemoCura · C13-B3 · RELEASE READINESS INVOKER CHAIN CANDIDATE
-- Completa la cadena anidada de readiness que alimenta Release Gate.
-- Aplicar DESPUÉS de C13-B1 y C13-B2.
-- =====================================================================

begin;

-- vw_app_required_objects es metadata VALUES-only.
alter view public.vw_app_required_objects set (security_invoker=true);

-- vw_app_schema_readiness consulta information_schema + required objects.
alter view public.vw_app_schema_readiness set (security_invoker=true);

-- vw_app_release_readiness compone schema + migration readiness.
alter view public.vw_app_release_readiness set (security_invoker=true);

-- Ninguna de estas vistas se necesita antes de autenticación.
revoke all on table public.vw_app_required_objects from anon;
revoke all on table public.vw_app_schema_readiness from anon;
revoke all on table public.vw_app_release_readiness from anon;

grant select on table public.vw_app_required_objects to authenticated;
grant select on table public.vw_app_schema_readiness to authenticated;
grant select on table public.vw_app_release_readiness to authenticated;

insert into public.app_migrations(migration_code,version,description,applied_by,notes)
values(
  'C13B3_RELEASE_READINESS_INVOKER_CHAIN_v0_44_12',
  '0.44.12',
  'Completa security_invoker en cadena anidada de schema/migration/release readiness',
  auth.uid(),
  'Aplicar después de C13-B1/B2; vw_release_1_0_readiness ya se endurece en C13-B2.'
)
on conflict(migration_code) do nothing;

commit;
