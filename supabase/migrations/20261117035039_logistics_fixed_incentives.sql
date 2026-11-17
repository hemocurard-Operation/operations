begin;
-- Empty by design: fixed incentives are business configuration, never guessed.
insert into public.app_permissions(permission_code,module,description,risk_level) values
('TRIPS_RATE_WRITE','LOGISTICS','Configurar tabla fija de incentivos por sucursal y motivo','CRITICO') on conflict(permission_code) do nothing;
insert into public.role_permissions(role_id,permission_code) select id,'TRIPS_RATE_WRITE' from public.roles where code='SUPER_USUARIO' on conflict do nothing;
create table public.logistics_trip_rates(
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),
 purpose text not null check(purpose in ('ENTREGA','RECOGIDA','TRASLADO','OTRO')),
 amount numeric(12,2) not null check(amount>0 and amount::text not in ('NaN','Infinity','-Infinity')),
 currency text not null default 'DOP' check(currency='DOP'),active boolean not null default true,
 revision integer not null default 1,created_by uuid not null references public.profiles(id),updated_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(branch_id,purpose)
);
create table public.logistics_trip_rate_history(
 id uuid primary key default gen_random_uuid(),rate_id uuid not null references public.logistics_trip_rates(id),branch_id uuid not null references public.branches(id),
 actor_id uuid not null references public.profiles(id),changed_at timestamptz not null default now(),before_data jsonb,after_data jsonb not null
);
alter table public.logistics_trip_rates enable row level security;
alter table public.logistics_trip_rate_history enable row level security;
revoke all on public.logistics_trip_rates,public.logistics_trip_rate_history from public,anon,authenticated;
grant select,insert,update on public.logistics_trip_rates to authenticated;
grant select on public.logistics_trip_rate_history to authenticated;
create policy logistics_rates_read on public.logistics_trip_rates for select to authenticated using(public.logistics_access(branch_id));
create policy logistics_rates_insert on public.logistics_trip_rates for insert to authenticated with check(public.logistics_access(branch_id,'TRIPS_RATE_WRITE'));
create policy logistics_rates_update on public.logistics_trip_rates for update to authenticated using(public.logistics_access(branch_id,'TRIPS_RATE_WRITE')) with check(public.logistics_access(branch_id,'TRIPS_RATE_WRITE'));
create policy logistics_rates_history_read on public.logistics_trip_rate_history for select to authenticated using(public.logistics_access(branch_id,'TRIPS_RATE_WRITE'));
create function private.guard_logistics_trip_rate() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(new.branch_id::text||':'||new.purpose,774));
 if not public.logistics_access(new.branch_id,'TRIPS_RATE_WRITE') then raise exception 'No puedes configurar incentivos.' using errcode='42501';end if;
 if tg_op='UPDATE' and row(new.id,new.branch_id,new.purpose,new.created_at,new.created_by) is distinct from row(old.id,old.branch_id,old.purpose,old.created_at,old.created_by) then raise exception 'La identidad de la tarifa es inmutable.';end if;
 if tg_op='INSERT' then new.created_by:=auth.uid();new.created_at:=now();new.revision:=1;else new.revision:=old.revision+1;end if;
 new.updated_by:=auth.uid();new.updated_at:=now();return new;
end$$;
revoke all on function private.guard_logistics_trip_rate() from public,anon,authenticated;
create trigger logistics_rate_guard before insert or update on public.logistics_trip_rates for each row execute function private.guard_logistics_trip_rate();
create function private.audit_logistics_trip_rate() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 insert into public.logistics_trip_rate_history(rate_id,branch_id,actor_id,before_data,after_data) values(new.id,new.branch_id,auth.uid(),case when tg_op='UPDATE' then to_jsonb(old) end,to_jsonb(new));return new;
end$$;
revoke all on function private.audit_logistics_trip_rate() from public,anon,authenticated;
create trigger logistics_rate_audit after insert or update on public.logistics_trip_rates for each row execute function private.audit_logistics_trip_rate();
create function public.logistics_trip_rate_save(p_data jsonb) returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare r public.logistics_trip_rates%rowtype;
begin
 if auth.uid() is null or not public.wf_active_actor() or not public.logistics_access((p_data->>'branch_id')::uuid,'TRIPS_RATE_WRITE') then raise exception 'No puedes configurar incentivos.' using errcode='42501';end if;
 if nullif(p_data->>'id','') is null then
  insert into public.logistics_trip_rates(branch_id,purpose,amount,active,created_by,updated_by) values((p_data->>'branch_id')::uuid,p_data->>'purpose',(p_data->>'amount')::numeric,coalesce((p_data->>'active')::boolean,true),auth.uid(),auth.uid()) returning * into r;
 else
  select * into r from public.logistics_trip_rates where id=(p_data->>'id')::uuid and branch_id=(p_data->>'branch_id')::uuid for update;
  if not found or r.revision is distinct from (p_data->>'revision')::integer then raise exception 'La tarifa cambió. Actualiza antes de guardar.';end if;
  update public.logistics_trip_rates set amount=(p_data->>'amount')::numeric,active=coalesce((p_data->>'active')::boolean,true) where id=r.id returning * into r;
 end if;
 return jsonb_build_object('id',r.id,'revision',r.revision);
