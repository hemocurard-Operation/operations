-- =====================================================================
-- HemoCura · C13-C2A · CONTROLLED RPC WRAPPERS · COMPATIBILITY STAGE
-- Crea wrappers hc_* con autorización explícita SIN retirar todavía
-- EXECUTE de las funciones legacy. Esto permite desplegar backend primero,
-- cambiar frontend después y hacer el cutover en C13-C2B sin downtime.
-- =====================================================================

begin;

create or replace function public.hc_adjust_sale_line(
  p_line_id uuid,
  p_adjustment numeric,
  p_reason text
) returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  if auth.uid() is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
  if not public.has_permission('SALES_WRITE') then
    raise exception 'Permiso SALES_WRITE requerido.' using errcode='42501';
  end if;
  perform public.adjust_sale_line(p_line_id,p_adjustment,p_reason);
end
$$;
revoke all on function public.hc_adjust_sale_line(uuid,numeric,text) from public,anon;
grant execute on function public.hc_adjust_sale_line(uuid,numeric,text) to authenticated;

create or replace function public.hc_calculate_monthly_product_costs(p_period_id uuid)
returns integer
language plpgsql
security definer
set search_path=''
as $$
begin
  if auth.uid() is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
  if not (public.has_role('ADMIN') or public.has_role('FINANZAS') or public.has_role('GERENCIA_OPERATIVA')) then
    raise exception 'Rol no autorizado para recalcular costos.' using errcode='42501';
  end if;
  return public.calculate_monthly_product_costs(p_period_id);
end
$$;

create or replace function public.hc_approve_monthly_cost_period(p_period_id uuid)
returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  if auth.uid() is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
  if not (public.has_role('ADMIN') or public.has_role('FINANZAS') or public.has_role('GERENCIA_OPERATIVA')) then
    raise exception 'Rol no autorizado para aprobar costos.' using errcode='42501';
  end if;
  perform public.approve_monthly_cost_period(p_period_id);
end
$$;
revoke all on function public.hc_calculate_monthly_product_costs(uuid) from public,anon;
revoke all on function public.hc_approve_monthly_cost_period(uuid) from public,anon;
grant execute on function public.hc_calculate_monthly_product_costs(uuid) to authenticated;
grant execute on function public.hc_approve_monthly_cost_period(uuid) to authenticated;

create or replace function public.hc_evaluate_daily_close(p_branch_id uuid,p_date date)
returns public.daily_close_checks
language plpgsql
security definer
set search_path=''
as $$
begin
  if auth.uid() is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
  if not public.has_permission('DAILY_CLOSE_EXECUTE') then raise exception 'Permiso DAILY_CLOSE_EXECUTE requerido.' using errcode='42501'; end if;
  if not public.can_access_branch(p_branch_id) then raise exception 'Sucursal fuera del alcance.' using errcode='42501'; end if;
  return public.evaluate_daily_close(p_branch_id,p_date);
end
$$;

create or replace function public.hc_close_operational_day(p_branch_id uuid,p_date date)
returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  if auth.uid() is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
  if not public.has_permission('DAILY_CLOSE_EXECUTE') then raise exception 'Permiso DAILY_CLOSE_EXECUTE requerido.' using errcode='42501'; end if;
  if not public.can_access_branch(p_branch_id) then raise exception 'Sucursal fuera del alcance.' using errcode='42501'; end if;
  perform public.close_operational_day(p_branch_id,p_date);
end
$$;
revoke all on function public.hc_evaluate_daily_close(uuid,date) from public,anon;
revoke all on function public.hc_close_operational_day(uuid,date) from public,anon;
grant execute on function public.hc_evaluate_daily_close(uuid,date) to authenticated;
grant execute on function public.hc_close_operational_day(uuid,date) to authenticated;

create or replace function public.hc_confirm_dispatch(p_dispatch_id uuid)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare v_branch uuid;
begin
  if auth.uid() is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
  if not public.has_permission('DISPATCH_WRITE') then raise exception 'Permiso DISPATCH_WRITE requerido.' using errcode='42501'; end if;
  select branch_id into v_branch from public.dispatches where id=p_dispatch_id;
  if v_branch is null then raise exception 'Despacho no existe.' using errcode='P0002'; end if;
  if not public.can_access_branch(v_branch) then raise exception 'Sucursal fuera del alcance.' using errcode='42501'; end if;
  return public.confirm_dispatch(p_dispatch_id);
end
$$;
revoke all on function public.hc_confirm_dispatch(uuid) from public,anon;
grant execute on function public.hc_confirm_dispatch(uuid) to authenticated;

create or replace function public.hc_generate_management_alerts(p_date date default current_date)
returns integer
language plpgsql
security definer
set search_path=''
as $$
begin
  if auth.uid() is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
  if not (public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('CALIDAD')) then
    raise exception 'Rol no autorizado para generar alertas de gestión.' using errcode='42501';
  end if;
  return public.generate_management_alerts(p_date);
end
$$;
revoke all on function public.hc_generate_management_alerts(date) from public,anon;
grant execute on function public.hc_generate_management_alerts(date) to authenticated;

create or replace function public.hc_recalculate_inventory_policy(p_policy_id uuid)
returns public.inventory_policies
language plpgsql
security definer
set search_path=''
as $$
begin
  if auth.uid() is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
  if not public.has_permission('BLOOD_INVENTORY_WRITE') then raise exception 'Permiso BLOOD_INVENTORY_WRITE requerido.' using errcode='42501'; end if;
  return public.recalculate_inventory_policy(p_policy_id);
end
$$;
revoke all on function public.hc_recalculate_inventory_policy(uuid) from public,anon;
grant execute on function public.hc_recalculate_inventory_policy(uuid) to authenticated;

create or replace function public.hc_production_healthcheck()
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
begin
  if auth.uid() is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
  if not public.has_permission('RELEASE_GATE_VIEW') then raise exception 'Permiso RELEASE_GATE_VIEW requerido.' using errcode='42501'; end if;
  return public.production_healthcheck();
end
$$;
revoke all on function public.hc_production_healthcheck() from public,anon;
grant execute on function public.hc_production_healthcheck() to authenticated;

insert into public.app_migrations(migration_code,version,description,applied_by,notes)
values(
  'C13C2A_CONTROLLED_RPC_WRAPPERS_v0_44_6',
  '0.44.6',
  'Wrappers hc_* con autorización explícita, etapa de compatibilidad sin retirar RPC legacy',
  auth.uid(),
  'Aplicar backend, luego desplegar frontend hc_*, validar smoke y finalmente ejecutar C13-C2B cutover.'
)
on conflict(migration_code) do nothing;

commit;
