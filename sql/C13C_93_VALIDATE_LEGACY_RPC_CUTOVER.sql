-- =====================================================================
-- HemoCura · C13-C2B · VALIDATE LEGACY RPC CUTOVER · READ ONLY
-- =====================================================================

with checks(name,ok,detail) as (
 values
 ('FRONTEND_WRAPPERS_AVAILABLE',
   has_function_privilege('authenticated',to_regprocedure('public.hc_adjust_sale_line(uuid,numeric,text)'),'EXECUTE')
   and has_function_privilege('authenticated',to_regprocedure('public.hc_calculate_monthly_product_costs(uuid)'),'EXECUTE'),
   'wrappers usados por frontend siguen disponibles'),

 ('LEGACY_SALES_COSTS_REVOKED',
   not has_function_privilege('authenticated',to_regprocedure('public.adjust_sale_line(uuid,numeric,text)'),'EXECUTE')
   and not has_function_privilege('authenticated',to_regprocedure('public.calculate_monthly_product_costs(uuid)'),'EXECUTE')
   and not has_function_privilege('authenticated',to_regprocedure('public.approve_monthly_cost_period(uuid)'),'EXECUTE'),
   'ventas/costos legacy internos'),

 ('LEGACY_COMMAND_DISPATCH_REVOKED',
   not has_function_privilege('authenticated',to_regprocedure('public.evaluate_daily_close(uuid,date)'),'EXECUTE')
   and not has_function_privilege('authenticated',to_regprocedure('public.close_operational_day(uuid,date)'),'EXECUTE')
   and not has_function_privilege('authenticated',to_regprocedure('public.confirm_dispatch(uuid)'),'EXECUTE'),
   'cierre/despacho legacy internos'),

 ('LEGACY_ADMIN_HELPERS_REVOKED',
   not has_function_privilege('authenticated',to_regprocedure('public.generate_management_alerts(date)'),'EXECUTE')
   and not has_function_privilege('authenticated',to_regprocedure('public.recalculate_inventory_policy(uuid)'),'EXECUTE')
   and not has_function_privilege('authenticated',to_regprocedure('public.production_healthcheck()'),'EXECUTE'),
   'alertas/inventario/health legacy internos'),

 ('C13C2B_REGISTERED',
   exists(select 1 from public.app_migrations where migration_code='C13C2B_LEGACY_RPC_CUTOVER_v0_44_7'),
   'app_migrations C13C2B_LEGACY_RPC_CUTOVER_v0_44_7')
)
select name,ok,detail,case when ok then 'PASS' else 'FAIL' end status
from checks
union all
select 'RESULTADO_GENERAL',bool_and(ok),'C13-C2B legacy cutover',
       case when bool_and(ok) then 'PASS' else 'STOP' end
from checks;
