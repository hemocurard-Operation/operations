-- =====================================================================
-- HemoCura · C13-D · VALIDATE FUNCTION SEARCH_PATH · READ ONLY
-- =====================================================================

with target(sig) as (
 values
 ('public.hc_assert_can_migrate(text)'),('public.hc_gate_continue_to(text)'),
 ('public.hc_gate_dependencies_ready(text)'),('public.hc_gate_migration_registered(text)'),
 ('public.hc_gate_next_step()'),('public.hc_gate_object_exists(text,text)'),
 ('public.hc_gate_result(text)'),('public.hc_migration_applied(text)'),
 ('public.hc_object_exists(text,text)'),('public.hc_postcheck(text)'),
 ('public.hc_precheck(text)'),('public.hc_qa_r1_v022()'),
 ('public.hc_run_validation(text)'),('public.hc_version_dependencies_ready(text)'),
 ('public.hc_version_objects_ready(text)'),('public.reconcile_inventory(uuid,date)'),
 ('public.refresh_forecasts(date)'),('public.set_updated_at()'),('public.trg_recalc_daily_sale()')
), state as (
 select sig,to_regprocedure(sig) oid
 from target
), checks(name,ok,detail) as (
 values
 ('ALL_19_HAVE_FIXED_SEARCH_PATH',
   (select count(*)=19 and bool_and(coalesce(array_to_string(p.proconfig,','),'') ilike '%search_path=public, pg_temp%' or coalesce(array_to_string(p.proconfig,','),'') ilike '%search_path=public,pg_temp%')
    from state s join pg_proc p on p.oid=s.oid),
   '19/19 funciones con search_path fijo'),
 ('NO_ANON_EXECUTE_TARGETS',
   (select not bool_or(has_function_privilege('anon',s.oid,'EXECUTE')) from state s),
   'anon sin EXECUTE en target set'),
 ('TRIGGER_FUNCTIONS_NOT_BROWSER_RPC',
   not has_function_privilege('authenticated',to_regprocedure('public.set_updated_at()'),'EXECUTE')
   and not has_function_privilege('authenticated',to_regprocedure('public.trg_recalc_daily_sale()'),'EXECUTE'),
   'triggers sin EXECUTE directo'),
 ('PUBLIC_SCHEMA_NOT_CREATEABLE_BY_BROWSER',
   not has_schema_privilege('anon','public','CREATE')
   and not has_schema_privilege('authenticated','public','CREATE'),
   'public schema sin CREATE para browser roles'),
 ('C13D_REGISTERED',
   exists(select 1 from public.app_migrations where migration_code='C13D_FUNCTION_SEARCH_PATH_v0_44_11'),
   'app_migrations C13D_FUNCTION_SEARCH_PATH_v0_44_11')
)
select name,ok,detail,case when ok then 'PASS' else 'FAIL' end status
from checks
union all
select 'RESULTADO_GENERAL',bool_and(ok),'C13-D search_path hardening',
       case when bool_and(ok) then 'PASS' else 'STOP' end
from checks;

-- Complementario: después de aplicar, el advisor debería dejar de listar
-- estas 19 funciones como search_path mutable.
select p.proname,pg_get_function_identity_arguments(p.oid) args,p.proconfig
from state s join pg_proc p on p.oid=s.oid
order by p.proname,args;
