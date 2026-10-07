-- =====================================================================
-- HemoCura · C13-C1 · FUNCTION EXECUTE HARDENING CANDIDATE
-- Reduce superficie RPC sin cambiar todavía la lógica funcional.
-- NO aplicar sin ejecutar C13C_00_PREFLIGHT_FUNCTION_SECURITY.sql.
--
-- IMPORTANTE: PostgreSQL concede EXECUTE a PUBLIC por defecto en funciones.
-- Revocar solo a anon NO basta si PUBLIC conserva EXECUTE. Este candidate
-- revoca PUBLIC + anon y luego reotorga explícitamente a authenticated
-- únicamente las funciones necesarias.
-- =====================================================================

begin;

-- 1) Ninguna SECURITY DEFINER operativa debe heredar EXECUTE desde PUBLIC
--    ni quedar accesible al rol anon.
revoke execute on function public.adjust_sale_line(uuid,numeric,text) from PUBLIC, anon;
revoke execute on function public.approve_monthly_cost_period(uuid) from PUBLIC, anon;
revoke execute on function public.audit_row_change() from PUBLIC, anon;
revoke execute on function public.calculate_monthly_product_costs(uuid) from PUBLIC, anon;
revoke execute on function public.can_access_branch(uuid) from PUBLIC, anon;
revoke execute on function public.close_operational_day(uuid,date) from PUBLIC, anon;
revoke execute on function public.confirm_dispatch(uuid) from PUBLIC, anon;
revoke execute on function public.current_branch_id() from PUBLIC, anon;
revoke execute on function public.emit_operational_alert(uuid,text,public.severity_level,text,uuid,text,text,text,jsonb,text) from PUBLIC, anon;
revoke execute on function public.evaluate_daily_close(uuid,date) from PUBLIC, anon;
revoke execute on function public.evaluate_temperature_reading() from PUBLIC, anon;
revoke execute on function public.generate_management_alerts(date) from PUBLIC, anon;
revoke execute on function public.generate_sale_from_dispatch(uuid) from PUBLIC, anon;
revoke execute on function public.has_permission(text) from PUBLIC, anon;
revoke execute on function public.has_role(text) from PUBLIC, anon;
revoke execute on function public.production_healthcheck() from PUBLIC, anon;
revoke execute on function public.recalc_daily_sale(uuid) from PUBLIC, anon;
revoke execute on function public.recalculate_inventory_policy(uuid) from PUBLIC, anon;
revoke execute on function public.reserve_blood_units_fefo(uuid) from PUBLIC, anon;

-- 2) Helpers internos / triggers no se exponen como RPC para authenticated.
revoke execute on function public.audit_row_change() from authenticated;
revoke execute on function public.evaluate_temperature_reading() from authenticated;
revoke execute on function public.emit_operational_alert(uuid,text,public.severity_level,text,uuid,text,text,text,jsonb,text) from authenticated;
revoke execute on function public.generate_sale_from_dispatch(uuid) from authenticated;
revoke execute on function public.recalc_daily_sale(uuid) from authenticated;

-- FEFO clínico queda cerrado hasta que C14 instale el doble gate y lo vuelva
-- a exponer de forma controlada. Fallar cerrado es preferible a permitir la
-- reserva serializada mientras clinical_fefo permanece SHADOW.
revoke execute on function public.reserve_blood_units_fefo(uuid) from authenticated;

-- 3) APIs/helpers que siguen temporalmente disponibles antes del cutover C13-C2.
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

-- C01/C02 ya instaladas y controladas: conservar authenticated, retirar
-- cualquier herencia futura desde PUBLIC/anon.
revoke execute on function public.hc_review_donor_status(uuid,text,text) from PUBLIC, anon;
revoke execute on function public.log_audit_event(text,text,uuid,text,uuid,text,jsonb,jsonb,jsonb) from PUBLIC, anon;
grant execute on function public.hc_review_donor_status(uuid,text,text) to authenticated;
grant execute on function public.log_audit_event(text,text,uuid,text,uuid,text,jsonb,jsonb,jsonb) to authenticated;

insert into public.app_migrations(migration_code,version,description,applied_by,notes)
values(
  'C13C1_FUNCTION_EXECUTE_HARDENING_v0_44_5',
  '0.44.5',
  'Revoca EXECUTE heredado de PUBLIC/anon, cierra helpers internos y FEFO hasta C14',
  auth.uid(),
  'No cambia lógica de negocio; grants authenticated se reconstruyen explícitamente.'
)
on conflict(migration_code) do nothing;

commit;
