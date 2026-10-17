begin;
insert into public.roles(code,name) values('LOGISTICA','Colaborador de Logística') on conflict(code) do nothing;
insert into public.app_permissions(permission_code,module,description,risk_level) values
('TRIPS_VIEW','LOGISTICS','Consultar viajes propios o del ámbito de supervisión','SENSIBLE'),
('TRIPS_WRITE','LOGISTICS','Registrar y corregir viajes propios','SENSIBLE'),
('TRIPS_REVIEW','LOGISTICS','Revisar viajes de otros colaboradores y reconocer incentivo','CRITICO'),
('TRIPS_SETTLE','LOGISTICS','Registrar inclusión de incentivos aprobados en liquidación','CRITICO');
insert into public.role_permissions(role_id,permission_code) select r.id,p.permission_code from public.roles r cross join public.app_permissions p where
r.code='SUPER_USUARIO' and p.permission_code like 'TRIPS_%'
or r.code in ('LOGISTICA','GERENCIA_OPERATIVA','GERENCIA_GENERAL') and p.permission_code in ('TRIPS_VIEW','TRIPS_WRITE')
or r.code in ('GERENCIA_OPERATIVA','GERENCIA_GENERAL') and p.permission_code='TRIPS_REVIEW'
or r.code='FINANZAS' and p.permission_code in ('TRIPS_VIEW','TRIPS_SETTLE')
or r.code='LOGISTICA' and p.permission_code='DASHBOARD_VIEW' on conflict do nothing;
insert into public.app_module_catalog(route_key,title,group_name,permission_code) values('extratrips','Viajes fuera de horario','TRABAJO DIARIO','TRIPS_VIEW');
insert into public.role_module_access(role_id,route_key,enabled) select id,'extratrips',code in ('SUPER_USUARIO','LOGISTICA','GERENCIA_OPERATIVA','GERENCIA_GENERAL','FINANZAS') from public.roles;
-- New role receives only its work entry and trip form; user assignment remains exclusive to Super Usuario.
insert into public.role_module_access(role_id,route_key,enabled) select r.id,m.route_key,m.route_key='mywork' from public.roles r cross join public.app_module_catalog m where r.code='LOGISTICA' and m.route_key<>'extratrips' on conflict do nothing;
create function public.logistics_access(p_branch uuid,p_permission text default 'TRIPS_VIEW') returns boolean language sql stable security invoker set search_path=public,pg_temp as $$
 select auth.uid() is not null and public.wf_active_actor() and public.has_permission('TRIPS_VIEW') and public.has_permission(p_permission) and p_branch is not null and public.can_access_branch(p_branch);
