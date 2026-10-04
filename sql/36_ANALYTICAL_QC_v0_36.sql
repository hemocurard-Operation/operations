-- ============================================================
-- HemoCura v0.36.0
-- Control de calidad analítico + verificación + EQA/PT
-- Requiere v0.35.0
-- ============================================================
begin;
create extension if not exists pgcrypto;

-- 1) MAESTRO DE MÉTODOS
create table if not exists public.lab_methods (
  id uuid primary key default gen_random_uuid(),
  method_code text not null unique,
  test_name text not null,
  discipline text,
  principle text,
  branch_id uuid references public.branches(id),
  equipment_id uuid references public.lab_equipment(id),
  reagent_code text,
  manufacturer_method text,
  status text not null default 'EN_VERIFICACION'
    check(status in ('EN_VERIFICACION','APROBADO','SUSPENDIDO','RETIRADO')),
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  review_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.lab_methods enable row level security;
drop policy if exists lab_methods_read on public.lab_methods;
create policy lab_methods_read on public.lab_methods for select
using(branch_id is null or public.can_access_branch(branch_id));
drop policy if exists lab_methods_write on public.lab_methods;
create policy lab_methods_write on public.lab_methods for all
using(
  (branch_id is null or public.can_access_branch(branch_id))
  and (
    public.has_role('ADMIN') or public.has_role('CALIDAD') or
    public.has_role('LABORATORIO') or public.has_role('GERENCIA_OPERATIVA')
  )
)
with check(
  (branch_id is null or public.can_access_branch(branch_id))
  and (
    public.has_role('ADMIN') or public.has_role('CALIDAD') or
    public.has_role('LABORATORIO') or public.has_role('GERENCIA_OPERATIVA')
  )
);
grant select,insert,update on public.lab_methods to authenticated;

-- 2) VERIFICACIÓN / VALIDACIÓN DE MÉTODOS
create table if not exists public.method_verifications (
  id uuid primary key default gen_random_uuid(),
  verification_code text not null unique,
  method_id uuid not null references public.lab_methods(id) on delete cascade,
  verification_type text not null
    check(verification_type in ('VERIFICACION','VALIDACION','REVERIFICACION')),
  start_date date not null,
  completion_date date,
  parameters_evaluated text not null,
  acceptance_criteria text not null,
  result_summary text,
  conclusion text,
  result text check(result in ('ACEPTADO','NO_ACEPTADO','CONDICIONAL') or result is null),
  responsible_user_id uuid references public.profiles(id),
  reviewer_user_id uuid references public.profiles(id),
  evidence_reference text,
  status text not null default 'EN_CURSO'
    check(status in ('PLANIFICADO','EN_CURSO','REVISION','CERRADO','CANCELADO')),
  created_at timestamptz not null default now()
);

alter table public.method_verifications enable row level security;
drop policy if exists method_verifications_read on public.method_verifications;
create policy method_verifications_read on public.method_verifications for select using(auth.role()='authenticated');
drop policy if exists method_verifications_write on public.method_verifications;
create policy method_verifications_write on public.method_verifications for all
using(
  public.has_role('ADMIN') or public.has_role('CALIDAD') or
  public.has_role('LABORATORIO') or public.has_role('GERENCIA_OPERATIVA')
)
with check(
  public.has_role('ADMIN') or public.has_role('CALIDAD') or
  public.has_role('LABORATORIO') or public.has_role('GERENCIA_OPERATIVA')
);
grant select,insert,update on public.method_verifications to authenticated;

-- 3) PLAN DE CONTROL INTERNO
create table if not exists public.iqc_plans (
  id uuid primary key default gen_random_uuid(),
  plan_code text not null unique,
  method_id uuid not null references public.lab_methods(id) on delete cascade,
  control_name text not null,
  control_level text,
  control_lot text,
  target_mean numeric,
  target_sd numeric,
  lower_limit numeric,
  upper_limit numeric,
  frequency text,
  active boolean not null default true,
  effective_date date not null default current_date,
  review_date date,
  notes text
);

