-- =====================================================================
-- HemoCura · C13-C1 · VALIDATE FUNCTION EXECUTE HARDENING · READ ONLY
-- =====================================================================

with checks(name,ok,detail) as (
 values
 ('NO_ANON_SECDEF_EXECUTE',
   not exists(
     select 1
     from pg_proc p
     join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='public'
       and p.prosecdef
       and has_function_privilege('anon',p.oid,'EXECUTE')
   ),
   '0 SECURITY DEFINER ejecutables por anon'),

 ('TRIGGER_HELPERS_NOT_AUTH_RPC',
   not has_function_privilege('authenticated',to_regprocedure('public.audit_row_change()'),'EXECUTE')
   and not has_function_privilege('authenticated',to_regprocedure('public.evaluate_temperature_reading()'),'EXECUTE'),
   'trigger functions no expuestas por RPC'),

 ('INTERNAL_HELPERS_NOT_AUTH_RPC',
   not has_function_privilege('authenticated',to_regprocedure('public.generate_sale_from_dispatch(uuid)'),'EXECUTE')
   and not has_function_privilege('authenticated',to_regprocedure('public.recalc_daily_sale(uuid)'),'EXECUTE')
   and not has_function_privilege(
     'authenticated',
     to_regprocedure('public.emit_operational_alert(uuid,text,severity_level,text,uuid,text,text,text,jsonb,text)'),
     'EXECUTE'
   ),
   'helpers internos sin EXECUTE directo'),

 ('FEFO_FAILS_CLOSED_BEFORE_C14',
   not has_function_privilege('authenticated',to_regprocedure('public.reserve_blood_units_fefo(uuid)'),'EXECUTE'),
   'reserve_blood_units_fefo no expuesto hasta instalar C14 double-gate'),

 ('CORE_RLS_HELPERS_AUTH_EXECUTE',
   has_function_privilege('authenticated',to_regprocedure('public.current_branch_id()'),'EXECUTE')
   and has_function_privilege('authenticated',to_regprocedure('public.can_access_branch(uuid)'),'EXECUTE')
   and has_function_privilege('authenticated',to_regprocedure('public.has_role(text)'),'EXECUTE')
   and has_function_privilege('authenticated',to_regprocedure('public.has_permission(text)'),'EXECUTE'),
   'helpers usados por RLS continúan disponibles'),

 ('LEGACY_FRONTEND_RPC_TEMPORARY_COMPATIBILITY',
   has_function_privilege('authenticated',to_regprocedure('public.adjust_sale_line(uuid,numeric,text)'),'EXECUTE')
   and has_function_privilege('authenticated',to_regprocedure('public.calculate_monthly_product_costs(uuid)'),'EXECUTE'),
   'RPC legacy de Ventas/Costos continúan temporalmente hasta C13-C2B'),

 ('C13C1_REGISTERED',
   exists(select 1 from public.app_migrations where migration_code='C13C1_FUNCTION_EXECUTE_HARDENING_v0_44_6'),
   'app_migrations C13C1_FUNCTION_EXECUTE_HARDENING_v0_44_6')
)
select name,ok,detail,case when ok then 'PASS' else 'FAIL' end status
from checks
union all
select 'RESULTADO_GENERAL',bool_and(ok),'C13-C1 EXECUTE hardening',
       case when bool_and(ok) then 'PASS' else 'STOP' end
from checks;

-- Evidencia complementaria: debe devolver 0 filas para anon.
select p.proname,pg_get_function_identity_arguments(p.oid) args
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.prosecdef
  and has_function_privilege('anon',p.oid,'EXECUTE')
order by p.proname,args;
