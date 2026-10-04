-- ============================================================
-- HemoCura v0.33.0
-- Auditorías internas + programa anual + hallazgos + evidencia
-- Requiere v0.32.1
-- ============================================================
begin;
create extension if not exists pgcrypto;

-- 1) CATÁLOGO DE CRITERIOS / REFERENCIAS
create table if not exists public.audit_criteria_catalog (
  id uuid primary key default gen_random_uuid(),
  framework text not null default 'ISO 15189',
  clause_reference text not null,
  criterion_code text not null unique,
  criterion_summary text not null,
  process_area text,
  mandatory boolean not null default true,
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.audit_criteria_catalog enable row level security;
drop policy if exists audit_criteria_catalog_read on public.audit_criteria_catalog;
create policy audit_criteria_catalog_read on public.audit_criteria_catalog for select
using(auth.role()='authenticated');

drop policy if exists audit_criteria_catalog_write on public.audit_criteria_catalog;
create policy audit_criteria_catalog_write on public.audit_criteria_catalog for all
using(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'))
with check(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));

grant select,insert,update on public.audit_criteria_catalog to authenticated;

-- Referencias generales, sin reproducir texto normativo.
insert into public.audit_criteria_catalog(
  framework,clause_reference,criterion_code,criterion_summary,process_area
) values
('ISO 15189','4','ISO15189-4-GEN','Requisitos generales: imparcialidad, confidencialidad y gobierno aplicable.','GOBIERNO'),
('ISO 15189','5','ISO15189-5-ORG','Estructura, responsabilidades, autoridad y gestión organizacional.','ORGANIZACION'),
('ISO 15189','6','ISO15189-6-RES','Recursos: personal, instalaciones, equipos, reactivos y servicios externos.','RECURSOS'),
('ISO 15189','7','ISO15189-7-PRO','Procesos preanalíticos, analíticos y postanalíticos aplicables.','PROCESOS'),
('ISO 15189','8','ISO15189-8-MGT','Sistema de gestión, documentación, riesgos, NC, CAPA, auditorías y mejora.','SGC')
on conflict(criterion_code) do nothing;

-- 2) PROGRAMA ANUAL
create table if not exists public.audit_programs (
  id uuid primary key default gen_random_uuid(),
  program_code text not null unique,
  program_year integer not null check(program_year between 2020 and 2100),
  title text not null,
  objective text not null,
  scope text,
  owner_user_id uuid references public.profiles(id),
  status text not null default 'BORRADOR'
    check(status in ('BORRADOR','APROBADO','EN_EJECUCION','CERRADO','CANCELADO')),
  planned_audits integer not null default 0,
  completed_audits integer not null default 0,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.audit_programs enable row level security;
drop policy if exists audit_programs_read on public.audit_programs;
create policy audit_programs_read on public.audit_programs for select
using(auth.role()='authenticated');
drop policy if exists audit_programs_write on public.audit_programs;
create policy audit_programs_write on public.audit_programs for all
using(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'))
with check(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
grant select,insert,update on public.audit_programs to authenticated;

-- 3) PLAN / EJECUCIÓN DE AUDITORÍA
create table if not exists public.internal_audits (
  id uuid primary key default gen_random_uuid(),
  audit_code text not null unique,
  program_id uuid references public.audit_programs(id),
  branch_id uuid references public.branches(id),
  process_id uuid references public.quality_processes(id),
  audit_type text not null default 'INTERNA'
    check(audit_type in ('INTERNA','SEGUIMIENTO','EXTRAORDINARIA','PRECERTIFICACION')),
  title text not null,
  objective text not null,
  scope text,
  lead_auditor_id uuid not null references public.profiles(id),
  process_owner_user_id uuid references public.profiles(id),
  planned_date date not null,
  actual_start_at timestamptz,
  actual_end_at timestamptz,
  status text not null default 'PLANIFICADA'
    check(status in ('PLANIFICADA','EN_CURSO','INFORME','CERRADA','CANCELADA')),
  conclusion text,
  overall_result text check(overall_result in ('CONFORME','CON_OBSERVACIONES','NO_CONFORME') or overall_result is null),
  created_at timestamptz not null default now(),
  closed_at timestamptz
);

alter table public.internal_audits enable row level security;
drop policy if exists internal_audits_read on public.internal_audits;
create policy internal_audits_read on public.internal_audits for select
using(branch_id is null or public.can_access_branch(branch_id));
drop policy if exists internal_audits_write on public.internal_audits;
create policy internal_audits_write on public.internal_audits for all
using(
  (branch_id is null or public.can_access_branch(branch_id))
  and (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'))
)
with check(
  (branch_id is null or public.can_access_branch(branch_id))
  and (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'))
);
grant select,insert,update on public.internal_audits to authenticated;

-- 4) CRITERIOS ASIGNADOS A AUDITORÍA
create table if not exists public.audit_plan_criteria (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.internal_audits(id) on delete cascade,
  criterion_id uuid not null references public.audit_criteria_catalog(id),
  planned_sample text,
  responsible_auditor_id uuid references public.profiles(id),
  result text check(result in ('C','NC','OBS','NA') or result is null),
  observation text,
  tested_at timestamptz,
  unique(audit_id,criterion_id)
);

alter table public.audit_plan_criteria enable row level security;
drop policy if exists audit_plan_criteria_access on public.audit_plan_criteria;
create policy audit_plan_criteria_access on public.audit_plan_criteria for all
using(auth.role()='authenticated')
with check(auth.role()='authenticated');
grant select,insert,update on public.audit_plan_criteria to authenticated;

-- 5) HALLAZGOS
create table if not exists public.audit_findings (
  id uuid primary key default gen_random_uuid(),
  finding_code text not null unique,
  audit_id uuid not null references public.internal_audits(id) on delete cascade,
  criterion_id uuid references public.audit_criteria_catalog(id),
  finding_type text not null
    check(finding_type in ('CONFORMIDAD','OBSERVACION','NO_CONFORMIDAD','OPORTUNIDAD_MEJORA')),
  severity text not null default 'MEDIA'
    check(severity in ('BAJA','MEDIA','ALTA','CRITICA')),
  title text not null,
  description text not null,
  evidence_summary text not null,
  process_owner_response text,
  nonconformity_id uuid references public.nonconformities(id),
  capa_id uuid references public.capa(id),
  status text not null default 'ABIERTO'
    check(status in ('ABIERTO','EN_TRATAMIENTO','VERIFICACION','CERRADO','CANCELADO')),
  due_date date,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  closed_at timestamptz
);

alter table public.audit_findings enable row level security;
drop policy if exists audit_findings_read on public.audit_findings;
create policy audit_findings_read on public.audit_findings for select
using(auth.role()='authenticated');
drop policy if exists audit_findings_write on public.audit_findings;
create policy audit_findings_write on public.audit_findings for all
using(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'))
with check(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
grant select,insert,update on public.audit_findings to authenticated;

-- 6) EVIDENCIA
create table if not exists public.audit_evidence (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.internal_audits(id) on delete cascade,
  finding_id uuid references public.audit_findings(id) on delete cascade,
  evidence_code text not null unique,
  evidence_type text not null
    check(evidence_type in ('DOCUMENTO','REGISTRO','ENTREVISTA','OBSERVACION','MUESTRA','FOTO','OTRO')),
  title text not null,
  description text,
  source_reference text,
  source_url text,
  captured_by uuid references public.profiles(id),
  captured_at timestamptz not null default now(),
  confidential boolean not null default false
);

alter table public.audit_evidence enable row level security;
drop policy if exists audit_evidence_read on public.audit_evidence;
create policy audit_evidence_read on public.audit_evidence for select
using(auth.role()='authenticated');
drop policy if exists audit_evidence_write on public.audit_evidence;
create policy audit_evidence_write on public.audit_evidence for all
using(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'))
with check(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
grant select,insert,update on public.audit_evidence to authenticated;

-- 7) CONTROL DE INDEPENDENCIA
create or replace function public.validate_auditor_independence()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
declare v_owner uuid;
begin
  v_owner:=new.process_owner_user_id;

  if v_owner is null and new.process_id is not null then
    select owner_user_id into v_owner
    from public.quality_processes
    where id=new.process_id;
    new.process_owner_user_id:=v_owner;
  end if;

  if v_owner is not null and new.lead_auditor_id=v_owner then
    raise exception 'Independencia de auditoría: el auditor líder no puede ser propietario del proceso auditado';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_auditor_independence on public.internal_audits;
create trigger trg_validate_auditor_independence
before insert or update of lead_auditor_id,process_id,process_owner_user_id
on public.internal_audits
for each row execute function public.validate_auditor_independence();

-- 8) CONVERTIR HALLAZGO EN NC
create or replace function public.audit_finding_to_nonconformity(
  p_finding_id uuid,
  p_owner_user_id uuid,
  p_due_date date
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_f public.audit_findings%rowtype;
  v_a public.internal_audits%rowtype;
  v_nc uuid;
  v_code text;
begin
  if not (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) then
    raise exception 'Rol no autorizado';
  end if;

  select * into v_f from public.audit_findings where id=p_finding_id for update;
  if v_f.id is null then raise exception 'Hallazgo no encontrado'; end if;
  if v_f.finding_type<>'NO_CONFORMIDAD' then
    raise exception 'Solo hallazgos NO_CONFORMIDAD pueden generar NC';
  end if;
  if v_f.nonconformity_id is not null then return v_f.nonconformity_id; end if;

  select * into v_a from public.internal_audits where id=v_f.audit_id;

  v_code:='NC-AUD-'||to_char(current_date,'YYYYMMDD')||'-'||upper(substr(md5(random()::text),1,5));

  insert into public.nonconformities(
    code,branch_id,process_id,description,status,owner_user_id,due_date
  ) values(
    v_code,v_a.branch_id,v_a.process_id,
    concat(v_f.title,': ',v_f.description),
    'ABIERTA',p_owner_user_id,p_due_date
  )
  returning id into v_nc;

  update public.audit_findings
  set nonconformity_id=v_nc,status='EN_TRATAMIENTO'
  where id=v_f.id;

  perform public.log_audit_event(
    'AUDITORIA','CREATE_NC',v_a.branch_id,'audit_findings',v_f.id,v_f.finding_code,
    null,jsonb_build_object('nonconformity_id',v_nc,'nc_code',v_code),null
  );

  return v_nc;
end;
$$;

grant execute on function public.audit_finding_to_nonconformity(uuid,uuid,date) to authenticated;

-- 9) CREAR CAPA DESDE NC VINCULADA
create or replace function public.audit_finding_create_capa(
  p_finding_id uuid,
  p_action_plan text,
  p_owner_user_id uuid,
  p_due_date date
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_f public.audit_findings%rowtype;
  v_capa uuid;
  v_code text;
begin
  if not (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) then
    raise exception 'Rol no autorizado';
  end if;

  select * into v_f from public.audit_findings where id=p_finding_id for update;
  if v_f.id is null then raise exception 'Hallazgo no encontrado'; end if;
  if v_f.nonconformity_id is null then
    raise exception 'El hallazgo debe tener una NC vinculada antes de crear CAPA';
  end if;
  if v_f.capa_id is not null then return v_f.capa_id; end if;
  if trim(coalesce(p_action_plan,''))='' then raise exception 'Plan de acción obligatorio'; end if;

  v_code:='CAPA-AUD-'||to_char(current_date,'YYYYMMDD')||'-'||upper(substr(md5(random()::text),1,5));

  insert into public.capa(
    code,nonconformity_id,problem,action_plan,owner_user_id,due_date,status
  ) values(
    v_code,v_f.nonconformity_id,
    concat(v_f.title,': ',v_f.description),
    p_action_plan,p_owner_user_id,p_due_date,'ABIERTA'
  )
  returning id into v_capa;

  update public.audit_findings
  set capa_id=v_capa,status='EN_TRATAMIENTO'
  where id=v_f.id;

  return v_capa;
end;
$$;

grant execute on function public.audit_finding_create_capa(uuid,text,uuid,date) to authenticated;

-- 10) VISTAS GERENCIALES
create or replace view public.vw_internal_audit_portfolio as
select
  a.id,a.audit_code,a.program_id,a.branch_id,a.process_id,a.audit_type,a.title,
  a.lead_auditor_id,a.process_owner_user_id,a.planned_date,a.status,a.overall_result,
  count(f.id) findings_count,
  count(f.id) filter(where f.finding_type='NO_CONFORMIDAD') nc_findings,
  count(f.id) filter(where f.finding_type='OBSERVACION') observations,
  count(f.id) filter(where f.status not in ('CERRADO','CANCELADO')) open_findings,
  count(f.id) filter(where f.due_date<current_date and f.status not in ('CERRADO','CANCELADO')) overdue_findings
from public.internal_audits a
left join public.audit_findings f on f.audit_id=a.id
group by a.id;

grant select on public.vw_internal_audit_portfolio to authenticated;

create or replace view public.vw_audit_program_summary as
select
  p.id,p.program_code,p.program_year,p.title,p.status,
  count(a.id) audits_total,
  count(a.id) filter(where a.status='CERRADA') audits_closed,
  count(a.id) filter(where a.planned_date<current_date and a.status='PLANIFICADA') audits_overdue,
  count(f.id) filter(where f.finding_type='NO_CONFORMIDAD') nc_findings,
  count(f.id) filter(where f.status not in ('CERRADO','CANCELADO')) open_findings
from public.audit_programs p
left join public.internal_audits a on a.program_id=p.id
left join public.audit_findings f on f.audit_id=a.id
group by p.id;

grant select on public.vw_audit_program_summary to authenticated;

create or replace view public.vw_audit_findings_open as
select
  f.id,f.finding_code,f.audit_id,a.audit_code,a.branch_id,a.process_id,
  f.finding_type,f.severity,f.title,f.description,f.evidence_summary,
  f.nonconformity_id,f.capa_id,f.status,f.due_date,
  (current_date-f.created_at::date) age_days,
  case when f.due_date<current_date and f.status not in ('CERRADO','CANCELADO') then true else false end overdue
from public.audit_findings f
join public.internal_audits a on a.id=f.audit_id
where f.status not in ('CERRADO','CANCELADO');

grant select on public.vw_audit_findings_open to authenticated;

-- 11) PERMISO
insert into public.app_permissions(permission_code,module,description,risk_level) values
('INTERNAL_AUDIT_VIEW','AUDIT','Ver auditorías internas','SENSIBLE'),
('INTERNAL_AUDIT_WRITE','AUDIT','Planificar y ejecutar auditorías internas','CRITICO')
on conflict(permission_code) do update set
 module=excluded.module,description=excluded.description,risk_level=excluded.risk_level,active=true;

insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p
on p.permission_code in ('INTERNAL_AUDIT_VIEW','INTERNAL_AUDIT_WRITE')
where r.code in ('ADMIN','CALIDAD','GERENCIA_OPERATIVA')
on conflict do nothing;

insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p
on p.permission_code='INTERNAL_AUDIT_VIEW'
where r.code='GERENCIA_GENERAL'
on conflict do nothing;

-- 12) MIGRACIÓN
insert into public.app_migrations(
  migration_code,version,description,applied_by
)
values(
  '33_INTERNAL_AUDITS_v0_33',
  '0.33.0',
  'Programa anual de auditoría, hallazgos, evidencia, NC y CAPA',
  auth.uid()
)
on conflict(migration_code) do update set
  version=excluded.version,
  description=excluded.description,
  applied_at=now(),
  applied_by=auth.uid();

commit;
