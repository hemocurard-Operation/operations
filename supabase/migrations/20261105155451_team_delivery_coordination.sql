begin;
-- Additive operational sidecar. Never changes clinical transport or incentive records.
insert into public.app_permissions(permission_code,module,description,risk_level,active) values
 ('DELIVERIES_VIEW','LOGISTICS','Consultar entregas operativas del equipo','SENSIBLE',true),
 ('DELIVERIES_ASSIGN','LOGISTICS','Asignar y proponer relevos de conductores','SENSIBLE',true),
 ('DELIVERIES_DRIVE','LOGISTICS','Ejecutar entregas asignadas a la cuenta personal','SENSIBLE',true),
 ('DELIVERIES_RECEIVE','LOGISTICS','Registrar verificación logística en laboratorio de destino','SENSIBLE',true);
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r cross join public.app_permissions p
where p.permission_code like 'DELIVERIES_%' and (
 r.code='SUPER_USUARIO' or
 p.permission_code='DELIVERIES_VIEW' and r.code in ('LOGISTICA','LOGISTICA_CONDUCTOR','LOGISTICA_SUPERVISOR','LOGISTICA_CONSULTA','LABORATORIO','ENCARGADA_LABORATORIO') or
 p.permission_code='DELIVERIES_ASSIGN' and r.code='LOGISTICA_SUPERVISOR' or
 p.permission_code='DELIVERIES_DRIVE' and r.code in ('LOGISTICA','LOGISTICA_CONDUCTOR','LOGISTICA_SUPERVISOR') or
 p.permission_code='DELIVERIES_RECEIVE' and r.code in ('LABORATORIO','ENCARGADA_LABORATORIO')) on conflict do nothing;
insert into public.app_module_catalog(route_key,title,group_name,permission_code,active) values('teamdeliveries','Entregas del equipo','TRABAJO DIARIO','DELIVERIES_VIEW',true);
insert into public.role_module_access(role_id,route_key,enabled) select r.id,'teamdeliveries',exists(select 1 from public.role_permissions rp where rp.role_id=r.id and rp.permission_code='DELIVERIES_VIEW') from public.roles r;
insert into public.app_feature_flags(key,enabled,mode,description) values('team_delivery_coordination',false,'OFF','Coordinación operativa aditiva; no modifica recepción clínica ni incentivos');
create table public.team_delivery_pilot(branch_id uuid primary key references public.branches(id),enabled boolean not null default false);
create table public.team_deliveries(
 id uuid primary key default gen_random_uuid(),transport_id uuid not null unique references public.transport_events(id),
 transport_code text not null,origin_branch_id uuid not null references public.branches(id),destination_branch_id uuid not null references public.branches(id),
 driver_id uuid not null references public.profiles(id),proposed_driver_id uuid references public.profiles(id),
 status text not null default 'ASIGNADO' check(status in ('ASIGNADO','EN_RUTA','ENTREGADO','RECEPCION_REGISTRADA','INCIDENCIA_RECEPCION')),
 revision integer not null default 1,created_at timestamptz not null default now(),created_by uuid not null references public.profiles(id),
 departed_at timestamptz,delivered_at timestamptz,received_at timestamptz,received_by uuid references public.profiles(id),
 delivery_reference text,receipt_temperature numeric,receipt_condition text check(receipt_condition in ('CONFORME','NO_CONFORME')),receipt_evidence text,
 check(origin_branch_id<>destination_branch_id),check(proposed_driver_id is null or proposed_driver_id<>driver_id));
create index team_deliveries_origin on public.team_deliveries(origin_branch_id,created_at desc);
create index team_deliveries_destination on public.team_deliveries(destination_branch_id,created_at desc);
create table public.team_delivery_history(
 id uuid primary key default gen_random_uuid(),delivery_id uuid not null references public.team_deliveries(id),actor_id uuid not null references public.profiles(id),
 action text not null,occurred_at timestamptz not null default now(),before_data jsonb,after_data jsonb not null,
 request_id uuid not null,request_data jsonb not null,unique(actor_id,request_id));
