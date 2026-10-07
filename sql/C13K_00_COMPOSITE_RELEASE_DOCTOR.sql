-- =====================================================================
-- HemoCura · C13-K · COMPOSITE RELEASE READINESS DOCTOR · READ ONLY
-- Version 0.44.18
--
-- This SQL recomputes the database/security/clinical/UAT/sign-off portions
-- of the release doctor. C13-J remains authoritative for the complete
-- GitHub ↔ Supabase relation/RPC contract and must be PASS before release.
-- No schema, data, RLS, grants, flags or migrations are modified.
-- =====================================================================

with base_tables as (
  select c.oid,c.relname,c.relrowsecurity
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind in ('r','p')
),
rls_off as (
  select relname from base_tables where not relrowsecurity
),
rls_no_policy as (
  select b.relname
  from base_tables b
  where b.relrowsecurity
    and not exists(
      select 1 from pg_policies p
      where p.schemaname='public' and p.tablename=b.relname
    )
),
broad_policies as (
  select tablename,policyname
  from pg_policies
  where schemaname='public' and cmd='ALL'
    and coalesce(qual,'') ilike '%auth.role()%authenticated%'
    and coalesce(with_check,'') ilike '%auth.role()%authenticated%'
),
anon_dml as (
  select distinct g.table_name,g.privilege_type
  from information_schema.role_table_grants g
  join base_tables b on b.relname=g.table_name
  where g.table_schema='public'
    and g.grantee='anon'
    and g.privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE')
),
anon_secdef as (
  select p.oid::regprocedure::text signature
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.prosecdef
    and p.prorettype <> 'trigger'::regtype
    and has_function_privilege('anon',p.oid,'EXECUTE')
),
callable_no_path as (
  select p.oid::regprocedure::text signature
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.prorettype <> 'trigger'::regtype
    and (
      has_function_privilege('anon',p.oid,'EXECUTE')
      or has_function_privilege('authenticated',p.oid,'EXECUTE')
    )
    and (
      p.proconfig is null
      or not exists(select 1 from unnest(p.proconfig) x where x like 'search_path=%')
    )
),
required_roles(code) as (
  values
    ('ADMIN'),('CALIDAD'),('GERENCIA_GENERAL'),('GERENCIA_OPERATIVA'),
    ('LABORATORIO'),('ENCARGADA_LABORATORIO'),('TI')
),
missing_roles as (
  select rr.code
  from required_roles rr
  where not exists(select 1 from public.roles r where r.code=rr.code)
),
critical_columns(table_name,column_name) as (
  values
    ('incidents','id'),('incidents','requires_quality_followup'),
    ('dispatches','id'),('dispatches','dispatch_date'),
    ('nonconformities','id'),('nonconformities','status'),
    ('capa','id'),('capa','status'),
    ('release_signoffs','id'),('uat_test_cases','id')
),
missing_critical_columns as (
  select c.table_name,c.column_name
  from critical_columns c
  where not exists(
    select 1 from information_schema.columns i
    where i.table_schema='public'
      and i.table_name=c.table_name
      and i.column_name=c.column_name
  )
),
forbidden_columns as (
  select 'incidents'::text table_name,'status'::text column_name
  where exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='incidents' and column_name='status'
  )
),
required_rpc(name) as (
  values
    ('adjust_sale_line'),('audit_finding_create_capa'),('audit_finding_to_nonconformity'),
    ('calculate_monthly_product_costs'),('capture_daily_operational_close'),
    ('create_approval_request'),('create_exception_from_candidate'),('decide_approval_request'),
    ('execute_approved_action'),('log_access_event'),('log_diagnostic_event'),
    ('production_healthcheck'),('refresh_forecasts'),('request_capa_close'),
    ('request_document_approval'),('review_and_release_unit')
),
missing_rpc as (
  select r.name
  from required_rpc r
  where not exists(
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname=r.name
  )
),
baseline as (
  select
    exists(
      select 1 from public.app_migrations
      where version='0.44.0' and migration_code='44_RELEASE_1_0_RC_v0_44'
    ) migration_0_44_0,
    coalesce((select backend_ready from public.vw_app_release_readiness limit 1),false)
      legacy_backend_ready,
    coalesce((
      select missing_migrations=0 and missing_objects=0
      from public.vw_release_1_0_readiness limit 1
    ),false) legacy_release_objects_ready
),
uat as (
  select
    (select count(*) from public.uat_test_cases where active) active_cases,
    (select count(*) from public.uat_test_cases where active and critical) active_critical_cases,
    (select count(*) from public.uat_test_runs where release_version='1.0.0') runs,
    (select count(*) from public.uat_test_runs where release_version='1.0.0' and status='PASS') passed_runs,
    (select count(*) from public.uat_test_results x
       join public.uat_test_runs r on r.id=x.run_id
       where r.release_version='1.0.0') results,
    (select count(*) from public.uat_test_results x
       join public.uat_test_runs r on r.id=x.run_id
       join public.uat_test_cases c on c.id=x.test_case_id
       where r.release_version='1.0.0'
         and c.critical and x.result in ('FAIL','BLOCKED')) critical_failures
),
signoffs as (
  select
    count(*) total,
    count(*) filter(where decision='APROBADO') approved,
    count(*) filter(where decision='RECHAZADO') rejected,
    count(distinct signoff_type) filter(where decision='APROBADO') approved_types
  from public.release_signoffs
  where release_version='1.0.0'
),
clinical as (
  select
    coalesce((select mode from public.system_operating_mode order by updated_at desc nulls last limit 1),'UNKNOWN') mode,
    coalesce((select excel_parallel_required from public.system_operating_mode order by updated_at desc nulls last limit 1),true) excel_parallel_required,
    coalesce((select clinical_unit_dispatch_enabled from public.system_operating_mode order by updated_at desc nulls last limit 1),false) clinical_dispatch,
    coalesce((select temperature_blocking_enabled from public.system_operating_mode order by updated_at desc nulls last limit 1),false) temperature_blocking,
    coalesce((select donor_recipient_traceability_enabled from public.system_operating_mode order by updated_at desc nulls last limit 1),false) donor_recipient_traceability,
    coalesce((select bool_or(enabled) from public.app_feature_flags
              where key in ('clinical_fefo','cold_chain_auto_block','donor_recipient_traceability')),false)
      any_clinical_automation_flag_enabled,
    exists(select 1 from public.app_migrations where migration_code='C14_CLINICAL_GUARDRAILS_v0_44_8')
      c14_registered
),
counts as (
  select
    (select count(*) from missing_rpc) missing_rpcs,
    (select count(*) from missing_critical_columns) missing_critical_columns,
    (select count(*) from forbidden_columns) forbidden_columns_present,
    (select count(*) from rls_off) rls_off_tables,
    (select count(*) from rls_no_policy) rls_no_policy_tables,
    (select count(*) from broad_policies) broad_authenticated_policies,
    (select count(*) from anon_dml) anon_dml_grants,
    (select count(distinct table_name) from anon_dml) anon_dml_tables,
    (select count(*) from anon_secdef) anon_executable_security_definer,
    (select count(*) from callable_no_path) callable_without_fixed_search_path,
    (select count(*) from missing_roles) missing_required_roles
),
components as (
  select
    case when b.migration_0_44_0 and b.legacy_backend_ready and b.legacy_release_objects_ready
         then 'PASS' else 'STOP' end database_status,
    case when c.missing_rpcs=0 and c.missing_critical_columns=0 and c.forbidden_columns_present=0
         then 'PASS' else 'STOP' end runtime_critical_status,
    case when c.rls_off_tables=0 and c.rls_no_policy_tables=0 and c.broad_authenticated_policies=0
         then 'PASS' else 'STOP' end rls_status,
    case when c.missing_rpcs=0 and c.anon_executable_security_definer=0
                   and c.callable_without_fixed_search_path=0
         then 'PASS' else 'STOP' end rpc_security_status,
    case when c.anon_dml_grants=0 then 'PASS' else 'STOP' end anon_surface_status,
    case when c.missing_required_roles=0 then 'PASS' else 'STOP' end role_model_status,
    case
      when cl.any_clinical_automation_flag_enabled or cl.clinical_dispatch
        or cl.temperature_blocking or cl.donor_recipient_traceability then 'STOP'
      when cl.c14_registered then 'PASS'
      when cl.mode='LIVE_LIMITED' then 'SAFE_LIMITED'
      else 'REVIEW'
    end clinical_guardrails_status,
    case when u.runs>0 and u.passed_runs>0 and u.results>=u.active_cases
                   and u.critical_failures=0
         then 'PASS' else 'STOP' end uat_status,
    case when s.approved=4 and s.approved_types=4 and s.rejected=0
         then 'PASS' else 'STOP' end signoffs_status
  from counts c cross join baseline b cross join uat u cross join signoffs s cross join clinical cl
)
select jsonb_build_object(
  'gate','C13-K',
  'version','0.44.18',
  'mode','READ_ONLY',
  'database',(select to_jsonb(b) from baseline b),
  'counts',(select to_jsonb(c) from counts c),
  'uat',(select to_jsonb(u) from uat u),
  'signoffs',(select to_jsonb(s) from signoffs s),
  'clinical',(select to_jsonb(cl) from clinical cl),
  'components',(select jsonb_build_object(
      'database',database_status,
      'runtime_critical',runtime_critical_status,
      'rls',rls_status,
      'rpc_security',rpc_security_status,
      'anon_surface',anon_surface_status,
      'role_model',role_model_status,
      'clinical_guardrails',clinical_guardrails_status,
      'uat',uat_status,
      'signoffs',signoffs_status
    ) from components),
  'missing_required_roles',coalesce((select jsonb_agg(code order by code) from missing_roles),'[]'::jsonb),
  'rls_no_policy_tables',coalesce((select jsonb_agg(relname order by relname) from rls_no_policy),'[]'::jsonb),
  'broad_authenticated_policies',coalesce((select jsonb_agg(tablename||'.'||policyname order by tablename,policyname) from broad_policies),'[]'::jsonb),
  'anon_executable_security_definer',coalesce((select jsonb_agg(signature order by signature) from anon_secdef),'[]'::jsonb),
  'callable_without_fixed_search_path',coalesce((select jsonb_agg(signature order by signature) from callable_no_path),'[]'::jsonb),
  'note','Full schema-drift contract remains C13-J; C13-K consumes its PASS in the verified snapshot.'
) as c13k_database_doctor;
