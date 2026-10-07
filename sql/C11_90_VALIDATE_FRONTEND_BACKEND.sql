-- HemoCura C11.2 · GitHub ↔ Supabase compatibility validator
-- READ ONLY. Does not modify data.
with checks(name,ok,detail) as (
  values
  ('MIGRATION_0_44', exists(select 1 from public.app_migrations where version='0.44.0'), 'app_migrations 0.44.0'),
  ('DISPATCH_ID', exists(select 1 from information_schema.columns where table_schema='public' and table_name='dispatches' and column_name='id'), 'dispatches.id'),
  ('DISPATCH_DATE', exists(select 1 from information_schema.columns where table_schema='public' and table_name='dispatches' and column_name='dispatch_date'), 'dispatches.dispatch_date'),
  ('INCIDENT_FOLLOWUP', exists(select 1 from information_schema.columns where table_schema='public' and table_name='incidents' and column_name='requires_quality_followup'), 'incidents.requires_quality_followup'),
  ('NC_STATUS', exists(select 1 from information_schema.columns where table_schema='public' and table_name='nonconformities' and column_name='status'), 'nonconformities.status'),
  ('CAPA_STATUS', exists(select 1 from information_schema.columns where table_schema='public' and table_name='capa' and column_name='status'), 'capa.status'),
  ('RELEASE_VIEW', to_regclass('public.vw_release_1_0_readiness') is not null, 'vw_release_1_0_readiness'),
  ('UAT_VIEW', to_regclass('public.vw_uat_summary') is not null, 'vw_uat_summary'),
  ('CONTINUITY_VIEW', to_regclass('public.vw_continuity_readiness') is not null, 'vw_continuity_readiness'),
  ('COLD_CHAIN_VIEW', to_regclass('public.vw_cold_chain_excursions') is not null, 'vw_cold_chain_excursions'),
  ('HEMOVIG_VIEW', to_regclass('public.vw_hemovigilance_summary') is not null, 'vw_hemovigilance_summary')
)
select name,ok,detail,case when ok then 'PASS' else 'FAIL' end status from checks
union all
select 'RESULTADO_GENERAL',bool_and(ok),'C11.2 frontend/backend compatibility',case when bool_and(ok) then 'PASS' else 'STOP' end from checks;
