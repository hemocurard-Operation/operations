begin;
create table if not exists public.quality_objectives(
 id uuid primary key default gen_random_uuid(), objective_code text not null unique,
 title text not null, description text not null, owner_user_id uuid references public.profiles(id),
 metric text not null, baseline numeric, target numeric, due_date date, status text not null default 'ABIERTO'
 check(status in ('ABIERTO','EN_CURSO','CUMPLIDO','NO_CUMPLIDO','CANCELADO'))
);
create table if not exists public.management_reviews(
 id uuid primary key default gen_random_uuid(), review_code text not null unique,
 review_date date not null, period_start date not null, period_end date not null,
 chair_user_id uuid references public.profiles(id), participants text,
 summary text, decisions text, status text not null default 'BORRADOR'
 check(status in ('BORRADOR','APROBADA','CERRADA')),
 created_at timestamptz not null default now()
);
create table if not exists public.management_review_actions(
 id uuid primary key default gen_random_uuid(), review_id uuid not null references public.management_reviews(id) on delete cascade,
 action_code text not null unique, description text not null, owner_user_id uuid references public.profiles(id),
 due_date date, status text not null default 'ABIERTA' check(status in ('ABIERTA','EN_CURSO','CERRADA','CANCELADA')),
 evidence_reference text
);
alter table public.quality_objectives enable row level security;
alter table public.management_reviews enable row level security;
alter table public.management_review_actions enable row level security;
drop policy if exists quality_objectives_auth on public.quality_objectives; create policy quality_objectives_auth on public.quality_objectives for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
drop policy if exists management_reviews_auth on public.management_reviews; create policy management_reviews_auth on public.management_reviews for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
drop policy if exists management_review_actions_auth on public.management_review_actions; create policy management_review_actions_auth on public.management_review_actions for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
grant select,insert,update on public.quality_objectives,public.management_reviews,public.management_review_actions to authenticated;
create or replace view public.vw_management_review_inputs as
select
 (select count(*) from public.vw_audit_findings_open) open_audit_findings,
 (select count(*) from public.capa where status not in ('CERRADA','CANCELADA')) open_capa,
 (select count(*) from public.vw_equipment_alerts where severity in ('CRITICA','ALTA')) equipment_alerts,
 (select count(*) from public.vw_reagent_alerts where severity in ('CRITICA','ALTA')) reagent_alerts,
 (select count(*) from public.vw_competency_alerts where severity='ALTA') competency_high_alerts,
 (select count(*) from public.vw_iqc_alerts) iqc_alerts,
 (select count(*) from public.hemovigilance_events where status not in ('CERRADO','CANCELADO')) open_hemovigilance;
grant select on public.vw_management_review_inputs to authenticated;
insert into public.app_permissions(permission_code,module,description,risk_level) values
('MANAGEMENT_REVIEW_VIEW','MANAGEMENT','Ver revisión por la dirección','SENSIBLE'),
('MANAGEMENT_REVIEW_WRITE','MANAGEMENT','Gestionar revisión por la dirección','CRITICO')
on conflict(permission_code) do update set active=true;
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r join public.app_permissions p on p.permission_code in ('MANAGEMENT_REVIEW_VIEW','MANAGEMENT_REVIEW_WRITE')
where r.code in ('ADMIN','GERENCIA_OPERATIVA','CALIDAD','GERENCIA_GENERAL') on conflict do nothing;
insert into public.app_migrations(migration_code,version,description,applied_by)
values('40_MANAGEMENT_REVIEW_v0_40','0.40.0','Objetivos y revisión por la dirección',auth.uid())
on conflict(migration_code) do update set applied_at=now(),version=excluded.version,description=excluded.description,applied_by=auth.uid();
commit;