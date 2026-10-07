-- =====================================================================
-- HemoCura · C13-B2 · VALIDATE CRITICAL SECURITY INVOKER VIEWS
-- =====================================================================

with targets(view_name) as (
 values
 ('vw_app_migration_readiness'),
 ('vw_blood_flow_status'),
 ('vw_blood_inventory_available'),
 ('vw_cold_chain_excursions'),
 ('vw_hemovigilance_summary'),
 ('vw_my_access'),
 ('vw_my_security_context'),
 ('vw_release_1_0_readiness'),
 ('vw_screening_release_queue'),
 ('vw_uat_summary')
), state as (
 select t.view_name,c.oid,
        coalesce(array_to_string(c.reloptions,','),'') ilike '%security_invoker=true%' as security_invoker,
        has_table_privilege('anon',format('public.%I',t.view_name),'SELECT') as anon_select,
        has_table_privilege('authenticated',format('public.%I',t.view_name),'SELECT') as auth_select
 from targets t
 join pg_class c on c.relname=t.view_name
 join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
 where c.relkind='v'
), checks(name,ok,detail) as (
 values
 ('ALL_10_SECURITY_INVOKER',
   (select count(*)=10 and bool_and(security_invoker) from state),
   '10/10 critical views security_invoker=true'),
 ('NO_ANON_SELECT',
   (select count(*)=10 and not bool_or(anon_select) from state),
   'anon sin SELECT en las 10 views'),
 ('AUTH_SELECT_RETAINED',
   (select count(*)=10 and bool_and(auth_select) from state),
   'authenticated conserva SELECT'),
 ('C13B2_REGISTERED',
   exists(select 1 from public.app_migrations where migration_code='C13B2_SECURITY_INVOKER_CRITICAL_VIEWS_v0_44_10'),
   'app_migrations C13B2_SECURITY_INVOKER_CRITICAL_VIEWS_v0_44_10')
)
select name,ok,detail,case when ok then 'PASS' else 'FAIL' end status
from checks
union all
select 'RESULTADO_GENERAL',bool_and(ok),'C13-B2 critical views',
       case when bool_and(ok) then 'PASS' else 'STOP' end
from checks;

select * from state order by view_name;