create index team_delivery_history_delivery on public.team_delivery_history(delivery_id,occurred_at);
create function private.delivery_permission(p_branch uuid,p_permission text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and public.wf_active_actor() and exists(
 select 1 from public.user_roles ur join public.roles r on r.id=ur.role_id join public.role_permissions rp on rp.role_id=r.id
 join public.app_permissions ap on ap.permission_code=rp.permission_code and ap.active
 where ur.user_id=auth.uid() and rp.permission_code=p_permission and (ur.branch_id=p_branch or r.code='SUPER_USUARIO'));
$$;
create function private.delivery_driver_eligible(p_user uuid,p_origin uuid,p_dest uuid) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.profiles where id=p_user and active) and
 not exists(select 1 from unnest(array[p_origin,p_dest]) b where not exists(
 select 1 from public.user_roles ur join public.role_permissions rp on rp.role_id=ur.role_id join public.app_permissions ap on ap.permission_code=rp.permission_code and ap.active
 where ur.user_id=p_user and ur.branch_id=b and rp.permission_code='DELIVERIES_DRIVE'));
$$;
revoke all on function private.delivery_permission(uuid,text),private.delivery_driver_eligible(uuid,uuid,uuid) from public,anon,authenticated;
grant usage on schema private to authenticated;
grant execute on function private.delivery_permission(uuid,text) to authenticated;
-- Eligibility is used only within the guarded catalog and mutation functions.
revoke all on public.team_deliveries,public.team_delivery_history,public.team_delivery_pilot from public,anon,authenticated;
grant select on public.team_deliveries,public.team_delivery_history,public.team_delivery_pilot to authenticated;
alter table public.team_deliveries enable row level security;
alter table public.team_delivery_history enable row level security;
alter table public.team_delivery_pilot enable row level security;
create policy delivery_read on public.team_deliveries for select to authenticated using(private.delivery_permission(origin_branch_id,'DELIVERIES_VIEW') or private.delivery_permission(destination_branch_id,'DELIVERIES_VIEW'));
create policy delivery_history_read on public.team_delivery_history for select to authenticated using(exists(select 1 from public.team_deliveries d where d.id=delivery_id));
create policy delivery_pilot_read on public.team_delivery_pilot for select to authenticated using(private.delivery_permission(branch_id,'DELIVERIES_VIEW'));
create function private.team_delivery_catalog() returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
 if not public.wf_active_actor() or not public.has_permission('DELIVERIES_VIEW') then raise exception 'Acceso a entregas requerido' using errcode='42501';end if;
 select jsonb_build_object(
 'enabled',coalesce((select enabled from public.app_feature_flags where key='team_delivery_coordination'),false),
 'branches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name,'can_assign',private.delivery_permission(b.id,'DELIVERIES_ASSIGN'),'can_receive',private.delivery_permission(b.id,'DELIVERIES_RECEIVE'),'pilot',exists(select 1 from public.team_delivery_pilot p where p.branch_id=b.id and p.enabled)) order by b.name) from public.branches b where b.active and private.delivery_permission(b.id,'DELIVERIES_VIEW')),'[]'::jsonb),
 'people',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.full_name)) from public.profiles p where p.active and exists(select 1 from public.team_deliveries d where (d.driver_id=p.id or d.proposed_driver_id=p.id) and (private.delivery_permission(d.origin_branch_id,'DELIVERIES_VIEW') or private.delivery_permission(d.destination_branch_id,'DELIVERIES_VIEW')))),'[]'::jsonb),
 'candidates',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.full_name,'branch_ids',(select jsonb_agg(distinct ur.branch_id) from public.user_roles ur join public.role_permissions rp on rp.role_id=ur.role_id join public.app_permissions ap on ap.permission_code=rp.permission_code and ap.active where ur.user_id=p.id and rp.permission_code='DELIVERIES_DRIVE'))) from public.profiles p where p.active and exists(select 1 from public.user_roles ur join public.role_permissions rp on rp.role_id=ur.role_id where ur.user_id=p.id and rp.permission_code='DELIVERIES_DRIVE' and private.delivery_permission(ur.branch_id,'DELIVERIES_ASSIGN'))),'[]'::jsonb),
 'transports',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'code',t.transport_code,'branch_id',t.branch_id,'min_temp',t.min_temp,'max_temp',t.max_temp)) from public.transport_events t where t.status in ('PLANIFICADO','EN_TRANSITO') and private.delivery_permission(t.branch_id,'DELIVERIES_ASSIGN') and not exists(select 1 from public.team_deliveries d where d.transport_id=t.id)),'[]'::jsonb)
 ) into result;
 return result;
