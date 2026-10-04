-- ============================================================
-- HemoCura v0.34.0
-- Competencias + capacitación + evaluación + evidencia
-- Requiere v0.33.0
-- ============================================================
begin;
create extension if not exists pgcrypto;

-- 1) PUESTOS / FUNCIONES
create table if not exists public.job_roles (
  id uuid primary key default gen_random_uuid(),
  role_code text not null unique,
  title text not null,
  department text,
  description text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.job_roles enable row level security;
drop policy if exists job_roles_read on public.job_roles;
create policy job_roles_read on public.job_roles for select using(auth.role()='authenticated');
drop policy if exists job_roles_write on public.job_roles;
create policy job_roles_write on public.job_roles for all
using(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'))
with check(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
grant select,insert,update on public.job_roles to authenticated;

-- 2) CATÁLOGO DE COMPETENCIAS
create table if not exists public.competency_catalog (
  id uuid primary key default gen_random_uuid(),
  competency_code text not null unique,
  title text not null,
  category text not null default 'TECNICA'
    check(category in ('TECNICA','CALIDAD','SEGURIDAD','REGULATORIA','GESTION','DIGITAL','COMUNICACION')),
  description text not null,
  evidence_required text,
  validity_months integer check(validity_months is null or validity_months between 1 and 120),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.competency_catalog enable row level security;
drop policy if exists competency_catalog_read on public.competency_catalog;
create policy competency_catalog_read on public.competency_catalog for select using(auth.role()='authenticated');
drop policy if exists competency_catalog_write on public.competency_catalog;
create policy competency_catalog_write on public.competency_catalog for all
using(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'))
with check(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
grant select,insert,update on public.competency_catalog to authenticated;

-- 3) MATRIZ PUESTO → COMPETENCIA
create table if not exists public.job_role_competencies (
  id uuid primary key default gen_random_uuid(),
  job_role_id uuid not null references public.job_roles(id) on delete cascade,
  competency_id uuid not null references public.competency_catalog(id) on delete cascade,
  required_level integer not null default 3 check(required_level between 1 and 5),
  mandatory boolean not null default true,
  evaluation_method text,
  notes text,
  unique(job_role_id,competency_id)
);

alter table public.job_role_competencies enable row level security;
drop policy if exists job_role_competencies_access on public.job_role_competencies;
create policy job_role_competencies_access on public.job_role_competencies for all
using(auth.role()='authenticated')
with check(auth.role()='authenticated');
grant select,insert,update on public.job_role_competencies to authenticated;

-- 4) ASIGNACIÓN DE PUESTOS A PERSONAS
create table if not exists public.staff_job_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  job_role_id uuid not null references public.job_roles(id),
  branch_id uuid references public.branches(id),
  start_date date not null default current_date,
  end_date date,
  primary_role boolean not null default true,
  active boolean not null default true,
  unique(user_id,job_role_id,branch_id,start_date)
);

alter table public.staff_job_assignments enable row level security;
drop policy if exists staff_job_assignments_read on public.staff_job_assignments;
create policy staff_job_assignments_read on public.staff_job_assignments for select
using(auth.role()='authenticated');
drop policy if exists staff_job_assignments_write on public.staff_job_assignments;
create policy staff_job_assignments_write on public.staff_job_assignments for all
using(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('CALIDAD'))
with check(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('CALIDAD'));
grant select,insert,update on public.staff_job_assignments to authenticated;

-- 5) CAPACITACIONES
create table if not exists public.training_events (
  id uuid primary key default gen_random_uuid(),
  training_code text not null unique,
  title text not null,
  provider text,
  modality text check(modality in ('PRESENCIAL','VIRTUAL','MIXTA','AUTOESTUDIO') or modality is null),
  start_date date not null,
  end_date date,
  duration_hours numeric check(duration_hours is null or duration_hours>=0),
  source_url text,
  objective text,
  status text not null default 'PLANIFICADA'
    check(status in ('PLANIFICADA','EN_CURSO','COMPLETADA','CANCELADA')),
  created_at timestamptz not null default now()
);

alter table public.training_events enable row level security;
drop policy if exists training_events_read on public.training_events;
create policy training_events_read on public.training_events for select using(auth.role()='authenticated');
drop policy if exists training_events_write on public.training_events;
create policy training_events_write on public.training_events for all
using(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'))
with check(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
grant select,insert,update on public.training_events to authenticated;

-- 6) PARTICIPACIÓN / RESULTADOS
create table if not exists public.training_participation (
  id uuid primary key default gen_random_uuid(),
  training_id uuid not null references public.training_events(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  competency_id uuid references public.competency_catalog(id),
  attendance_status text not null default 'INSCRITO'
    check(attendance_status in ('INSCRITO','ASISTIO','COMPLETO','NO_ASISTIO','CANCELADO')),
  score numeric,
  passed boolean,
  evidence_reference text,
  certificate_url text,
  completed_at timestamptz,
  unique(training_id,user_id,competency_id)
);

alter table public.training_participation enable row level security;
drop policy if exists training_participation_read on public.training_participation;
create policy training_participation_read on public.training_participation for select using(auth.role()='authenticated');
drop policy if exists training_participation_write on public.training_participation;
create policy training_participation_write on public.training_participation for all
using(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'))
with check(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
grant select,insert,update on public.training_participation to authenticated;

-- 7) EVALUACIÓN DE COMPETENCIA
create table if not exists public.competency_assessments (
  id uuid primary key default gen_random_uuid(),
  assessment_code text not null unique,
  user_id uuid not null references public.profiles(id),
  competency_id uuid not null references public.competency_catalog(id),
  branch_id uuid references public.branches(id),
  assessment_date date not null default current_date,
  assessor_user_id uuid not null references public.profiles(id),
  method text not null,
  score numeric,
  level_achieved integer check(level_achieved between 1 and 5),
  result text not null check(result in ('COMPETENTE','NO_COMPETENTE','REQUIERE_SUPERVISION')),
  evidence_reference text not null,
  valid_until date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.competency_assessments enable row level security;
drop policy if exists competency_assessments_read on public.competency_assessments;
create policy competency_assessments_read on public.competency_assessments for select using(auth.role()='authenticated');
drop policy if exists competency_assessments_write on public.competency_assessments;
create policy competency_assessments_write on public.competency_assessments for all
using(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'))
with check(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
grant select,insert,update on public.competency_assessments to authenticated;

-- 8) VALIDACIÓN DE INDEPENDENCIA DEL EVALUADOR
create or replace function public.validate_competency_assessor()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
begin
  if new.user_id=new.assessor_user_id then
    raise exception 'La persona evaluada no puede evaluarse a sí misma';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_competency_assessor on public.competency_assessments;
create trigger trg_validate_competency_assessor
before insert or update of user_id,assessor_user_id
on public.competency_assessments
for each row execute function public.validate_competency_assessor();

-- 9) BRECHAS DE COMPETENCIA
create or replace view public.vw_staff_competency_gaps as
with req as (
  select
    s.user_id,s.branch_id,s.job_role_id,jr.title job_title,
    rc.competency_id,c.competency_code,c.title competency_title,
    rc.required_level,rc.mandatory,c.validity_months
  from public.staff_job_assignments s
  join public.job_roles jr on jr.id=s.job_role_id
  join public.job_role_competencies rc on rc.job_role_id=s.job_role_id
  join public.competency_catalog c on c.id=rc.competency_id
  where s.active and jr.active and c.active
),
last_assessment as (
  select distinct on(user_id,competency_id)
    user_id,competency_id,assessment_date,level_achieved,result,valid_until,evidence_reference
  from public.competency_assessments
  order by user_id,competency_id,assessment_date desc,created_at desc
)
select
  r.user_id,r.branch_id,r.job_role_id,r.job_title,
  r.competency_id,r.competency_code,r.competency_title,
  r.required_level,r.mandatory,
  a.assessment_date,a.level_achieved,a.result,a.valid_until,a.evidence_reference,
  case
    when a.user_id is null then 'SIN_EVALUAR'
    when a.result='NO_COMPETENTE' then 'BRECHA'
    when a.result='REQUIERE_SUPERVISION' then 'SUPERVISION'
    when a.level_achieved<r.required_level then 'BRECHA'
    when a.valid_until is not null and a.valid_until<current_date then 'VENCIDA'
    when a.valid_until is not null and a.valid_until<=current_date+30 then 'POR_VENCER'
    else 'COMPETENTE'
  end competency_status
from req r
left join last_assessment a
  on a.user_id=r.user_id and a.competency_id=r.competency_id;

grant select on public.vw_staff_competency_gaps to authenticated;

-- 10) MATRIZ DE CUMPLIMIENTO
create or replace view public.vw_competency_compliance_summary as
select
  user_id,branch_id,
  count(*) required_competencies,
  count(*) filter(where competency_status='COMPETENTE') competent,
  count(*) filter(where competency_status in ('BRECHA','SIN_EVALUAR','VENCIDA','SUPERVISION')) gaps,
  count(*) filter(where competency_status='POR_VENCER') expiring_soon,
  round(
    case when count(*)=0 then 0
         else 100.0*count(*) filter(where competency_status='COMPETENTE')/count(*)
    end,1
  ) compliance_pct
from public.vw_staff_competency_gaps
group by user_id,branch_id;

grant select on public.vw_competency_compliance_summary to authenticated;

-- 11) ALERTAS
create or replace view public.vw_competency_alerts as
select
  g.user_id,g.branch_id,g.competency_code,g.competency_title,g.job_title,
  g.competency_status,
  case
    when g.competency_status in ('BRECHA','VENCIDA') then 'ALTA'
    when g.competency_status in ('SIN_EVALUAR','SUPERVISION','POR_VENCER') then 'MEDIA'
    else 'BAJA'
  end severity,
  case
    when g.competency_status='SIN_EVALUAR' then 'Competencia requerida sin evaluación'
    when g.competency_status='BRECHA' then 'Nivel o resultado no cumple requisito'
    when g.competency_status='SUPERVISION' then 'Requiere supervisión'
    when g.competency_status='VENCIDA' then 'Evaluación de competencia vencida'
    when g.competency_status='POR_VENCER' then 'Evaluación vence en 30 días o menos'
    else 'Sin alerta'
  end message
from public.vw_staff_competency_gaps g
where g.competency_status<>'COMPETENTE';

grant select on public.vw_competency_alerts to authenticated;

-- 12) RELACIÓN CON AUDITORÍAS
alter table public.audit_findings
  add column if not exists competency_id uuid references public.competency_catalog(id),
  add column if not exists staff_user_id uuid references public.profiles(id);

-- 13) PERMISOS
insert into public.app_permissions(permission_code,module,description,risk_level) values
('COMPETENCY_VIEW','COMPETENCY','Ver matriz de competencias','SENSIBLE'),
('COMPETENCY_WRITE','COMPETENCY','Gestionar competencias y evaluaciones','CRITICO')
on conflict(permission_code) do update set
 module=excluded.module,description=excluded.description,risk_level=excluded.risk_level,active=true;

insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p
on p.permission_code in ('COMPETENCY_VIEW','COMPETENCY_WRITE')
where r.code in ('ADMIN','CALIDAD','GERENCIA_OPERATIVA')
on conflict do nothing;

insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p
on p.permission_code='COMPETENCY_VIEW'
where r.code in ('GERENCIA_GENERAL','LABORATORIO','SUCURSAL')
on conflict do nothing;

-- 14) MIGRACIÓN
insert into public.app_migrations(
  migration_code,version,description,applied_by
)
values(
  '34_COMPETENCY_TRAINING_v0_34',
  '0.34.0',
  'Matriz de competencias, capacitación, evaluación y alertas',
  auth.uid()
)
on conflict(migration_code) do update set
  version=excluded.version,
  description=excluded.description,
  applied_at=now(),
  applied_by=auth.uid();

commit;
