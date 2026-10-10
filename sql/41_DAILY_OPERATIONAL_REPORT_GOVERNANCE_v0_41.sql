-- HemoCura v0.41.0
-- Gobierno del Reporte Operativo Diario: permisos, versionado, revisión, cierre y reapertura.

begin;

insert into public.app_permissions(permission_code,module,description,risk_level,active) values
('DAILY_REPORT_VIEW','DAILY_REPORT','Ver reportes operativos diarios','SENSIBLE',true),
('DAILY_REPORT_WRITE','DAILY_REPORT','Crear y editar borradores del reporte operativo diario','CRITICO',true),
('DAILY_REPORT_SUBMIT','DAILY_REPORT','Enviar reporte operativo diario a revisión','SENSIBLE',true),
('DAILY_REPORT_CLOSE','DAILY_REPORT','Cerrar y firmar reporte operativo diario','CRITICO',true),
('DAILY_REPORT_REOPEN','DAILY_REPORT','Reabrir reporte operativo diario cerrado','CRITICO',true)
on conflict(permission_code) do update set module=excluded.module,description=excluded.description,risk_level=excluded.risk_level,active=true;

alter table public.daily_operational_closes
  add column if not exists report_version integer not null default 1,
  add column if not exists last_modified_by uuid references public.profiles(id),
  add column if not exists submitted_by uuid references public.profiles(id),
  add column if not exists submitted_at timestamptz,
  add column if not exists reopened_by uuid references public.profiles(id),
  add column if not exists reopened_at timestamptz,
  add column if not exists reopen_reason text;

create table if not exists public.daily_operational_report_versions(
  id bigint generated always as identity primary key,
  report_id uuid not null references public.daily_operational_closes(id) on delete cascade,
  branch_id uuid not null references public.branches(id),
  close_date date not null,
  report_version integer not null,
  status text not null,
  snapshot jsonb not null,
  changed_by uuid references public.profiles(id),
  changed_at timestamptz not null default now()
);
create index if not exists idx_daily_report_versions_report on public.daily_operational_report_versions(report_id,report_version desc);
create index if not exists idx_daily_report_versions_branch_date on public.daily_operational_report_versions(branch_id,close_date desc);
alter table public.daily_operational_report_versions enable row level security;

drop policy if exists daily_report_versions_select on public.daily_operational_report_versions;
create policy daily_report_versions_select on public.daily_operational_report_versions
for select to authenticated
using(public.can_access_branch(branch_id) and public.has_permission('DAILY_REPORT_VIEW'));
revoke all on public.daily_operational_report_versions from anon, authenticated;
grant select on public.daily_operational_report_versions to authenticated;

insert into public.role_permissions(role_id,permission_code)
select distinct rp.role_id,'DAILY_REPORT_VIEW' from public.role_permissions rp
where rp.permission_code in ('BLOOD_INVENTORY_VIEW','COMMAND_VIEW') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code)
select distinct rp.role_id,'DAILY_REPORT_WRITE' from public.role_permissions rp
where rp.permission_code='BLOOD_INVENTORY_WRITE' on conflict do nothing;
insert into public.role_permissions(role_id,permission_code)
select distinct rp.role_id,'DAILY_REPORT_SUBMIT' from public.role_permissions rp
where rp.permission_code='BLOOD_INVENTORY_WRITE' on conflict do nothing;
insert into public.role_permissions(role_id,permission_code)
select r.id,'DAILY_REPORT_CLOSE' from public.roles r
where r.code in ('ADMIN','SUPER_USUARIO','GERENCIA_OPERATIVA','ENCARGADA_LABORATORIO') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code)
select r.id,'DAILY_REPORT_REOPEN' from public.roles r
where r.code in ('ADMIN','SUPER_USUARIO','GERENCIA_OPERATIVA','CALIDAD') on conflict do nothing;

drop policy if exists daily_operational_closes_access on public.daily_operational_closes;
drop policy if exists daily_operational_closes_select on public.daily_operational_closes;
drop policy if exists daily_operational_closes_insert on public.daily_operational_closes;
drop policy if exists daily_operational_closes_update on public.daily_operational_closes;
create policy daily_operational_closes_select on public.daily_operational_closes
for select to authenticated using(public.can_access_branch(branch_id) and public.has_permission('DAILY_REPORT_VIEW'));
create policy daily_operational_closes_insert on public.daily_operational_closes
for insert to authenticated with check(public.can_access_branch(branch_id) and public.has_permission('DAILY_REPORT_WRITE'));
create policy daily_operational_closes_update on public.daily_operational_closes
for update to authenticated
using(public.can_access_branch(branch_id) and public.has_permission('DAILY_REPORT_WRITE'))
with check(public.can_access_branch(branch_id) and public.has_permission('DAILY_REPORT_WRITE'));

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create or replace function private.capture_daily_report_version()
returns trigger language plpgsql security definer set search_path=public,private as $$
begin
  insert into public.daily_operational_report_versions(report_id,branch_id,close_date,report_version,status,snapshot,changed_by)
  values(new.id,new.branch_id,new.close_date,new.report_version,new.status,to_jsonb(new),auth.uid());
  return new;
end; $$;
revoke all on function private.capture_daily_report_version() from public,anon,authenticated;
drop trigger if exists trg_daily_report_version on public.daily_operational_closes;
create trigger trg_daily_report_version after insert or update on public.daily_operational_closes
for each row execute function private.capture_daily_report_version();

