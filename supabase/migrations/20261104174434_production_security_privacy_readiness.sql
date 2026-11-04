-- Hemocura only: authorization hardening, preserving signatures and data.
-- hc-lint: allow=HC009 reason=REVOKE of TRUNCATE only; no TRUNCATE command.
-- hc-lint: allow=HC005 reason=Default privileges are revoked, never granted.
begin;
set local lock_timeout='5s';

-- Public is not writable by browser roles; fixed legacy paths remain trusted.
revoke create on schema public from public,anon,authenticated;

-- Preserve authenticated effective CRUD while removing all anonymous grants.
do $acl$
declare r record;op text;
begin
 for r in select c.oid,n.nspname,c.relname,
  has_table_privilege('authenticated',c.oid,'SELECT') as sel,
  has_table_privilege('authenticated',c.oid,'INSERT') as ins,
  has_table_privilege('authenticated',c.oid,'UPDATE') as upd,
  has_table_privilege('authenticated',c.oid,'DELETE') as del
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind in ('r','p','v','m')
 loop
  execute format('revoke all privileges on table %I.%I from public,anon',r.nspname,r.relname);
  foreach op in array array['SELECT','INSERT','UPDATE','DELETE'] loop
   if (case op when 'SELECT' then r.sel when 'INSERT' then r.ins when 'UPDATE' then r.upd else r.del end) then
    execute format('grant %s on table %I.%I to authenticated',op,r.nspname,r.relname);
   end if;
  end loop;
  execute format('revoke truncate,references,trigger,maintain on table %I.%I from authenticated',r.nspname,r.relname);
 end loop;
 for r in select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='v' loop
  execute format('alter view public.%I set (security_invoker=true)',r.relname);
 end loop;
end $acl$;

-- Fixed function paths; no direct anonymous RPC or browser trigger invocation.
do $paths$
declare r record;
begin
 for r in select p.oid,format('%I.%I(%s)',n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)) sig,
  has_function_privilege('authenticated',p.oid,'EXECUTE') auth_exec,p.prorettype='trigger'::regtype is_trigger,
  p.proconfig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.prokind='f'
 loop
  if r.proconfig is null or not exists(select 1 from unnest(r.proconfig) x where x like 'search_path=%') then
   execute format('alter function %s set search_path=public,pg_temp',r.sig);
  end if;
  execute format('revoke execute on function %s from public,anon',r.sig);
  if r.auth_exec and not r.is_trigger then execute format('grant execute on function %s to authenticated',r.sig);end if;
  if r.is_trigger then execute format('revoke execute on function %s from authenticated',r.sig);end if;
 end loop;
end $paths$;

-- Existing browser code uses protected hc_* replacements; internal owner calls remain.
revoke execute on function public.adjust_sale_line(uuid,numeric,text),
 public.calculate_monthly_product_costs(uuid),public.approve_monthly_cost_period(uuid),
 public.evaluate_daily_close(uuid,date),public.close_operational_day(uuid,date),
 public.confirm_dispatch(uuid),public.generate_management_alerts(date),
 public.recalculate_inventory_policy(uuid),public.production_healthcheck(),
 public.hc_review_donor_status(uuid,text,text) from authenticated;

create or replace function public.has_role(role_code text)
returns boolean language sql stable security definer set search_path='' as $role$
 select exists(select 1 from public.profiles p where p.id=auth.uid() and p.active)
 and exists(select 1 from public.user_roles ur join public.roles r on r.id=ur.role_id
 where ur.user_id=auth.uid() and r.code=role_code)
$role$;
revoke all on function public.has_role(text) from public,anon;
grant execute on function public.has_role(text) to authenticated;