$$;
revoke all on function public.logistics_access(uuid,text) from public,anon;grant execute on function public.logistics_access(uuid,text) to authenticated;
create table public.logistics_trips(
 id uuid primary key default gen_random_uuid(),trip_no bigint generated always as identity unique,
 branch_id uuid not null references public.branches(id),worker_id uuid not null references public.profiles(id),worker_name text not null,
 origin text not null check(length(trim(origin)) between 2 and 180),destination text not null check(length(trim(destination)) between 2 and 180),
 departure_at timestamptz not null,arrival_at timestamptz not null check(arrival_at>departure_at),
 purpose text not null check(purpose in ('ENTREGA','RECOGIDA','TRASLADO','OTRO')),delivery_reference text check(length(delivery_reference)<=120),note text check(length(note)<=1000),
 status text not null default 'ENVIADO' check(status in ('ENVIADO','DEVUELTO','APROBADO','RECHAZADO','LIQUIDADO','ANULADO')),
 schedule_snapshot jsonb not null,scheduled_end_at timestamptz,amount numeric(12,2) check(amount>0),currency text not null default 'DOP' check(currency='DOP'),
 reviewed_by uuid references public.profiles(id),reviewer_name text,reviewed_at timestamptz,review_note text check(length(review_note)<=1500),
 settled_by uuid references public.profiles(id),settled_at timestamptz,payroll_reference text check(length(payroll_reference)<=180),withdraw_reason text check(length(withdraw_reason)<=1000),
 revision integer not null default 1,request_id uuid not null,request_hash text not null,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(worker_id,request_id)
);
create index logistics_trips_branch_status_idx on public.logistics_trips(branch_id,status,departure_at,id);
create index logistics_trips_worker_dates_idx on public.logistics_trips(worker_id,departure_at,arrival_at);
create table public.logistics_trip_history(id uuid primary key default gen_random_uuid(),trip_id uuid not null references public.logistics_trips(id),actor_id uuid not null references public.profiles(id),actor_name text not null,changed_at timestamptz not null default now(),before_data jsonb,after_data jsonb not null);
create index logistics_history_trip_idx on public.logistics_trip_history(trip_id,changed_at,id);
alter table public.logistics_trips enable row level security;alter table public.logistics_trip_history enable row level security;
revoke all on public.logistics_trips,public.logistics_trip_history from public,anon,authenticated;
grant select,insert,update on public.logistics_trips to authenticated;grant usage on sequence public.logistics_trips_trip_no_seq to authenticated;
grant select on public.logistics_trip_history to authenticated;
create policy logistics_read on public.logistics_trips for select to authenticated using(public.logistics_access(branch_id) and (worker_id=auth.uid() or public.has_permission('TRIPS_REVIEW') or public.has_permission('TRIPS_SETTLE')));
create policy logistics_insert on public.logistics_trips for insert to authenticated with check(public.logistics_access(branch_id,'TRIPS_WRITE') and worker_id=auth.uid());
create policy logistics_update on public.logistics_trips for update to authenticated using(public.logistics_access(branch_id) and (worker_id=auth.uid() and public.has_permission('TRIPS_WRITE') or public.has_permission('TRIPS_REVIEW') or public.has_permission('TRIPS_SETTLE'))) with check(public.logistics_access(branch_id));
create policy logistics_history_read on public.logistics_trip_history for select to authenticated using(exists(select 1 from public.logistics_trips t where t.id=trip_id));
create view public.vw_logistics_trip_branches with(security_invoker=true) as select id,name,code from public.branches where active and public.logistics_access(id);
revoke all on public.vw_logistics_trip_branches from public,anon;grant select on public.vw_logistics_trip_branches to authenticated;
-- Authorized schedule: Mon-Fri 08:00-18:00, Saturday 08:00-12:00, Sunday no regular workday.
-- Every claim preserves its schedule version; later rule changes cannot rewrite its evidence.
create function public.logistics_trip_schedule(p_arrival timestamptz) returns jsonb language sql immutable security invoker set search_path=public,pg_temp as $$
 with x as(select p_arrival at time zone 'America/Santo_Domingo' local_time),d as(select *,extract(isodow from local_time)::integer dow from x),v as(select *,case when dow=6 then time '12:00' else time '18:00' end cutoff from d)
 select jsonb_build_object('version','HC-LOG-HOR-001-1','timezone','America/Santo_Domingo','day',dow,'work_start_local',case when dow<>7 then to_char(local_time::date+time '08:00','YYYY-MM-DD"T"HH24:MI') end,'work_end_local',case when dow<>7 then to_char(local_time::date+cutoff,'YYYY-MM-DD"T"HH24:MI') end,'classification',case when dow=7 then 'DIA_NO_LABORABLE' when local_time::time<time '08:00' then 'ANTES_DE_JORNADA' when local_time::time>cutoff then 'DESPUES_DE_JORNADA' else 'DENTRO_DE_JORNADA' end) from v;
