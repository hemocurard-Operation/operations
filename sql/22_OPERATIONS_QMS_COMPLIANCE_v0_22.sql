-- ============================================================
-- HemoCura v0.22.0
-- OPERACIONES + SGC + COMPLIANCE
-- Migración incremental sobre esquema v7.2
-- ============================================================

begin;

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- 1. REQUISICIONES
-- ------------------------------------------------------------
create table if not exists public.requisitions (
  id uuid primary key default gen_random_uuid(),
  requisition_code text not null unique,
  request_date date not null default current_date,
  requesting_branch_id uuid not null references public.branches(id),
  supplying_branch_id uuid references public.branches(id),
  requested_by uuid references public.profiles(id),
  department text,
  priority text not null default 'NORMAL' check(priority in ('NORMAL','URGENTE')),
  status text not null default 'BORRADOR'
    check(status in ('BORRADOR','PENDIENTE','APROBADA','PARCIAL','ENTREGADA','RECHAZADA','CANCELADA')),
  justification text,
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  received_by uuid references public.profiles(id),
  received_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.requisition_lines (
  id uuid primary key default gen_random_uuid(),
  requisition_id uuid not null references public.requisitions(id) on delete cascade,
  category text,
  item_name text not null,
  unit text,
  requested_qty numeric not null check(requested_qty > 0),
  authorized_qty numeric check(authorized_qty >= 0),
  received_qty numeric check(received_qty >= 0),
  observations text,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 2. INSPECCIONES Y HALLAZGOS
-- ------------------------------------------------------------
create table if not exists public.branch_inspections (
  id uuid primary key default gen_random_uuid(),
  inspection_code text not null unique,
  branch_id uuid not null references public.branches(id),
  inspection_date date not null default current_date,
  inspection_time time,
  inspector_id uuid references public.profiles(id),
  site_responsible text,
  inspection_type text not null default 'RUTINA'
    check(inspection_type in ('RUTINA','SEGUIMIENTO','APERTURA','EXTRAORDINARIA')),
  status text not null default 'BORRADOR'
    check(status in ('BORRADOR','FINALIZADA','CERRADA')),
  compliant_count integer not null default 0,
  nonconforming_count integer not null default 0,
  not_applicable_count integer not null default 0,
  compliance_pct numeric,
  positive_findings text,
  correction_findings text,
  commitments text,
  next_visit_date date,
  overall_rating text check(overall_rating in ('SATISFACTORIO','CON_OBSERVACIONES','CRITICO') or overall_rating is null),
  report_url text,
  created_at timestamptz not null default now(),
  closed_at timestamptz
);

create table if not exists public.inspection_findings (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid not null references public.branch_inspections(id) on delete cascade,
  section_code text,
  section_name text not null,
  criterion_no text,
  criterion text not null,
  result text not null check(result in ('C','NC','NA')),
  observation text,
  severity integer check(severity between 1 and 5),
  incident_id uuid references public.incidents(id),
  nonconformity_id uuid references public.nonconformities(id),
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 3. REGISTRO DOCUMENTAL / CONTROL DE CAMBIOS
-- ------------------------------------------------------------
create table if not exists public.document_register (
  id uuid primary key default gen_random_uuid(),
  document_code text not null unique,
  title text not null,
  area text not null,
  document_type text not null,
  version text not null default '01',
  status text not null default 'BORRADOR'
    check(status in ('BORRADOR','EN_REVISION','APROBADO','VIGENTE','OBSOLETO','DEROGADO')),
  owner_user_id uuid references public.profiles(id),
  approver_user_id uuid references public.profiles(id),
  effective_date date,
  review_date date,
  supersedes_code text,
  source_path text,
  controlled_copy boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  approved_at timestamptz
);

create table if not exists public.document_changes (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.document_register(id) on delete cascade,
  change_date timestamptz not null default now(),
  requested_by uuid references public.profiles(id),
  change_reason text not null,
  impact_assessment text,
  previous_version text,
  new_version text,
  status text not null default 'PENDIENTE'
    check(status in ('PENDIENTE','APROBADO','RECHAZADO','IMPLEMENTADO')),
  approved_by uuid references public.profiles(id),
  approved_at timestamptz
);

-- ------------------------------------------------------------
-- 4. RIESGOS INSTITUCIONALES / COMPLIANCE
-- ------------------------------------------------------------
create table if not exists public.risk_register (
  id uuid primary key default gen_random_uuid(),
  risk_code text not null unique,
  branch_id uuid references public.branches(id),
  process_name text not null,
  risk_domain text not null default 'SGC'
    check(risk_domain in ('OPERACIONAL','SGC','COMPLIANCE','LEGAL','BIOSEGURIDAD','TECNOLOGIA')),
  risk_description text not null,
  cause text,
  consequence text,
  probability integer not null check(probability between 1 and 5),
  impact integer not null check(impact between 1 and 5),
  inherent_score integer generated always as (probability * impact) stored,
  existing_controls text,
  treatment_action text,
  owner_user_id uuid references public.profiles(id),
  residual_probability integer check(residual_probability between 1 and 5),
  residual_impact integer check(residual_impact between 1 and 5),
  status text not null default 'ABIERTO'
    check(status in ('ABIERTO','EN_TRATAMIENTO','ACEPTADO','CERRADO')),
  review_date date,
  evidence_url text,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 5. VINCULACIÓN NC/CAPA CON HALLAZGOS
-- ------------------------------------------------------------
alter table public.nonconformities
  add column if not exists source_table text,
  add column if not exists source_id uuid;

alter table public.capa
  add column if not exists evidence_url text,
  add column if not exists effectiveness_verified_at timestamptz;

-- ------------------------------------------------------------
-- 6. RLS
-- ------------------------------------------------------------
alter table public.requisitions enable row level security;
alter table public.requisition_lines enable row level security;
alter table public.branch_inspections enable row level security;
alter table public.inspection_findings enable row level security;
alter table public.document_register enable row level security;
alter table public.document_changes enable row level security;
alter table public.risk_register enable row level security;

drop policy if exists requisitions_read on public.requisitions;
create policy requisitions_read on public.requisitions for select
using (public.can_access_branch(requesting_branch_id));

drop policy if exists requisitions_write on public.requisitions;
create policy requisitions_write on public.requisitions for all
using (public.can_access_branch(requesting_branch_id))
with check (public.can_access_branch(requesting_branch_id));

drop policy if exists requisition_lines_access on public.requisition_lines;
create policy requisition_lines_access on public.requisition_lines for all
using (exists (
  select 1 from public.requisitions r
  where r.id=requisition_id and public.can_access_branch(r.requesting_branch_id)
))
with check (exists (
  select 1 from public.requisitions r
  where r.id=requisition_id and public.can_access_branch(r.requesting_branch_id)
));

drop policy if exists inspections_read on public.branch_inspections;
create policy inspections_read on public.branch_inspections for select
using (public.can_access_branch(branch_id));

drop policy if exists inspections_write on public.branch_inspections;
create policy inspections_write on public.branch_inspections for all
using (public.can_access_branch(branch_id))
with check (public.can_access_branch(branch_id));

drop policy if exists inspection_findings_access on public.inspection_findings;
create policy inspection_findings_access on public.inspection_findings for all
using (exists (
  select 1 from public.branch_inspections i
  where i.id=inspection_id and public.can_access_branch(i.branch_id)
))
with check (exists (
  select 1 from public.branch_inspections i
  where i.id=inspection_id and public.can_access_branch(i.branch_id)
));

drop policy if exists document_register_read on public.document_register;
create policy document_register_read on public.document_register for select
using (auth.role()='authenticated');

drop policy if exists document_register_write on public.document_register;
create policy document_register_write on public.document_register for all
using (
  public.has_role('ADMIN') or
  public.has_role('GERENCIA_OPERATIVA') or
  public.has_role('CALIDAD')
)
with check (
  public.has_role('ADMIN') or
  public.has_role('GERENCIA_OPERATIVA') or
  public.has_role('CALIDAD')
);

drop policy if exists document_changes_read on public.document_changes;
create policy document_changes_read on public.document_changes for select
using (auth.role()='authenticated');

drop policy if exists document_changes_write on public.document_changes;
create policy document_changes_write on public.document_changes for all
using (
  public.has_role('ADMIN') or
  public.has_role('GERENCIA_OPERATIVA') or
  public.has_role('CALIDAD')
)
with check (
  public.has_role('ADMIN') or
  public.has_role('GERENCIA_OPERATIVA') or
  public.has_role('CALIDAD')
);

drop policy if exists risk_register_read on public.risk_register;
create policy risk_register_read on public.risk_register for select
using (branch_id is null or public.can_access_branch(branch_id));

drop policy if exists risk_register_write on public.risk_register;
create policy risk_register_write on public.risk_register for all
using (
  public.has_role('ADMIN') or
  public.has_role('GERENCIA_OPERATIVA') or
  public.has_role('CALIDAD')
)
with check (
  public.has_role('ADMIN') or
  public.has_role('GERENCIA_OPERATIVA') or
  public.has_role('CALIDAD')
);

grant select,insert,update on public.requisitions, public.requisition_lines,
  public.branch_inspections, public.inspection_findings,
  public.document_register, public.document_changes, public.risk_register
to authenticated;

-- ------------------------------------------------------------
-- 7. VISTAS DE GESTIÓN
-- ------------------------------------------------------------
create or replace view public.vw_qms_open_actions as
select 'INCIDENTE' source_type, i.id source_id, i.branch_id, i.incident_date action_date,
       i.incident_code code, i.description, null::date due_date,
       case when i.requires_quality_followup then 'SEGUIMIENTO' else 'INFORMATIVO' end status
from public.incidents i
where i.requires_quality_followup
union all
select 'NC', n.id, n.branch_id, n.detected_at::date, n.code, n.description, n.due_date, n.status
from public.nonconformities n
where upper(n.status) not in ('CERRADA','CERRADO','CANCELADA')
union all
select 'CAPA', c.id, n.branch_id, c.created_at::date, c.code, c.problem, c.due_date, c.status
from public.capa c
left join public.nonconformities n on n.id=c.nonconformity_id
where upper(c.status) not in ('CERRADA','CERRADO','CANCELADA','COMPLETADA');

create or replace view public.vw_inspection_summary as
select i.id,i.inspection_code,i.branch_id,i.inspection_date,i.inspection_type,i.status,
       i.compliant_count,i.nonconforming_count,i.not_applicable_count,i.compliance_pct,
       count(f.id) total_findings,
       count(*) filter(where f.result='NC') nc_findings,
       count(*) filter(where f.nonconformity_id is not null) converted_to_nc
from public.branch_inspections i
left join public.inspection_findings f on f.inspection_id=i.id
group by i.id;

grant select on public.vw_qms_open_actions, public.vw_inspection_summary to authenticated;

commit;
