-- =====================================================================
-- HemoCura · C13-C2B · LEGACY RPC CUTOVER CANDIDATE
-- Ejecutar SOLO después de:
--   1) C13-C2A PASS;
--   2) frontend desplegado usando hc_*;
--   3) smoke Ventas + Costos PASS.
-- =====================================================================

begin;

revoke execute on function public.adjust_sale_line(uuid,numeric,text) from anon,authenticated;
revoke execute on function public.approve_monthly_cost_period(uuid) from anon,authenticated;
revoke execute on function public.calculate_monthly_product_costs(uuid) from anon,authenticated;
revoke execute on function public.evaluate_daily_close(uuid,date) from anon,authenticated;
revoke execute on function public.close_operational_day(uuid,date) from anon,authenticated;
revoke execute on function public.confirm_dispatch(uuid) from anon,authenticated;
revoke execute on function public.generate_management_alerts(date) from anon,authenticated;
revoke execute on function public.recalculate_inventory_policy(uuid) from anon,authenticated;
revoke execute on function public.production_healthcheck() from anon,authenticated;

insert into public.app_migrations(migration_code,version,description,applied_by,notes)
values(
  'C13C2B_LEGACY_RPC_CUTOVER_v0_44_7',
  '0.44.7',
  'Retira EXECUTE directo de RPC legacy tras migración frontend a wrappers hc_*',
  auth.uid(),
  'Requiere smoke frontend favorable antes de ejecutar.'
)
on conflict(migration_code) do nothing;

commit;