$$;
revoke all on function public.logistics_trip_schedule(timestamptz) from public,anon;grant execute on function public.logistics_trip_schedule(timestamptz) to authenticated;
create function private.guard_logistics_trip() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
declare actor uuid:=auth.uid();facts_changed boolean;reviewer boolean;settler boolean;name text;
begin
 if not public.logistics_access(new.branch_id) then raise exception 'Tu usuario no tiene acceso a esta sucursal.' using errcode='42501';end if;
 select full_name into name from public.profiles where id=actor;
 if not isfinite(new.departure_at) or not isfinite(new.arrival_at) then raise exception 'Indica una fecha y hora válidas.';end if;
 if new.arrival_at>clock_timestamp() then raise exception 'Revisa la llegada: el viaje debe haber terminado.';end if;
 if new.arrival_at<=new.departure_at then raise exception 'La llegada debe ser posterior a la salida. Si llegaste al día siguiente, marca esa opción.';end if;
 if tg_op='INSERT' then
  if not public.has_permission('TRIPS_WRITE') or new.worker_id<>actor or new.status<>'ENVIADO' then raise exception 'Solo puedes registrar tus propios viajes.' using errcode='42501';end if;
  new.schedule_snapshot:=public.logistics_trip_schedule(new.arrival_at);
  new.worker_name:=coalesce(nullif(trim(name),''),'Colaborador');new.created_at:=now();new.updated_at:=now();new.revision:=1;
  new.scheduled_end_at:=null;new.amount:=null;new.currency:='DOP';new.reviewed_by:=null;new.reviewer_name:=null;new.reviewed_at:=null;new.review_note:=null;new.settled_by:=null;new.settled_at:=null;new.payroll_reference:=null;new.withdraw_reason:=null;
 else
  if row(new.id,new.trip_no,new.branch_id,new.worker_id,new.worker_name,new.created_at,new.request_id,new.request_hash) is distinct from row(old.id,old.trip_no,old.branch_id,old.worker_id,old.worker_name,old.created_at,old.request_id,old.request_hash) then raise exception 'La identidad del viaje es inmutable.';end if;
  if not (old.status='DEVUELTO' and new.status='ENVIADO' and old.worker_id=actor) and new.schedule_snapshot is distinct from old.schedule_snapshot then raise exception 'El horario aplicado es inmutable.';end if;
  if row(new.revision,new.updated_at) is distinct from row(old.revision,old.updated_at) then raise exception 'No puedes cambiar la trazabilidad del registro.';end if;
  facts_changed:=row(new.origin,new.destination,new.departure_at,new.arrival_at,new.purpose,new.delivery_reference,new.note) is distinct from row(old.origin,old.destination,old.departure_at,old.arrival_at,old.purpose,old.delivery_reference,old.note);
  reviewer:=actor<>old.worker_id and public.has_permission('TRIPS_REVIEW');settler:=actor<>old.worker_id and public.has_permission('TRIPS_SETTLE');
  if old.status='DEVUELTO' and new.status='ENVIADO' and old.worker_id=actor and public.has_permission('TRIPS_WRITE') then
   new.schedule_snapshot:=public.logistics_trip_schedule(new.arrival_at);
   new.scheduled_end_at:=null;new.amount:=null;new.reviewed_by:=null;new.reviewer_name:=null;new.reviewed_at:=null;new.review_note:=null;new.withdraw_reason:=null;
   if row(new.settled_by,new.settled_at,new.payroll_reference,new.currency) is distinct from row(old.settled_by,old.settled_at,old.payroll_reference,old.currency) then raise exception 'No puedes registrar una liquidación.';end if;
  elsif old.status in ('ENVIADO','DEVUELTO') and new.status='ANULADO' and old.worker_id=actor and public.has_permission('TRIPS_WRITE') then
   if facts_changed or nullif(trim(new.withdraw_reason),'') is null or (to_jsonb(new)-array['status','withdraw_reason']) is distinct from (to_jsonb(old)-array['status','withdraw_reason']) then raise exception 'Indica el motivo para anular el viaje sin cambiar otros datos.';end if;
  elsif (old.status='ENVIADO' and new.status in ('APROBADO','DEVUELTO','RECHAZADO') or old.status='APROBADO' and new.status='DEVUELTO') and reviewer then
   if facts_changed or nullif(trim(new.review_note),'') is null or row(new.settled_by,new.settled_at,new.payroll_reference,new.withdraw_reason,new.currency) is distinct from row(old.settled_by,old.settled_at,old.payroll_reference,old.withdraw_reason,old.currency) then raise exception 'Documenta la revisión sin modificar el viaje del colaborador.';end if;
   if new.status='APROBADO' then
    if new.schedule_snapshot->>'classification'='DENTRO_DE_JORNADA' then raise exception 'El viaje terminó dentro del horario laboral; no se aprueba incentivo fuera de horario.';end if;
    new.scheduled_end_at:=(new.schedule_snapshot->>'work_end_local')::timestamp at time zone 'America/Santo_Domingo';
    if new.amount is null or new.amount<=0 or new.amount::text in ('NaN','Infinity','-Infinity') then raise exception 'Indica el incentivo autorizado, mayor que cero.';end if;
   else new.amount:=null;new.scheduled_end_at:=null;end if;
   new.reviewed_by:=actor;new.reviewer_name:=name;new.reviewed_at:=now();
  elsif old.status='APROBADO' and new.status='LIQUIDADO' and settler then
   if nullif(trim(new.payroll_reference),'') is null or (to_jsonb(new)-array['status','payroll_reference','settled_by','settled_at']) is distinct from (to_jsonb(old)-array['status','payroll_reference','settled_by','settled_at']) then raise exception 'Indica la referencia de nómina o liquidación sin cambiar el incentivo aprobado.';end if;
   new.settled_by:=actor;new.settled_at:=now();
  else raise exception 'El viaje cambió de estado o no tienes autorización para esta acción.' using errcode='42501';end if;
  new.revision:=old.revision+1;new.updated_at:=now();
 end if;
 -- Serialize each worker globally: changing branches cannot create overlapping duplicate claims.
 if tg_op='INSERT' or old.status='DEVUELTO' and new.status='ENVIADO' then
  if new.schedule_snapshot->>'classification'='DENTRO_DE_JORNADA' then raise exception 'La hora de llegada está dentro de tu jornada. Revisa el horario antes de registrar un viaje fuera de horario.';end if;
  perform pg_advisory_xact_lock(hashtextextended(actor::text,773));
  if exists(select 1 from public.logistics_trips t where t.worker_id=new.worker_id and t.id<>new.id and t.status not in ('RECHAZADO','ANULADO') and new.departure_at<t.arrival_at and new.arrival_at>t.departure_at) then raise exception 'Ya hay un viaje tuyo registrado en ese horario. Revisa Mis viajes.';end if;
 end if;
 return new;