-- A browser-callable privileged entry point also requires a live active profile.
-- Do not modify private maintenance/trigger functions or SQL policy helpers.
do $active$
declare r record;definition text;body text;
begin
 for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
  where n.nspname='public' and p.prosecdef and l.lanname='plpgsql' and p.prorettype<>'trigger'::regtype
   and has_function_privilege('authenticated',p.oid,'EXECUTE')
 loop
  definition:=pg_get_functiondef(r.oid);
  if position('HC_ACTIVE_ACTOR_GUARD' in definition)>0 then continue;end if;
  body:=split_part(definition,'AS $function$',2);
  if body='' then raise exception 'Unexpected function format: %',r.oid::regprocedure;end if;
  body:=regexp_replace(body,'\mbegin\M',$guard$begin
 -- HC_ACTIVE_ACTOR_GUARD
 if auth.uid() is null or not public.wf_active_actor() then raise exception 'Usuario activo requerido' using errcode='42501';end if;
$guard$,'i');
  execute split_part(definition,'AS $function$',1)||'AS $function$'||body;
 end loop;
end $active$;

-- Safe defaults for FUTURE application-owned objects; existing authenticated CRUD unchanged.
alter default privileges for role postgres in schema public revoke all privileges on tables from public,anon,authenticated;
alter default privileges for role postgres in schema public revoke all privileges on sequences from public,anon,authenticated;
alter default privileges for role postgres in schema public revoke execute on functions from public,anon,authenticated;
-- Schema-specific revocation cannot override PostgreSQL's global PUBLIC EXECUTE default.
alter default privileges for role postgres revoke execute on functions from public;

-- Privacy boundary: the public view is a checked projection, not a raw-table alias.
-- This narrow privileged helper intentionally replaces direct raw-column access.
create schema if not exists hc_privacy;
revoke all on schema hc_privacy from public,anon;
create or replace function hc_privacy.hyperbaric_display_v1()
returns table(id uuid,branch_id uuid,resource_id uuid,customer_id uuid,patient_name text,
 patient_phone text,patient_code text,starts_at timestamptz,ends_at timestamptz,
 operational_date date,shift text,price numeric,currency text,session_label text,
 referrer_id uuid,referrer_name text,note text,status text,created_by uuid,created_at timestamptz)
language sql stable security definer set search_path='' as $display$
 select a.id,a.branch_id,a.resource_id,a.customer_id,
 case when public.has_permission('HYPERBARIC_PATIENT_PII') then a.patient_name else 'PX-'||replace(a.id::text,'-','') end,
 case when public.has_permission('HYPERBARIC_PATIENT_PII') then a.patient_phone else null::text end,
 'PX-'||replace(a.id::text,'-',''),a.starts_at,a.ends_at,a.operational_date,a.shift,a.price,a.currency,
 case when public.has_permission('HYPERBARIC_PATIENT_PII') then a.session_label else 'Sesión programada'::text end,
 a.referrer_id,a.referrer_name,
 case when public.has_permission('HYPERBARIC_PATIENT_PII') then a.note else null::text end,
 a.status,a.created_by,a.created_at
 from public.hyperbaric_appointments a
 where auth.uid() is not null and public.wf_active_actor()
  and public.has_permission('HYPERBARIC_VIEW') and public.can_access_branch(a.branch_id)
$display$;
revoke all on function hc_privacy.hyperbaric_display_v1() from public,anon;
grant usage on schema hc_privacy to authenticated;
grant execute on function hc_privacy.hyperbaric_display_v1() to authenticated;
create or replace view public.vw_hyperbaric_appointments_display with (security_invoker=true) as
 select id,branch_id,resource_id,customer_id,patient_name,patient_phone,patient_code,
 starts_at,ends_at,operational_date,shift,price::numeric(14,2) as price,currency,
 session_label,referrer_id,referrer_name,note,status,created_by,created_at
 from hc_privacy.hyperbaric_display_v1();
revoke all on public.vw_hyperbaric_appointments_display from public,anon;
grant select on public.vw_hyperbaric_appointments_display to authenticated;
revoke all on public.hyperbaric_appointments from public,anon,authenticated;
-- Privileged mutations still use existing wf_* RPCs. No raw patient identity in browser SQL.
grant select(id,branch_id,resource_id,customer_id,starts_at,ends_at,operational_date,
 shift,price,currency,referrer_id,referrer_name,status,created_by,created_at) on public.hyperbaric_appointments to authenticated;

-- Existing audit snapshots can contain names; prevent an audit-table bypass.
create policy hyperbaric_audit_identity_guard on public.audit_events
 as restrictive for select to authenticated using (
  coalesce(entity_table,'') not like 'hyperbaric_%' or public.has_permission('HYPERBARIC_PATIENT_PII'));

