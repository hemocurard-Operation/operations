-- HemoCura: additive operational route, commercial work, hyperbaric service and daily quality.
-- Requires the reconciled daily report baseline and Decision Chain foundation.
-- No historical user/role deletion, clinical feature activation or synthetic production data.
begin;
set local lock_timeout='5s';
set local statement_timeout='120s';
do $$ begin
 if to_regclass('public.medical_referrers') is null or to_regclass('public.daily_operational_closes') is null
    or to_regprocedure('public.has_permission(text)') is null or to_regclass('public.operational_sales') is null then
  raise exception 'Prerequisites missing: daily report, Decision Chain and access governance';
 end if;
end $$;

insert into public.app_permissions(permission_code,module,description,risk_level) values
('WORKFLOW_VIEW','WORKFLOW','Consultar ruta operativa por sucursal','NORMAL'),
('COMMERCIAL_VIEW','COMMERCIAL','Ver cartera, agenda y planes comerciales','SENSIBLE'),
('COMMERCIAL_WRITE','COMMERCIAL','Registrar visitas, compromisos y oportunidades','SENSIBLE'),
('HYPERBARIC_VIEW','HYPERBARIC','Ver agenda y reporte nominativo autorizado','SENSIBLE'),
('HYPERBARIC_WRITE','HYPERBARIC','Asignar y gestionar citas','SENSIBLE'),
('HYPERBARIC_SESSION_WRITE','HYPERBARIC','Documentar sesión por personal clínico autorizado','CRITICO'),
('HYPERBARIC_BILLING','HYPERBARIC','Facturar y registrar cobros de sesiones','SENSIBLE'),
('QUALITY_DAILY_REVIEW','QUALITY','Revisar evidencias de calidad de otro ejecutor','SENSIBLE')
on conflict(permission_code) do nothing;
-- Administration receives management access, not clinical execution by virtue of being admin.
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r cross join public.app_permissions p
where r.code in ('ADMIN','SUPER_USUARIO') and p.permission_code in
('WORKFLOW_VIEW','COMMERCIAL_VIEW','COMMERCIAL_WRITE','HYPERBARIC_VIEW','HYPERBARIC_WRITE','HYPERBARIC_BILLING','QUALITY_DAILY_REVIEW')
on conflict do nothing;
insert into public.role_permissions(role_id,permission_code)
select rp.role_id,x.new_permission from public.role_permissions rp join (values
('DAILY_REPORT_VIEW','WORKFLOW_VIEW'),('CUSTOMER_VIEW','COMMERCIAL_VIEW'),
('MEDICAL_NETWORK_WRITE','COMMERCIAL_WRITE'),('QUALITY_WRITE','QUALITY_DAILY_REVIEW')
) x(existing_permission,new_permission) on x.existing_permission=rp.permission_code
on conflict do nothing;
insert into public.role_permissions(role_id,permission_code)
select r.id,'HYPERBARIC_SESSION_WRITE' from public.roles r where r.code='MEDICO_GERENTE_TECNICO'
on conflict do nothing;

create table if not exists public.workflow_audit (
 id uuid primary key default gen_random_uuid(),branch_id uuid references public.branches(id),
 actor_id uuid not null references public.profiles(id),table_name text not null,record_id uuid not null,
 operation text not null,old_status text,new_status text,changed_at timestamptz not null default now()
);
create table if not exists public.workflow_daily_sections (
 id uuid primary key default gen_random_uuid(),report_id uuid not null references public.daily_operational_closes(id),
 branch_id uuid not null references public.branches(id),report_date date not null,
 donor_batch text not null,accepted integer not null check(accepted>=0),deferred integer not null check(deferred>=0),
 discarded integer not null check(discarded>=0),markers jsonb not null default '[]',receipts jsonb not null default '[]',
 updated_by uuid not null references public.profiles(id),updated_at timestamptz not null default now(),unique(report_id)
);
create table if not exists public.commercial_locations (
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),
 customer_id uuid not null references public.customers(id),address text not null,latitude numeric check(latitude between -90 and 90),
 longitude numeric check(longitude between -180 and 180),contact_name text,contact_phone text,verified_at timestamptz,
 created_by uuid not null references public.profiles(id),unique(branch_id,customer_id),
 check((latitude is null)=(longitude is null))
);
create table if not exists public.commercial_plans (
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),
 agent_id uuid not null references public.profiles(id),cycle_start date not null,goal text not null,
 target_visits integer not null check(target_visits>0),tactics text not null,created_at timestamptz not null default now()
);
create table if not exists public.commercial_visits (
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),customer_id uuid not null references public.customers(id),
 agent_id uuid not null references public.profiles(id),plan_id uuid references public.commercial_plans(id),
 scheduled_at timestamptz not null,duration_minutes integer not null default 30 check(duration_minutes between 5 and 480),
 purpose text not null,status text not null default 'PROPUESTA' check(status in ('PROPUESTA','CONFIRMADA','REALIZADA','CANCELADA')),
 evidence text,commitment text,followup_at timestamptz,completed_at timestamptz,created_at timestamptz not null default now()
);
create table if not exists public.commercial_opportunities (
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),
 customer_id uuid not null references public.customers(id),owner_id uuid not null references public.profiles(id),
 title text not null,stage text not null default 'PROSPECTO' check(stage in ('PROSPECTO','CONTACTO','PROPUESTA','NEGOCIACION','GANADA','PERDIDA')),
 currency text not null check(currency in ('DOP','USD')),estimated_amount numeric(14,2) not null check(estimated_amount>=0 and estimated_amount::text not in ('NaN','Infinity','-Infinity')),
 sale_id uuid references public.operational_sales(id),loss_reason text,created_at timestamptz not null default now(),
 check(stage<>'PERDIDA' or length(btrim(loss_reason))>=3)
);
create table if not exists public.hyperbaric_resources (
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),name text not null,
 capacity integer not null check(capacity between 1 and 30),procedure_reference text not null,
 active boolean not null default true,created_by uuid not null references public.profiles(id),unique(branch_id,name)
);
create table if not exists public.hyperbaric_appointments (
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),
 resource_id uuid not null references public.hyperbaric_resources(id),customer_id uuid references public.customers(id),patient_name text not null,patient_phone text not null,
 starts_at timestamptz not null,ends_at timestamptz not null,operational_date date not null,
 shift text not null check(shift in ('DIURNO','NOCTURNO')),price numeric(14,2) not null check(price>=0 and price::text not in ('NaN','Infinity','-Infinity')),
 currency text not null check(currency in ('USD','DOP')),session_label text not null,
 referrer_id uuid references public.medical_referrers(id),referrer_name text not null,note text,
 status text not null default 'SOLICITADA' check(status in ('SOLICITADA','CONFIRMADA','ATENDIDA','CANCELADA','NO_ASISTIO')),
 created_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),
 check(ends_at>starts_at and ends_at-starts_at<=interval '8 hours')
);
create table if not exists public.hyperbaric_sessions (
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),
 appointment_id uuid not null unique references public.hyperbaric_appointments(id),
 performed_at timestamptz not null,operational_date date not null,shift text not null check(shift in ('DIURNO','NOCTURNO')),
 provider_id uuid not null references public.profiles(id),clinical_authorization text not null,consent_reference text not null,
 evidence text not null,status text not null check(status in ('REALIZADA','INTERRUMPIDA')),created_at timestamptz not null default now()
);
create table if not exists public.hyperbaric_charges (
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),
 session_id uuid not null unique references public.hyperbaric_sessions(id),customer_id uuid references public.customers(id),invoice_number text not null,
 invoice_date date not null,service_date date not null,shift text not null check(shift in ('DIURNO','NOCTURNO')),currency text not null check(currency in ('USD','DOP')),amount numeric(14,2) not null check(amount>0 and amount::text not in ('NaN','Infinity','-Infinity')),
 status text not null default 'FACTURADA' check(status in ('FACTURADA','ANULADA')),
 created_by uuid not null references public.profiles(id),unique(branch_id,invoice_number)
);
create table if not exists public.hyperbaric_payments (
 id uuid primary key,branch_id uuid not null references public.branches(id),
 charge_id uuid not null references public.hyperbaric_charges(id),payment_date date not null,
 currency text not null check(currency in ('USD','DOP')),amount numeric(14,2) not null check(amount>0 and amount::text not in ('NaN','Infinity','-Infinity')),
 receipt_number text not null,created_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),
 unique(branch_id,receipt_number)
);
create table if not exists public.blood_quality_tasks (
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),
 task_date date not null,shift text not null check(shift in ('DIURNO','NOCTURNO')),title text not null,
 process text not null,procedure_reference text not null,priority text not null check(priority in ('NORMAL','ALTA','CRITICA')),
 owner_id uuid not null references public.profiles(id),due_at timestamptz not null,
 status text not null default 'PENDIENTE' check(status in ('PENDIENTE','EN_REVISION','ACEPTADA','CORRECCION','NO_APLICA')),
 evidence text,submitted_at timestamptz,reviewed_by uuid references public.profiles(id),reviewed_at timestamptz,review_note text,
 incident_id uuid references public.incidents(id),created_at timestamptz not null default now()
);
create table if not exists public.blood_transfers (
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),
 destination_branch_id uuid not null references public.branches(id),batch_code text not null,
 status text not null default 'EN_TRANSITO' check(status in ('EN_TRANSITO','PARCIAL','RECIBIDA')),
 transport_evidence text not null,sent_by uuid not null references public.profiles(id),sent_at timestamptz not null default now(),
 check(branch_id<>destination_branch_id),unique(branch_id,batch_code)
);
create table if not exists public.blood_transfer_lines (
 id uuid primary key default gen_random_uuid(),transfer_id uuid not null references public.blood_transfers(id),
 unit_id uuid not null references public.blood_inventory_units(id),unit_code text,component_name text,abo text,rh text,received_at timestamptz,
 received_by uuid references public.profiles(id),receipt_evidence text,receipt_condition text,
 review_decision text,reviewed_by uuid references public.profiles(id),reviewed_at timestamptz,review_evidence text,
 unique(transfer_id,unit_id)
);
alter table public.blood_transfer_lines add column if not exists unit_code text;
alter table public.blood_transfer_lines add column if not exists component_name text;
alter table public.blood_transfer_lines add column if not exists abo text;
alter table public.blood_transfer_lines add column if not exists rh text;
create unique index if not exists blood_transfer_one_pending_unit on public.blood_transfer_lines(unit_id) where received_at is null;
create index if not exists commercial_visits_branch_schedule on public.commercial_visits(branch_id,scheduled_at);
create index if not exists hyperbaric_appointments_resource_period on public.hyperbaric_appointments(resource_id,starts_at,ends_at);
create index if not exists blood_quality_daily_queue on public.blood_quality_tasks(branch_id,task_date,shift);