alter table public.iqc_plans enable row level security;
drop policy if exists iqc_plans_read on public.iqc_plans;
create policy iqc_plans_read on public.iqc_plans for select using(auth.role()='authenticated');
drop policy if exists iqc_plans_write on public.iqc_plans;
create policy iqc_plans_write on public.iqc_plans for all
using(
  public.has_role('ADMIN') or public.has_role('CALIDAD') or
  public.has_role('LABORATORIO') or public.has_role('GERENCIA_OPERATIVA')
)
with check(
  public.has_role('ADMIN') or public.has_role('CALIDAD') or
  public.has_role('LABORATORIO') or public.has_role('GERENCIA_OPERATIVA')
);
grant select,insert,update on public.iqc_plans to authenticated;

-- 4) RESULTADOS IQC
create table if not exists public.iqc_results (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.iqc_plans(id) on delete cascade,
  run_time timestamptz not null default now(),
  value numeric not null,
  operator_user_id uuid references public.profiles(id),
  equipment_id uuid references public.lab_equipment(id),
  reagent_lot_id uuid references public.reagent_lots(id),
  result_status text not null default 'PENDIENTE'
    check(result_status in ('PENDIENTE','ACEPTADO','FUERA_CONTROL','INVESTIGACION','CERRADO')),
  rule_flags text[],
  comment text,
  created_at timestamptz not null default now()
);

alter table public.iqc_results enable row level security;
drop policy if exists iqc_results_read on public.iqc_results;
create policy iqc_results_read on public.iqc_results for select using(auth.role()='authenticated');
drop policy if exists iqc_results_write on public.iqc_results;
create policy iqc_results_write on public.iqc_results for all
using(
  public.has_role('ADMIN') or public.has_role('CALIDAD') or
  public.has_role('LABORATORIO') or public.has_role('GERENCIA_OPERATIVA')
)
with check(
  public.has_role('ADMIN') or public.has_role('CALIDAD') or
  public.has_role('LABORATORIO') or public.has_role('GERENCIA_OPERATIVA')
);
grant select,insert,update on public.iqc_results to authenticated;

-- 5) CLASIFICACIÓN EXPLICABLE DEL CONTROL
create or replace function public.evaluate_iqc_result()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
declare
  v public.iqc_plans%rowtype;
  z numeric;
  flags text[] := '{}';
begin
  select * into v from public.iqc_plans where id=new.plan_id;
  if v.id is null then raise exception 'Plan IQC no encontrado'; end if;

  -- Límites directos configurados por el laboratorio.
  if v.lower_limit is not null and new.value<v.lower_limit then
    flags:=array_append(flags,'BELOW_LIMIT');
  end if;
  if v.upper_limit is not null and new.value>v.upper_limit then
    flags:=array_append(flags,'ABOVE_LIMIT');
  end if;

  -- Soporte estadístico simple y transparente.
  if v.target_mean is not null and v.target_sd is not null and v.target_sd>0 then
    z:=(new.value-v.target_mean)/v.target_sd;
    if abs(z)>=3 then flags:=array_append(flags,'ABS_Z_GE_3'); end if;
    if abs(z)>=2 and abs(z)<3 then flags:=array_append(flags,'ABS_Z_GE_2'); end if;
  end if;

  new.rule_flags:=flags;

  if array_length(flags,1) is null then
    new.result_status:='ACEPTADO';
  else
    new.result_status:='FUERA_CONTROL';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_evaluate_iqc_result on public.iqc_results;
create trigger trg_evaluate_iqc_result
before insert or update of value,plan_id
on public.iqc_results
for each row execute function public.evaluate_iqc_result();

-- 6) DESVIACIONES DE QC
create table if not exists public.qc_deviations (
  id uuid primary key default gen_random_uuid(),
  deviation_code text not null unique,
  iqc_result_id uuid references public.iqc_results(id),
  method_id uuid references public.lab_methods(id),
  branch_id uuid references public.branches(id),
  opened_at timestamptz not null default now(),
  severity text not null default 'MEDIA'
    check(severity in ('BAJA','MEDIA','ALTA','CRITICA')),
  description text not null,
  immediate_action text,
  investigation text,
  root_cause text,
  disposition text,
  nonconformity_id uuid references public.nonconformities(id),
  capa_id uuid references public.capa(id),
  owner_user_id uuid references public.profiles(id),
  status text not null default 'ABIERTA'
    check(status in ('ABIERTA','INVESTIGACION','ACCION','VERIFICACION','CERRADA','CANCELADA')),
  due_date date,
  closed_at timestamptz
);

