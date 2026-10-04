-- ============================================================
-- HemoCura v0.26.0
-- Centro de Mando + Cierre Diario + Gestión por Excepciones
-- Requiere v0.25.0
-- ============================================================
begin;
create extension if not exists pgcrypto;

-- 1) CIERRE OPERATIVO DIARIO
create table if not exists public.daily_operational_closes (
  id uuid primary key default gen_random_uuid(),
  close_date date not null,
  branch_id uuid not null references public.branches(id),
  status text not null default 'BORRADOR'
    check(status in ('BORRADOR','EN_REVISION','CERRADO','REABIERTO')),
  donors_count integer not null default 0,
  effective_donations integer not null default 0,
  screened_units integer not null default 0,
  reactive_results integer not null default 0,
  released_units integer not null default 0,
  produced_units numeric not null default 0,
  available_units integer not null default 0,
  dispatched_units numeric not null default 0,
  invoiced_units numeric not null default 0,
  invoiced_amount numeric not null default 0,
  open_quality_actions integer not null default 0,
  critical_alerts integer not null default 0,
  notes text,
  closed_by uuid references public.profiles(id),
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  unique(close_date,branch_id)
);

alter table public.daily_operational_closes enable row level security;
drop policy if exists daily_operational_closes_access on public.daily_operational_closes;
create policy daily_operational_closes_access on public.daily_operational_closes for all
using(public.can_access_branch(branch_id))
with check(public.can_access_branch(branch_id));
grant select,insert,update on public.daily_operational_closes to authenticated;

-- 2) EXCEPCIONES OPERATIVAS
create table if not exists public.operational_exceptions (
  id uuid primary key default gen_random_uuid(),
  exception_code text not null unique,
  exception_date date not null default current_date,
  branch_id uuid references public.branches(id),
  domain text not null check(domain in ('DONANTES','TAMIZAJE','PRODUCCION','INVENTARIO','DESPACHO','VENTAS','SGC','COMPLIANCE','PROYECTO')),
  severity text not null check(severity in ('BAJA','MEDIA','ALTA','CRITICA')),
  source_type text,
  source_id uuid,
  source_reference text,
  title text not null,
  description text not null,
  owner_user_id uuid references public.profiles(id),
  due_date date,
  status text not null default 'ABIERTA'
    check(status in ('ABIERTA','EN_TRATAMIENTO','RESUELTA','CERRADA','CANCELADA')),
  resolution text,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.operational_exceptions enable row level security;
drop policy if exists operational_exceptions_read on public.operational_exceptions;
create policy operational_exceptions_read on public.operational_exceptions for select
using(branch_id is null or public.can_access_branch(branch_id));
drop policy if exists operational_exceptions_write on public.operational_exceptions;
create policy operational_exceptions_write on public.operational_exceptions for all
using(
  branch_id is null or public.can_access_branch(branch_id)
)
with check(
  branch_id is null or public.can_access_branch(branch_id)
);
grant select,insert,update on public.operational_exceptions to authenticated;

-- 3) PLAN DE ACCIÓN GERENCIAL
create table if not exists public.management_actions (
  id uuid primary key default gen_random_uuid(),
  action_code text not null unique,
  branch_id uuid references public.branches(id),
  action_date date not null default current_date,
  source_exception_id uuid references public.operational_exceptions(id),
  source_project_id uuid references public.projects(id),
  title text not null,
  objective text,
  owner_user_id uuid references public.profiles(id),
  due_date date,
  priority text not null default 'MEDIA'
    check(priority in ('BAJA','MEDIA','ALTA','CRITICA')),
  status text not null default 'PENDIENTE'
    check(status in ('PENDIENTE','EN_CURSO','BLOQUEADA','COMPLETADA','CANCELADA')),
  progress_pct numeric not null default 0 check(progress_pct between 0 and 100),
  evidence_reference text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.management_actions enable row level security;
drop policy if exists management_actions_read on public.management_actions;
create policy management_actions_read on public.management_actions for select
using(auth.role()='authenticated');
drop policy if exists management_actions_write on public.management_actions;
create policy management_actions_write on public.management_actions for all
using(
  public.has_role('ADMIN') or
  public.has_role('GERENCIA_OPERATIVA') or
  public.has_role('CALIDAD')
)
with check(
  public.has_role('ADMIN') or
  public.has_role('GERENCIA_OPERATIVA') or
  public.has_role('CALIDAD')
);
grant select,insert,update on public.management_actions to authenticated;

-- 4) RESUMEN DIARIO POR SUCURSAL
create or replace view public.vw_daily_branch_operations as
select
  b.id branch_id,
  b.name branch_name,
  current_date operation_date,
  coalesce(d.donors,0) donors,
  coalesce(d.effective,0) effective_donations,
  coalesce(s.screened,0) screened_units,
  coalesce(s.reactive,0) reactive_results,
  coalesce(r.released,0) released_units,
  coalesce(p.produced,0) produced_units,
  coalesce(i.available,0) available_units,
  coalesce(v.dispatched,0) dispatched_units,
  coalesce(v.invoiced_units,0) invoiced_units,
  coalesce(v.invoiced_amount,0) invoiced_amount,
  coalesce(q.open_actions,0) open_quality_actions,
  coalesce(a.critical_alerts,0) critical_alerts