end$$;
revoke all on function private.guard_logistics_trip() from public,anon,authenticated;
create trigger logistics_trip_guard before insert or update on public.logistics_trips for each row execute function private.guard_logistics_trip();
create function private.audit_logistics_trip() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 insert into public.logistics_trip_history(trip_id,actor_id,actor_name,before_data,after_data) values(new.id,auth.uid(),coalesce((select full_name from public.profiles where id=auth.uid()),'Colaborador'),case when tg_op='UPDATE' then to_jsonb(old) end,to_jsonb(new));return new;
end$$;
revoke all on function private.audit_logistics_trip() from public,anon,authenticated;
create trigger logistics_trip_audit after insert or update on public.logistics_trips for each row execute function private.audit_logistics_trip();
create function public.logistics_trip_action(p_action text,p_data jsonb) returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
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
   update public.logistics_trips set status=case p_action when 'APPROVE' then 'APROBADO' when 'RETURN' then 'DEVUELTO' else 'RECHAZADO' end,review_note=trim(p_data->>'review_note'),scheduled_end_at=case when p_action='APPROVE' then (t.schedule_snapshot->>'work_end_local')::timestamp at time zone 'America/Santo_Domingo' end,amount=case when p_action='APPROVE' then (p_data->>'amount')::numeric end where id=t.id returning * into t;
  else raise exception 'Acción no reconocida.';end if;
 end if;
 return jsonb_build_object('id',t.id,'trip_no',t.trip_no,'revision',t.revision);
end$$;
revoke all on function public.logistics_trip_action(text,jsonb) from public,anon;grant execute on function public.logistics_trip_action(text,jsonb) to authenticated;
commit;
