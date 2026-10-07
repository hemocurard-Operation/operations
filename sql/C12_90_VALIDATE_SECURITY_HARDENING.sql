-- =====================================================================
-- HemoCura · C12 · VALIDATE SECURITY HARDENING · READ ONLY
-- Ejecutar DESPUÉS de aplicar C12_01_SECURITY_HARDENING_CANDIDATE.sql
-- =====================================================================

with checks(name,ok,detail) as (
  values
  ('ROLE_ENCARGADA',
    exists(select 1 from public.roles where code='ENCARGADA_LABORATORIO'),
    'roles.ENCARGADA_LABORATORIO'),

  ('ROLE_TI',
    exists(select 1 from public.roles where code='TI'),
    'roles.TI'),

  ('PERMISSION_UAT_MANAGE',
    exists(select 1 from public.app_permissions where permission_code='UAT_MANAGE' and active),
    'app_permissions.UAT_MANAGE'),

  ('RELEASE_RPC',
    to_regprocedure('public.hc_v044_release_signoff(text,text,text,text)') is not null,
    'hc_v044_release_signoff'),

  ('UAT_START_RPC',
    to_regprocedure('public.hc_uat_start_run(text,text)') is not null,
    'hc_uat_start_run'),

  ('UAT_RESULT_RPC',
    to_regprocedure('public.hc_uat_record_result(uuid,uuid,text,text,text)') is not null,
    'hc_uat_record_result'),

  ('UAT_COMPLETE_RPC',
    to_regprocedure('public.hc_uat_complete_run(uuid,text)') is not null,
    'hc_uat_complete_run'),

  ('NO_ANON_RELEASE',
    not has_table_privilege('anon','public.release_signoffs','SELECT')
    and not has_table_privilege('anon','public.release_signoffs','INSERT')
    and not has_table_privilege('anon','public.release_signoffs','UPDATE')
    and not has_table_privilege('anon','public.release_signoffs','DELETE'),
    'anon sin acceso a release_signoffs'),

  ('NO_AUTH_DIRECT_RELEASE_WRITE',
    has_table_privilege('authenticated','public.release_signoffs','SELECT')
    and not has_table_privilege('authenticated','public.release_signoffs','INSERT')
    and not has_table_privilege('authenticated','public.release_signoffs','UPDATE')
    and not has_table_privilege('authenticated','public.release_signoffs','DELETE'),
    'authenticated solo SELECT en release_signoffs'),

  ('NO_ANON_UAT',
    not has_table_privilege('anon','public.uat_test_runs','SELECT')
    and not has_table_privilege('anon','public.uat_test_cases','SELECT')
    and not has_table_privilege('anon','public.uat_test_results','SELECT'),
    'anon sin acceso UAT'),

  ('AUTH_UAT_READ_ONLY',
    has_table_privilege('authenticated','public.uat_test_runs','SELECT')
    and has_table_privilege('authenticated','public.uat_test_cases','SELECT')
    and has_table_privilege('authenticated','public.uat_test_results','SELECT')
    and not has_table_privilege('authenticated','public.uat_test_runs','INSERT')
    and not has_table_privilege('authenticated','public.uat_test_cases','INSERT')
    and not has_table_privilege('authenticated','public.uat_test_results','INSERT'),
    'authenticated UAT read-only'),

  ('NO_BROAD_RELEASE_POLICY',
    not exists(
      select 1 from pg_policies
      where schemaname='public' and tablename='release_signoffs'
        and cmd='ALL'
        and (coalesce(qual,'') ilike '%authenticated%' or coalesce(with_check,'') ilike '%authenticated%')
    ),
    'sin policy ALL autenticado en release_signoffs'),

  ('NO_BROAD_UAT_POLICY',
    not exists(
      select 1 from pg_policies
      where schemaname='public'
        and tablename in ('uat_test_runs','uat_test_cases','uat_test_results')
        and cmd='ALL'
        and (coalesce(qual,'') ilike '%authenticated%' or coalesce(with_check,'') ilike '%authenticated%')
    ),
    'sin policy ALL autenticado en UAT')
)
select name,ok,detail,case when ok then 'PASS' else 'FAIL' end as status
from checks
union all
select 'RESULTADO_GENERAL',bool_and(ok),'C12 security hardening',
       case when bool_and(ok) then 'PASS' else 'STOP' end
from checks;
