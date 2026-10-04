-- ============================================================
-- HemoCura v0.25.0
-- Producción + Demanda + Cobertura + Donantes requeridos
-- Requiere v0.24.0
-- ============================================================
begin;
create extension if not exists pgcrypto;

-- 1) PARÁMETROS DE PLANIFICACIÓN POR SUCURSAL/COMPONENTE
create table if not exists public.blood_stock_targets (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  component_name text not null,
  abo text,
  rh text,
  min_units numeric not null default 0 check(min_units >= 0),
  target_units numeric not null default 0 check(target_units >= 0),
  max_units numeric not null default 0 check(max_units >= 0),
  safety_days numeric not null default 3 check(safety_days >= 0),
  planning_horizon_days integer not null default 7 check(planning_horizon_days between 1 and 90),
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  unique(branch_id,component_name,abo,rh)
);

alter table public.blood_stock_targets enable row level security;
drop policy if exists blood_stock_targets_read on public.blood_stock_targets;
create policy blood_stock_targets_read on public.blood_stock_targets for select
using(public.can_access_branch(branch_id));
drop policy if exists blood_stock_targets_write on public.blood_stock_targets;
create policy blood_stock_targets_write on public.blood_stock_targets for all
using(
  public.can_access_branch(branch_id) and
  (public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('INVENTARIO') or public.has_role('CALIDAD'))
)
with check(
  public.can_access_branch(branch_id) and
  (public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('INVENTARIO') or public.has_role('CALIDAD'))
);
grant select,insert,update on public.blood_stock_targets to authenticated;

-- 2) REGLAS DE RENDIMIENTO POR DONACIÓN
create table if not exists public.production_yield_rules (
  id uuid primary key default gen_random_uuid(),
  component_name text not null unique,
  avg_units_per_effective_donation numeric not null default 1 check(avg_units_per_effective_donation > 0),
  default_shelf_life_days integer check(default_shelf_life_days > 0),
  active boolean not null default true,
  validation_status text not null default 'REQUIERE_VALIDACION'
    check(validation_status in ('REQUIERE_VALIDACION','VALIDADO')),
  notes text,
  updated_at timestamptz not null default now()
);

alter table public.production_yield_rules enable row level security;
drop policy if exists production_yield_rules_read on public.production_yield_rules;
create policy production_yield_rules_read on public.production_yield_rules for select
using(auth.role()='authenticated');
drop policy if exists production_yield_rules_write on public.production_yield_rules;
create policy production_yield_rules_write on public.production_yield_rules for all
using(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('LABORATORIO') or public.has_role('CALIDAD'))
with check(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('LABORATORIO') or public.has_role('CALIDAD'));
grant select,insert,update on public.production_yield_rules to authenticated;

-- 3) PRODUCCIÓN REGISTRADA
create table if not exists public.production_batches (
  id uuid primary key default gen_random_uuid(),
  production_code text not null unique,
  branch_id uuid not null references public.branches(id),
  production_date date not null default current_date,
  source_unit_code text not null,
  component_name text not null,
  abo text,
  rh text,
  quantity numeric not null default 1 check(quantity > 0),
  expiry_date date,
  responsible text,
  status text not null default 'CUARENTENA'
    check(status in ('CUARENTENA','DISPONIBLE','RESERVADA','DESCARTADA')),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.production_batches enable row level security;
drop policy if exists production_batches_access on public.production_batches;
create policy production_batches_access on public.production_batches for all
using(public.can_access_branch(branch_id))
with check(public.can_access_branch(branch_id));
grant select,insert,update on public.production_batches to authenticated;

-- 4) DEMANDA HISTÓRICA 30/60/90
create or replace view public.vw_blood_demand_history as
with x as (
  select
    s.branch_id,
    l.component_name,
    l.abo,
    l.rh,
    s.sale_date,
    sum(l.quantity) qty
  from public.operational_sales s
  join public.operational_sale_lines l on l.sale_id=s.id
  where s.status<>'ANULADA'
    and s.sale_date>=current_date-89
  group by s.branch_id,l.component_name,l.abo,l.rh,s.sale_date
)
select
  branch_id,component_name,abo,rh,
  sum(qty) filter(where sale_date>=current_date-29) units_30d,
  sum(qty) filter(where sale_date>=current_date-59) units_60d,
  sum(qty) units_90d,
  round(coalesce(sum(qty) filter(where sale_date>=current_date-29),0)/30.0,3) avg_daily_30d,
  round(coalesce(sum(qty) filter(where sale_date>=current_date-59),0)/60.0,3) avg_daily_60d,
  round(coalesce(sum(qty),0)/90.0,3) avg_daily_90d
