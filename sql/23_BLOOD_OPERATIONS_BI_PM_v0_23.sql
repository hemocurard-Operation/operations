-- ============================================================
-- HemoCura v0.23.0
-- Operaciones de sangre + Ventas/Salidas + Donantes + Tamizaje
-- BI + Gestión de Proyectos
-- Requiere v0.22.0 instalado
-- ============================================================

begin;
create extension if not exists pgcrypto;

-- 1) DONANTES
create table if not exists public.donors (
  id uuid primary key default gen_random_uuid(),
  donor_code text not null unique,
  branch_id uuid not null references public.branches(id),
  donor_type text not null check(donor_type in ('VOLUNTARIO','REPOSICION','DIRIGIDO')),
  abo text check(abo in ('A','B','AB','O') or abo is null),
  rh text check(rh in ('POSITIVO','NEGATIVO') or rh is null),
  status text not null default 'ACEPTADO' check(status in ('ACEPTADO','DIFERIDO')),
  deferral_reason text,
  effective_donation boolean not null default false,
  observations text,
  registration_date date not null default current_date,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

-- 2) DONACIONES / UNIDADES DE ORIGEN
create table if not exists public.donations (
  id uuid primary key default gen_random_uuid(),
  donation_code text not null unique,
  donor_id uuid not null references public.donors(id),
  branch_id uuid not null references public.branches(id),
  donation_date date not null default current_date,
  collection_effective boolean not null default true,
  collected_units numeric not null default 1 check(collected_units >= 0),
  source_unit_code text not null unique,
  status text not null default 'RECOLECTADA'
    check(status in ('RECOLECTADA','EN_TAMIZAJE','APTA','NO_APTA','PROCESADA','DESCARTADA')),
  observations text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

-- 3) TAMIZAJE
create table if not exists public.screening_tests (
  id uuid primary key default gen_random_uuid(),
  screening_code text not null unique,
  donation_id uuid references public.donations(id),
  source_unit_code text not null,
  branch_id uuid not null references public.branches(id),
  screening_date date not null default current_date,
  test_type text not null,
  result text not null check(result in ('NO_REACTIVO','REACTIVO','INDETERMINADO')),
  reagent text,
  reagent_lot text,
  reagent_expiry date,
  responsible text,
  status text not null default 'PENDIENTE'
    check(status in ('PENDIENTE','VALIDADO','REPETIR','CERRADO')),
  observations text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

-- 4) COMPONENTES PRODUCIDOS / INVENTARIO DE SANGRE
create table if not exists public.blood_inventory_units (
  id uuid primary key default gen_random_uuid(),
  unit_code text not null unique,
  source_unit_code text not null,
  donation_id uuid references public.donations(id),
  branch_id uuid not null references public.branches(id),
  product_id uuid references public.products(id),
  component_name text not null,
  abo text check(abo in ('A','B','AB','O') or abo is null),
  rh text check(rh in ('POSITIVO','NEGATIVO') or rh is null),
  quantity numeric not null default 1 check(quantity > 0),
  production_date date not null default current_date,
  expiry_date date,
  screening_status text not null default 'PENDIENTE'
    check(screening_status in ('PENDIENTE','APTO','NO_APTO','INDETERMINADO')),
  inventory_status text not null default 'CUARENTENA'
    check(inventory_status in ('CUARENTENA','DISPONIBLE','RESERVADA','DESPACHADA','DESCARTADA','VENCIDA')),
  reserved_for text,
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

-- 5) SALIDAS / VENTAS OPERATIVAS
create table if not exists public.operational_sales (
  id uuid primary key default gen_random_uuid(),
  sale_code text not null unique,
  sale_date date not null default current_date,
  branch_id uuid not null references public.branches(id),
  customer_name text not null,
  destination_center text,
  request_number text,
  patient_code text,
  invoice_number text,
  status text not null default 'DESPACHADA'
    check(status in ('PENDIENTE','DESPACHADA','FACTURADA','COBRADA','ANULADA')),
  payment_status text not null default 'PENDIENTE'
    check(payment_status in ('PENDIENTE','PARCIAL','COBRADA','NO_APLICA')),
  total_amount numeric not null default 0,
  collected_amount numeric not null default 0,
  dispatch_id uuid references public.dispatches(id),
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.operational_sale_lines (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.operational_sales(id) on delete cascade,
  blood_inventory_unit_id uuid references public.blood_inventory_units(id),
  product_id uuid references public.products(id),
  component_name text not null,
  abo text,
  rh text,
  quantity numeric not null default 1 check(quantity > 0),
  unit_price numeric not null default 0 check(unit_price >= 0),
  line_total numeric generated always as (quantity * unit_price) stored,
  created_at timestamptz not null default now()
);

-- 6) RESUMEN OPERATIVO DIARIO
create table if not exists public.daily_operational_register (
  id uuid primary key default gen_random_uuid(),
  operation_date date not null default current_date,
  branch_id uuid not null references public.branches(id),
  donors_registered integer not null default 0,
  donors_deferred integer not null default 0,
  units_collected integer not null default 0,
  units_screened integer not null default 0,
  units_reactive integer not null default 0,
  units_dispatched integer not null default 0,
  units_invoiced integer not null default 0,
  invoiced_amount numeric not null default 0,
  observations text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(operation_date, branch_id)
);