-- La edición permanece SECURITY INVOKER y solo permite borradores/reabiertos.
create or replace function public.save_daily_operational_report(
  p_close_date date,p_branch_id uuid,p_responsible_name text,p_screening_lots jsonb default '[]'::jsonb,
  p_manual_inventory jsonb default '{}'::jsonb,p_manual_dispatches jsonb default '[]'::jsonb,
  p_equipment_snapshot jsonb default '[]'::jsonb,p_notes text default null,p_status text default 'BORRADOR'
) returns uuid language plpgsql security invoker set search_path=public as $$
declare v_id uuid; v_existing public.daily_operational_closes%rowtype; v_screened numeric:=0; v_reactive numeric:=0; v_available numeric:=0; v_dispatched numeric:=0; v_live public.vw_daily_branch_operations%rowtype;
begin
  if not public.can_access_branch(p_branch_id) or not public.has_permission('DAILY_REPORT_WRITE') then raise exception 'Sin permiso para editar este reporte'; end if;
  select * into v_existing from public.daily_operational_closes where close_date=p_close_date and branch_id=p_branch_id;
  if v_existing.status in ('EN_REVISION','CERRADO') then raise exception 'El reporte no puede editarse en estado %',v_existing.status; end if;
  select coalesce(sum(coalesce((x->>'non_reactive')::numeric,0)+coalesce((x->>'reactive')::numeric,0)),0),coalesce(sum(coalesce((x->>'reactive')::numeric,0)),0) into v_screened,v_reactive from jsonb_array_elements(coalesce(p_screening_lots,'[]'::jsonb)) x;
  select coalesce(sum(coalesce((x.value->>'whole_blood')::numeric,0)+coalesce((x.value->>'packed_cells')::numeric,0)+coalesce((x.value->>'plasma')::numeric,0)+coalesce((x.value->>'platelets')::numeric,0)),0) into v_available from jsonb_each(coalesce(p_manual_inventory,'{}'::jsonb)) x;
  select coalesce(sum(coalesce((x->>'quantity')::numeric,0)),0) into v_dispatched from jsonb_array_elements(coalesce(p_manual_dispatches,'[]'::jsonb)) x;
  if p_close_date=current_date then select * into v_live from public.vw_daily_branch_operations where branch_id=p_branch_id; end if;
  insert into public.daily_operational_closes(close_date,branch_id,status,responsible_name,donors_count,effective_donations,screened_units,reactive_results,available_units,dispatched_units,invoiced_units,invoiced_amount,screening_lots,manual_inventory,manual_dispatches,equipment_snapshot,source_mode,notes,last_modified_by,updated_at)
  values(p_close_date,p_branch_id,'BORRADOR',nullif(trim(p_responsible_name),''),coalesce(v_live.donors,0),coalesce(v_live.effective_donations,0),v_screened,v_reactive,v_available,v_dispatched,coalesce(v_live.invoiced_units,0),coalesce(v_live.invoiced_amount,0),coalesce(p_screening_lots,'[]'::jsonb),coalesce(p_manual_inventory,'{}'::jsonb),coalesce(p_manual_dispatches,'[]'::jsonb),coalesce(p_equipment_snapshot,'[]'::jsonb),'MANUAL_CONSOLIDADO',p_notes,auth.uid(),now())
  on conflict(close_date,branch_id) do update set status='BORRADOR',responsible_name=excluded.responsible_name,donors_count=excluded.donors_count,effective_donations=excluded.effective_donations,screened_units=excluded.screened_units,reactive_results=excluded.reactive_results,available_units=excluded.available_units,dispatched_units=excluded.dispatched_units,invoiced_units=excluded.invoiced_units,invoiced_amount=excluded.invoiced_amount,screening_lots=excluded.screening_lots,manual_inventory=excluded.manual_inventory,manual_dispatches=excluded.manual_dispatches,equipment_snapshot=excluded.equipment_snapshot,source_mode='MANUAL_CONSOLIDADO',notes=excluded.notes,last_modified_by=auth.uid(),report_version=public.daily_operational_closes.report_version+1,updated_at=now()
  returning id into v_id; return v_id;
end; $$;
revoke all on function public.save_daily_operational_report(date,uuid,text,jsonb,jsonb,jsonb,jsonb,text,text) from public,anon;
grant execute on function public.save_daily_operational_report(date,uuid,text,jsonb,jsonb,jsonb,jsonb,text,text) to authenticated;

create or replace function public.submit_daily_operational_report(p_report_id uuid)
returns uuid language plpgsql security invoker set search_path=public as $$
declare r public.daily_operational_closes%rowtype;
begin
  select * into r from public.daily_operational_closes where id=p_report_id;
  if r.id is null then raise exception 'Reporte no encontrado'; end if;
  if not public.can_access_branch(r.branch_id) or not public.has_permission('DAILY_REPORT_SUBMIT') then raise exception 'Sin permiso para enviar a revisión'; end if;
  if r.status not in ('BORRADOR','REABIERTO') then raise exception 'Estado no válido para envío'; end if;
  update public.daily_operational_closes set status='EN_REVISION',submitted_by=auth.uid(),submitted_at=now(),last_modified_by=auth.uid(),report_version=report_version+1,updated_at=now() where id=p_report_id;
  return p_report_id;
end; $$;
revoke all on function public.submit_daily_operational_report(uuid) from public,anon;
grant execute on function public.submit_daily_operational_report(uuid) to authenticated;

commit;
