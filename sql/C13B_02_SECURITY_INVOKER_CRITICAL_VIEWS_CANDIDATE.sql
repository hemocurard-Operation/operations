-- =====================================================================
-- HemoCura · C13-B2 · SECURITY INVOKER CRITICAL VIEWS CANDIDATE
-- Aplicar DESPUÉS de C12 y C13-B1. Las views seleccionadas dependen
-- directamente de tablas con RLS/policies verificadas en Supabase.
-- =====================================================================

begin;

alter view public.vw_app_migration_readiness set (security_invoker=true);
alter view public.vw_blood_flow_status set (security_invoker=true);
alter view public.vw_blood_inventory_available set (security_invoker=true);
alter view public.vw_cold_chain_excursions set (security_invoker=true);
alter view public.vw_hemovigilance_summary set (security_invoker=true);
alter view public.vw_my_access set (security_invoker=true);
alter view public.vw_my_security_context set (security_invoker=true);
alter view public.vw_release_1_0_readiness set (security_invoker=true);
alter view public.vw_screening_release_queue set (security_invoker=true);
alter view public.vw_uat_summary set (security_invoker=true);

revoke all on table public.vw_app_migration_readiness from anon;
revoke all on table public.vw_blood_flow_status from anon;
revoke all on table public.vw_blood_inventory_available from anon;
revoke all on table public.vw_cold_chain_excursions from anon;
revoke all on table public.vw_hemovigilance_summary from anon;
revoke all on table public.vw_my_access from anon;
revoke all on table public.vw_my_security_context from anon;
revoke all on table public.vw_release_1_0_readiness from anon;
revoke all on table public.vw_screening_release_queue from anon;
revoke all on table public.vw_uat_summary from anon;

grant select on table public.vw_app_migration_readiness to authenticated;
grant select on table public.vw_blood_flow_status to authenticated;
grant select on table public.vw_blood_inventory_available to authenticated;
grant select on table public.vw_cold_chain_excursions to authenticated;
grant select on table public.vw_hemovigilance_summary to authenticated;
grant select on table public.vw_my_access to authenticated;
grant select on table public.vw_my_security_context to authenticated;
grant select on table public.vw_release_1_0_readiness to authenticated;
grant select on table public.vw_screening_release_queue to authenticated;
grant select on table public.vw_uat_summary to authenticated;

insert into public.app_migrations(migration_code,version,description,applied_by,notes)
values(
  'C13B2_SECURITY_INVOKER_CRITICAL_VIEWS_v0_44_10',
  '0.44.10',
  'Convierte 10 views frontend críticas a security_invoker y elimina acceso anon',
  auth.uid(),
  'Fase controlada; no convertir las 67 views en lote.'
)
on conflict(migration_code) do nothing;

commit;