from public.branches b
left join (
  select branch_id,count(*) donors,count(*) filter(where effective_donation) effective
  from public.donors where registration_date=current_date group by branch_id
) d on d.branch_id=b.id
left join (
  select branch_id,count(distinct source_unit_code) screened,
         count(*) filter(where result='REACTIVO') reactive
  from public.screening_tests where screening_date=current_date group by branch_id
) s on s.branch_id=b.id
left join (
  select branch_id,count(distinct source_unit_code) released
  from public.unit_release_reviews
  where review_date::date=current_date and decision='APTO'
  group by branch_id
) r on r.branch_id=b.id
left join (
  select branch_id,sum(quantity) produced
  from public.production_batches where production_date=current_date group by branch_id
) p on p.branch_id=b.id
left join (
  select branch_id,count(*) available
  from public.blood_inventory_units
  where inventory_status='DISPONIBLE' and screening_status='APTO'
  group by branch_id
) i on i.branch_id=b.id
left join (
  select s.branch_id,
         sum(l.quantity) dispatched,
         sum(l.quantity) filter(where s.status in ('FACTURADA','COBRADA')) invoiced_units,
         sum(s.total_amount) invoiced_amount
  from public.operational_sales s
  join public.operational_sale_lines l on l.sale_id=s.id
  where s.sale_date=current_date and s.status<>'ANULADA'
  group by s.branch_id
) v on v.branch_id=b.id
left join (
  select branch_id,count(*) open_actions
  from public.vw_qms_open_actions
  group by branch_id
) q on q.branch_id=b.id
left join (
  select branch_id,count(*) critical_alerts
  from public.vw_blood_flow_alerts
  where severity='ALTA'
  group by branch_id
) a on a.branch_id=b.id
where b.active;

grant select on public.vw_daily_branch_operations to authenticated;

-- 5) CONCILIACIÓN DEL CIERRE
create or replace view public.vw_daily_close_reconciliation as
select
  o.*,
  c.id close_id,
  c.status close_status,
  c.donors_count close_donors,
  c.screened_units close_screened,
  c.produced_units close_produced,
  c.dispatched_units close_dispatched,
  c.invoiced_amount close_invoiced_amount,
  (coalesce(c.donors_count,0)-o.donors) donors_difference,
  (coalesce(c.screened_units,0)-o.screened_units) screening_difference,
  (coalesce(c.produced_units,0)-o.produced_units) production_difference,
  (coalesce(c.dispatched_units,0)-o.dispatched_units) dispatch_difference,
  (coalesce(c.invoiced_amount,0)-o.invoiced_amount) invoiced_difference
from public.vw_daily_branch_operations o
left join public.daily_operational_closes c
  on c.close_date=o.operation_date and c.branch_id=o.branch_id;

grant select on public.vw_daily_close_reconciliation to authenticated;

