-- =====================================================================
-- HemoCura · C13-C2 · VALIDATE CONTROLLED RPC WRAPPERS · READ ONLY
-- =====================================================================

with checks(name,ok,detail) as (
 values
 ('WRAPPER_SALES',
   to_regprocedure('public.hc_adjust_sale_line(uuid,numeric,text)') is not null
   and has_function_privilege('authenticated',to_regprocedure('public.hc_adjust_sale_line(uuid,numeric,text)'),'EXECUTE')
   and not has_function_privilege('authenticated',to_regprocedure('public.adjust_sale_line(uuid,numeric,text)'),'EXECUTE'),
   'ventas: wrapper expuesto / legacy interno'),

 ('WRAPPER_COSTS',
   to_regprocedure('public.hc_calculate_monthly_product_costs(uuid)') is not null
   and has_function_privilege('authenticated',to_regprocedure('public.hc_calculate_monthly_product_costs(uuid)'),'EXECUTE')
   and not has_function_privilege('authenticated',to_regprocedure('public.calculate_monthly_product_costs(uuid)'),'EXECUTE'),
   'costos: wrapper expuesto / legacy interno'),

 ('WRAPPER_COST_APPROVAL',
   to_regprocedure('public.hc_approve_monthly_cost_period(uuid)') is not null
   and not has_function_privilege('authenticated',to_regprocedure('public.approve_monthly_cost_period(uuid)'),'EXECUTE'),
   'aprobación de costos controlada'),

 ('WRAPPER_DAILY_CLOSE',
   to_regprocedure('public.hc_evaluate_daily_close(uuid,date)') is not null
   and to_regprocedure('public.hc_close_operational_day(uuid,date)') is not null
   and not has_function_privilege('authenticated',to_regprocedure('public.evaluate_daily_close(uuid,date)'),'EXECUTE')
   and not has_function_privilege('authenticated',to_regprocedure('public.close_operational_day(uuid,date)'),'EXECUTE'),
   'cierre diario controlado'),

 ('WRAPPER_DISPATCH',
   to_regprocedure('public.hc_confirm_dispatch(uuid)') is not null
   and not has_function_privilege('authenticated',to_regprocedure('public.confirm_dispatch(uuid)'),'EXECUTE'),
   'confirmación de despacho controlada'),

 ('WRAPPER_MANAGEMENT_ALERTS',
   to_regprocedure('public.hc_generate_management_alerts(date)') is not null
   and not has_function_privilege('authenticated',to_regprocedure('public.generate_management_alerts(date)'),'EXECUTE'),
   'alertas de gestión controladas'),

 ('WRAPPER_INVENTORY_POLICY',
   to_regprocedure('public.hc_recalculate_inventory_policy(uuid)') is not null
   and not has_function_privilege('authenticated',to_regprocedure('public.recalculate_inventory_policy(uuid)'),'EXECUTE'),
   'recalcular política inventario controlado'),

 ('WRAPPER_HEALTHCHECK',
   to_regprocedure('public.hc_production_healthcheck()') is not null
   and not has_function_privilege('authenticated',to_regprocedure('public.production_healthcheck()'),'EXECUTE'),
   'healthcheck controlado'),

 ('WRAPPERS_NOT_ANON',
   not has_function_privilege('anon',to_regprocedure('public.hc_adjust_sale_line(uuid,numeric,text)'),'EXECUTE')
   and not has_function_privilege('anon',to_regprocedure('public.hc_calculate_monthly_product_costs(uuid)'),'EXECUTE')
   and not has_function_privilege('anon',to_regprocedure('public.hc_confirm_dispatch(uuid)'),'EXECUTE')
   and not has_function_privilege('anon',to_regprocedure('public.hc_production_healthcheck()'),'EXECUTE'),
   'wrappers no accesibles por anon'),

 ('C13C2_REGISTERED',
   exists(select 1 from public.app_migrations where migration_code='C13C2_CONTROLLED_RPC_WRAPPERS_v0_44_7'),
   'app_migrations C13C2_CONTROLLED_RPC_WRAPPERS_v0_44_7')
)
select name,ok,detail,case when ok then 'PASS' else 'FAIL' end status
from checks
union all
select 'RESULTADO_GENERAL',bool_and(ok),'C13-C2 controlled RPC wrappers',
       case when bool_and(ok) then 'PASS' else 'STOP' end
from checks;