end;$$;
create function private.team_delivery_action(p_action text,p_data jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare actor uuid:=auth.uid();rid uuid:=(p_data->>'request_id')::uuid;d public.team_deliveries;before_row jsonb;previous public.team_delivery_history;t public.transport_events;dest uuid;driver uuid;v numeric;condition text;
begin
 if actor is null or not public.wf_active_actor() or not public.has_permission('DELIVERIES_VIEW') then raise exception 'Sesión activa y acceso a entregas requeridos' using errcode='42501';end if;
 if rid is null then raise exception 'Identificador de solicitud requerido';end if;
 -- Serialize retries per actor and key; this lock does not affect other requests.
 perform pg_advisory_xact_lock(hashtextextended(actor::text||rid::text,0));
 select * into previous from public.team_delivery_history where actor_id=actor and request_id=rid;
 if found then
  if previous.action<>p_action or previous.request_data<>p_data then raise exception 'Solicitud reutilizada con otros datos';end if;
  if not (private.delivery_permission((previous.after_data->>'origin_branch_id')::uuid,'DELIVERIES_VIEW') or private.delivery_permission((previous.after_data->>'destination_branch_id')::uuid,'DELIVERIES_VIEW')) then raise exception 'Sucursal no autorizada' using errcode='42501';end if;
  return previous.after_data;
 end if;
 if not coalesce((select enabled from public.app_feature_flags where key='team_delivery_coordination'),false) then raise exception 'Coordinación desactivada; no se guardaron cambios';end if;
 if p_action='CREATE' then
  select * into t from public.transport_events where id=(p_data->>'transport_id')::uuid for update;
  if not found or t.status not in ('PLANIFICADO','EN_TRANSITO') then raise exception 'Traslado activo requerido';end if;
  dest:=(p_data->>'destination_branch_id')::uuid;driver:=(p_data->>'driver_id')::uuid;
  if not private.delivery_permission(t.branch_id,'DELIVERIES_ASSIGN') or not private.delivery_permission(dest,'DELIVERIES_ASSIGN') then raise exception 'Solo supervisión autorizada puede asignar estas sucursales' using errcode='42501';end if;
  if not exists(select 1 from public.branches where id=dest and active) then raise exception 'Destino activo requerido';end if;
  if not private.delivery_driver_eligible(driver,t.branch_id,dest) then raise exception 'Conductor activo con acceso a origen y destino requerido';end if;
  insert into public.team_deliveries(transport_id,transport_code,origin_branch_id,destination_branch_id,driver_id,created_by) values(t.id,t.transport_code,t.branch_id,dest,driver,actor) returning * into d;
 else
  select * into d from public.team_deliveries where id=(p_data->>'id')::uuid for update;
  if not found or not (private.delivery_permission(d.origin_branch_id,'DELIVERIES_VIEW') or private.delivery_permission(d.destination_branch_id,'DELIVERIES_VIEW')) then raise exception 'Entrega no disponible' using errcode='42501';end if;
  if d.revision is distinct from (p_data->>'revision')::integer then raise exception 'Otro usuario actualizó la entrega. Actualice antes de continuar' using errcode='40001';end if;
  before_row:=to_jsonb(d);
  if p_action='REASSIGN' then
   if not private.delivery_permission(d.origin_branch_id,'DELIVERIES_ASSIGN') or not private.delivery_permission(d.destination_branch_id,'DELIVERIES_ASSIGN') then raise exception 'Solo supervisión autorizada puede reasignar' using errcode='42501';end if;
   driver:=(p_data->>'driver_id')::uuid;
   if d.status not in ('ASIGNADO','EN_RUTA') or d.proposed_driver_id is not null then raise exception 'No se permite relevo en este estado';end if;
   if driver=d.driver_id or not private.delivery_driver_eligible(driver,d.origin_branch_id,d.destination_branch_id) then raise exception 'Seleccione otro conductor activo autorizado';end if;
   if length(trim(coalesce(p_data->>'reason',''))) not between 3 and 300 then raise exception 'Motivo de relevo obligatorio (3 a 300 caracteres)';end if;
   d.proposed_driver_id:=driver;
  elsif p_action='ACCEPT' then
   if d.proposed_driver_id is distinct from actor or d.status not in ('ASIGNADO','EN_RUTA') or not private.delivery_driver_eligible(actor,d.origin_branch_id,d.destination_branch_id) then raise exception 'Solo el nuevo conductor autorizado puede aceptar el relevo' using errcode='42501';end if;
   d.driver_id:=actor;d.proposed_driver_id:=null;
  elsif p_action in ('DEPART','DELIVER') then
   if d.driver_id<>actor or d.proposed_driver_id is not null or not private.delivery_driver_eligible(actor,d.origin_branch_id,d.destination_branch_id) then raise exception 'Solo el conductor vigente puede operar esta entrega' using errcode='42501';end if;
   if p_action='DEPART' then
    if d.status<>'ASIGNADO' then raise exception 'Entrega ya iniciada';end if;
    d.status:='EN_RUTA';d.departed_at:=now();
   else
    if d.status<>'EN_RUTA' then raise exception 'Entrega en ruta requerida';end if;
    if length(trim(coalesce(p_data->>'reference',''))) not between 1 and 120 then raise exception 'Referencia de entrega requerida (máximo 120 caracteres)';end if;
    d.status:='ENTREGADO';d.delivered_at:=now();d.delivery_reference:=trim(p_data->>'reference');
   end if;
  elsif p_action='RECEIVE' then
   if not private.delivery_permission(d.destination_branch_id,'DELIVERIES_RECEIVE') then raise exception 'Laboratorio autorizado en destino requerido' using errcode='42501';end if;
   if d.driver_id=actor or d.status<>'ENTREGADO' then raise exception 'Recepción independiente pendiente requerida';end if;
   if coalesce(p_data->>'temperature','') !~ '^[+-]?[0-9]+(\.[0-9]+)?$' then raise exception 'Temperatura numérica finita requerida';end if;
   v:=(p_data->>'temperature')::numeric;condition:=p_data->>'condition';
   if condition is null or condition not in ('CONFORME','NO_CONFORME') or length(trim(coalesce(p_data->>'evidence',''))) not between 1 and 120 then raise exception 'Condición y referencia de evidencia requeridas';end if;
   select * into t from public.transport_events where id=d.transport_id;
   d.status:=case when condition='CONFORME' and t.min_temp is not null and t.max_temp is not null and t.min_temp<t.max_temp and v between t.min_temp and t.max_temp then 'RECEPCION_REGISTRADA' else 'INCIDENCIA_RECEPCION' end;
   d.receipt_temperature:=v;d.receipt_condition:=condition;d.receipt_evidence:=trim(p_data->>'evidence');d.received_at:=now();d.received_by:=actor;
  else raise exception 'Acción no permitida';end if;
  d.revision:=d.revision+1;
 end if;
 if not exists(select 1 from public.branches where id=d.origin_branch_id and active) or not exists(select 1 from public.branches where id=d.destination_branch_id and active) then raise exception 'Origen y destino deben estar activos';end if;
 if not exists(select 1 from public.transport_events where id=d.transport_id and status<>'CANCELADO') then raise exception 'El traslado fue cancelado; no se permiten acciones';end if;
 if not exists(select 1 from public.team_delivery_pilot where branch_id=d.origin_branch_id and enabled) then raise exception 'Sucursal de origen fuera del piloto';end if;
 if p_action<>'CREATE' then
  update public.team_deliveries set driver_id=d.driver_id,proposed_driver_id=d.proposed_driver_id,status=d.status,revision=d.revision,departed_at=d.departed_at,delivered_at=d.delivered_at,delivery_reference=d.delivery_reference,receipt_temperature=d.receipt_temperature,receipt_condition=d.receipt_condition,receipt_evidence=d.receipt_evidence,received_at=d.received_at,received_by=d.received_by where id=d.id;
 end if;
 insert into public.team_delivery_history(delivery_id,actor_id,action,before_data,after_data,request_id,request_data) values(d.id,actor,p_action,before_row,to_jsonb(d),rid,p_data);
 return to_jsonb(d);
end;$$;
revoke all on function private.team_delivery_catalog(),private.team_delivery_action(text,jsonb) from public,anon;
grant execute on function private.team_delivery_catalog(),private.team_delivery_action(text,jsonb) to authenticated;
create function public.team_delivery_catalog() returns jsonb language sql security invoker set search_path=public,pg_temp as $$select private.team_delivery_catalog()$$;
create function public.team_delivery_action(p_action text,p_data jsonb) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select private.team_delivery_action(p_action,p_data)$$;
revoke all on function public.team_delivery_catalog(),public.team_delivery_action(text,jsonb) from public,anon;
grant execute on function public.team_delivery_catalog(),public.team_delivery_action(text,jsonb) to authenticated;
comment on table public.team_deliveries is 'Coordinación operativa. La verificación de entrega no sustituye lab_operation ni libera unidades. No altera transport_events ni logistics_trips.';
notify pgrst,'reload schema';
commit;
