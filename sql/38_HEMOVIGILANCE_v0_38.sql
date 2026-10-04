begin;
create table if not exists public.hemovigilance_events(
 id uuid primary key default gen_random_uuid(), event_code text not null unique,
 branch_id uuid references public.branches(id), event_date timestamptz not null default now(),
 event_type text not null check(event_type in ('REACCION_DONANTE','REACCION_TRANSFUSIONAL','ERROR','CASI_EVENTO','QUEJA','RETIRO','OTRO')),
 severity text not null default 'MEDIA' check(severity in ('BAJA','MEDIA','ALTA','CRITICA')),
 source_unit_code text, patient_reference text, donor_reference text,
 description text not null, immediate_action text, reported_by uuid references public.profiles(id),
 status text not null default 'ABIERTO' check(status in ('ABIERTO','INVESTIGACION','ACCION','VERIFICACION','CERRADO','CANCELADO')),
 nonconformity_id uuid references public.nonconformities(id), capa_id uuid references public.capa(id),
 closed_at timestamptz
);
create table if not exists public.product_recalls(
 id uuid primary key default gen_random_uuid(), recall_code text not null unique,
 branch_id uuid references public.branches(id), initiated_at timestamptz not null default now(),
 reason text not null, scope text, initiated_by uuid references public.profiles(id),
 status text not null default 'ABIERTO' check(status in ('ABIERTO','EN_CURSO','COMPLETADO','CANCELADO')),
 completion_summary text, completed_at timestamptz
);
create table if not exists public.recall_units(
 id uuid primary key default gen_random_uuid(), recall_id uuid not null references public.product_recalls(id) on delete cascade,
 source_unit_code text not null, current_location text, disposition text,
 confirmed_recovered boolean not null default false, confirmed_at timestamptz,
 unique(recall_id,source_unit_code)
);
alter table public.hemovigilance_events enable row level security;
alter table public.product_recalls enable row level security;
alter table public.recall_units enable row level security;
drop policy if exists hemovig_auth on public.hemovigilance_events;
create policy hemovig_auth on public.hemovigilance_events for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
drop policy if exists recalls_auth on public.product_recalls;
create policy recalls_auth on public.product_recalls for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
drop policy if exists recall_units_auth on public.recall_units;
create policy recall_units_auth on public.recall_units for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
grant select,insert,update on public.hemovigilance_events,public.product_recalls,public.recall_units to authenticated;
create or replace view public.vw_hemovigilance_summary as
select count(*) filter(where status not in ('CERRADO','CANCELADO')) open_events,
count(*) filter(where severity='CRITICA' and status not in ('CERRADO','CANCELADO')) critical_open,
count(*) filter(where event_type='CASI_EVENTO') near_misses,
count(*) filter(where event_type='RETIRO') recall_related
from public.hemovigilance_events;
grant select on public.vw_hemovigilance_summary to authenticated;
insert into public.app_permissions(permission_code,module,description,risk_level) values
('HEMOVIGILANCE_VIEW','HEMOVIGILANCE','Ver hemovigilancia','SENSIBLE'),
('HEMOVIGILANCE_WRITE','HEMOVIGILANCE','Gestionar eventos de hemovigilancia','CRITICO')
on conflict(permission_code) do update set active=true;
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r join public.app_permissions p on p.permission_code in ('HEMOVIGILANCE_VIEW','HEMOVIGILANCE_WRITE')
where r.code in ('ADMIN','GERENCIA_OPERATIVA','CALIDAD','LABORATORIO') on conflict do nothing;
insert into public.app_migrations(migration_code,version,description,applied_by)
values('38_HEMOVIGILANCE_v0_38','0.38.0','Hemovigilancia, eventos y retiros',auth.uid())
on conflict(migration_code) do update set applied_at=now(),version=excluded.version,description=excluded.description,applied_by=auth.uid();
commit;