alter table public.qc_deviations enable row level security;
drop policy if exists qc_deviations_read on public.qc_deviations;
create policy qc_deviations_read on public.qc_deviations for select
using(branch_id is null or public.can_access_branch(branch_id));
drop policy if exists qc_deviations_write on public.qc_deviations;
create policy qc_deviations_write on public.qc_deviations for all
using(
  (branch_id is null or public.can_access_branch(branch_id))
  and (
    public.has_role('ADMIN') or public.has_role('CALIDAD') or
    public.has_role('LABORATORIO') or public.has_role('GERENCIA_OPERATIVA')
  )
)
with check(
  (branch_id is null or public.can_access_branch(branch_id))
  and (
    public.has_role('ADMIN') or public.has_role('CALIDAD') or
    public.has_role('LABORATORIO') or public.has_role('GERENCIA_OPERATIVA')
  )
);
grant select,insert,update on public.qc_deviations to authenticated;

-- 7) PROGRAMAS EQA / PT
create table if not exists public.eqa_programs (
  id uuid primary key default gen_random_uuid(),
  program_code text not null unique,
  provider text not null,
  program_name text not null,
  discipline text,
  frequency text,
  active boolean not null default true,
  notes text
);

alter table public.eqa_programs enable row level security;
drop policy if exists eqa_programs_read on public.eqa_programs;
create policy eqa_programs_read on public.eqa_programs for select using(auth.role()='authenticated');
drop policy if exists eqa_programs_write on public.eqa_programs;
create policy eqa_programs_write on public.eqa_programs for all
using(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'))
with check(public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
grant select,insert,update on public.eqa_programs to authenticated;

-- 8) EVENTOS EQA / PT
create table if not exists public.eqa_events (
  id uuid primary key default gen_random_uuid(),
  event_code text not null unique,
  program_id uuid not null references public.eqa_programs(id),
  method_id uuid references public.lab_methods(id),
  branch_id uuid references public.branches(id),
  cycle text,
  sample_received_date date,
  due_date date,
  submitted_date date,
  provider_result_date date,
  result text check(result in ('SATISFACTORIO','NO_SATISFACTORIO','PENDIENTE','NO_EVALUABLE') or result is null),
  score numeric,
  evidence_reference text,
  investigation_required boolean not null default false,
  investigation_summary text,
  nonconformity_id uuid references public.nonconformities(id),
  capa_id uuid references public.capa(id),
  status text not null default 'PENDIENTE'
    check(status in ('PENDIENTE','EN_PROCESO','ENVIADO','EVALUADO','CERRADO','CANCELADO')),
  created_at timestamptz not null default now()
);

alter table public.eqa_events enable row level security;
drop policy if exists eqa_events_read on public.eqa_events;
create policy eqa_events_read on public.eqa_events for select
using(branch_id is null or public.can_access_branch(branch_id));
drop policy if exists eqa_events_write on public.eqa_events;
create policy eqa_events_write on public.eqa_events for all
using(
  (branch_id is null or public.can_access_branch(branch_id))
  and (
    public.has_role('ADMIN') or public.has_role('CALIDAD') or
    public.has_role('LABORATORIO') or public.has_role('GERENCIA_OPERATIVA')
  )
)
with check(
  (branch_id is null or public.can_access_branch(branch_id))
  and (
    public.has_role('ADMIN') or public.has_role('CALIDAD') or
    public.has_role('LABORATORIO') or public.has_role('GERENCIA_OPERATIVA')
  )
);
grant select,insert,update on public.eqa_events to authenticated;

-- 9) VISTAS DE ALERTA
create or replace view public.vw_iqc_alerts as
select
  r.id result_id,r.run_time,r.value,r.result_status,r.rule_flags,
  p.plan_code,p.control_name,p.control_level,
  m.id method_id,m.method_code,m.test_name,m.branch_id,
  case
    when r.result_status='FUERA_CONTROL' then 'ALTA'
    when r.result_status='INVESTIGACION' then 'ALTA'
    else 'MEDIA'
  end severity,
  concat('QC ',p.plan_code,' · ',coalesce(array_to_string(r.rule_flags,', '),'sin bandera')) message