alter table public.operational_sales add column if not exists shift text;
alter table public.operational_sales add column if not exists treating_doctor text;
-- Legacy sales remain DOP. USD hyperbaric charges have their own service origin and explicit union report.

create or replace function public.wf_require(p_permission text,p_branch uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and active)
    or not public.has_permission(p_permission) or p_branch is null or not public.can_access_branch(p_branch)
    or not exists(select 1 from public.branches where id=p_branch and active) then
  raise exception 'Permiso o sucursal no autorizados: %',p_permission using errcode='42501';
 end if;
end $$;
revoke execute on function public.wf_require(text,uuid) from public,anon,authenticated;

create or replace function public.wf_active_actor()
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and exists(select 1 from public.profiles where id=auth.uid() and active);
$$;
revoke execute on function public.wf_active_actor() from public,anon;
grant execute on function public.wf_active_actor() to authenticated;

create or replace function public.wf_audit_change()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare b uuid; j jsonb:=to_jsonb(new);
begin
 b:=nullif(j->>'branch_id','')::uuid;
 if b is null and tg_table_name='blood_transfer_lines' then select branch_id into b from public.blood_transfers where id=new.transfer_id;end if;
 insert into public.workflow_audit(branch_id,actor_id,table_name,record_id,operation,old_status,new_status)
 values(b,auth.uid(),tg_table_name,(j->>'id')::uuid,tg_op,case when tg_op='UPDATE' then to_jsonb(old)->>'status' end,j->>'status');
 return new;
end $$;
revoke execute on function public.wf_audit_change() from public,anon,authenticated;

alter table public.workflow_audit enable row level security;
revoke all privileges on public.workflow_audit from public,authenticated,anon;
drop policy if exists wf_read on public.workflow_audit;
create policy wf_read on public.workflow_audit for select to authenticated using (public.wf_active_actor() and (public.has_permission('AUDIT_VIEW') and public.can_access_branch(branch_id)));
grant select on public.workflow_audit to authenticated;

alter table public.workflow_daily_sections enable row level security;
revoke all privileges on public.workflow_daily_sections from public,authenticated,anon;
drop policy if exists wf_read on public.workflow_daily_sections;
create policy wf_read on public.workflow_daily_sections for select to authenticated using (public.wf_active_actor() and (public.has_permission('DAILY_REPORT_VIEW') and public.can_access_branch(branch_id)));
grant select on public.workflow_daily_sections to authenticated;
drop trigger if exists wf_audit on public.workflow_daily_sections;
create trigger wf_audit after insert or update on public.workflow_daily_sections for each row execute function public.wf_audit_change();

alter table public.commercial_locations enable row level security;
revoke all privileges on public.commercial_locations from public,authenticated,anon;
drop policy if exists wf_read on public.commercial_locations;
create policy wf_read on public.commercial_locations for select to authenticated using (public.wf_active_actor() and (public.has_permission('COMMERCIAL_VIEW') and public.can_access_branch(branch_id)));
grant select on public.commercial_locations to authenticated;
drop trigger if exists wf_audit on public.commercial_locations;
create trigger wf_audit after insert or update on public.commercial_locations for each row execute function public.wf_audit_change();

alter table public.commercial_plans enable row level security;
revoke all privileges on public.commercial_plans from public,authenticated,anon;
drop policy if exists wf_read on public.commercial_plans;
create policy wf_read on public.commercial_plans for select to authenticated using (public.wf_active_actor() and (public.has_permission('COMMERCIAL_VIEW') and public.can_access_branch(branch_id)));
grant select on public.commercial_plans to authenticated;
drop trigger if exists wf_audit on public.commercial_plans;
create trigger wf_audit after insert or update on public.commercial_plans for each row execute function public.wf_audit_change();

alter table public.commercial_visits enable row level security;
revoke all privileges on public.commercial_visits from public,authenticated,anon;
drop policy if exists wf_read on public.commercial_visits;
create policy wf_read on public.commercial_visits for select to authenticated using (public.wf_active_actor() and (public.has_permission('COMMERCIAL_VIEW') and public.can_access_branch(branch_id)));
grant select on public.commercial_visits to authenticated;
drop trigger if exists wf_audit on public.commercial_visits;
create trigger wf_audit after insert or update on public.commercial_visits for each row execute function public.wf_audit_change();

alter table public.commercial_opportunities enable row level security;
revoke all privileges on public.commercial_opportunities from public,authenticated,anon;
drop policy if exists wf_read on public.commercial_opportunities;
create policy wf_read on public.commercial_opportunities for select to authenticated using (public.wf_active_actor() and (public.has_permission('COMMERCIAL_VIEW') and public.can_access_branch(branch_id)));
grant select on public.commercial_opportunities to authenticated;
drop trigger if exists wf_audit on public.commercial_opportunities;
create trigger wf_audit after insert or update on public.commercial_opportunities for each row execute function public.wf_audit_change();

alter table public.hyperbaric_resources enable row level security;
revoke all privileges on public.hyperbaric_resources from public,authenticated,anon;
drop policy if exists wf_read on public.hyperbaric_resources;
create policy wf_read on public.hyperbaric_resources for select to authenticated using (public.wf_active_actor() and (public.has_permission('HYPERBARIC_VIEW') and public.can_access_branch(branch_id)));
grant select on public.hyperbaric_resources to authenticated;
drop trigger if exists wf_audit on public.hyperbaric_resources;
create trigger wf_audit after insert or update on public.hyperbaric_resources for each row execute function public.wf_audit_change();

alter table public.hyperbaric_appointments enable row level security;
revoke all privileges on public.hyperbaric_appointments from public,authenticated,anon;
drop policy if exists wf_read on public.hyperbaric_appointments;
create policy wf_read on public.hyperbaric_appointments for select to authenticated using (public.wf_active_actor() and (public.has_permission('HYPERBARIC_VIEW') and public.can_access_branch(branch_id)));
grant select on public.hyperbaric_appointments to authenticated;
drop trigger if exists wf_audit on public.hyperbaric_appointments;
create trigger wf_audit after insert or update on public.hyperbaric_appointments for each row execute function public.wf_audit_change();

alter table public.hyperbaric_sessions enable row level security;
revoke all privileges on public.hyperbaric_sessions from public,authenticated,anon;
drop policy if exists wf_read on public.hyperbaric_sessions;
create policy wf_read on public.hyperbaric_sessions for select to authenticated using (public.wf_active_actor() and (public.has_permission('HYPERBARIC_VIEW') and public.can_access_branch(branch_id)));
grant select on public.hyperbaric_sessions to authenticated;
drop trigger if exists wf_audit on public.hyperbaric_sessions;
create trigger wf_audit after insert or update on public.hyperbaric_sessions for each row execute function public.wf_audit_change();

alter table public.hyperbaric_charges enable row level security;
revoke all privileges on public.hyperbaric_charges from public,authenticated,anon;
drop policy if exists wf_read on public.hyperbaric_charges;
create policy wf_read on public.hyperbaric_charges for select to authenticated using (public.wf_active_actor() and ((public.has_permission('HYPERBARIC_VIEW') or public.has_permission('SALES_VIEW')) and public.can_access_branch(branch_id)));
grant select on public.hyperbaric_charges to authenticated;
drop trigger if exists wf_audit on public.hyperbaric_charges;
create trigger wf_audit after insert or update on public.hyperbaric_charges for each row execute function public.wf_audit_change();

alter table public.hyperbaric_payments enable row level security;
revoke all privileges on public.hyperbaric_payments from public,authenticated,anon;
drop policy if exists wf_read on public.hyperbaric_payments;
create policy wf_read on public.hyperbaric_payments for select to authenticated using (public.wf_active_actor() and ((public.has_permission('HYPERBARIC_VIEW') or public.has_permission('SALES_VIEW')) and public.can_access_branch(branch_id)));
grant select on public.hyperbaric_payments to authenticated;
drop trigger if exists wf_audit on public.hyperbaric_payments;
create trigger wf_audit after insert or update on public.hyperbaric_payments for each row execute function public.wf_audit_change();

alter table public.blood_quality_tasks enable row level security;
revoke all privileges on public.blood_quality_tasks from public,authenticated,anon;
drop policy if exists wf_read on public.blood_quality_tasks;
create policy wf_read on public.blood_quality_tasks for select to authenticated using (public.wf_active_actor() and (public.has_permission('QUALITY_VIEW') and public.can_access_branch(branch_id)));
grant select on public.blood_quality_tasks to authenticated;
drop trigger if exists wf_audit on public.blood_quality_tasks;
create trigger wf_audit after insert or update on public.blood_quality_tasks for each row execute function public.wf_audit_change();

alter table public.blood_transfers enable row level security;
revoke all privileges on public.blood_transfers from public,authenticated,anon;
drop policy if exists wf_read on public.blood_transfers;
create policy wf_read on public.blood_transfers for select to authenticated using (public.wf_active_actor() and (public.has_permission('BLOOD_INVENTORY_VIEW') and (public.can_access_branch(branch_id) or public.can_access_branch(destination_branch_id))));
grant select on public.blood_transfers to authenticated;
drop trigger if exists wf_audit on public.blood_transfers;
create trigger wf_audit after insert or update on public.blood_transfers for each row execute function public.wf_audit_change();

alter table public.blood_transfer_lines enable row level security;
revoke all privileges on public.blood_transfer_lines from public,authenticated,anon;
drop policy if exists wf_read on public.blood_transfer_lines;
create policy wf_read on public.blood_transfer_lines for select to authenticated using (public.wf_active_actor() and (exists(select 1 from public.blood_transfers t where t.id=transfer_id)));
grant select on public.blood_transfer_lines to authenticated;
drop trigger if exists wf_audit on public.blood_transfer_lines;
create trigger wf_audit after insert or update on public.blood_transfer_lines for each row execute function public.wf_audit_change();

