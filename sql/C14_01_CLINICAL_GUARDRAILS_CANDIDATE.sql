-- =====================================================================
-- HemoCura · C14 · CLINICAL GUARDRAILS CANDIDATE
-- No activa FEFO ni bloqueo térmico. Refuerza que ambas funciones
-- respeten DOS gates: app_feature_flags + system_operating_mode.
-- =====================================================================

begin;

create or replace function public.reserve_blood_units_fefo(p_dispatch_line_id uuid)
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare
  v_line public.dispatch_lines%rowtype;
  v_dispatch public.dispatches%rowtype;
  v_required integer;
  v_reserved integer;
  v_mode public.product_control_modes%rowtype;
  v_feature_enabled boolean := false;
  v_system_enabled boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.' using errcode='42501';
  end if;

  if not public.has_permission('DISPATCH_WRITE') then
    raise exception 'Permiso DISPATCH_WRITE requerido.' using errcode='42501';
  end if;

  select coalesce(enabled,false) and mode in ('LIVE','LIVE_LIMITED')
    into v_feature_enabled
  from public.app_feature_flags
  where key='clinical_fefo';

  select coalesce(clinical_unit_dispatch_enabled,false)
    into v_system_enabled
  from public.system_operating_mode
  where id=1;

  if not coalesce(v_feature_enabled,false)
     or not coalesce(v_system_enabled,false) then
    raise exception 'FEFO clínico permanece SHADOW/BLOCKED; no se permite reserva automática por unidad.'
      using errcode='42501';
  end if;

  select * into v_line
  from public.dispatch_lines
  where id=p_dispatch_line_id
  for update;
  if not found then raise exception 'Línea de despacho no existe'; end if;

  select * into v_dispatch
  from public.dispatches
  where id=v_line.dispatch_id
  for update;
  if not found then raise exception 'Despacho no existe'; end if;

  if not public.can_access_branch(v_dispatch.branch_id) then
    raise exception 'Sin acceso a la sucursal' using errcode='42501';
  end if;
  if v_dispatch.status <> 'BORRADOR' then
    raise exception 'Solo se reserva FEFO en despachos BORRADOR';
  end if;
  if v_line.units <> trunc(v_line.units) then
    raise exception 'Unidades biológicas serializadas deben ser enteras';
  end if;

  select * into v_mode
  from public.product_control_modes
  where product_id=v_line.product_id and active;
  if not found or v_mode.control_mode <> 'SERIALIZED' or not v_mode.requires_fefo then
    raise exception 'Producto no configurado para FEFO serializado';
  end if;

  v_required := v_line.units::integer;

  select count(*) into v_reserved
  from public.dispatch_unit_allocations
  where dispatch_line_id=p_dispatch_line_id and allocation_status='RESERVED';

  if v_reserved < v_required then
    with candidates as (
      select bu.id
      from public.blood_units bu
      where bu.branch_id=v_dispatch.branch_id
        and bu.product_id=v_line.product_id
        and bu.inventory_status='AVAILABLE'
        and bu.release_status='RELEASED'
        and bu.expires_at>now()
        and not exists (
          select 1 from public.dispatch_unit_allocations a
          where a.blood_unit_id=bu.id
            and a.allocation_status in ('RESERVED','DISPATCHED')
        )
      order by bu.expires_at asc,bu.collected_at asc,bu.unit_code asc
      for update skip locked
      limit (v_required-v_reserved)
    ), ins as (
      insert into public.dispatch_unit_allocations(dispatch_line_id,blood_unit_id,created_by)
      select p_dispatch_line_id,id,auth.uid() from candidates
      on conflict (blood_unit_id) do nothing
      returning blood_unit_id
    )
    update public.blood_units bu
       set inventory_status='RESERVED',updated_at=now()
     where bu.id in (select blood_unit_id from ins);
  end if;

  select count(*) into v_reserved
  from public.dispatch_unit_allocations
  where dispatch_line_id=p_dispatch_line_id and allocation_status='RESERVED';

  if v_reserved < v_required then
    raise exception 'Stock FEFO insuficiente: requeridas %, reservadas %',v_required,v_reserved;
  end if;

  return v_reserved;
