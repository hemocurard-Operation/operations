-- =====================================================================
-- HemoCura · C13-C1 · FUNCTION EXECUTE HARDENING CANDIDATE
-- Reduce superficie RPC sin cambiar todavía la lógica funcional.
-- NO aplicar sin ejecutar C13C_00_PREFLIGHT_FUNCTION_SECURITY.sql.
-- =====================================================================

begin;

-- 1) Ninguna SECURITY DEFINER operativa debe ser ejecutable por anon.
revoke execute on function public.adjust_sale_line(uuid,numeric,text) from anon;
revoke execute on function public.approve_monthly_cost_period(uuid) from anon;
revoke execute on function public.audit_row_change() from anon;
revoke execute on function public.calculate_monthly_product_costs(uuid) from anon;
revoke execute on function public.can_access_branch(uuid) from anon;
revoke execute on function public.close_operational_day(uuid,date) from anon;
revoke execute on function public.confirm_dispatch(uuid) from anon;
revoke execute on function public.current_branch_id() from anon;
revoke execute on function public.emit_operational_alert(uuid,text,public.severity_level,text,uuid,text,text,text,jsonb,text) from anon;
revoke execute on function public.evaluate_daily_close(uuid,date) from anon;
revoke execute on function public.evaluate_temperature_reading() from anon;
revoke execute on function public.generate_management_alerts(date) from anon;
revoke execute on function public.generate_sale_from_dispatch(uuid) from anon;
revoke execute on function public.has_permission(text) from anon;
revoke execute on function public.has_role(text) from anon;
revoke execute on function public.production_healthcheck() from anon;
revoke execute on function public.recalc_daily_sale(uuid) from anon;
revoke execute on function public.recalculate_inventory_policy(uuid) from anon;
revoke execute on function public.reserve_blood_units_fefo(uuid) from anon;

-- 2) Helpers internos / triggers no se exponen como RPC para authenticated.
-- Permanecen disponibles al propietario/service_role y para ejecución interna.
revoke execute on function public.audit_row_change() from authenticated;
revoke execute on function public.evaluate_temperature_reading() from authenticated;
revoke execute on function public.emit_operational_alert(uuid,text,public.severity_level,text,uuid,text,text,text,jsonb,text) from authenticated;
revoke execute on function public.generate_sale_from_dispatch(uuid) from authenticated;
revoke execute on function public.recalc_daily_sale(uuid) from authenticated;

-- 3) APIs/helpers que sí necesita el usuario autenticado se mantienen explícitos.
grant execute on function public.adjust_sale_line(uuid,numeric,text) to authenticated;
grant execute on function public.approve_monthly_cost_period(uuid) to authenticated;
grant execute on function public.calculate_monthly_product_costs(uuid) to authenticated;
grant execute on function public.can_access_branch(uuid) to authenticated;
grant execute on function public.close_operational_day(uuid,date) to authenticated;
grant execute on function public.confirm_dispatch(uuid) to authenticated;
grant execute on function public.current_branch_id() to authenticated;
grant execute on function public.evaluate_daily_close(uuid,date) to authenticated;
grant execute on function public.generate_management_alerts(date) to authenticated;
grant execute on function public.has_permission(text) to authenticated;
grant execute on function public.has_role(text) to authenticated;
grant execute on function public.production_healthcheck() to authenticated;
grant execute on function public.recalculate_inventory_policy(uuid) to authenticated;
grant execute on function public.reserve_blood_units_fefo(uuid) to authenticated;

-- C01/C02 ya instaladas y controladas.
revoke execute on function public.hc_review_donor_status(uuid,text,text) from anon;
revoke execute on function public.log_audit_event(text,text,uuid,text,uuid,text,jsonb,jsonb,jsonb) from anon;
grant execute on function public.hc_review_donor_status(uuid,text,text) to authenticated;
grant execute on function public.log_audit_event(text,text,uuid,text,uuid,text,jsonb,jsonb,jsonb) to authenticated;

insert into public.app_migrations(migration_code,version,description,applied_by,notes)
values(
  'C13C1_FUNCTION_EXECUTE_HARDENING_v0_44_6',
  '0.44.6',
  'Revoca RPC anon y acceso directo a helpers SECURITY DEFINER internos',
  auth.uid(),
  'No cambia lógica de negocio; reduce EXECUTE expuesto.'
)
on conflict(migration_code) do nothing;

commit;