-- Add the extension to every subsequent snapshot, including close/reopen transitions.
create or replace function private.capture_daily_report_version()
returns trigger language plpgsql security definer set search_path=public,private,pg_temp as $$
declare extension jsonb;
begin
 select to_jsonb(w) into extension from public.workflow_daily_sections w where report_id=new.id;
 insert into public.daily_operational_report_versions(report_id,branch_id,close_date,report_version,status,snapshot,changed_by)
 values(new.id,new.branch_id,new.close_date,new.report_version,new.status,to_jsonb(new)||jsonb_build_object('workflow_sections',extension),auth.uid());
 return new;
end $$;
revoke execute on function private.capture_daily_report_version() from public,anon,authenticated;

create or replace function public.wf_save_daily_sections(p_report_id uuid,p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.daily_operational_closes%rowtype; rowdata jsonb; x jsonb; marker text;
begin
 select * into r from public.daily_operational_closes where id=p_report_id for update;
 if not found then raise exception 'Reporte no encontrado';end if;
 perform public.wf_require('DAILY_REPORT_WRITE',r.branch_id);
 if r.status not in ('BORRADOR','REABIERTO') then raise exception 'Reporte no editable';end if;
 if nullif(btrim(p_data->>'donor_batch'),'') is null then raise exception 'Lote de captación requerido';end if;
 if jsonb_typeof(p_data->'markers') is distinct from 'array' or jsonb_typeof(p_data->'receipts') is distinct from 'array'
    or jsonb_array_length(p_data->'markers')<>6 or jsonb_array_length(p_data->'receipts')<>8 then raise exception 'Se requieren 6 marcadores y 8 grupos';end if;
 if (select count(distinct v->>'marker') from jsonb_array_elements(p_data->'markers')v)<>6
    or (select count(distinct v->>'group') from jsonb_array_elements(p_data->'receipts')v)<>8 then raise exception 'Marcadores/grupos duplicados';end if;
 for x in select value from jsonb_array_elements(p_data->'markers') loop
  if x->>'marker' is null or x->>'platform' is null or x->>'marker' not in ('VIH (Ag/Ac)','HBsAg','Anti-HCV','Sífilis','HTLV I/II','CORE')
     or not (x ?& array['tested','nonreactive','reactive','platform']) or x->>'tested' is null or x->>'nonreactive' is null or x->>'reactive' is null or (x->>'tested')::integer<0 or (x->>'nonreactive')::integer<0 or (x->>'reactive')::integer<0
     or (x->>'nonreactive')::integer+(x->>'reactive')::integer<>(x->>'tested')::integer
     or x->>'platform' not in ('AutoLumo','MiniVidas','ELISA') then raise exception 'Marcador/plataforma/conteo inválido';end if;
  if (x->>'tested')::integer>0 and (nullif(btrim(x->>'reagent_lot'),'') is null or nullif(btrim(x->>'control_reference'),'') is null)
     then raise exception 'Lote de reactivo y control requeridos';end if;
 end loop;
 for x in select value from jsonb_array_elements(p_data->'receipts') loop
  if x->>'group' is null or x->>'group' not in ('A+','A-','B+','B-','O+','O-','AB+','AB-') or not (x ?& array['received','pending','discarded']) or x->>'received' is null or x->>'pending' is null or x->>'discarded' is null or (x->>'received')::integer<0
    or (x->>'pending')::integer<0 or (x->>'discarded')::integer<0
    or (x->>'pending')::integer+(x->>'discarded')::integer>(x->>'received')::integer then raise exception 'Recepciones incoherentes';end if;
 end loop;
 -- Integer casts plus NOT NULL/CHECK constraints reject missing, negative or fractional donor counts.
 insert into public.workflow_daily_sections(report_id,branch_id,report_date,donor_batch,accepted,deferred,discarded,markers,receipts,updated_by)
 values(r.id,r.branch_id,r.close_date,btrim(p_data->>'donor_batch'),(p_data->>'accepted')::integer,
 (p_data->>'deferred')::integer,(p_data->>'discarded')::integer,p_data->'markers',p_data->'receipts',auth.uid())
 on conflict(report_id) do update set donor_batch=excluded.donor_batch,accepted=excluded.accepted,deferred=excluded.deferred,
 discarded=excluded.discarded,markers=excluded.markers,receipts=excluded.receipts,updated_by=auth.uid(),updated_at=now()
 returning to_jsonb(workflow_daily_sections.*) into rowdata;
 -- Preserve each extension change in the report's existing version history.
 update public.daily_operational_closes set report_version=report_version+1,last_modified_by=auth.uid(),updated_at=now() where id=r.id;

 return (rowdata->>'id')::uuid;
end $$;

create or replace function public.wf_save_location(p_branch uuid,p_customer uuid,p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare result uuid;
begin
 perform public.wf_require('COMMERCIAL_WRITE',p_branch);
 if not exists(select 1 from public.customers where id=p_customer and active) then raise exception 'Cliente activo requerido';end if;
 if nullif(btrim(p_data->>'address'),'') is null then raise exception 'Dirección requerida';end if;
 if coalesce((p_data->>'verified')::boolean,false) and (nullif(p_data->>'latitude','') is null or nullif(p_data->>'longitude','') is null) then raise exception 'Coordenadas requeridas para verificar ubicación';end if;
 insert into public.commercial_locations(branch_id,customer_id,address,latitude,longitude,contact_name,contact_phone,verified_at,created_by)
 values(p_branch,p_customer,btrim(p_data->>'address'),nullif(p_data->>'latitude','')::numeric,nullif(p_data->>'longitude','')::numeric,
 p_data->>'contact_name',p_data->>'contact_phone',case when coalesce((p_data->>'verified')::boolean,false) then now() end,auth.uid())
 on conflict(branch_id,customer_id) do update set address=excluded.address,latitude=excluded.latitude,longitude=excluded.longitude,
 contact_name=excluded.contact_name,contact_phone=excluded.contact_phone,verified_at=excluded.verified_at returning id into result;
 return result;
end $$;

create or replace function public.wf_create_plan(p_branch uuid,p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare result uuid;
begin
 perform public.wf_require('COMMERCIAL_WRITE',p_branch);
 if nullif(btrim(p_data->>'goal'),'') is null or nullif(btrim(p_data->>'tactics'),'') is null then raise exception 'Meta y tácticas requeridas';end if;
 insert into public.commercial_plans(branch_id,agent_id,cycle_start,goal,target_visits,tactics)
 values(p_branch,auth.uid(),(p_data->>'cycle_start')::date,btrim(p_data->>'goal'),(p_data->>'target_visits')::integer,btrim(p_data->>'tactics')) returning id into result;
 return result;
end $$;

create or replace function public.wf_save_visit(p_branch uuid,p_id uuid,p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.commercial_visits%rowtype;result uuid;
begin
 perform public.wf_require('COMMERCIAL_WRITE',p_branch);
 if p_id is null then
  if not exists(select 1 from public.customers where id=(p_data->>'customer_id')::uuid and active) then raise exception 'Cliente activo requerido';end if;
  if nullif(btrim(p_data->>'purpose'),'') is null then raise exception 'Objetivo de visita requerido';end if;
  if nullif(p_data->>'plan_id','') is not null and not exists(select 1 from public.commercial_plans
      where id=(p_data->>'plan_id')::uuid and branch_id=p_branch and agent_id=auth.uid()
      and (p_data->>'scheduled_at')::timestamptz>=cycle_start::timestamp at time zone 'America/Santo_Domingo'
      and (p_data->>'scheduled_at')::timestamptz<(cycle_start+84)::timestamp at time zone 'America/Santo_Domingo') then raise exception 'Plan fuera de ciclo/agente/sucursal';end if;
  insert into public.commercial_visits(branch_id,customer_id,agent_id,plan_id,scheduled_at,duration_minutes,purpose,commitment,followup_at)
  values(p_branch,(p_data->>'customer_id')::uuid,auth.uid(),nullif(p_data->>'plan_id','')::uuid,(p_data->>'scheduled_at')::timestamptz,
    (p_data->>'duration_minutes')::integer,btrim(p_data->>'purpose'),p_data->>'commitment',nullif(p_data->>'followup_at','')::timestamptz) returning id into result;
 else
  select * into v from public.commercial_visits where id=p_id and branch_id=p_branch for update;
  if not found or (v.agent_id<>auth.uid() and not public.has_permission('ACCESS_ADMIN')) then raise exception 'Visita no accesible';end if;
  if v.status in ('REALIZADA','CANCELADA') then raise exception 'Visita finalizada';end if;
  if p_data->>'status' not in ('CONFIRMADA','REALIZADA','CANCELADA') then raise exception 'Estado inválido';end if;
  if p_data->>'status'='REALIZADA' and nullif(btrim(p_data->>'evidence'),'') is null then raise exception 'Evidencia de visita requerida';end if;
  update public.commercial_visits set status=p_data->>'status',evidence=p_data->>'evidence',commitment=p_data->>'commitment',
    followup_at=nullif(p_data->>'followup_at','')::timestamptz,completed_at=case when p_data->>'status'='REALIZADA' then now() end where id=p_id;
  result:=p_id;
 end if;
 return result;
end $$;

alter table public.commercial_opportunities add column if not exists service_type text not null default 'SANGRE';
alter table public.commercial_opportunities add column if not exists hyperbaric_charge_id uuid references public.hyperbaric_charges(id);
alter table public.commercial_opportunities drop constraint if exists commercial_opportunities_check;
alter table public.commercial_opportunities drop constraint if exists wf_opportunity_evidence;
alter table public.commercial_opportunities drop constraint if exists wf_opportunity_loss_reason;
alter table public.commercial_opportunities add constraint wf_opportunity_loss_reason
check(stage<>'PERDIDA' or coalesce(length(btrim(loss_reason))>=3,false));
alter table public.commercial_opportunities add constraint wf_opportunity_evidence
check(service_type in ('SANGRE','CAMARA_HIPERBARICA') and (stage<>'GANADA' or sale_id is not null or hyperbaric_charge_id is not null));
alter table public.hyperbaric_appointments add column if not exists customer_id uuid references public.customers(id);
alter table public.hyperbaric_charges add column if not exists customer_id uuid references public.customers(id);

create or replace function public.wf_save_opportunity(p_branch uuid,p_id uuid,p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare result uuid; customer uuid; new_stage text; sale uuid; service text; charge uuid;
begin
 perform public.wf_require('COMMERCIAL_WRITE',p_branch);
 if (p_data->>'service_type'='CAMARA_HIPERBARICA' and nullif(p_data->>'sale_id','') is not null) or (coalesce(p_data->>'service_type','SANGRE')='SANGRE' and nullif(p_data->>'hyperbaric_charge_id','') is not null) then raise exception 'Una oportunidad tiene un único tipo de origen financiero';end if;
 customer:=(p_data->>'customer_id')::uuid;new_stage:=p_data->>'stage';sale:=nullif(p_data->>'sale_id','')::uuid;service:=coalesce(p_data->>'service_type','SANGRE');charge:=nullif(p_data->>'hyperbaric_charge_id','')::uuid;
 if not exists(select 1 from public.customers where id=customer and active) or nullif(btrim(p_data->>'title'),'') is null then raise exception 'Cliente y título requeridos';end if;
 if p_id is not null then
  perform 1 from public.commercial_opportunities where id=p_id and branch_id=p_branch and customer_id=customer and (owner_id=auth.uid() or public.has_permission('ACCESS_ADMIN')) for update;
  if not found then raise exception 'Oportunidad no accesible';end if;
 end if;
 if (new_stage='GANADA' and service='SANGRE' or sale is not null) and not exists(select 1 from public.operational_sales where id=sale and branch_id=p_branch
    and customer_id=customer and status in ('FACTURADA','COBRADA') and p_data->>'currency'='DOP') then raise exception 'Venta facturada del mismo cliente/sucursal/moneda requerida';end if;
 if (new_stage='GANADA' and service='CAMARA_HIPERBARICA' or charge is not null) and not exists(select 1 from public.hyperbaric_charges where id=charge and customer_id=customer and branch_id=p_branch and currency=p_data->>'currency' and status='FACTURADA') then raise exception 'Factura de sesión del mismo centro/sucursal/moneda requerida';end if;
 if p_id is null then
  insert into public.commercial_opportunities(branch_id,customer_id,owner_id,title,stage,currency,estimated_amount,sale_id,loss_reason,service_type,hyperbaric_charge_id)
  values(p_branch,customer,auth.uid(),btrim(p_data->>'title'),new_stage,p_data->>'currency',(p_data->>'estimated_amount')::numeric,sale,p_data->>'loss_reason',service,charge) returning id into result;
 else
  update public.commercial_opportunities set title=btrim(p_data->>'title'),stage=new_stage,currency=p_data->>'currency',
    estimated_amount=(p_data->>'estimated_amount')::numeric,sale_id=sale,loss_reason=p_data->>'loss_reason',service_type=service,hyperbaric_charge_id=charge where id=p_id returning id into result;
 end if;
 return result;
end $$;

create or replace function public.wf_create_resource(p_branch uuid,p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare result uuid;
begin
 perform public.wf_require('ACCESS_ADMIN',p_branch);
 if nullif(btrim(p_data->>'name'),'') is null or nullif(btrim(p_data->>'procedure_reference'),'') is null then raise exception 'Equipo y procedimiento aprobado requeridos';end if;
 insert into public.hyperbaric_resources(branch_id,name,capacity,procedure_reference,created_by)
 values(p_branch,btrim(p_data->>'name'),(p_data->>'capacity')::integer,btrim(p_data->>'procedure_reference'),auth.uid()) returning id into result;
 return result;
end $$;

create or replace function public.wf_save_appointment(p_branch uuid,p_id uuid,p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare resource public.hyperbaric_resources%rowtype;appt public.hyperbaric_appointments%rowtype;result uuid;start_time timestamptz;end_time timestamptz;occupied integer;event_time timestamptz;
begin
 perform public.wf_require('HYPERBARIC_WRITE',p_branch);
 if p_id is not null then
  select * into appt from public.hyperbaric_appointments where id=p_id and branch_id=p_branch for update;
  if not found then raise exception 'Cita no encontrada';end if;
  if appt.status in ('ATENDIDA','CANCELADA','NO_ASISTIO') then raise exception 'Cita finalizada';end if;
  if p_data->>'status' in ('CANCELADA','NO_ASISTIO') then
   update public.hyperbaric_appointments set status=p_data->>'status',note=concat_ws(' · ',note,p_data->>'note') where id=p_id;return p_id;
  end if;
 end if;
 select * into resource from public.hyperbaric_resources where id=(p_data->>'resource_id')::uuid and branch_id=p_branch and active for update;
 if not found then raise exception 'Cámara habilitada requerida';end if;
 start_time:=(p_data->>'starts_at')::timestamptz;end_time:=(p_data->>'ends_at')::timestamptz;
 if start_time is null or end_time is null or end_time<=start_time or end_time-start_time>interval '8 hours' then raise exception 'Horario inválido';end if;
 -- Sweep every start boundary; total overlapping rows overcounts sequential occupants in a multi-place chamber.
 for event_time in select start_time union select starts_at from public.hyperbaric_appointments
    where resource_id=resource.id and id is distinct from p_id and status in ('SOLICITADA','CONFIRMADA') and starts_at>start_time and starts_at<end_time loop
  select count(*) into occupied from public.hyperbaric_appointments where resource_id=resource.id and id is distinct from p_id
    and status in ('SOLICITADA','CONFIRMADA') and starts_at<=event_time and ends_at>event_time;
  if occupied>=resource.capacity then raise exception 'Capacidad ocupada; seleccione otro horario';end if;
 end loop;
 perform public.wf_validate_service_date(start_time,(p_data->>'operational_date')::date,p_data->>'shift');
 if nullif(btrim(p_data->>'patient_name'),'') is null or nullif(btrim(p_data->>'patient_phone'),'') is null
    or nullif(btrim(p_data->>'session_label'),'') is null or nullif(btrim(p_data->>'referrer_name'),'') is null then raise exception 'Paciente, teléfono, sesión y referidor requeridos';end if;
 if nullif(p_data->>'referrer_id','') is not null and not exists(select 1 from public.medical_referrers where id=(p_data->>'referrer_id')::uuid and (branch_id=p_branch or branch_id is null)) then raise exception 'Referidor de otra sucursal';end if;
 if p_id is null then
  insert into public.hyperbaric_appointments(branch_id,resource_id,customer_id,patient_name,patient_phone,starts_at,ends_at,operational_date,shift,price,currency,session_label,referrer_id,referrer_name,note,created_by)
  values(p_branch,resource.id,nullif(p_data->>'customer_id','')::uuid,btrim(p_data->>'patient_name'),btrim(p_data->>'patient_phone'),start_time,end_time,(p_data->>'operational_date')::date,
   p_data->>'shift',(p_data->>'price')::numeric,p_data->>'currency',p_data->>'session_label',nullif(p_data->>'referrer_id','')::uuid,p_data->>'referrer_name',p_data->>'note',auth.uid()) returning id into result;
 else
  update public.hyperbaric_appointments set resource_id=resource.id,customer_id=nullif(p_data->>'customer_id','')::uuid,starts_at=start_time,ends_at=end_time,operational_date=(p_data->>'operational_date')::date,
  shift=p_data->>'shift',patient_name=btrim(p_data->>'patient_name'),patient_phone=btrim(p_data->>'patient_phone'),
  price=(p_data->>'price')::numeric,currency=p_data->>'currency',session_label=p_data->>'session_label',referrer_id=nullif(p_data->>'referrer_id','')::uuid,
  referrer_name=p_data->>'referrer_name',note=p_data->>'note',status='CONFIRMADA' where id=p_id returning id into result;
 end if;
 return result;
end $$;

create or replace function public.wf_record_session(p_appointment uuid,p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare a public.hyperbaric_appointments%rowtype;result uuid;
begin
 select * into a from public.hyperbaric_appointments where id=p_appointment for update;
 if not found then raise exception 'Cita no encontrada';end if;
 perform public.wf_require('HYPERBARIC_SESSION_WRITE',a.branch_id);
 if a.status not in ('SOLICITADA','CONFIRMADA') then raise exception 'Cita no vigente';end if;
 if nullif(btrim(p_data->>'clinical_authorization'),'') is null or nullif(btrim(p_data->>'consent_reference'),'') is null
   or nullif(btrim(p_data->>'evidence'),'') is null then raise exception 'Autorización clínica, consentimiento y evidencia requeridos';end if;
 if (p_data->>'performed_at')::timestamptz>now() then raise exception 'No se registra una sesión futura como realizada';end if;
 perform public.wf_validate_service_date((p_data->>'performed_at')::timestamptz,(p_data->>'operational_date')::date,p_data->>'shift');
 insert into public.hyperbaric_sessions(branch_id,appointment_id,performed_at,operational_date,shift,provider_id,clinical_authorization,consent_reference,evidence,status)
 values(a.branch_id,a.id,(p_data->>'performed_at')::timestamptz,(p_data->>'operational_date')::date,p_data->>'shift',auth.uid(),
 p_data->>'clinical_authorization',p_data->>'consent_reference',p_data->>'evidence',p_data->>'status') returning id into result;
 insert into public.workflow_service_events(branch_id,session_id,customer_id,service_date,shift,status,currency,price)
 values(a.branch_id,result,a.customer_id,(p_data->>'operational_date')::date,p_data->>'shift',p_data->>'status',a.currency,a.price);
 update public.hyperbaric_appointments set status='ATENDIDA' where id=a.id;
 return result;
end $$;

create or replace function public.wf_invoice_session(p_session uuid,p_invoice text,p_date date)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare sess public.hyperbaric_sessions%rowtype;a public.hyperbaric_appointments%rowtype;result uuid;
begin
 select * into sess from public.hyperbaric_sessions where id=p_session for update;
 if not found then raise exception 'Sesión no encontrada';end if;
 perform public.wf_require('HYPERBARIC_BILLING',sess.branch_id);
 if p_date < (sess.performed_at at time zone 'America/Santo_Domingo')::date then raise exception 'Factura anterior al servicio realizado';end if;
 if sess.status<>'REALIZADA' or nullif(btrim(p_invoice),'') is null or p_date is null then raise exception 'Sesión realizada y factura requeridas';end if;
 select * into a from public.hyperbaric_appointments where id=sess.appointment_id;
 select id into result from public.hyperbaric_charges where session_id=sess.id;
 if found then
  if not exists(select 1 from public.hyperbaric_charges where id=result and invoice_number=btrim(p_invoice) and invoice_date=p_date) then raise exception 'Sesión ya facturada con otros datos';end if;
  return result;
 end if;
 insert into public.hyperbaric_charges(branch_id,session_id,customer_id,invoice_number,invoice_date,service_date,shift,currency,amount,created_by)
 values(sess.branch_id,sess.id,a.customer_id,btrim(p_invoice),p_date,sess.operational_date,sess.shift,a.currency,a.price,auth.uid()) returning id into result;
 return result;
end $$;

create or replace function public.wf_pay_session(p_charge uuid,p_request uuid,p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare c public.hyperbaric_charges%rowtype;paid numeric;amount numeric; prior public.hyperbaric_payments%rowtype;
begin
 select * into c from public.hyperbaric_charges where id=p_charge for update;
 if not found then raise exception 'Factura no encontrada';end if;
 perform public.wf_require('HYPERBARIC_BILLING',c.branch_id);
 amount:=(p_data->>'amount')::numeric;
 if p_request is null or amount is null or amount<=0 or amount::text in ('NaN','Infinity','-Infinity')
    or nullif(btrim(p_data->>'receipt_number'),'') is null or p_data->>'currency' is distinct from c.currency then raise exception 'Recibo, moneda y monto válidos requeridos';end if;
 select * into prior from public.hyperbaric_payments where id=p_request;
 if found then
  if prior.charge_id<>c.id or prior.amount<>amount or prior.currency<>c.currency or prior.payment_date is distinct from (p_data->>'payment_date')::date
     or prior.receipt_number is distinct from btrim(p_data->>'receipt_number') then raise exception 'Solicitud reutilizada con datos diferentes';end if;
  return prior.id;
 end if;
 if c.status<>'FACTURADA' then raise exception 'Factura anulada';end if;
 select coalesce(sum(p.amount),0) into paid from public.hyperbaric_payments p where charge_id=c.id;
 if paid+amount>c.amount then raise exception 'Cobro excede saldo';end if;
 insert into public.hyperbaric_payments(id,branch_id,charge_id,payment_date,currency,amount,receipt_number,created_by)
 values(p_request,c.branch_id,c.id,(p_data->>'payment_date')::date,c.currency,amount,btrim(p_data->>'receipt_number'),auth.uid());return p_request;
end $$;

create or replace function public.wf_quality_task(p_branch uuid,p_id uuid,p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare t public.blood_quality_tasks%rowtype;result uuid;state text;
begin
 if p_id is null then
  perform public.wf_require('QUALITY_WRITE',p_branch);
  if nullif(btrim(p_data->>'title'),'') is null or nullif(btrim(p_data->>'process'),'') is null or nullif(btrim(p_data->>'procedure_reference'),'') is null then raise exception 'Tarea, proceso y procedimiento requeridos';end if;
  insert into public.blood_quality_tasks(branch_id,task_date,shift,title,process,procedure_reference,priority,owner_id,due_at)
  values(p_branch,(p_data->>'task_date')::date,p_data->>'shift',p_data->>'title',p_data->>'process',p_data->>'procedure_reference',p_data->>'priority',auth.uid(),(p_data->>'due_at')::timestamptz) returning id into result;
 else
  select * into t from public.blood_quality_tasks where id=p_id and branch_id=p_branch for update;
  if not found then raise exception 'Tarea no encontrada';end if;
  state:=p_data->>'status';
  if state='EN_REVISION' then
   perform public.wf_require('QUALITY_WRITE',p_branch);
   if t.owner_id<>auth.uid() or t.status not in ('PENDIENTE','CORRECCION') or nullif(btrim(p_data->>'evidence'),'') is null then raise exception 'Ejecutor y evidencia requeridos';end if;
   update public.blood_quality_tasks set evidence=p_data->>'evidence',status=state,submitted_at=now(),reviewed_by=null,reviewed_at=null where id=t.id;
  elsif state in ('ACEPTADA','CORRECCION','NO_APLICA') then
   perform public.wf_require('QUALITY_DAILY_REVIEW',p_branch);
   if t.owner_id=auth.uid() then raise exception 'La revisión requiere otro usuario';end if;
   if t.status<>'EN_REVISION' or nullif(btrim(p_data->>'review_note'),'') is null then raise exception 'Evidencia enviada y nota de revisión requeridas';end if;
   update public.blood_quality_tasks set status=state,reviewed_by=auth.uid(),reviewed_at=now(),review_note=p_data->>'review_note' where id=t.id;
  else raise exception 'Transición inválida';end if;
  result:=t.id;
 end if;
 return result;
end $$;

create or replace function public.wf_send_transfer(p_branch uuid,p_destination uuid,p_batch text,p_units uuid[],p_evidence text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare result uuid;u public.blood_inventory_units%rowtype;cnt integer:=0;unit_identifier uuid;
begin
 perform public.wf_require('BLOOD_INVENTORY_WRITE',p_branch);
 if p_destination is null or p_destination=p_branch or not exists(select 1 from public.branches where id=p_destination and active)
  or nullif(btrim(p_batch),'') is null or nullif(btrim(p_evidence),'') is null or coalesce(cardinality(p_units),0)=0 then raise exception 'Destino, lote, unidades y evidencia requeridos';end if;
 if cardinality(p_units)<>(select count(distinct v) from unnest(p_units)v) then raise exception 'Unidades duplicadas';end if;
 -- Lock in stable order to serialize concurrent transfers.
 for unit_identifier in select v from unnest(p_units)v order by v loop
  select * into u from public.blood_inventory_units where blood_inventory_units.id=unit_identifier for update;
  if not found or u.branch_id<>p_branch or u.inventory_status<>'DISPONIBLE' or u.screening_status<>'APTO'
     or u.expiry_date is null or u.expiry_date<(now() at time zone 'America/Santo_Domingo')::date then raise exception 'Unidad no disponible/liberada/vigente';end if;
  cnt:=cnt+1;
 end loop;
 insert into public.blood_transfers(branch_id,destination_branch_id,batch_code,transport_evidence,sent_by)
 values(p_branch,p_destination,btrim(p_batch),btrim(p_evidence),auth.uid()) returning blood_transfers.id into result;
 insert into public.blood_transfer_lines(transfer_id,unit_id,unit_code,component_name,abo,rh)
 select result,b.id,b.unit_code,b.component_name,b.abo,b.rh from public.blood_inventory_units b where b.id=any(p_units);
 update public.blood_inventory_units set inventory_status='RESERVADA',reserved_for='TRANSFERENCIA:'||result where blood_inventory_units.id=any(p_units);
 return result;
end $$;

create or replace function public.wf_receive_transfer(p_transfer uuid,p_units uuid[],p_evidence text,p_condition text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare t public.blood_transfers%rowtype;unit_identifier uuid;line public.blood_transfer_lines%rowtype;u public.blood_inventory_units%rowtype;
begin
 select * into t from public.blood_transfers where blood_transfers.id=p_transfer for update;
 if not found then raise exception 'Transferencia no encontrada';end if;
 perform public.wf_require('BLOOD_INVENTORY_WRITE',t.destination_branch_id);
 if nullif(btrim(p_evidence),'') is null or nullif(btrim(p_condition),'') is null or coalesce(cardinality(p_units),0)=0
    or cardinality(p_units)<>(select count(distinct v) from unnest(p_units)v) then raise exception 'Unidades únicas, evidencia y condición requeridas';end if;
 for unit_identifier in select v from unnest(p_units)v order by v loop
  select * into line from public.blood_transfer_lines where transfer_id=t.id and unit_id=unit_identifier for update;
  if not found then raise exception 'Unidad ajena a la transferencia';end if;
  if line.received_at is not null then continue;end if; -- Same receipt cannot move stock twice.
  select * into u from public.blood_inventory_units where blood_inventory_units.id=unit_identifier for update;
  if u.branch_id<>t.branch_id or u.inventory_status<>'RESERVADA' or u.reserved_for is distinct from 'TRANSFERENCIA:'||t.id then raise exception 'Estado físico de unidad no concuerda';end if;
  -- Receipt is NOT a release. Keep it in quarantine for the existing authorized review.
  update public.blood_inventory_units set branch_id=t.destination_branch_id,inventory_status='CUARENTENA',reserved_for=null where blood_inventory_units.id=unit_identifier;
  update public.blood_transfer_lines set received_at=now(),received_by=auth.uid(),receipt_evidence=p_evidence,receipt_condition=p_condition where blood_transfer_lines.id=line.id;
 end loop;
 update public.blood_transfers set status=case when exists(select 1 from public.blood_transfer_lines where transfer_id=t.id and received_at is null) then 'PARCIAL' else 'RECIBIDA' end where blood_transfers.id=t.id;
 return t.id;
end $$;

create or replace function public.wf_review_transfer_receipt(p_transfer uuid,p_unit uuid,p_accept boolean,p_evidence text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare t public.blood_transfers%rowtype;l public.blood_transfer_lines%rowtype;u public.blood_inventory_units%rowtype;
begin
 select * into t from public.blood_transfers where id=p_transfer for update;
 if not found then raise exception 'Transferencia no encontrada';end if;
 perform public.wf_require('UNIT_RELEASE',t.destination_branch_id);
 select * into l from public.blood_transfer_lines where transfer_id=t.id and unit_id=p_unit for update;
 if not found or l.received_at is null or l.reviewed_at is not null or p_accept is null or nullif(btrim(p_evidence),'') is null then raise exception 'Recepción sin revisar y evidencia requeridas';end if;
 select * into u from public.blood_inventory_units where id=p_unit for update;
 if u.branch_id<>t.destination_branch_id or u.inventory_status<>'CUARENTENA' then raise exception 'Unidad fuera de cuarentena de recepción';end if;
 if p_accept and (u.screening_status<>'APTO' or u.expiry_date is null or u.expiry_date<(now() at time zone 'America/Santo_Domingo')::date) then raise exception 'Unidad no apta o vencida';end if;
 update public.blood_transfer_lines set reviewed_by=auth.uid(),reviewed_at=now(),review_decision=case when p_accept then 'ACEPTADA' else 'RETENIDA' end,review_evidence=p_evidence where id=l.id;
 if p_accept then update public.blood_inventory_units set inventory_status='DISPONIBLE' where id=p_unit;end if;
 return l.id;
end $$;
revoke execute on function public.wf_review_transfer_receipt(uuid,uuid,boolean,text) from public,anon;
grant execute on function public.wf_review_transfer_receipt(uuid,uuid,boolean,text) to authenticated;

create or replace view public.vw_hyperbaric_finance with (security_invoker=true) as
select c.id,c.branch_id,c.session_id,c.invoice_number,c.invoice_date,c.service_date,c.shift,c.currency,c.amount,c.status,
 coalesce(p.paid,0) paid,greatest(c.amount-coalesce(p.paid,0),0) outstanding,c.customer_id,coalesce(cl.name,'Servicio hiperbárico') client_name
from public.hyperbaric_charges c left join public.customers cl on cl.id=c.customer_id left join lateral(select sum(amount) paid from public.hyperbaric_payments where charge_id=c.id)p on true;
grant select on public.vw_hyperbaric_finance to authenticated;

-- No patient-identifying data enters the general sales report.
create or replace view public.vw_workflow_shift_sales with (security_invoker=true) as
select s.id source_id,'SANGRE'::text source_type,s.branch_id,s.sale_date operational_date,coalesce(s.shift,'SIN_TURNO') shift,
 'DOP'::text currency,s.customer_name client_name,s.treating_doctor,
 case when s.status in ('FACTURADA','COBRADA') then s.total_amount else 0 end invoiced,
 coalesce(p.paid,s.collected_amount,0) paid,s.status
from public.operational_sales s left join lateral(select sum(amount) paid from public.customer_payments where sale_id=s.id)p on true
where s.status not in ('ANULADA','CANCELADA') and public.wf_active_actor() and public.has_permission('SALES_VIEW') and public.can_access_branch(s.branch_id)
union all
select f.id,'CAMARA_HIPERBARICA',f.branch_id,f.service_date,f.shift,f.currency,f.client_name,null,
 f.amount,f.paid,f.status from public.vw_hyperbaric_finance f
where f.status='FACTURADA' and public.wf_active_actor() and public.has_permission('SALES_VIEW') and public.can_access_branch(f.branch_id);
grant select on public.vw_workflow_shift_sales to authenticated;

insert into public.app_migrations(migration_code,version,description)
values('workflow_commercial_quality','20261013120000','Ruta por sucursal, visitas y planes, cámara hiperbárica y tareas de calidad con evidencia')
on conflict(migration_code) do nothing;

revoke execute on function public.wf_save_daily_sections(uuid,jsonb) from public,anon;
grant execute on function public.wf_save_daily_sections(uuid,jsonb) to authenticated;

revoke execute on function public.wf_save_location(uuid,uuid,jsonb) from public,anon;
grant execute on function public.wf_save_location(uuid,uuid,jsonb) to authenticated;

revoke execute on function public.wf_create_plan(uuid,jsonb) from public,anon;
grant execute on function public.wf_create_plan(uuid,jsonb) to authenticated;

revoke execute on function public.wf_save_visit(uuid,uuid,jsonb) from public,anon;
grant execute on function public.wf_save_visit(uuid,uuid,jsonb) to authenticated;

revoke execute on function public.wf_save_opportunity(uuid,uuid,jsonb) from public,anon;
grant execute on function public.wf_save_opportunity(uuid,uuid,jsonb) to authenticated;

revoke execute on function public.wf_create_resource(uuid,jsonb) from public,anon;
grant execute on function public.wf_create_resource(uuid,jsonb) to authenticated;

revoke execute on function public.wf_save_appointment(uuid,uuid,jsonb) from public,anon;
grant execute on function public.wf_save_appointment(uuid,uuid,jsonb) to authenticated;

revoke execute on function public.wf_record_session(uuid,jsonb) from public,anon;
grant execute on function public.wf_record_session(uuid,jsonb) to authenticated;

revoke execute on function public.wf_invoice_session(uuid,text,date) from public,anon;
grant execute on function public.wf_invoice_session(uuid,text,date) to authenticated;

revoke execute on function public.wf_pay_session(uuid,uuid,jsonb) from public,anon;
grant execute on function public.wf_pay_session(uuid,uuid,jsonb) to authenticated;

revoke execute on function public.wf_quality_task(uuid,uuid,jsonb) from public,anon;
grant execute on function public.wf_quality_task(uuid,uuid,jsonb) to authenticated;

revoke execute on function public.wf_send_transfer(uuid,uuid,text,uuid[],text) from public,anon;
grant execute on function public.wf_send_transfer(uuid,uuid,text,uuid[],text) to authenticated;

revoke execute on function public.wf_receive_transfer(uuid,uuid[],text,text) from public,anon;
grant execute on function public.wf_receive_transfer(uuid,uuid[],text,text) to authenticated;

create table if not exists public.workflow_supply_catalog (
 id uuid primary key default gen_random_uuid(),code text not null unique,source_label text not null,
 approved_name text,unit_of_measure text,product_id uuid references public.products(id),
 reviewed_by uuid references public.profiles(id),reviewed_at timestamptz
);
alter table public.workflow_supply_catalog enable row level security;
revoke all privileges on public.workflow_supply_catalog from public,authenticated,anon;
drop policy if exists wf_catalog_read on public.workflow_supply_catalog;
create policy wf_catalog_read on public.workflow_supply_catalog for select to authenticated
using (public.wf_active_actor() and (public.has_permission('SUPPLY_VIEW') or public.has_permission('ACCESS_ADMIN')));
grant select on public.workflow_supply_catalog to authenticated;

create or replace function public.wf_map_supply_item(p_branch uuid,p_item uuid,p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare c public.workflow_supply_catalog%rowtype;product uuid;unit text;name text;minimum numeric;warning numeric;target numeric;
begin
 perform public.wf_require('ACCESS_ADMIN',p_branch);
 select * into c from public.workflow_supply_catalog where id=p_item for update;
 if not found then raise exception 'Insumo no encontrado';end if;
 name:=btrim(p_data->>'name');unit:=btrim(p_data->>'unit');product:=nullif(p_data->>'product_id','')::uuid;
 if nullif(name,'') is null or nullif(unit,'') is null then raise exception 'Nombre y unidad revisados requeridos';end if;
 if product is null then
  insert into public.products(code,name,category,unit_of_measure) values(c.code,name,'INSUMO',unit) on conflict(code) do nothing returning id into product;
  if product is null then select id into product from public.products where code=c.code and unit_of_measure=unit;end if;
 end if;
 if not exists(select 1 from public.products where id=product and active and unit_of_measure=unit) then raise exception 'Producto activo y unidad concordante requeridos';end if;
 if c.product_id is not null and c.product_id<>product then raise exception 'Insumo ya vinculado; no reasignar historial';end if;
 minimum:=(p_data->>'minimum')::numeric;warning:=(p_data->>'warning')::numeric;target:=(p_data->>'target')::numeric;
 if minimum is null or warning is null or target is null or minimum<0 or warning<minimum or target<warning
    or minimum::text in ('NaN','Infinity','-Infinity') or warning::text in ('NaN','Infinity','-Infinity') or target::text in ('NaN','Infinity','-Infinity') then raise exception 'Mínimo <= alerta <= objetivo, finitos y no negativos';end if;
 update public.workflow_supply_catalog set approved_name=name,unit_of_measure=unit,product_id=product,reviewed_by=auth.uid(),reviewed_at=now() where id=c.id;
 insert into public.inventory_policies(branch_id,product_id,minimum_stock,warning_stock,target_stock,active)
 values(p_branch,product,minimum,warning,target,true)
 on conflict(branch_id,product_id) do update set minimum_stock=excluded.minimum_stock,warning_stock=excluded.warning_stock,target_stock=excluded.target_stock,active=true;
 insert into public.workflow_audit(branch_id,actor_id,table_name,record_id,operation)
 values(p_branch,auth.uid(),'workflow_supply_catalog',c.id,'MAP_PRODUCT_AND_THRESHOLDS');
 return product;
end $$;
revoke execute on function public.wf_map_supply_item(uuid,uuid,jsonb) from public,anon;
grant execute on function public.wf_map_supply_item(uuid,uuid,jsonb) to authenticated;

alter table public.commercial_visits add column if not exists commitment_closed_at timestamptz;
alter table public.commercial_visits add column if not exists commitment_evidence text;
create or replace function public.wf_close_commitment(p_branch uuid,p_visit uuid,p_evidence text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.commercial_visits%rowtype;
begin
 perform public.wf_require('COMMERCIAL_WRITE',p_branch);
 select * into v from public.commercial_visits where id=p_visit and branch_id=p_branch for update;
 if not found or (v.agent_id<>auth.uid() and not public.has_permission('ACCESS_ADMIN')) then raise exception 'Compromiso no accesible';end if;
 if v.commitment_closed_at is not null then return v.id;end if;
 if nullif(btrim(v.commitment),'') is null or nullif(btrim(p_evidence),'') is null then raise exception 'Compromiso y evidencia requeridos';end if;
 update public.commercial_visits set commitment_closed_at=now(),commitment_evidence=p_evidence where id=v.id;return v.id;
end $$;
revoke execute on function public.wf_close_commitment(uuid,uuid,text) from public,anon;
grant execute on function public.wf_close_commitment(uuid,uuid,text) to authenticated;

-- Source catalog only: no stock, thresholds or clinical names are approved by this import.
insert into public.workflow_supply_catalog(code,source_label) values
('HC-SUP-001','Bolsa de Recolección 450 - 500 ml con anticoagulante CPD/CPDA-1, aguja 16G integrada uds'),
('HC-SUP-002','Bajante de Sangre 20/paq'),
('HC-SUP-003','Bolsa Filtro de leucorreducción Adultos'),
('HC-SUP-004','Bolsa Filtro de leucorreducción Niños'),
('HC-SUP-005','Tarjetas de gel (columna) ABO/Rh'),
('HC-SUP-006','Tarjetas de gel para prueba cruzada (Coombs D/I )'),
('HC-SUP-007','Reactivo Anti-A'),
('HC-SUP-008','Reactivo Anti B'),
('HC-SUP-009','Reactivo Anti D'),
('HC-SUP-010','Reactivo Anti Globulina Humana'),
('HC-SUP-011','Reactivo Albumina Bovina'),
('HC-SUP-012','Wash System Autolumo'),
('HC-SUP-013','Sustrato Autlumo'),
('HC-SUP-014','Buffer Autolumo'),
('HC-SUP-015','Reactivo AutoLumo HIV'),
('HC-SUP-016','Reactivo AutoLumo HTLV'),
('HC-SUP-017','Reactivo AutoLumo TP'),
('HC-SUP-018','Reactivo AutoLumo CORE'),
('HC-SUP-019','Reactivo AutoLumo Hep B'),
('HC-SUP-020','Reactivo AutoLumo Hep C'),
('HC-SUP-021','MiniVidas Controles QCV'),
('HC-SUP-022','Reactivo MiniVidas HIV'),
('HC-SUP-023','Reactivo MiniVidas HTLV'),
('HC-SUP-024','Reactivo MiniVidas CORE'),
('HC-SUP-025','Reactivo MiniVidas Hep. B'),
('HC-SUP-026','Reactivo MiniVidas Hep. C'),
('HC-SUP-027','Sustrato ELISA'),
('HC-SUP-028','Buffer ELISA'),
('HC-SUP-029','Reactivo ELISA HIV'),
('HC-SUP-030','Reactivo ELISA HTLV'),
('HC-SUP-031','Reactivo ELISA CORE'),
('HC-SUP-032','Reactivo ELISA Hep. B'),
('HC-SUP-033','Reactivo ELISA Hep. C'),
('HC-SUP-034','RTest HIV'),
('HC-SUP-035','RTest HTLV'),
('HC-SUP-036','RTest CORE'),
('HC-SUP-037','RTest Hep. B'),
('HC-SUP-038','RTest Hep. C'),
('HC-SUP-039','RTest TP'),
('HC-SUP-040','RTest HCG'),
('HC-SUP-041','RTest COVID'),
('HC-SUP-042','Guantes Size S'),
('HC-SUP-043','Guantes Size M'),
('HC-SUP-044','Guantes Size L'),
('HC-SUP-045','Tips Amarillos Puntas Micropipetas 10 µl a 200 µl'),
('HC-SUP-046','Tips Azules Puntas Micropipetas 100 a 1000 µl'),
('HC-SUP-047','Tubo piloto Amarillo (gel separador y activador de coagulación) cja/100uds'),
('HC-SUP-048','Tubo piloto Morado (EDTA (K2 o K3) cja/100uds'),
('HC-SUP-049','Aplicadores'),
('HC-SUP-050','Algodón rollo'),
('HC-SUP-051','Pipetas Plásticas'),
('HC-SUP-052','Aguja de flebotomía cja/100uds'),
('HC-SUP-053','Jeringa 5 cc'),
('HC-SUP-054','Jeringa 10 cc'),
('HC-SUP-055','Jeringa 20 cc'),
('HC-SUP-056','Maripositas'),
('HC-SUP-057','Alcohol al 70% galón'),
('HC-SUP-058','Agua Destilada galón'),
('HC-SUP-059','Jabón antibacterial galón'),
('HC-SUP-060','Transfer 300 ml'),
('HC-SUP-061','Transfer 150 ml'),
('HC-SUP-062','Rollo Papel Minividas'),
('HC-SUP-063','Tarjeta de Despacho Blanca "O"'),
('HC-SUP-064','Tarjeta de Despacho Amarilla "B"'),
('HC-SUP-065','Tarjeta de Despacho Azul "A"'),
('HC-SUP-066','Tarjeta de Despacho Rosada "AB"'),
('HC-SUP-067','Papel Facturación Rollo'),
('HC-SUP-068','Papel Verifone Rollo'),
('HC-SUP-069','Etiqueta de identificación de Tubo Rollo / 1,000 uds'),
('HC-SUP-070','Etiqueta de identificación de Bolsa Rollo / 1,000 uds'),
('HC-SUP-071','Solución Salida 1000 ml'),
('HC-SUP-072','Solución Salida 500 ml'),
('HC-SUP-073','Solución Salida 100 ml'),
('HC-SUP-074','Bolsas de hielo'),
('HC-SUP-075','Kit Aferesis Haemonetics'),
('HC-SUP-076','Kit Aferesis Trima'),
('HC-SUP-077','Kit Aferesis AmiCore'),
('HC-SUP-078','Controles de Hematología MedMay'),
('HC-SUP-079','Lyser MedMay'),
('HC-SUP-080','Diluent Medmay'),
('HC-SUP-081','Cleaner Medmay'),
('HC-SUP-082','Controles de Hematología Mindray'),
('HC-SUP-083','Lyser Mindray'),
('HC-SUP-084','Diluent Mindray'),
('HC-SUP-085','Cleaner Mindray'),
('HC-SUP-086','Controles de Hematología Horiba'),
('HC-SUP-087','Lyser Horiba'),
('HC-SUP-088','Diluent Horiba'),
('HC-SUP-089','Cleaner Horiba'),
('HC-SUP-090','Kit Reactivos Norma'),
('HC-SUP-091','Cleaner Norma'),
('HC-SUP-092','Controles Hematología Norma'),
('HC-SUP-093','Envase de Reacción (Reaction Vessel) Autolumo'),
('HC-SUP-094','Copa de Prueba - Sample Cup paq'),
('HC-SUP-095','CD4 uds'),
('HC-SUP-096','Gorro desechable'),
('HC-SUP-097','Mascarilla quirúrgica uds'),
('HC-SUP-098','Papel Higiénico Rollo'),
('HC-SUP-099','Papel Toalla Rollo'),
('HC-SUP-100','Servilletas Fardo'),
('HC-SUP-101','Bolsa NEGRA para desechos fardo'),
('HC-SUP-102','Bolsa ROJA para desechos biológicos fardo'),
('HC-SUP-103','Durapore -(Z-O)'),
('HC-SUP-104','Lapicero Azul'),
('HC-SUP-105','Lapicero Rojo'),
('HC-SUP-106','Lapicero Negro'),
('HC-SUP-107','Resma de papel impresora'),
('HC-SUP-108','Jugos Donantes'),
('HC-SUP-109','Paleta Caramelo'),
('HC-SUP-110','Tirilla Glucometro'),
('HC-SUP-111','Pila AAA'),
('HC-SUP-112','Pila AA'),
('HC-SUP-113','Bolsa Térmica Empaque'),
('HC-SUP-114','Bolsa Papel Timbrada'),
('HC-SUP-115','Tarjetas de Presentación Sucursales'),
('HC-SUP-116','Etiqueta Adhesiva Sucursales'),
('HC-SUP-117','Cinta Adhesiva empaque')
on conflict(code) do nothing;

-- Atomic stock outflow and sale: a failed line must not leave an orphan header.
create or replace function public.wf_create_blood_sale(p_header jsonb,p_lines jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare branch uuid;customer public.customers%rowtype;u public.blood_inventory_units%rowtype;l jsonb;result uuid;
 total numeric:=0;collected numeric;quantity numeric;price numeric;state text;unit_id uuid;
begin
 branch:=(p_header->>'branch_id')::uuid;perform public.wf_require('SALES_WRITE',branch);
 if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines)=0 then raise exception 'Detalle de venta requerido';end if;
 select * into customer from public.customers where id=(p_header->>'customer_id')::uuid and active;
 if not found then raise exception 'Cliente de catálogo requerido';end if;
 if nullif(btrim(p_header->>'sale_code'),'') is null or p_header->>'shift' not in ('DIURNO','NOCTURNO')
    or p_header->>'shift' is null or nullif(btrim(p_header->>'treating_doctor'),'') is null then raise exception 'Código, turno y médico tratante requeridos';end if;
 state:=p_header->>'status';collected:=coalesce((p_header->>'collected_amount')::numeric,0);
 if state not in ('DESPACHADA','FACTURADA','COBRADA') or state is null then raise exception 'La salida física requiere estado despachada/facturada/cobrada';end if;
 for l in select value from jsonb_array_elements(p_lines) loop
  unit_id:=nullif(l->>'blood_inventory_unit_id','')::uuid;quantity:=(l->>'quantity')::numeric;price:=(l->>'unit_price')::numeric;
  if unit_id is null then raise exception 'Cada línea requiere unidad liberada identificada';end if;
  perform public.wf_require('DISPATCH_WRITE',branch);
  select * into u from public.blood_inventory_units where id=unit_id for update;
  if not found or u.branch_id<>branch or u.screening_status<>'APTO' or u.inventory_status<>'DISPONIBLE' or u.expiry_date is null or u.expiry_date<(now() at time zone 'America/Santo_Domingo')::date then raise exception 'Unidad fuera de sucursal/no apta/no disponible/vencida';end if;
  if quantity is null or quantity<=0 or quantity::text in ('NaN','Infinity','-Infinity') or quantity<>u.quantity or price is null or price<0 or price::text in ('NaN','Infinity','-Infinity') then raise exception 'Cantidad de unidad y precio finito requeridos';end if;
  total:=total+quantity*price;
 end loop;
 if (select count(distinct v->>'blood_inventory_unit_id') from jsonb_array_elements(p_lines)v)<>jsonb_array_length(p_lines) then raise exception 'Unidad repetida en detalle';end if;
 if collected<0 or collected>total or collected::text in ('NaN','Infinity','-Infinity') then raise exception 'Cobro inválido';end if;
 if state in ('FACTURADA','COBRADA') and nullif(btrim(p_header->>'invoice_number'),'') is null then raise exception 'Factura requerida';end if;
 if state='COBRADA' and (total<=0 or collected<>total) then raise exception 'Estado cobrada requiere pago completo';end if;
 if collected>0 and state not in ('FACTURADA','COBRADA') then raise exception 'Facture antes de registrar cobro';end if;
 insert into public.operational_sales(sale_code,sale_date,branch_id,customer_id,customer_name,destination_center,request_number,patient_code,
 invoice_number,invoice_date,status,payment_status,total_amount,collected_amount,notes,shift,treating_doctor,created_by)
 values(btrim(p_header->>'sale_code'),(p_header->>'sale_date')::date,branch,customer.id,customer.name,customer.name,p_header->>'request_number',p_header->>'patient_code',
 nullif(btrim(p_header->>'invoice_number'),''),case when state in ('FACTURADA','COBRADA') then (p_header->>'sale_date')::date end,state,
 case when collected>=total and total>0 then 'COBRADA' when collected>0 then 'PARCIAL' else 'PENDIENTE' end,total,0,p_header->>'notes',p_header->>'shift',btrim(p_header->>'treating_doctor'),auth.uid()) returning id into result;
 for l in select value from jsonb_array_elements(p_lines) loop
  select * into u from public.blood_inventory_units where id=(l->>'blood_inventory_unit_id')::uuid;
  insert into public.operational_sale_lines(sale_id,blood_inventory_unit_id,product_id,component_name,abo,rh,quantity,unit_price)
  values(result,u.id,u.product_id,u.component_name,u.abo,u.rh,u.quantity,(l->>'unit_price')::numeric);
 end loop;
 if collected>0 then
  perform public.wf_require('COLLECTIONS_WRITE',branch);
  insert into public.customer_payments(branch_id,customer_id,sale_id,payment_date,amount,payment_method,reference,created_by)
  values(branch,customer.id,result,(p_header->>'sale_date')::date,collected,'REGISTRO_INICIAL',p_header->>'invoice_number',auth.uid());
  -- Mirror the new ledger for legacy summaries; source of truth remains customer_payments.
  update public.operational_sales set collected_amount=collected where id=result;
 end if;
 return result;
end $$;
revoke execute on function public.wf_create_blood_sale(jsonb,jsonb) from public,anon;
grant execute on function public.wf_create_blood_sale(jsonb,jsonb) to authenticated;

create or replace function public.wf_report_sections_required()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.status='EN_REVISION' and old.status is distinct from new.status
    and not exists(select 1 from public.workflow_daily_sections where report_id=new.id) then
  raise exception 'Guarde captación y los seis marcadores antes de enviar el reporte a revisión';
 end if;
 return new;
end $$;
revoke execute on function public.wf_report_sections_required() from public,anon,authenticated;
drop trigger if exists wf_report_sections_required on public.daily_operational_closes;
create trigger wf_report_sections_required before update of status on public.daily_operational_closes
for each row execute function public.wf_report_sections_required();

create table if not exists public.blood_quality_templates (
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),
 title text not null,process text not null,procedure_reference text not null,priority text not null check(priority in ('NORMAL','ALTA','CRITICA')),
 frequency text not null check(frequency in ('POR_TURNO','DIARIA','SEMANAL')),due_time time not null,due_next_day boolean not null default false,
 weekday integer check(weekday between 1 and 7),owner_id uuid not null references public.profiles(id),
 active boolean not null default false,version integer not null default 1,
 reviewed_by uuid references public.profiles(id),reviewed_at timestamptz,review_note text,created_at timestamptz not null default now(),
 check(frequency<>'SEMANAL' or weekday is not null)
);
alter table public.blood_quality_templates enable row level security;
revoke all privileges on public.blood_quality_templates from public,authenticated,anon;
drop policy if exists wf_template_read on public.blood_quality_templates;
create policy wf_template_read on public.blood_quality_templates for select to authenticated
using (public.wf_active_actor() and (public.has_permission('QUALITY_VIEW') and public.can_access_branch(branch_id)));
grant select on public.blood_quality_templates to authenticated;
drop trigger if exists wf_audit on public.blood_quality_templates;
create trigger wf_audit after insert or update on public.blood_quality_templates for each row execute function public.wf_audit_change();
alter table public.blood_quality_tasks add column if not exists template_id uuid references public.blood_quality_templates(id);
alter table public.blood_quality_tasks add column if not exists template_version integer;
create unique index if not exists wf_quality_one_routine_per_context on public.blood_quality_tasks(template_id,task_date,shift) where template_id is not null;

create or replace function public.wf_create_quality_template(p_branch uuid,p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare result uuid;
begin
 perform public.wf_require('QUALITY_WRITE',p_branch);
 if nullif(btrim(p_data->>'title'),'') is null or nullif(btrim(p_data->>'process'),'') is null or nullif(btrim(p_data->>'procedure_reference'),'') is null then raise exception 'Tarea, proceso y procedimiento requeridos';end if;
 insert into public.blood_quality_templates(branch_id,title,process,procedure_reference,priority,frequency,due_time,due_next_day,weekday,owner_id)
 values(p_branch,p_data->>'title',p_data->>'process',p_data->>'procedure_reference',p_data->>'priority',p_data->>'frequency',
 (p_data->>'due_time')::time,coalesce((p_data->>'due_next_day')::boolean,false),nullif(p_data->>'weekday','')::integer,auth.uid()) returning id into result;
 return result;
end $$;
create or replace function public.wf_review_quality_template(p_branch uuid,p_template uuid,p_note text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare t public.blood_quality_templates%rowtype;
begin
 perform public.wf_require('QUALITY_DAILY_REVIEW',p_branch);
 select * into t from public.blood_quality_templates where id=p_template and branch_id=p_branch for update;
 if not found or t.owner_id=auth.uid() or nullif(btrim(p_note),'') is null or t.active then raise exception 'Plantilla pendiente, revisión por otro usuario y nota requeridas';end if;
 update public.blood_quality_templates set active=true,reviewed_by=auth.uid(),reviewed_at=now(),review_note=p_note where id=t.id;return t.id;
end $$;
create or replace function public.wf_generate_quality_tasks(p_branch uuid,p_date date,p_shift text)
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare t public.blood_quality_templates%rowtype;n integer:=0;written integer;due timestamptz;
begin
 perform public.wf_require('QUALITY_WRITE',p_branch);
 if p_date is null or p_shift not in ('DIURNO','NOCTURNO') or p_shift is null then raise exception 'Fecha y turno requeridos';end if;
 for t in select * from public.blood_quality_templates where branch_id=p_branch and active and owner_id=auth.uid()
   and (frequency='POR_TURNO' or p_shift='DIURNO') and (frequency<>'SEMANAL' or weekday=extract(isodow from p_date)) loop
  due:=((p_date+case when t.due_next_day then 1 else 0 end)::text||' '||t.due_time::text)::timestamp at time zone 'America/Santo_Domingo';
  insert into public.blood_quality_tasks(branch_id,task_date,shift,title,process,procedure_reference,priority,owner_id,due_at,template_id,template_version)
  values(p_branch,p_date,p_shift,t.title,t.process,t.procedure_reference,t.priority,t.owner_id,due,t.id,t.version)
  on conflict(template_id,task_date,shift) where template_id is not null do nothing;
  get diagnostics written=row_count;n:=n+written;
 end loop;return n;
end $$;
revoke execute on function public.wf_create_quality_template(uuid,jsonb) from public,anon;
grant execute on function public.wf_create_quality_template(uuid,jsonb) to authenticated;
revoke execute on function public.wf_review_quality_template(uuid,uuid,text) from public,anon;
grant execute on function public.wf_review_quality_template(uuid,uuid,text) to authenticated;
revoke execute on function public.wf_generate_quality_tasks(uuid,date,text) from public,anon;
grant execute on function public.wf_generate_quality_tasks(uuid,date,text) to authenticated;

-- Anonymous service facts for sales: no patient, phone, consent or clinical evidence.
create table if not exists public.workflow_service_events (
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),
 session_id uuid not null unique references public.hyperbaric_sessions(id),customer_id uuid references public.customers(id),
 service_date date not null,shift text not null check(shift in ('DIURNO','NOCTURNO')),
 status text not null check(status in ('REALIZADA','INTERRUMPIDA')),currency text not null check(currency in ('USD','DOP')),
 price numeric(14,2) not null check(price>=0 and price::text not in ('NaN','Infinity','-Infinity'))
);
alter table public.workflow_service_events enable row level security;
revoke all privileges on public.workflow_service_events from public,authenticated,anon;
drop policy if exists wf_service_event_read on public.workflow_service_events;
create policy wf_service_event_read on public.workflow_service_events for select to authenticated
using (public.wf_active_actor() and (public.has_permission('SALES_VIEW') and public.can_access_branch(branch_id)));
grant select on public.workflow_service_events to authenticated;
drop trigger if exists wf_audit on public.workflow_service_events;
create trigger wf_audit after insert on public.workflow_service_events for each row execute function public.wf_audit_change();

create or replace function public.wf_validate_service_date(p_actual timestamptz,p_day date,p_shift text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare actual_day date:=(p_actual at time zone 'America/Santo_Domingo')::date;
begin
 if p_actual is null or p_day is null or p_shift is null or p_shift not in ('DIURNO','NOCTURNO')
    or (p_shift='DIURNO' and p_day<>actual_day)
    or (p_shift='NOCTURNO' and p_day not in (actual_day,actual_day-1)) then raise exception 'Fecha operativa no corresponde al evento/turno';end if;
end $$;
revoke execute on function public.wf_validate_service_date(timestamptz,date,text) from public,anon,authenticated;

insert into public.role_permissions(role_id,permission_code)
select role_id,'HYPERBARIC_BILLING' from public.role_permissions where permission_code='COLLECTIONS_WRITE'
on conflict do nothing;
insert into public.role_permissions(role_id,permission_code)
select role_id,'COMMERCIAL_VIEW' from public.role_permissions where permission_code='MEDICAL_NETWORK_WRITE'
on conflict do nothing;
insert into public.role_permissions(role_id,permission_code)
select r.id,'HYPERBARIC_VIEW' from public.roles r where r.code='MEDICO_GERENTE_TECNICO' on conflict do nothing;

create or replace view public.vw_workflow_receipts with (security_invoker=true) as
select id,branch_id,payment_date,'DOP'::text currency,amount,'SANGRE'::text source_type from public.customer_payments
where public.wf_active_actor() and public.has_permission('COLLECTIONS_VIEW') and public.can_access_branch(branch_id)
union all
select id,branch_id,payment_date,currency,amount,'CAMARA_HIPERBARICA' from public.hyperbaric_payments
where public.wf_active_actor() and public.has_permission('COLLECTIONS_VIEW') and public.can_access_branch(branch_id);
grant select on public.vw_workflow_receipts to authenticated;

create or replace view public.vw_workflow_transfer_lines with (security_invoker=true) as
select l.*,t.branch_id,t.destination_branch_id from public.blood_transfer_lines l join public.blood_transfers t on t.id=l.transfer_id;
grant select on public.vw_workflow_transfer_lines to authenticated;

commit;