end
$$;

revoke all on function public.reserve_blood_units_fefo(uuid) from public,anon;
grant execute on function public.reserve_blood_units_fefo(uuid) to authenticated;

create or replace function public.evaluate_temperature_reading()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_policy public.temperature_policies%rowtype;
  v_device public.storage_devices%rowtype;
  v_excursion_id uuid;
  v_feature_enabled boolean := false;
  v_system_enabled boolean := false;
begin
  select * into v_device
  from public.storage_devices
  where id=new.storage_device_id;

  select * into v_policy
  from public.temperature_policies
  where storage_device_id=new.storage_device_id and active;

  if not found then
    perform public.emit_operational_alert(
      v_device.branch_id,'CALIDAD','ALTA','temperature_readings',null,
      'Lectura sin política térmica','No existe rango activo configurado para el equipo.',
      'TEMP_POLICY_MISSING:'||new.storage_device_id::text,
      jsonb_build_object('reading_id',new.id,'temperature_c',new.temperature_c),'QUALITY'
    );
    return new;
  end if;

  if new.temperature_c < v_policy.min_temp or new.temperature_c > v_policy.max_temp then
    insert into public.storage_excursions(
      storage_device_id,started_at,detected_reading_id,observed_temp,min_allowed,max_allowed
    )
    values(
      new.storage_device_id,new.measured_at,new.id,new.temperature_c,v_policy.min_temp,v_policy.max_temp
    )
    returning id into v_excursion_id;

    select coalesce(enabled,false) and mode in ('LIVE','LIVE_LIMITED')
      into v_feature_enabled
    from public.app_feature_flags
    where key='cold_chain_auto_block';

    select coalesce(temperature_blocking_enabled,false)
      into v_system_enabled
    from public.system_operating_mode
    where id=1;

    perform public.emit_operational_alert(
      v_device.branch_id,'CADENA_FRIO','CRITICA','storage_excursions',v_excursion_id,
      'Desviación de temperatura',
      format('Equipo %s: %s °C fuera de rango [%s, %s].',
             v_device.device_code,new.temperature_c,v_policy.min_temp,v_policy.max_temp),
      'TEMP_EXCURSION:'||v_excursion_id::text,
      jsonb_build_object(
        'device_id',v_device.id,
        'reading_id',new.id,
        'temperature_c',new.temperature_c,
        'auto_block_feature_enabled',coalesce(v_feature_enabled,false),
        'auto_block_system_enabled',coalesce(v_system_enabled,false)
      ),
      'QUALITY'
    );

    -- El bloqueo automático solo puede ejecutarse cuando LOS DOS gates están activos.
    if v_device.hold_on_excursion
       and coalesce(v_feature_enabled,false)
       and coalesce(v_system_enabled,false) then
      update public.blood_units
         set inventory_status='QUARANTINE',
             release_status='BLOCKED',
             quarantine_reason='Temperature excursion '||v_excursion_id::text,
             updated_at=now()
       where storage_device_id=new.storage_device_id
         and inventory_status in ('AVAILABLE','RESERVED');
    end if;
  end if;

  return new;
end
$$;

-- Función de trigger: no debe exponerse como RPC de navegador.
revoke all on function public.evaluate_temperature_reading() from public,anon,authenticated;

insert into public.app_migrations(migration_code,version,description,applied_by,notes)
values(
  'C14_CLINICAL_GUARDRAILS_v0_44_5',
  '0.44.5',
  'Double-gate para FEFO y bloqueo térmico; no activa funcionalidades clínicas SHADOW',
  auth.uid(),
  'clinical_fefo y cold_chain_auto_block permanecen controlados por feature flag + system mode.'
)
on conflict(migration_code) do nothing;

commit;
