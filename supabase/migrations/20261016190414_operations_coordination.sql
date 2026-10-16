-- Administrative planning only: never reserves/releases stock or declares clinical eligibility.
begin;
create schema if not exists private;
revoke all on schema private from public,anon,authenticated;
insert into public.app_permissions(permission_code,module,description,risk_level) values
 ('ORDER_PLAN_VIEW','OPERATIONS','Consultar planificación de pedidos','SENSIBLE'),
 ('ORDER_PLAN_WRITE','OPERATIONS','Gestionar planificación administrativa de pedidos','SENSIBLE'),
 ('DONOR_AGENDA_CONFIG','DONORS','Configurar cupos por franja de donación','SENSIBLE')
on conflict(permission_code) do nothing;
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r cross join public.app_permissions p where
 (p.permission_code='ORDER_PLAN_VIEW' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','GERENCIA_GENERAL','ASISTENTE_OPERACIONES','ENCARGADA_LABORATORIO','LABORATORIO','INVENTARIO')) or
 (p.permission_code='ORDER_PLAN_WRITE' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','ASISTENTE_OPERACIONES','ENCARGADA_LABORATORIO')) or
 (p.permission_code='DONOR_AGENDA_CONFIG' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','ENCARGADA_LABORATORIO'))
on conflict do nothing;

create table public.operations_orders(
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),
 reference text not null check(length(btrim(reference)) between 1 and 100),
 requester text not null check(length(btrim(requester)) between 1 and 200),
 component text not null check(length(btrim(component)) between 1 and 120),
 abo text check(abo in ('A','B','AB','O')),rh text check(rh in ('POSITIVO','NEGATIVO')),
 units integer not null check(units between 1 and 10000),due_at timestamptz not null,
 priority text not null default 'NORMAL' check(priority in ('NORMAL','URGENTE')),
 status text not null default 'PENDIENTE' check(status in ('PENDIENTE','EN_GESTION','LISTO','COMPLETADO','CANCELADO')),
 responsible text not null check(length(btrim(responsible)) between 1 and 200),
 notes text check(length(notes)<=4000),revision integer not null default 1,
 created_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(branch_id,reference)
);
create index operations_order_due on public.operations_orders(branch_id,due_at,id) where status not in ('COMPLETADO','CANCELADO');
create index operations_order_actor on public.operations_orders(created_by);
alter table public.operations_orders enable row level security;
revoke all on public.operations_orders from public,anon,authenticated;
grant select,insert,update on public.operations_orders to authenticated;
create policy order_plan_read on public.operations_orders for select to authenticated using(public.wf_active_actor() and public.has_permission('ORDER_PLAN_VIEW') and public.can_access_branch(branch_id));
create policy order_plan_insert on public.operations_orders for insert to authenticated with check(public.wf_active_actor() and public.has_permission('ORDER_PLAN_WRITE') and public.has_permission('ORDER_PLAN_VIEW') and public.can_access_branch(branch_id) and created_by=auth.uid());
create policy order_plan_update on public.operations_orders for update to authenticated using(public.wf_active_actor() and public.has_permission('ORDER_PLAN_WRITE') and public.can_access_branch(branch_id)) with check(public.wf_active_actor() and public.has_permission('ORDER_PLAN_WRITE') and public.can_access_branch(branch_id));
create function public.operations_order_guard() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
begin
 if not public.wf_active_actor() or not public.has_permission('ORDER_PLAN_WRITE') then raise exception 'Sin permiso para planificar pedidos' using errcode='42501';end if;
 if tg_op='INSERT' then
  if new.status<>'PENDIENTE' then raise exception 'El pedido debe comenzar pendiente';end if;
  new.created_by:=auth.uid();new.created_at:=clock_timestamp();new.revision:=1;
 else
  if new.id<>old.id or new.branch_id<>old.branch_id then raise exception 'No se puede trasladar el pedido a otra sucursal';end if;
  if old.status in ('COMPLETADO','CANCELADO') then raise exception 'El pedido ya está cerrado';end if;
  if new.revision<>old.revision then raise exception 'Actualice el pedido antes de modificarlo' using errcode='40001';end if;
  if new.status<>old.status and not ((old.status='PENDIENTE' and new.status in ('EN_GESTION','CANCELADO')) or (old.status='EN_GESTION' and new.status in ('LISTO','CANCELADO')) or (old.status='LISTO' and new.status in ('EN_GESTION','COMPLETADO','CANCELADO'))) then raise exception 'Transición de pedido no permitida';end if;
  if new.status='CANCELADO' and nullif(btrim(new.notes),'') is null then raise exception 'Indique el motivo de cancelación';end if;
  new.created_by:=old.created_by;new.created_at:=old.created_at;new.revision:=old.revision+1;
 end if;
 new.updated_at:=clock_timestamp();return new;
end$$;
revoke all on function public.operations_order_guard() from public,anon,authenticated;
create trigger operations_order_guard before insert or update on public.operations_orders for each row execute function public.operations_order_guard();
create trigger operations_order_audit after insert or update on public.operations_orders for each row execute function public.wf_audit_change();

create table public.donor_agenda_capacity(
 branch_id uuid primary key references public.branches(id),slot_minutes integer not null check(slot_minutes in (15,30,60)),
 capacity integer not null check(capacity between 1 and 100),updated_at timestamptz not null default now(),updated_by uuid not null references public.profiles(id)
);
create index donor_agenda_capacity_actor on public.donor_agenda_capacity(updated_by);
alter table public.donor_agenda_capacity enable row level security;
revoke all on public.donor_agenda_capacity from public,anon,authenticated;
grant select,insert,update on public.donor_agenda_capacity to authenticated;
create policy donor_capacity_read on public.donor_agenda_capacity for select to authenticated using(public.wf_active_actor() and public.has_permission('DONORS_VIEW') and public.can_access_branch(branch_id));
create policy donor_capacity_insert on public.donor_agenda_capacity for insert to authenticated with check(public.wf_active_actor() and public.has_permission('DONOR_AGENDA_CONFIG') and public.has_permission('DONORS_VIEW') and public.can_access_branch(branch_id) and updated_by=auth.uid());
create policy donor_capacity_update on public.donor_agenda_capacity for update to authenticated using(public.wf_active_actor() and public.has_permission('DONOR_AGENDA_CONFIG') and public.can_access_branch(branch_id)) with check(public.wf_active_actor() and public.has_permission('DONOR_AGENDA_CONFIG') and public.can_access_branch(branch_id));
create function private.donor_capacity_guard() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if tg_op='UPDATE' and new.branch_id<>old.branch_id then raise exception 'No se puede reasignar la configuración';end if;
 if auth.uid() is null or not public.wf_active_actor() or not public.has_permission('DONOR_AGENDA_CONFIG') or not public.has_permission('DONORS_VIEW') or not public.can_access_branch(new.branch_id) then raise exception 'Sin permiso para configurar cupos' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('donor-agenda:'||new.branch_id::text,0));
 if exists(select 1 from public.donor_visits v where v.branch_id=new.branch_id and v.status in ('POR_CONFIRMAR','CONFIRMADA') and v.starts_at>=now() group by (v.starts_at at time zone 'America/Santo_Domingo')::date, floor(extract(epoch from ((v.starts_at at time zone 'America/Santo_Domingo')::time))/ (new.slot_minutes*60)) having count(*)>new.capacity) then raise exception 'Los cupos propuestos son menores que las citas ya reservadas';end if;
 new.updated_at:=clock_timestamp();new.updated_by:=auth.uid();return new;
end$$;
revoke all on function private.donor_capacity_guard() from public,anon,authenticated;
create trigger donor_capacity_guard before insert or update on public.donor_agenda_capacity for each row execute function private.donor_capacity_guard();

-- The latest actual contact governs follow-up; imported notes are not counted as new contacts.
create view public.vw_donor_coordination with(security_invoker=true) as
select d.*,c.id as last_contact_id,c.contacted_at as last_contact_at,c.outcome as last_contact_outcome,c.next_contact_at,
 v.id as active_visit_id,v.branch_id as visit_branch_id,v.starts_at as visit_starts_at,v.status as visit_status
from public.vw_donor_next_donation d
left join lateral(select id,contacted_at,outcome,next_contact_at from public.donor_contacts where donor_id=d.id order by contacted_at desc,created_at desc,id desc limit 1)c on true
left join lateral(select id,branch_id,starts_at,status from public.donor_visits where donor_id=d.id and status in ('POR_CONFIRMAR','CONFIRMADA') order by starts_at,id limit 1)v on true;
create view public.vw_donor_appointment_agenda with(security_invoker=true) as
select v.*,d.full_name,d.donor_code,d.phone,d.abo,d.rh,d.last_donation_date,d.next_donation_date
from public.donor_visits v join public.vw_donor_next_donation d on d.id=v.donor_id;
revoke all on public.vw_donor_coordination,public.vw_donor_appointment_agenda from public,anon;
grant select on public.vw_donor_coordination,public.vw_donor_appointment_agenda to authenticated;
create index donor_calendar_window on public.donor_visits(starts_at,id);
create index donor_latest_contact on public.donor_contacts(donor_id,contacted_at desc,created_at desc,id desc);

create function private.donor_visit_planning_guard() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare lim public.donor_agenda_capacity;last_date date;ref_date date;bucket bigint;occupied integer;b uuid;
begin
 if auth.uid() is null or not public.wf_active_actor() or not public.has_permission('DONORS_WRITE') or not public.has_permission('DONORS_VIEW') or not public.can_access_branch(new.branch_id) or not exists(select 1 from public.donors d where d.id=new.donor_id and public.can_access_branch(d.branch_id)) then raise exception 'Sin acceso a la agenda del donante' using errcode='42501';end if;
 -- Count every reservation in the branch, including donor identities hidden by RLS.
 -- The private trigger exposes no cross-branch identities or public RPC.
 -- Lock both branch identifiers in order when moving a reservation between branches.
 for b in select distinct x from unnest(case when tg_op='UPDATE' then array[old.branch_id,new.branch_id] else array[new.branch_id] end)x order by x loop
  perform pg_advisory_xact_lock(hashtextextended('donor-agenda:'||b::text,0));
 end loop;
 if new.status not in ('POR_CONFIRMAR','CONFIRMADA') then return new;end if;
 select last_donation_date,next_donation_date into last_date,ref_date from public.vw_donor_next_donation where id=new.donor_id;
 if not found then raise exception 'Ficha del donante no accesible' using errcode='42501';end if;
 if last_date is not null and (ref_date is null or (new.starts_at at time zone 'America/Santo_Domingo')::date<last_date+84) then raise exception 'La visita debe respetar 84 días desde la última donación; verifique el antecedente';end if;
 select * into lim from public.donor_agenda_capacity where branch_id=new.branch_id;
 if found then
  bucket:=floor(extract(epoch from ((new.starts_at at time zone 'America/Santo_Domingo')::time))/(lim.slot_minutes*60));
  select count(*) into occupied from public.donor_visits v where v.branch_id=new.branch_id and v.status in ('POR_CONFIRMAR','CONFIRMADA') and v.id<>new.id
   and v.starts_at>=(((new.starts_at at time zone 'America/Santo_Domingo')::date)::timestamp at time zone 'America/Santo_Domingo')
   and v.starts_at<((((new.starts_at at time zone 'America/Santo_Domingo')::date)+1)::timestamp at time zone 'America/Santo_Domingo')
   and floor(extract(epoch from ((v.starts_at at time zone 'America/Santo_Domingo')::time))/(lim.slot_minutes*60))=bucket;
  if occupied>=lim.capacity then raise exception 'No quedan cupos en esa franja. Seleccione otro horario.' using errcode='23514';end if;
 end if;
 return new;
end$$;
revoke all on function private.donor_visit_planning_guard() from public,anon,authenticated;
create trigger zz_donor_visit_planning_guard before insert or update on public.donor_visits for each row execute function private.donor_visit_planning_guard();
notify pgrst,'reload schema';
commit;