-- The wrapper gates remain authoritative for the legacy clinical entry points.

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
    raise exception 'FEFO clínico permanece SHADOW/BLOCKED; no se permite reserva automática por unidad.' using errcode='42501';
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
      format('Equipo %s: %s °C fuera de rango [%s, %s].',v_device.device_code,new.temperature_c,v_policy.min_temp,v_policy.max_temp),
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

revoke all on function public.evaluate_temperature_reading() from public,anon,authenticated;


-- Release readiness is computed; test results and signatures are never fabricated.
create or replace function hc_privacy.release_checks_v1(p_version text)
returns jsonb language plpgsql stable security definer set search_path='' as $checks$
declare latest public.uat_test_runs%rowtype;cases_count int;missing int;signatures int;signers int;tech jsonb;
begin
 select * into latest from public.uat_test_runs where release_version=p_version order by started_at desc,id desc limit 1;
 select count(*),count(*) filter(where r.result is distinct from 'PASS' or nullif(btrim(r.actual_result),'') is null
  or nullif(btrim(r.evidence_reference),'') is null) into cases_count,missing
 from public.uat_test_cases c left join public.uat_test_results r on r.test_case_id=c.id and r.run_id=latest.id where c.active;
 select count(distinct s.signoff_type),count(distinct s.signed_by) into signatures,signers
 from public.release_signoffs s join public.profiles p on p.id=s.signed_by and p.active
 where s.release_version=p_version and s.decision='APROBADO' and s.signed_at>=latest.completed_at;
 tech:=jsonb_build_object(
  'owner_views',(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='v' and not coalesce(c.reloptions @> array['security_invoker=true'],false)),
  'rls_off',(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and not c.relrowsecurity),
  'anonymous_tables',(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p','v','m') and has_table_privilege('anon',c.oid,'SELECT')),
  'anonymous_definers',(select count(*) from pg_proc f join pg_namespace n on n.oid=f.pronamespace where n.nspname='public' and f.prosecdef and has_function_privilege('anon',f.oid,'EXECUTE')),
  'mutable_paths',(select count(*) from pg_proc f join pg_namespace n on n.oid=f.pronamespace where n.nspname='public' and (f.proconfig is null or not exists(select 1 from unnest(f.proconfig) x where x like 'search_path=%'))),
  'raw_patient_access',has_column_privilege('authenticated','public.hyperbaric_appointments','patient_name','SELECT'),
  'broad_all_policies',(select count(*) from pg_policies p where p.schemaname='public' and p.cmd='ALL' and coalesce(p.qual,'') ilike '%auth.role()%authenticated%'));
 return jsonb_build_object('version',p_version,'technical_checks',tech,
  'technical_ready',not exists(select 1 from jsonb_each(tech) e where e.value not in ('0'::jsonb,'false'::jsonb)),
  'uat_ready',coalesce(latest.status='PASS' and cases_count>0 and missing=0,false),
  'uat_run_id',latest.id,'uat_status',latest.status,'active_cases',cases_count,'missing_or_unproven',missing,
  'approved_areas',signatures,'independent_signers',signers,'signoffs_ready',signatures=4 and signers=4,
  'production_eligible',p_version ~ '^[0-9]+\.[0-9]+\.[0-9]+$',
  'go_live_ready',p_version ~ '^[0-9]+\.[0-9]+\.[0-9]+$' and signatures=4 and signers=4
   and coalesce(latest.status='PASS' and cases_count>0 and missing=0,false)
   and not exists(select 1 from jsonb_each(tech) e where e.value not in ('0'::jsonb,'false'::jsonb)),
  'operating_mode',(select mode from public.system_operating_mode where id=1),
  'clinical_automation_enabled',exists(select 1 from public.app_feature_flags where key in ('clinical_fefo','cold_chain_auto_block','donor_recipient_traceability','clinical_supply_demand') and enabled),
  'external_evidence_required',jsonb_build_array('Protección de contraseñas filtradas','Restauración de respaldo en entorno aislado','Aceptación clínica por responsables'),
  'checked_at',now());
end $checks$;
revoke all on function hc_privacy.release_checks_v1(text) from public,anon,authenticated;
create or replace function public.hc_release_readiness_v1(p_version text default '1.0.0')
returns jsonb language plpgsql stable security definer set search_path='' as $ready$
begin
 if not public.wf_active_actor() or not public.has_permission('RELEASE_GATE_VIEW') then raise exception 'Acceso de liberación requerido' using errcode='42501';end if;
 return hc_privacy.release_checks_v1(p_version);
end $ready$;
revoke all on function public.hc_release_readiness_v1(text) from public,anon;
grant execute on function public.hc_release_readiness_v1(text) to authenticated;
CREATE OR REPLACE FUNCTION public.hc_uat_start_run(p_run_code text, p_release_version text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=''
AS $function$
declare
  v_id uuid;
begin
  if not public.wf_active_actor() then raise exception 'Usuario activo requerido' using errcode='42501';end if;
  if auth.uid() is null or not public.has_permission('UAT_MANAGE') then
    raise exception 'No autorizado para iniciar UAT.' using errcode='42501';
  end if;

  if length(trim(coalesce(p_run_code,'')))=0
     or length(trim(coalesce(p_release_version,'')))=0 then
    raise exception 'run_code y release_version son obligatorios.' using errcode='22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('release:'||trim(p_release_version),0));
  insert into public.uat_test_runs(run_code,release_version,tester_user_id,status)
  values(trim(p_run_code),trim(p_release_version),auth.uid(),'EN_CURSO')
  returning id into v_id;

  perform public.log_audit_event(
    'UAT','RUN_STARTED',null,'uat_test_runs',v_id,trim(p_run_code),
    null,
    (select to_jsonb(r) from public.uat_test_runs r where r.id=v_id),
    jsonb_build_object('release_version',trim(p_release_version))
  );

  return v_id;
end
$function$
;
REVOKE ALL ON FUNCTION public.hc_uat_start_run(text,text) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.hc_uat_start_run(text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.hc_uat_record_result(p_run_id uuid, p_test_case_id uuid, p_result text, p_actual_result text DEFAULT NULL::text, p_evidence_reference text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=''
AS $function$
declare
  v_result text := upper(trim(coalesce(p_result,'')));
  v_before jsonb;
begin
  if not public.wf_active_actor() then raise exception 'Usuario activo requerido' using errcode='42501';end if;
  if auth.uid() is null or not public.has_permission('UAT_MANAGE') then
    raise exception 'No autorizado para registrar UAT.' using errcode='42501';
  end if;

  if v_result not in ('PASS','FAIL','BLOCKED','NOT_RUN') then
    raise exception 'Resultado UAT inválido.' using errcode='22023';
  end if;

  perform 1 from public.uat_test_runs where id=p_run_id and status='EN_CURSO' and tester_user_id=auth.uid() for update;
  if not found then raise exception 'Ejecución inexistente, cerrada o de otro responsable' using errcode='42501';end if;
  if v_result<>'NOT_RUN' and nullif(btrim(p_actual_result),'') is null then raise exception 'Describa el resultado observado' using errcode='22023';end if;
  if v_result='PASS' and nullif(btrim(p_evidence_reference),'') is null then raise exception 'Referencia de evidencia requerida para PASS' using errcode='22023';end if;

  if not exists(select 1 from public.uat_test_cases where id=p_test_case_id and active=true) then
    raise exception 'Caso UAT inexistente o inactivo.' using errcode='P0002';
  end if;

  select to_jsonb(r) into v_before
  from public.uat_test_results r
  where r.run_id=p_run_id and r.test_case_id=p_test_case_id;

  insert into public.uat_test_results(
    run_id,test_case_id,result,actual_result,evidence_reference,tested_at
  )
  values(
    p_run_id,p_test_case_id,v_result,
    nullif(trim(coalesce(p_actual_result,'')),''),
    nullif(trim(coalesce(p_evidence_reference,'')),''),now()
  )
  on conflict(run_id,test_case_id) do update
    set result=excluded.result,
        actual_result=excluded.actual_result,
        evidence_reference=excluded.evidence_reference,
        tested_at=excluded.tested_at;

  perform public.log_audit_event(
    'UAT','RESULT_RECORDED',null,'uat_test_results',null,
    p_run_id::text||':'||p_test_case_id::text,
    v_before,
    (select to_jsonb(r) from public.uat_test_results r where r.run_id=p_run_id and r.test_case_id=p_test_case_id),
    jsonb_build_object('result',v_result)
  );
end
$function$
;
REVOKE ALL ON FUNCTION public.hc_uat_record_result(uuid,uuid,text,text,text) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.hc_uat_record_result(uuid,uuid,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.hc_uat_complete_run(p_run_id uuid, p_summary text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=''
AS $function$
declare
  v_fail integer;
  v_blocked integer;
  v_not_pass integer;
  v_status text;
  v_before jsonb;
begin
  if not public.wf_active_actor() then raise exception 'Usuario activo requerido' using errcode='42501';end if;
  if auth.uid() is null or not public.has_permission('UAT_MANAGE') then
    raise exception 'No autorizado para cerrar UAT.' using errcode='42501';
  end if;

  select to_jsonb(r) into v_before from public.uat_test_runs r where r.id=p_run_id and r.tester_user_id=auth.uid() for update;
  if v_before is null then raise exception 'Run UAT no encontrado.' using errcode='P0002'; end if;
  if (v_before->>'status')<>'EN_CURSO' then raise exception 'El run UAT ya está cerrado.' using errcode='22023'; end if;

  if not exists(select 1 from public.uat_test_cases where active) then raise exception 'No hay casos activos que validar' using errcode='22023';end if;
  select
    count(*) filter(where r.result='FAIL'),
    count(*) filter(where r.result='BLOCKED'),
    count(*) filter(where coalesce(r.result,'NOT_RUN')<>'PASS')
  into v_fail,v_blocked,v_not_pass
  from public.uat_test_cases c
  left join public.uat_test_results r on r.test_case_id=c.id and r.run_id=p_run_id
  where c.active=true;

  v_status := case when v_fail>0 then 'FAIL' when v_blocked>0 or v_not_pass>0 then 'BLOQUEADO' else 'PASS' end;

  update public.uat_test_runs
  set status=v_status,completed_at=now(),summary=nullif(trim(coalesce(p_summary,'')),'')
  where id=p_run_id;

  perform public.log_audit_event(
    'UAT','RUN_COMPLETED',null,'uat_test_runs',p_run_id,p_run_id::text,
    v_before,
    (select to_jsonb(r) from public.uat_test_runs r where r.id=p_run_id),
    jsonb_build_object('status',v_status,'not_pass_count',v_not_pass)
  );

  return v_status;
end
$function$
;
REVOKE ALL ON FUNCTION public.hc_uat_complete_run(uuid,text) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.hc_uat_complete_run(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.hc_v044_release_signoff(p_release_version text, p_type text, p_decision text, p_comment text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path=''
AS $function$
declare
  v_type text := upper(trim(coalesce(p_type,'')));
  v_decision text := upper(trim(coalesce(p_decision,'')));
  v_permission text;
  v_id uuid;
  v_existing_signer uuid;
  v_before jsonb;
begin
  if not public.wf_active_actor() then raise exception 'Usuario activo requerido' using errcode='42501';end if;
  if auth.uid() is null then
    raise exception 'Sesión requerida.' using errcode='42501';
  end if;

  if length(trim(coalesce(p_release_version,'')))=0 then
    raise exception 'Versión de release requerida.' using errcode='22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('release:'||trim(p_release_version),0));
  if nullif(btrim(p_comment),'') is null then raise exception 'Comentario y referencia de evidencia requeridos' using errcode='22023';end if;
  if v_decision='APROBADO' and not coalesce((hc_privacy.release_checks_v1(trim(p_release_version))->>'uat_ready')::boolean,false) then
   raise exception 'Complete la UAT con evidencia antes de aprobar la liberación' using errcode='42501';
  end if;
  v_permission := case v_type
    when 'OPERACIONES' then 'RELEASE_SIGNOFF_OPERACIONES'
    when 'CALIDAD'     then 'RELEASE_SIGNOFF_CALIDAD'
    when 'TI'          then 'RELEASE_SIGNOFF_TI'
    when 'GERENCIA'    then 'RELEASE_SIGNOFF_GERENCIA'
    else null
  end;

  if v_permission is null then
    raise exception 'Tipo de sign-off inválido.' using errcode='22023';
  end if;

  if not public.has_permission(v_permission) then
    raise exception 'No autorizado para sign-off %.',v_type using errcode='42501';
  end if;

  if v_decision not in ('APROBADO','RECHAZADO','CONDICIONAL') then
    raise exception 'Decisión inválida.' using errcode='22023';
  end if;

  if exists(
    select 1
    from public.release_signoffs
    where release_version=trim(p_release_version)
      and signed_by=auth.uid()
      and signoff_type<>v_type
  ) then
    raise exception 'Segregación de funciones: un usuario no puede firmar dos áreas del mismo release.' using errcode='42501';
  end if;

  select signed_by,to_jsonb(s)
    into v_existing_signer,v_before
  from public.release_signoffs s
  where s.release_version=trim(p_release_version)
    and s.signoff_type=v_type;

  if v_existing_signer is not null and v_existing_signer<>auth.uid() then
    raise exception 'El área % ya fue firmada por otro usuario.',v_type using errcode='42501';
  end if;

  insert into public.release_signoffs(
    release_version,signoff_type,signed_by,signed_at,decision,comment
  )
  values(
    trim(p_release_version),v_type,auth.uid(),now(),v_decision,
    coalesce(nullif(trim(coalesce(p_comment,'')),''),'Sin comentario')
  )
  on conflict(release_version,signoff_type) do update
    set signed_by=excluded.signed_by,
        signed_at=excluded.signed_at,
        decision=excluded.decision,
        comment=excluded.comment
  returning id into v_id;

  perform public.log_audit_event(
    'RELEASE','SIGNOFF',null,'release_signoffs',v_id,
    trim(p_release_version)||':'||v_type,
    v_before,
    (select to_jsonb(s) from public.release_signoffs s where s.id=v_id),
    jsonb_build_object('permission',v_permission)
  );

  return v_id;
end
$function$
;
REVOKE ALL ON FUNCTION public.hc_v044_release_signoff(text,text,text,text) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.hc_v044_release_signoff(text,text,text,text) TO authenticated;

-- Authorized area signers can reach the EXISTING UAT/release screens.
insert into public.role_permissions(role_id,permission_code)
select distinct rp.role_id,'RELEASE_GATE_VIEW' from public.role_permissions rp
where rp.permission_code in ('UAT_MANAGE','RELEASE_SIGNOFF_OPERACIONES','RELEASE_SIGNOFF_CALIDAD','RELEASE_SIGNOFF_TI','RELEASE_SIGNOFF_GERENCIA') on conflict do nothing;
insert into public.role_module_access(role_id,route_key,enabled)
select distinct rp.role_id,m.route_key,true from public.role_permissions rp cross join public.app_module_catalog m
where rp.permission_code in ('UAT_MANAGE','RELEASE_SIGNOFF_OPERACIONES','RELEASE_SIGNOFF_CALIDAD','RELEASE_SIGNOFF_TI','RELEASE_SIGNOFF_GERENCIA')
 and m.route_key in ('uat','release1') on conflict(role_id,route_key) do nothing;
insert into public.uat_test_cases(test_code,module,title,steps,expected_result,critical) values
 ('UAT-PRIVACY-001','SECURITY','Privacidad de pacientes','Comprobar lector sin PII, tabla original, bitácora y otra sucursal','Identidad solo accesible con permiso y sucursal',true),
 ('UAT-BACKUP-001','CONTINUITY','Restauración de respaldo','Restaurar copia en entorno aislado y adjuntar evidencia de integridad y recuperación','Restauración verificada por TI sin afectar producción',true),
 ('UAT-AUTH-LEAK-001','AUTH','Contraseñas filtradas','Habilitar protección de contraseñas filtradas y documentar su configuración','Protección activa y política comprobada por TI',true)
on conflict(test_code) do nothing;
-- Cover foreign-key lookups without removing existing indexes.
-- lock_timeout aborts the transaction instead of waiting behind active workload.
do $indexes$
declare r record;index_name text;
begin
 for r in select c.oid,c.conname,t.relname,
  (select string_agg(quote_ident(a.attname),',' order by k.ord) from unnest(c.conkey) with ordinality k(attnum,ord)
   join pg_attribute a on a.attrelid=c.conrelid and a.attnum=k.attnum) cols
 from pg_constraint c join pg_class t on t.oid=c.conrelid join pg_namespace n on n.oid=t.relnamespace
 where n.nspname='public' and c.contype='f' and not exists(
  select 1 from pg_index i where i.indrelid=c.conrelid and i.indisvalid and i.indisready and i.indpred is null
   and (i.indkey::smallint[])[0:cardinality(c.conkey)-1] @> c.conkey)
 loop
  index_name:='hc_fk_'||substr(md5(r.relname||':'||r.conname),1,20);
  execute format('create index if not exists %I on public.%I (%s)',index_name,r.relname,r.cols);
 end loop;
end $indexes$;

-- Staging rows gain a surrogate identity; source fields and duplicate source rows stay intact.
do $staging$
declare t text;
begin
 foreach t in array array['stg_resp_despachos','stg_requerimientos'] loop
  if to_regclass('public.'||t) is not null and not exists(select 1 from pg_constraint where conrelid=to_regclass('public.'||t) and contype='p') then
   execute format('alter table public.%I add column hc_staging_row_id bigint generated by default as identity primary key',t);
  end if;
 end loop;
end $staging$;

-- Auth claims are constant within a statement. InitPlans avoid reevaluating them for every row.
do $rlsplans$
declare p record;expr text;check_expr text;statement text;
begin
 for p in select pol.oid,pol.polname,c.relname,pg_get_expr(pol.polqual,pol.polrelid) qual,
  pg_get_expr(pol.polwithcheck,pol.polrelid) chk
 from pg_policy pol join pg_class c on c.oid=pol.polrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'
 loop
  expr:=regexp_replace(p.qual,'(?<!select )auth\.(uid|role|jwt)\(\)','(select auth.\1())','gi');
  check_expr:=regexp_replace(p.chk,'(?<!select )auth\.(uid|role|jwt)\(\)','(select auth.\1())','gi');
  if expr is distinct from p.qual or check_expr is distinct from p.chk then
   statement:=format('alter policy %I on public.%I',p.polname,p.relname);
   if expr is not null then statement:=statement||' using ('||expr||')';end if;
   if check_expr is not null then statement:=statement||' with check ('||check_expr||')';end if;
   execute statement;
  end if;
 end loop;
end $rlsplans$;

-- Reconcile only records proven by the Supabase migration ledger; never manufacture UAT/signatures.
do $registry$
begin
 if to_regclass('supabase_migrations.schema_migrations') is not null then
  insert into public.app_migrations(migration_code,version,description,notes)
  select name,version,'Registro conciliado con historial Supabase: '||name,
   'Fecha de conciliación; la ejecución original consta en supabase_migrations.schema_migrations.'
  from supabase_migrations.schema_migrations where name in (
   'daily_operational_report_v0_40','daily_operational_report_governance_v0_41','daily_operational_report_hardening_v0_42',
   'daily_operational_report_performance_v0_43','daily_operational_report_anon_hardening_v0_44',
   'training_release_1_0_foundation','training_recertification_and_management_inputs','training_assignment_document_and_bi_controls',
   'training_duration_and_module_performance','training_native_1_1_permissions','training_native_1_1_schema','training_native_1_1_views_and_rpcs',
   'training_native_1_1_seed_content','training_native_1_1_rpcs_hardening','training_native_1_1_instructor_views',
   'training_native_1_1_server_write_only','training_native_1_1_job_assignment_rpc') on conflict(migration_code) do nothing;
 end if;
end $registry$;
insert into public.app_migrations(migration_code,version,description,notes)
values('C14_CLINICAL_GUARDRAILS_v0_44_8','0.44.8','Guardas clínicas de doble conmutador aplicadas por migración de preparación',
 'Se instala y prueba el control interno; no activa automatización clínica ni firma aprobaciones.') on conflict(migration_code) do nothing;

notify pgrst,'reload schema';
commit;