from public.iqc_results r
join public.iqc_plans p on p.id=r.plan_id
join public.lab_methods m on m.id=p.method_id
where r.result_status in ('FUERA_CONTROL','INVESTIGACION');

grant select on public.vw_iqc_alerts to authenticated;

create or replace view public.vw_eqa_alerts as
select
  e.id event_id,e.event_code,e.branch_id,e.cycle,e.due_date,e.result,e.status,
  p.program_code,p.program_name,p.provider,
  case
    when e.result='NO_SATISFACTORIO' then 'CRITICA'
    when e.due_date<current_date and e.status not in ('EVALUADO','CERRADO','CANCELADO') then 'ALTA'
    when e.due_date<=current_date+7 and e.status not in ('EVALUADO','CERRADO','CANCELADO') then 'MEDIA'
    else 'BAJA'
  end severity,
  case
    when e.result='NO_SATISFACTORIO' then 'Resultado EQA/PT no satisfactorio'
    when e.due_date<current_date then 'Evento EQA/PT vencido'
    else 'Evento EQA/PT próximo a vencer'
  end message
from public.eqa_events e
join public.eqa_programs p on p.id=e.program_id
where e.result='NO_SATISFACTORIO'
   or (
      e.due_date is not null
      and e.due_date<=current_date+7
      and e.status not in ('EVALUADO','CERRADO','CANCELADO')
   );

grant select on public.vw_eqa_alerts to authenticated;

-- 10) RESUMEN GERENCIAL
create or replace view public.vw_analytical_quality_summary as
select
  (select count(*) from public.lab_methods where status='APROBADO') approved_methods,
  (select count(*) from public.method_verifications where status not in ('CERRADO','CANCELADO')) open_verifications,
  (select count(*) from public.iqc_results where result_status='FUERA_CONTROL' and run_time>=now()-interval '30 days') iqc_out_of_control_30d,
  (select count(*) from public.qc_deviations where status not in ('CERRADA','CANCELADA')) open_qc_deviations,
  (select count(*) from public.eqa_events where result='NO_SATISFACTORIO' and created_at>=now()-interval '365 days') eqa_unsatisfactory_12m,
  (select count(*) from public.vw_eqa_alerts) eqa_alerts;

grant select on public.vw_analytical_quality_summary to authenticated;

-- 11) VINCULAR AUDITORÍA
alter table public.audit_findings
  add column if not exists method_id uuid references public.lab_methods(id),
  add column if not exists iqc_result_id uuid references public.iqc_results(id),
  add column if not exists eqa_event_id uuid references public.eqa_events(id);

-- 12) PERMISOS
insert into public.app_permissions(permission_code,module,description,risk_level) values
('ANALYTICAL_QC_VIEW','ANALYTICAL_QC','Ver control de calidad analítico','SENSIBLE'),
('ANALYTICAL_QC_WRITE','ANALYTICAL_QC','Gestionar métodos, QC y EQA/PT','CRITICO')
on conflict(permission_code) do update set
 module=excluded.module,description=excluded.description,risk_level=excluded.risk_level,active=true;

insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p
on p.permission_code in ('ANALYTICAL_QC_VIEW','ANALYTICAL_QC_WRITE')
where r.code in ('ADMIN','CALIDAD','LABORATORIO','GERENCIA_OPERATIVA')
on conflict do nothing;

insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p
on p.permission_code='ANALYTICAL_QC_VIEW'
where r.code='GERENCIA_GENERAL'
on conflict do nothing;

-- 13) MIGRACIÓN
insert into public.app_migrations(
  migration_code,version,description,applied_by
)
values(
  '36_ANALYTICAL_QC_v0_36',
  '0.36.0',
  'Métodos, verificación, IQC, desviaciones y EQA/PT',
  auth.uid()
)
on conflict(migration_code) do update set
  version=excluded.version,
  description=excluded.description,
  applied_at=now(),
  applied_by=auth.uid();

commit;