from x
group by branch_id,component_name,abo,rh;

grant select on public.vw_blood_demand_history to authenticated;

-- 5) COBERTURA Y NECESIDAD
create or replace view public.vw_blood_supply_plan as
with inv as (
  select
    branch_id,component_name,abo,rh,
    count(*) filter(where inventory_status='DISPONIBLE' and screening_status='APTO')::numeric available_units,
    count(*) filter(where inventory_status='RESERVADA')::numeric reserved_units,
    min(expiry_date) filter(where inventory_status='DISPONIBLE' and screening_status='APTO') nearest_expiry
  from public.blood_inventory_units
  group by branch_id,component_name,abo,rh
),
dem as (
  select * from public.vw_blood_demand_history
)
select
  t.branch_id,t.component_name,t.abo,t.rh,
  coalesce(i.available_units,0) available_units,
  coalesce(i.reserved_units,0) reserved_units,
  i.nearest_expiry,
  coalesce(d.avg_daily_30d,0) avg_daily_30d,
  coalesce(d.avg_daily_60d,0) avg_daily_60d,
  coalesce(d.avg_daily_90d,0) avg_daily_90d,
  t.min_units,t.target_units,t.max_units,t.safety_days,t.planning_horizon_days,
  case when coalesce(d.avg_daily_30d,0)>0
       then round(coalesce(i.available_units,0)/d.avg_daily_30d,1)
       else null end coverage_days,
  greatest(
    t.target_units + (coalesce(d.avg_daily_30d,0)*t.safety_days) - coalesce(i.available_units,0),
    0
  ) required_units,
  case
    when coalesce(i.available_units,0)<=t.min_units then 'ROJO'
    when coalesce(i.available_units,0)<t.target_units then 'AMARILLO'
    else 'VERDE'
  end stock_status
from public.blood_stock_targets t
left join inv i
  on i.branch_id=t.branch_id
 and i.component_name=t.component_name
 and i.abo is not distinct from t.abo
 and i.rh is not distinct from t.rh
left join dem d
  on d.branch_id=t.branch_id
 and d.component_name=t.component_name
 and d.abo is not distinct from t.abo
 and d.rh is not distinct from t.rh
where t.active;

grant select on public.vw_blood_supply_plan to authenticated;

-- 6) DONANTES REQUERIDOS
create or replace view public.vw_donors_required_plan as
select
  p.branch_id,p.component_name,p.abo,p.rh,
  p.required_units,
  y.avg_units_per_effective_donation,
  case
    when y.avg_units_per_effective_donation is null then null
    else ceil(p.required_units / y.avg_units_per_effective_donation)
  end donors_required,
  y.validation_status yield_validation_status,
  p.coverage_days,p.stock_status,p.nearest_expiry
from public.vw_blood_supply_plan p
left join public.production_yield_rules y on y.component_name=p.component_name and y.active;

grant select on public.vw_donors_required_plan to authenticated;

-- 7) BI DE PRODUCCIÓN
create or replace view public.vw_production_summary_30d as
select
  branch_id,component_name,abo,rh,
  count(*) batches,
  sum(quantity) produced_units,
  count(*) filter(where status='DISPONIBLE') available_batches,
  count(*) filter(where status='DESCARTADA') discarded_batches
from public.production_batches
where production_date>=current_date-29
group by branch_id,component_name,abo,rh;

grant select on public.vw_production_summary_30d to authenticated;

-- 8) ALERTAS DE ABASTECIMIENTO
create or replace view public.vw_supply_alerts as
select
  branch_id,
  concat(component_name,' ',coalesce(abo,''),' ',coalesce(rh,'')) reference,
  stock_status severity,
  coverage_days,
  required_units,
  nearest_expiry,
  case
    when stock_status='ROJO' then 'Stock en o por debajo del mínimo'
    when stock_status='AMARILLO' then 'Stock por debajo de objetivo'
    else 'Stock dentro de objetivo'
  end message
from public.vw_blood_supply_plan
where stock_status in ('ROJO','AMARILLO')
   or (nearest_expiry is not null and nearest_expiry<=current_date+7);

grant select on public.vw_supply_alerts to authenticated;

commit;
