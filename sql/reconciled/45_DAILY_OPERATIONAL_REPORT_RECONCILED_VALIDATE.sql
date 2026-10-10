-- HemoCura Operations · I-004
-- READ-ONLY validation for 45_DAILY_OPERATIONAL_REPORT_RECONCILED_BASELINE.sql
-- Safe to run against the current production database: SELECT-only.

select
  to_regclass('public.daily_operational_closes') is not null as daily_operational_closes_exists,
  to_regclass('public.daily_operational_report_versions') is not null as report_versions_exists,
  to_regclass('public.vw_daily_branch_operations') is not null as daily_operations_view_exists,
  to_regprocedure('public.can_access_branch(uuid)') is not null as can_access_branch_exists,
  to_regprocedure('public.has_permission(text)') is not null as has_permission_exists,
  to_regprocedure('public.save_daily_operational_report(date,uuid,text,jsonb,jsonb,jsonb,jsonb,text,text)') is not null as save_rpc_exists,
  to_regprocedure('public.submit_daily_operational_report(uuid)') is not null as submit_rpc_exists,
  to_regprocedure('public.close_daily_operational_report(uuid)') is not null as close_rpc_exists,
  to_regprocedure('public.reopen_daily_operational_report(uuid,text)') is not null as reopen_rpc_exists,
  exists (
    select 1 from pg_constraint c
    join pg_class t on t.oid=c.conrelid
    join pg_namespace n on n.oid=t.relnamespace
    where n.nspname='public' and t.relname='daily_operational_closes'
      and c.contype='u'
      and pg_get_constraintdef(c.oid) ilike '%close_date%branch_id%'
  ) as unique_close_date_branch_exists;

select p.proname,
       not p.prosecdef as security_invoker,
       p.proconfig @> array['search_path=public']::text[] as fixed_public_search_path,
       not has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute_revoked,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute_granted
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in (
    'save_daily_operational_report',
    'submit_daily_operational_report',
    'close_daily_operational_report',
    'reopen_daily_operational_report'
  )
order by p.proname;

select tablename, policyname, cmd, roles
from pg_policies
where schemaname='public'
  and tablename in ('daily_operational_closes','daily_operational_report_versions')
order by tablename, policyname;

select c.relname as table_name,
       c.relrowsecurity as rls_enabled,
       has_table_privilege('anon',c.oid,'SELECT') as anon_select,
       has_table_privilege('anon',c.oid,'INSERT') as anon_insert,
       has_table_privilege('anon',c.oid,'UPDATE') as anon_update
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public'
  and c.relname in ('daily_operational_closes','daily_operational_report_versions')
order by c.relname;