end$$;
revoke all on function public.logistics_trip_rate_save(jsonb) from public,anon;grant execute on function public.logistics_trip_rate_save(jsonb) to authenticated;
alter table public.logistics_trips add column incentive_rule_id uuid references public.logistics_trip_rates(id),add column incentive_rule_snapshot jsonb;
CREATE OR REPLACE FUNCTION private.guard_logistics_trip()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare actor uuid:=auth.uid();facts_changed boolean;reviewer boolean;settler boolean;name text;rate public.logistics_trip_rates%rowtype;
begin
 if not public.logistics_access(new.branch_id) then raise exception 'Tu usuario no tiene acceso a esta sucursal.' using errcode='42501';end if;
 select full_name into name from public.profiles where id=actor;
 if not isfinite(new.departure_at) or not isfinite(new.arrival_at) then raise exception 'Indica una fecha y hora válidas.';end if;
 if new.arrival_at>clock_timestamp() then raise exception 'Revisa la llegada: el viaje debe haber terminado.';end if;
 if new.arrival_at<=new.departure_at then raise exception 'La llegada debe ser posterior a la salida. Si llegaste al día siguiente, marca esa opción.';end if;
 if tg_op='INSERT' then
  if not public.has_permission('TRIPS_WRITE') or new.worker_id<>actor or new.status<>'ENVIADO' then raise exception 'Solo puedes registrar tus propios viajes.' using errcode='42501';end if;
  new.schedule_snapshot:=public.logistics_trip_timing(new.departure_at,new.arrival_at);
  new.worker_name:=coalesce(nullif(trim(name),''),'Colaborador');new.created_at:=now();new.updated_at:=now();new.revision:=1;
  new.scheduled_end_at:=null;new.amount:=null;new.incentive_rule_id:=null;new.incentive_rule_snapshot:=null;new.currency:='DOP';new.reviewed_by:=null;new.reviewer_name:=null;new.reviewed_at:=null;new.review_note:=null;new.settled_by:=null;new.settled_at:=null;new.payroll_reference:=null;new.withdraw_reason:=null;
 else
  if row(new.incentive_rule_id,new.incentive_rule_snapshot) is distinct from row(old.incentive_rule_id,old.incentive_rule_snapshot) then raise exception 'La tarifa aplicada es inmutable.';end if;
  if row(new.id,new.trip_no,new.branch_id,new.worker_id,new.worker_name,new.created_at,new.request_id,new.request_hash) is distinct from row(old.id,old.trip_no,old.branch_id,old.worker_id,old.worker_name,old.created_at,old.request_id,old.request_hash) then raise exception 'La identidad del viaje es inmutable.';end if;
  if not (old.status='DEVUELTO' and new.status='ENVIADO' and old.worker_id=actor) and new.schedule_snapshot is distinct from old.schedule_snapshot then raise exception 'El horario aplicado es inmutable.';end if;
  if row(new.revision,new.updated_at) is distinct from row(old.revision,old.updated_at) then raise exception 'No puedes cambiar la trazabilidad del registro.';end if;
  facts_changed:=row(new.origin,new.destination,new.departure_at,new.arrival_at,new.purpose,new.delivery_reference,new.note) is distinct from row(old.origin,old.destination,old.departure_at,old.arrival_at,old.purpose,old.delivery_reference,old.note);
  reviewer:=actor<>old.worker_id and public.has_permission('TRIPS_REVIEW');settler:=actor<>old.worker_id and public.has_permission('TRIPS_SETTLE');
  if old.status='DEVUELTO' and new.status='ENVIADO' and old.worker_id=actor and public.has_permission('TRIPS_WRITE') then
   new.schedule_snapshot:=public.logistics_trip_timing(new.departure_at,new.arrival_at);
   new.scheduled_end_at:=null;new.amount:=null;new.incentive_rule_id:=null;new.incentive_rule_snapshot:=null;new.reviewed_by:=null;new.reviewer_name:=null;new.reviewed_at:=null;new.review_note:=null;new.withdraw_reason:=null;
   if row(new.settled_by,new.settled_at,new.payroll_reference,new.currency) is distinct from row(old.settled_by,old.settled_at,old.payroll_reference,old.currency) then raise exception 'No puedes registrar una liquidación.';end if;
  elsif old.status in ('ENVIADO','DEVUELTO') and new.status='ANULADO' and old.worker_id=actor and public.has_permission('TRIPS_WRITE') then
   if facts_changed or nullif(trim(new.withdraw_reason),'') is null or (to_jsonb(new)-array['status','withdraw_reason']) is distinct from (to_jsonb(old)-array['status','withdraw_reason']) then raise exception 'Indica el motivo para anular el viaje sin cambiar otros datos.';end if;
  elsif (old.status='ENVIADO' and new.status in ('APROBADO','DEVUELTO','RECHAZADO') or old.status='APROBADO' and new.status='DEVUELTO') and reviewer then
   if facts_changed or nullif(trim(new.review_note),'') is null or row(new.settled_by,new.settled_at,new.payroll_reference,new.withdraw_reason,new.currency) is distinct from row(old.settled_by,old.settled_at,old.payroll_reference,old.withdraw_reason,old.currency) then raise exception 'Documenta la revisión sin modificar el viaje del colaborador.';end if;
   if new.status='APROBADO' then
    -- One decision authorizes the trip. A fixed, configured rule determines
    -- the incentive; caller-entered amounts and working hours do not determine it.
    perform pg_advisory_xact_lock(hashtextextended(new.branch_id::text||':'||new.purpose,774));
    select * into rate from public.logistics_trip_rates where branch_id=new.branch_id and purpose=new.purpose and active;
    new.amount:=case when found then rate.amount else null end;
    new.incentive_rule_id:=case when rate.id is not null then rate.id else null end;
    new.incentive_rule_snapshot:=case when rate.id is not null then jsonb_build_object('id',rate.id,'revision',rate.revision,'branch_id',rate.branch_id,'purpose',rate.purpose,'amount',rate.amount,'currency',rate.currency,'authorized_at',now()) else jsonb_build_object('status','PENDIENTE_CONFIGURACION','authorized_at',now()) end;
    new.scheduled_end_at:=(new.schedule_snapshot->>'work_end_local')::timestamp at time zone 'America/Santo_Domingo';
   else new.amount:=null;new.scheduled_end_at:=null;new.incentive_rule_id:=null;new.incentive_rule_snapshot:=null;end if;
   new.reviewed_by:=actor;new.reviewer_name:=name;new.reviewed_at:=now();
  elsif old.status='APROBADO' and new.status='LIQUIDADO' and settler then
   if old.amount is null or old.amount<=0 then raise exception 'Incentivo pendiente de configuración: no se puede registrar liquidación sin cantidad autorizada.';end if;
   if nullif(trim(new.payroll_reference),'') is null or (to_jsonb(new)-array['status','payroll_reference','settled_by','settled_at']) is distinct from (to_jsonb(old)-array['status','payroll_reference','settled_by','settled_at']) then raise exception 'Indica la referencia de nómina o liquidación sin cambiar el incentivo aprobado.';end if;
   new.settled_by:=actor;new.settled_at:=now();
  else raise exception 'El viaje cambió de estado o no tienes autorización para esta acción.' using errcode='42501';end if;
  new.revision:=old.revision+1;new.updated_at:=now();
 end if;
 -- Serialize each worker globally: changing branches cannot create overlapping duplicate claims.
 if tg_op='INSERT' or old.status='DEVUELTO' and new.status='ENVIADO' then
  perform pg_advisory_xact_lock(hashtextextended(actor::text,773));
  if exists(select 1 from public.logistics_trips t where t.worker_id=new.worker_id and t.id<>new.id and t.status not in ('RECHAZADO','ANULADO') and new.departure_at<t.arrival_at and new.arrival_at>t.departure_at) then raise exception 'Ya hay un viaje tuyo registrado en ese horario. Revisa Mis viajes.';end if;
 end if;
 return new;