-- 6) PROCEDIMIENTO DE CAPTURA DE CIERRE
create or replace function public.capture_daily_operational_close(
  p_branch_id uuid,
  p_notes text default null
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  v public.vw_daily_branch_operations%rowtype;
  v_id uuid;
begin
  if not public.can_access_branch(p_branch_id) then
    raise exception 'Sin acceso a la sucursal';
  end if;

  select * into v
  from public.vw_daily_branch_operations
  where branch_id=p_branch_id;

  if v.branch_id is null then
    raise exception 'Sucursal no encontrada';
  end if;

  insert into public.daily_operational_closes(
    close_date,branch_id,status,
    donors_count,effective_donations,screened_units,reactive_results,released_units,
    produced_units,available_units,dispatched_units,invoiced_units,invoiced_amount,
    open_quality_actions,critical_alerts,notes,closed_by,closed_at
  ) values(
    current_date,p_branch_id,'CERRADO',
    v.donors,v.effective_donations,v.screened_units,v.reactive_results,v.released_units,
    v.produced_units,v.available_units,v.dispatched_units,v.invoiced_units,v.invoiced_amount,
    v.open_quality_actions,v.critical_alerts,p_notes,auth.uid(),now()
  )
  on conflict(close_date,branch_id) do update set
    status='CERRADO',
    donors_count=excluded.donors_count,
    effective_donations=excluded.effective_donations,
    screened_units=excluded.screened_units,
    reactive_results=excluded.reactive_results,
    released_units=excluded.released_units,
    produced_units=excluded.produced_units,
    available_units=excluded.available_units,
    dispatched_units=excluded.dispatched_units,
    invoiced_units=excluded.invoiced_units,
    invoiced_amount=excluded.invoiced_amount,
    open_quality_actions=excluded.open_quality_actions,
    critical_alerts=excluded.critical_alerts,
    notes=excluded.notes,
    closed_by=excluded.closed_by,
    closed_at=excluded.closed_at
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.capture_daily_operational_close(uuid,text) to authenticated;

-- 7) SCORE GERENCIAL EXPLICABLE
create or replace view public.vw_management_scorecard as
with ops as (
  select * from public.vw_daily_branch_operations
),
supply as (
  select
    branch_id,
    count(*) filter(where stock_status='ROJO') red_stock,
    count(*) filter(where stock_status='AMARILLO') yellow_stock
  from public.vw_blood_supply_plan
  group by branch_id
),
ex as (
  select
    branch_id,
    count(*) filter(where status in ('ABIERTA','EN_TRATAMIENTO')) open_exceptions,
    count(*) filter(where severity='CRITICA' and status in ('ABIERTA','EN_TRATAMIENTO')) critical_exceptions
  from public.operational_exceptions
  group by branch_id
)
select
  o.branch_id,o.branch_name,
  o.donors,o.effective_donations,o.screened_units,o.available_units,o.dispatched_units,o.invoiced_amount,
  o.open_quality_actions,o.critical_alerts,
  coalesce(s.red_stock,0) red_stock,
  coalesce(s.yellow_stock,0) yellow_stock,
  coalesce(e.open_exceptions,0) open_exceptions,
  coalesce(e.critical_exceptions,0) critical_exceptions,
  greatest(
    0,
    100
    - (coalesce(s.red_stock,0)*10)
    - (coalesce(o.critical_alerts,0)*8)
    - (coalesce(e.critical_exceptions,0)*15)
    - (least(coalesce(o.open_quality_actions,0),10)*3)
  ) management_score,
  case
    when greatest(
      0,
      100
      - (coalesce(s.red_stock,0)*10)
      - (coalesce(o.critical_alerts,0)*8)
      - (coalesce(e.critical_exceptions,0)*15)
      - (least(coalesce(o.open_quality_actions,0),10)*3)
    ) >= 85 then 'VERDE'
    when greatest(
      0,
      100
      - (coalesce(s.red_stock,0)*10)
      - (coalesce(o.critical_alerts,0)*8)
      - (coalesce(e.critical_exceptions,0)*15)
      - (least(coalesce(o.open_quality_actions,0),10)*3)
    ) >= 70 then 'AMARILLO'
    else 'ROJO'
  end management_status
from ops o
left join supply s on s.branch_id=o.branch_id
left join ex e on e.branch_id=o.branch_id;

grant select on public.vw_management_scorecard to authenticated;

-- 8) PORTAFOLIO DE ACCIONES ABIERTAS
create or replace view public.vw_management_action_portfolio as
select
  a.id,a.action_code,a.branch_id,a.action_date,a.title,a.priority,a.status,a.progress_pct,a.due_date,
  case
    when a.status not in ('COMPLETADA','CANCELADA') and a.due_date<current_date then true
    else false
  end overdue,
  e.exception_code,
  p.project_code
from public.management_actions a
left join public.operational_exceptions e on e.id=a.source_exception_id
left join public.projects p on p.id=a.source_project_id
order by
  case a.priority when 'CRITICA' then 1 when 'ALTA' then 2 when 'MEDIA' then 3 else 4 end,
  a.due_date nulls last;

grant select on public.vw_management_action_portfolio to authenticated;

commit;
