-- =====================================================================
-- HemoCura · C13-C2A · VALIDATE WRAPPER COMPATIBILITY STAGE · READ ONLY
-- Antes del cutover, wrappers NUEVOS y RPC legacy deben coexistir.
-- =====================================================================

with checks(name,ok,detail) as (
 values
 ('WRAPPER_SALES_READY',
   to_regprocedure('public.hc_adjust_sale_line(uuid,numeric,text)') is not null
   and has_function_privilege('authenticated',to_regprocedure('public.hc_adjust_sale_line(uuid,numeric,text)'),'EXECUTE'),
   'hc_adjust_sale_line disponible'),

 ('WRAPPER_COSTS_READY',
   to_regprocedure('public.hc_calculate_monthly_product_costs(uuid)') is not null
   and has_function_privilege('authenticated',to_regprocedure('public.hc_calculate_monthly_product_costs(uuid)'),'EXECUTE'),
   'hc_calculate_monthly_product_costs disponible'),

 ('OTHER_WRAPPERS_READY',
   to_regprocedure('public.hc_approve_monthly_cost_period(uuid)') is not null
   and to_regprocedure('public.hc_evaluate_daily_close(uuid,date)') is not null
   and to_regprocedure('public.hc_close_operational_day(uuid,date)') is not null
   and to_regprocedure('public.hc_confirm_dispatch(uuid)') is not null
   and to_regprocedure('public.hc_generate_management_alerts(date)') is not null
   and to_regprocedure('public.hc_recalculate_inventory_policy(uuid)') is not null
   and to_regprocedure('public.hc_production_healthcheck()') is not null,
   'wrappers de costos/cierre/despacho/alertas/inventario/health presentes'),

 ('WRAPPERS_NOT_ANON',
   not has_function_privilege('anon',to_regprocedure('public.hc_adjust_sale_line(uuid,numeric,text)'),'EXECUTE')
   and not has_function_privilege('anon',to_regprocedure('public.hc_calculate_monthly_product_costs(uuid)'),'EXECUTE')
   and not has_function_privilege('anon',to_regprocedure('public.hc_confirm_dispatch(uuid)'),'EXECUTE')
   and not has_function_privilege('anon',to_regprocedure('public.hc_production_healthcheck()'),'EXECUTE'),
   'wrappers no accesibles por anon'),

 ('LEGACY_COMPATIBILITY_STILL_ACTIVE',
   has_function_privilege('authenticated',to_regprocedure('public.adjust_sale_line(uuid,numeric,text)'),'EXECUTE')
   and has_function_privilege('authenticated',to_regprocedure('public.calculate_monthly_product_costs(uuid)'),'EXECUTE'),
   'frontend anterior sigue funcionando hasta desplegar hc_*'),

 ('C13C2A_REGISTERED',
   exists(select 1 from public.app_migrations where migration_code='C13C2A_CONTROLLED_RPC_WRAPPERS_v0_44_6'),
   'app_migrations C13C2A_CONTROLLED_RPC_WRAPPERS_v0_44_6')
)
select name,ok,detail,case when ok then 'PASS' else 'FAIL' end status
from checks
union all
select 'RESULTADO_GENERAL',bool_and(ok),'C13-C2A compatibility stage',
       case when bool_and(ok) then 'PASS' else 'STOP' end
from checks;