-- 7) PROJECT MANAGEMENT
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  project_code text not null unique,
  title text not null,
  domain text not null default 'OPERACIONES'
    check(domain in ('OPERACIONES','SGC','COMPLIANCE','TECNOLOGIA','CAPACITACION')),
  owner_user_id uuid references public.profiles(id),
  sponsor text,
  start_date date,
  target_date date,
  status text not null default 'PLANIFICADO'
    check(status in ('PLANIFICADO','EN_CURSO','EN_RIESGO','BLOQUEADO','COMPLETADO','CANCELADO')),
  progress_pct numeric not null default 0 check(progress_pct between 0 and 100),
  priority text not null default 'MEDIA' check(priority in ('BAJA','MEDIA','ALTA','CRITICA')),
  objective text,
  expected_result text,
  created_at timestamptz not null default now()
);

create table if not exists public.project_tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  task_code text,
  title text not null,
  responsible_user_id uuid references public.profiles(id),
  start_date date,
  due_date date,
  status text not null default 'PENDIENTE'
    check(status in ('PENDIENTE','EN_CURSO','BLOQUEADA','COMPLETADA','CANCELADA')),
  progress_pct numeric not null default 0 check(progress_pct between 0 and 100),
  dependency_task_id uuid references public.project_tasks(id),
  notes text,
  created_at timestamptz not null default now()
);

-- 8) RLS
alter table public.donors enable row level security;
alter table public.donations enable row level security;
alter table public.screening_tests enable row level security;
alter table public.blood_inventory_units enable row level security;
alter table public.operational_sales enable row level security;
alter table public.operational_sale_lines enable row level security;
alter table public.daily_operational_register enable row level security;
alter table public.projects enable row level security;
alter table public.project_tasks enable row level security;

do $$
declare t text;
begin
  foreach t in array array[
    'donors','donations','screening_tests','blood_inventory_units',
    'operational_sales','daily_operational_register'
  ]
  loop
    execute format('drop policy if exists %I_branch_access on public.%I', t, t);
  end loop;
end $$;

create policy donors_branch_access on public.donors for all
using(public.can_access_branch(branch_id))
with check(public.can_access_branch(branch_id));

create policy donations_branch_access on public.donations for all
using(public.can_access_branch(branch_id))
with check(public.can_access_branch(branch_id));

create policy screening_tests_branch_access on public.screening_tests for all
using(public.can_access_branch(branch_id))
with check(public.can_access_branch(branch_id));

create policy blood_inventory_units_branch_access on public.blood_inventory_units for all
using(public.can_access_branch(branch_id))
with check(public.can_access_branch(branch_id));

create policy operational_sales_branch_access on public.operational_sales for all
using(public.can_access_branch(branch_id))
with check(public.can_access_branch(branch_id));

create policy daily_operational_register_branch_access on public.daily_operational_register for all
using(public.can_access_branch(branch_id))
with check(public.can_access_branch(branch_id));

drop policy if exists operational_sale_lines_access on public.operational_sale_lines;
create policy operational_sale_lines_access on public.operational_sale_lines for all
using(exists(select 1 from public.operational_sales s where s.id=sale_id and public.can_access_branch(s.branch_id)))
with check(exists(select 1 from public.operational_sales s where s.id=sale_id and public.can_access_branch(s.branch_id)));

drop policy if exists projects_read on public.projects;
create policy projects_read on public.projects for select using(auth.role()='authenticated');
drop policy if exists projects_write on public.projects;
create policy projects_write on public.projects for all
using(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('CALIDAD'))
with check(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('CALIDAD'));

