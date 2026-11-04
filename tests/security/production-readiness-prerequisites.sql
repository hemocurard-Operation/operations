-- Local-only parity fixture: definitions inspected from production, no records copied.
CREATE OR REPLACE FUNCTION public.production_healthcheck()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=public
AS $function$
declare
  result jsonb;
  missing text[] := array[]::text[];
begin
  if to_regclass('public.branches') is null then missing := array_append(missing,'branches'); end if;
  if to_regclass('public.products') is null then missing := array_append(missing,'products'); end if;
  if to_regclass('public.dispatches') is null then missing := array_append(missing,'dispatches'); end if;
  if to_regclass('public.daily_sales') is null then missing := array_append(missing,'daily_sales'); end if;
  if to_regclass('public.inventory_movements') is null then missing := array_append(missing,'inventory_movements'); end if;
  result := jsonb_build_object(
    'ok', cardinality(missing)=0,
    'missing_relations', to_jsonb(missing),
    'mode',(select mode from public.system_operating_mode where id=1),
    'checked_at',now()
  );
  return result;
end $function$;

REVOKE ALL ON FUNCTION public.production_healthcheck() FROM public,anon;
GRANT EXECUTE ON FUNCTION public.production_healthcheck() TO authenticated;
CREATE OR REPLACE FUNCTION public.recalculate_inventory_policy(p_policy_id uuid)
 RETURNS inventory_policies
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_policy public.inventory_policies%rowtype; v_avg numeric; v_std numeric; v_safety numeric; v_reorder numeric; v_target numeric; v_result public.inventory_policies%rowtype;
begin
  select * into v_policy from public.inventory_policies where id=p_policy_id for update;
  if not found then raise exception 'Política de inventario no existe'; end if;
  if not public.can_access_branch(v_policy.branch_id) then raise exception 'Sin acceso'; end if;
  with days as (
    select gs::date d from generate_series(current_date-(v_policy.calculation_window_days-1),current_date,interval '1 day') gs
  ), consumption as (
    select d.d,coalesce(sum(abs(im.quantity)) filter(where im.movement_type='CONSUMPTION'),0)::numeric qty
    from days d left join public.inventory_movements im
      on im.branch_id=v_policy.branch_id and im.product_id=v_policy.product_id and im.movement_date=d.d
    group by d.d
  ) select coalesce(avg(qty),0),coalesce(stddev_pop(qty),0) into v_avg,v_std from consumption;
  v_safety:=v_policy.service_level_z*v_std*sqrt(greatest(v_policy.lead_time_days,0));
  v_reorder:=v_avg*v_policy.lead_time_days+v_safety;
  v_target:=v_avg*(v_policy.lead_time_days+v_policy.review_period_days)+v_safety;
  update public.inventory_policies set avg_daily_consumption=v_avg,consumption_stddev=v_std,safety_stock=v_safety,
    reorder_point=v_reorder,minimum_stock=v_reorder,warning_stock=greatest(coalesce(warning_stock,0),v_reorder),
    target_stock=greatest(coalesce(target_stock,0),v_target),last_calculated_at=now()
  where id=p_policy_id returning * into v_result;
  return v_result;
end $function$
;
REVOKE ALL ON FUNCTION public.recalculate_inventory_policy(uuid) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.recalculate_inventory_policy(uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.hc_review_donor_status(p_donor uuid, p_status text, p_notes text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=''
AS $function$
declare
  v_status text := upper(trim(coalesce(p_status,'')));
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.' using errcode='42501';
  end if;

  if not (
    public.has_role('ADMIN')
    or public.has_role('GERENCIA_OPERATIVA')
    or public.has_role('CALIDAD')
    or public.has_role('LABORATORIO')
    or public.has_role('ENCARGADA_LABORATORIO')
  ) then
    raise exception 'Rol no autorizado para revisar donantes.' using errcode='42501';
  end if;

  if v_status not in ('ACEPTADO','DIFERIDO','PENDIENTE') then
    raise exception 'Estado clínico inválido.' using errcode='22023';
  end if;

  perform set_config('app.hc_donor_human_review','on',true);

  update public.donors
     set status=v_status,
         reviewed_by=auth.uid(),
         reviewed_at=now(),
         review_notes=nullif(trim(coalesce(p_notes,'')),'')
   where id=p_donor;

  if not found then
    raise exception 'Donante no encontrado.' using errcode='P0002';
  end if;
end
$function$
;
REVOKE ALL ON FUNCTION public.hc_review_donor_status(uuid,text,text) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.hc_review_donor_status(uuid,text,text) TO authenticated;

