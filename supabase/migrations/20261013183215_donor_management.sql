-- Identification and administrative agenda. Existing clinical status guards remain active.
-- Additive schema: no donor/donation records are rewritten or removed.
alter table public.donors add column if not exists full_name text;
alter table public.donors add column if not exists cedula text;
alter table public.donors add column if not exists sex text;
alter table public.donors add column if not exists phone text;
alter table public.donors add column if not exists preferred_channel text not null default 'LLAMADA';
alter table public.donors add constraint donor_identity_cedula check(cedula is null or cedula ~ '^[0-9]{11}$');
alter table public.donors add constraint donor_identity_sex check(sex is null or sex in ('FEMENINO','MASCULINO','OTRO','NO_INFORMADO'));
alter table public.donors add constraint donor_identity_channel check(preferred_channel in ('LLAMADA','WHATSAPP','SMS','CORREO'));
create unique index donor_identity_cedula_unique on public.donors(cedula) where cedula is not null;
create index donor_identity_name on public.donors(lower(full_name));
create index if not exists donor_history_date on public.donations(donor_id,donation_date desc,id);

create table public.donor_lab_comments(
 id uuid primary key default gen_random_uuid(),donor_id uuid not null references public.donors(id),
 branch_id uuid not null references public.branches(id),comment text not null check(length(btrim(comment)) between 1 and 4000),
 created_by uuid not null references public.profiles(id),responsible_name text not null,
 created_at timestamptz not null default now()
);
create table public.donor_contacts(
 id uuid primary key default gen_random_uuid(),donor_id uuid not null references public.donors(id),
 branch_id uuid not null references public.branches(id),channel text not null check(channel in ('LLAMADA','WHATSAPP','SMS','CORREO')),
 outcome text not null check(outcome in ('CONTACTADO','SIN_RESPUESTA','VOLVER_A_LLAMAR','NO_DESEA')),
 notes text not null check(length(btrim(notes)) between 1 and 4000),contacted_at timestamptz not null,
 next_contact_at timestamptz check(next_contact_at is null or next_contact_at>contacted_at),
 created_by uuid not null references public.profiles(id),responsible_name text not null,created_at timestamptz not null default now()
);
create table public.donor_visits(
 id uuid primary key default gen_random_uuid(),donor_id uuid not null references public.donors(id),
 branch_id uuid not null references public.branches(id),starts_at timestamptz not null,
 status text not null default 'POR_CONFIRMAR' check(status in ('POR_CONFIRMAR','CONFIRMADA','ASISTIO','NO_ASISTIO','CANCELADA')),
 notes text check(length(notes)<=4000),created_by uuid not null references public.profiles(id),responsible_name text not null,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 revision integer not null default 1,history jsonb not null default '[]'::jsonb check(jsonb_typeof(history)='array')
);
create unique index donor_visit_active_unique on public.donor_visits(donor_id) where status in ('POR_CONFIRMAR','CONFIRMADA');
create index donor_lab_history on public.donor_lab_comments(donor_id,created_at desc,id);
create index donor_contact_history on public.donor_contacts(donor_id,contacted_at desc,id);
create index donor_visit_history on public.donor_visits(donor_id,starts_at desc,id);
create index donor_visit_agenda on public.donor_visits(branch_id,starts_at) where status in ('POR_CONFIRMAR','CONFIRMADA');
create index donor_contact_followup on public.donor_contacts(next_contact_at) where next_contact_at is not null;
create index donor_lab_actor on public.donor_lab_comments(created_by);
create index donor_contact_actor on public.donor_contacts(created_by);
create index donor_visit_actor on public.donor_visits(created_by);
create index donor_lab_branch on public.donor_lab_comments(branch_id);
create index donor_contact_branch on public.donor_contacts(branch_id);

-- Restrictive policies combine with existing branch policies rather than replacing them.
create policy donor_identity_read on public.donors as restrictive for select to authenticated
 using(public.wf_active_actor() and public.has_permission('DONORS_VIEW'));
create policy donor_identity_insert on public.donors as restrictive for insert to authenticated
 with check(public.wf_active_actor() and public.has_permission('DONORS_WRITE') and public.can_access_branch(branch_id));
create policy donor_identity_update on public.donors as restrictive for update to authenticated
 using(public.wf_active_actor() and public.has_permission('DONORS_WRITE') and public.can_access_branch(branch_id))
 with check(public.wf_active_actor() and public.has_permission('DONORS_WRITE') and public.can_access_branch(branch_id));
create policy donor_identity_delete on public.donors as restrictive for delete to authenticated
 using(public.wf_active_actor() and public.has_permission('DONORS_WRITE') and public.can_access_branch(branch_id));

alter table public.donor_lab_comments enable row level security;
alter table public.donor_contacts enable row level security;
alter table public.donor_visits enable row level security;
revoke all on public.donor_lab_comments,public.donor_contacts,public.donor_visits from public,anon,authenticated;
grant select,insert on public.donor_lab_comments,public.donor_contacts to authenticated;
grant select,insert,update on public.donor_visits to authenticated;
create policy donor_lab_read on public.donor_lab_comments for select to authenticated
 using(public.wf_active_actor() and public.has_permission('DONORS_VIEW') and public.can_access_branch(branch_id) and exists(select 1 from public.donors d where d.id=donor_id and d.branch_id=donor_lab_comments.branch_id));