drop policy if exists project_tasks_read on public.project_tasks;
create policy project_tasks_read on public.project_tasks for select using(auth.role()='authenticated');
drop policy if exists project_tasks_write on public.project_tasks;
create policy project_tasks_write on public.project_tasks for all
using(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('CALIDAD'))
with check(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('CALIDAD'));

grant select,insert,update on
  public.donors, public.donations, public.screening_tests, public.blood_inventory_units,
  public.operational_sales, public.operational_sale_lines, public.daily_operational_register,
  public.projects, public.project_tasks
to authenticated;

-- 9) VISTAS BI
create or replace view public.vw_blood_inventory_available as
select
  branch_id, component_name, abo, rh,
  count(*) filter(where inventory_status='DISPONIBLE' and screening_status='APTO') available_units,
  count(*) filter(where inventory_status='CUARENTENA') quarantine_units,
  count(*) filter(where inventory_status='RESERVADA') reserved_units,
  min(expiry_date) filter(where inventory_status='DISPONIBLE' and screening_status='APTO') nearest_expiry
from public.blood_inventory_units
group by branch_id, component_name, abo, rh;

create or replace view public.vw_screening_summary as
select
  screening_date, branch_id, test_type,
  count(*) total_tests,
  count(*) filter(where result='NO_REACTIVO') non_reactive,
  count(*) filter(where result='REACTIVO') reactive,
  count(*) filter(where result='INDETERMINADO') indeterminate,
  round(100.0 * count(*) filter(where result='REACTIVO') / nullif(count(*),0),2) reactive_pct
from public.screening_tests
group by screening_date, branch_id, test_type;

create or replace view public.vw_donor_summary as
select
  registration_date, branch_id,
  count(*) total_donors,
  count(*) filter(where status='DIFERIDO') deferred_donors,
  count(*) filter(where effective_donation) effective_donations,
  round(100.0 * count(*) filter(where effective_donation) / nullif(count(*),0),2) effective_pct
from public.donors
group by registration_date, branch_id;

create or replace view public.vw_sales_operational_summary as
select
  sale_date, branch_id,
  count(*) sale_records,
  sum(total_amount) invoiced_value,
  sum(collected_amount) collected_value,
  sum(greatest(total_amount-collected_amount,0)) pending_value,
  count(*) filter(where status='DESPACHADA') dispatched_records,
  count(*) filter(where status='FACTURADA') invoiced_records,
  count(*) filter(where status='COBRADA') collected_records
from public.operational_sales
where status<>'ANULADA'
group by sale_date, branch_id;

create or replace view public.vw_bi_operations_today as
select
  b.id branch_id,
  b.name branch_name,
  coalesce(d.total_donors,0) donors,
  coalesce(d.effective_donations,0) effective_donations,
  coalesce(s.tests,0) screened_tests,
  coalesce(s.reactive,0) reactive_tests,
  coalesce(i.available,0) available_blood_units,
  coalesce(v.sales,0) sales_outflows,
  coalesce(v.invoiced,0) invoiced_amount
from public.branches b
left join (
  select branch_id, count(*) total_donors, count(*) filter(where effective_donation) effective_donations
  from public.donors where registration_date=current_date group by branch_id
) d on d.branch_id=b.id
left join (
  select branch_id, count(*) tests, count(*) filter(where result='REACTIVO') reactive
  from public.screening_tests where screening_date=current_date group by branch_id
) s on s.branch_id=b.id
left join (
  select branch_id, count(*) available
  from public.blood_inventory_units
  where inventory_status='DISPONIBLE' and screening_status='APTO'
  group by branch_id
) i on i.branch_id=b.id
left join (
  select branch_id, count(*) sales, sum(total_amount) invoiced
  from public.operational_sales
  where sale_date=current_date and status<>'ANULADA'
  group by branch_id
) v on v.branch_id=b.id
where b.active;

create or replace view public.vw_project_portfolio as
select
  p.id,p.project_code,p.title,p.domain,p.status,p.priority,p.progress_pct,p.start_date,p.target_date,
  count(t.id) tasks,
  count(t.id) filter(where t.status='COMPLETADA') completed_tasks,
  count(t.id) filter(where t.due_date < current_date and t.status not in ('COMPLETADA','CANCELADA')) overdue_tasks
from public.projects p
left join public.project_tasks t on t.project_id=p.id
group by p.id;

grant select on
  public.vw_blood_inventory_available,
  public.vw_screening_summary,
  public.vw_donor_summary,
  public.vw_sales_operational_summary,
  public.vw_bi_operations_today,
  public.vw_project_portfolio
to authenticated;

commit;