end$function$;
create or replace function public.logistics_trip_action(p_action text,p_data jsonb) returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare t public.logistics_trips%rowtype;b uuid;key uuid;hash text;item jsonb;n integer:=0;dep timestamptz;arr timestamptz;
begin
 if auth.uid() is null or not public.wf_active_actor() or not public.has_permission('TRIPS_VIEW') then raise exception 'Inicia sesión con tu usuario de Logística.' using errcode='42501';end if;
 if jsonb_typeof(p_data) is distinct from 'object' then raise exception 'Datos de viaje no válidos.';end if;
 if p_action='CREATE' then
  b:=(p_data->>'branch_id')::uuid;key:=(p_data->>'request_id')::uuid;hash:=md5(p_data::text);
  if key is null or not public.logistics_access(b,'TRIPS_WRITE') then raise exception 'No puedes registrar viajes en esta sucursal.' using errcode='42501';end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,773));
  select * into t from public.logistics_trips where worker_id=auth.uid() and request_id=key;
  if found then if t.request_hash<>hash then raise exception 'Esta solicitud ya fue enviada con otros datos. Revisa Mis viajes.';end if;return jsonb_build_object('id',t.id,'trip_no',t.trip_no,'already_created',true);end if;
  dep:=(p_data->>'departure_local')::timestamp at time zone 'America/Santo_Domingo';arr:=(p_data->>'arrival_local')::timestamp at time zone 'America/Santo_Domingo';
  insert into public.logistics_trips(branch_id,worker_id,worker_name,origin,destination,departure_at,arrival_at,purpose,delivery_reference,note,request_id,request_hash)
  values(b,auth.uid(),'',trim(p_data->>'origin'),trim(p_data->>'destination'),dep,arr,p_data->>'purpose',nullif(trim(p_data->>'delivery_reference'),''),nullif(trim(p_data->>'note'),''),key,hash) returning * into t;
 elsif p_action='SETTLE' then
  if jsonb_typeof(p_data->'trips') is distinct from 'array' or jsonb_array_length(p_data->'trips') not between 1 and 200 or nullif(trim(p_data->>'payroll_reference'),'') is null then raise exception 'Selecciona de 1 a 200 viajes y escribe la referencia de liquidación.';end if;
  -- Fixed lock order; any stale or unauthorized entry rolls back the complete batch.
  for item in select value from jsonb_array_elements(p_data->'trips') order by value->>'id' loop
   select * into t from public.logistics_trips where id=(item->>'id')::uuid for update;
   if not found or t.revision is distinct from (item->>'revision')::integer or t.status<>'APROBADO' or not public.logistics_access(t.branch_id,'TRIPS_SETTLE') or t.branch_id is distinct from (p_data->>'branch_id')::uuid then raise exception 'Algún viaje cambió o no está autorizado. Actualiza la lista.';end if;
   update public.logistics_trips set status='LIQUIDADO',payroll_reference=trim(p_data->>'payroll_reference') where id=t.id;n:=n+1;
  end loop;return jsonb_build_object('count',n);
 else
  select * into t from public.logistics_trips where id=(p_data->>'id')::uuid for update;
  if not found or t.revision is distinct from (p_data->>'revision')::integer then raise exception 'El viaje cambió. Actualiza antes de continuar.';end if;
  if p_action='RESUBMIT' then
   update public.logistics_trips set origin=trim(p_data->>'origin'),destination=trim(p_data->>'destination'),departure_at=(p_data->>'departure_local')::timestamp at time zone 'America/Santo_Domingo',arrival_at=(p_data->>'arrival_local')::timestamp at time zone 'America/Santo_Domingo',purpose=p_data->>'purpose',delivery_reference=nullif(trim(p_data->>'delivery_reference'),''),note=nullif(trim(p_data->>'note'),''),status='ENVIADO' where id=t.id returning * into t;
  elsif p_action='WITHDRAW' then update public.logistics_trips set status='ANULADO',withdraw_reason=trim(p_data->>'reason') where id=t.id returning * into t;
  elsif p_action in ('APPROVE','RETURN','REJECT') then
   update public.logistics_trips set status=case p_action when 'APPROVE' then 'APROBADO' when 'RETURN' then 'DEVUELTO' else 'RECHAZADO' end,review_note=trim(p_data->>'review_note'),scheduled_end_at=case when p_action='APPROVE' then (t.schedule_snapshot->>'work_end_local')::timestamp at time zone 'America/Santo_Domingo' end,amount=null where id=t.id returning * into t;
  else raise exception 'Acción no reconocida.';end if;
 end if;
 return jsonb_build_object('id',t.id,'trip_no',t.trip_no,'revision',t.revision);
end$$;
notify pgrst,'reload schema';
commit;