create policy donor_lab_insert on public.donor_lab_comments for insert to authenticated
 with check(public.wf_active_actor() and public.has_permission('SCREENING_WRITE') and created_by=(select auth.uid()) and public.can_access_branch(branch_id) and exists(select 1 from public.donors d where d.id=donor_id and d.branch_id=donor_lab_comments.branch_id));
create policy donor_contact_read on public.donor_contacts for select to authenticated
 using(public.wf_active_actor() and public.has_permission('DONORS_VIEW') and public.can_access_branch(branch_id) and exists(select 1 from public.donors d where d.id=donor_id and d.branch_id=donor_contacts.branch_id));
create policy donor_contact_insert on public.donor_contacts for insert to authenticated
 with check(public.wf_active_actor() and public.has_permission('DONORS_WRITE') and created_by=(select auth.uid()) and public.can_access_branch(branch_id) and exists(select 1 from public.donors d where d.id=donor_id and d.branch_id=donor_contacts.branch_id));
create policy donor_visit_read on public.donor_visits for select to authenticated
 using(public.wf_active_actor() and public.has_permission('DONORS_VIEW') and public.can_access_branch(branch_id) and exists(select 1 from public.donors d where d.id=donor_id and public.can_access_branch(d.branch_id)));
create policy donor_visit_insert on public.donor_visits for insert to authenticated
 with check(public.wf_active_actor() and public.has_permission('DONORS_WRITE') and created_by=(select auth.uid()) and public.can_access_branch(branch_id) and exists(select 1 from public.donors d where d.id=donor_id and public.can_access_branch(d.branch_id)));
create policy donor_visit_update on public.donor_visits for update to authenticated
 using(public.wf_active_actor() and public.has_permission('DONORS_WRITE') and public.can_access_branch(branch_id) and exists(select 1 from public.donors d where d.id=donor_id and public.can_access_branch(d.branch_id)))
 with check(public.wf_active_actor() and public.has_permission('DONORS_WRITE') and public.can_access_branch(branch_id) and exists(select 1 from public.donors d where d.id=donor_id and public.can_access_branch(d.branch_id)));

create function public.donor_management_stamp() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
declare actor_name text;
begin
 if not public.wf_active_actor() then raise exception 'Sesión activa requerida' using errcode='42501';end if;
 select coalesce(nullif(btrim(full_name),''),auth.uid()::text) into actor_name from public.profiles where id=auth.uid();
 actor_name:=coalesce(actor_name,auth.uid()::text);
 if tg_op='INSERT' then
  new.created_by:=auth.uid();new.created_at:=clock_timestamp();new.responsible_name:=actor_name;
  if tg_table_name='donor_contacts' then
   if new.contacted_at>clock_timestamp() or (new.next_contact_at is not null and new.next_contact_at<=clock_timestamp()) then raise exception 'Fecha del contacto o seguimiento inválida';end if;
  elsif tg_table_name='donor_visits' then
   if new.status not in ('POR_CONFIRMAR','CONFIRMADA') or new.starts_at<=clock_timestamp() then raise exception 'La cita debe tener fecha futura y estado pendiente o confirmado';end if;
   new.revision:=1;new.history:='[]'::jsonb;new.updated_at:=clock_timestamp();
  end if;
 elsif tg_table_name='donor_visits' then
  if new.id<>old.id or new.donor_id<>old.donor_id then raise exception 'No se puede reasignar la visita';end if;
  if old.status not in ('POR_CONFIRMAR','CONFIRMADA') then raise exception 'La visita ya está cerrada';end if;
  if (new.starts_at is distinct from old.starts_at or new.branch_id is distinct from old.branch_id) and (new.starts_at<=clock_timestamp() or new.status not in ('POR_CONFIRMAR','CONFIRMADA')) then raise exception 'Reprogramación inválida';end if;
  if new.status in ('ASISTIO','NO_ASISTIO') and old.starts_at>clock_timestamp() then raise exception 'No se puede registrar asistencia antes de la cita';end if;
  new.created_by:=old.created_by;new.created_at:=old.created_at;new.responsible_name:=old.responsible_name;
  new.revision:=old.revision+1;new.updated_at:=clock_timestamp();
  new.history:=old.history||jsonb_build_array(jsonb_build_object('starts_at',old.starts_at,'branch_id',old.branch_id,'status',old.status,'notes',old.notes,'changed_at',new.updated_at,'actor_id',auth.uid(),'responsible_name',actor_name));
 end if;
 return new;
end $$;
revoke all on function public.donor_management_stamp() from public,anon,authenticated;
create trigger donor_lab_stamp before insert on public.donor_lab_comments for each row execute function public.donor_management_stamp();
create trigger donor_contact_stamp before insert on public.donor_contacts for each row execute function public.donor_management_stamp();
create trigger donor_visit_stamp before insert or update on public.donor_visits for each row execute function public.donor_management_stamp();
create trigger donor_lab_audit after insert on public.donor_lab_comments for each row execute function public.wf_audit_change();
create trigger donor_contact_audit after insert on public.donor_contacts for each row execute function public.wf_audit_change();
create trigger donor_visit_audit after insert or update on public.donor_visits for each row execute function public.wf_audit_change();
notify pgrst,'reload schema';
