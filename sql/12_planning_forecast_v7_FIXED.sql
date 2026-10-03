-- 12_planning_forecast_v7.sql
-- ============================================================

-- HemoCura v7 — Planificación operativa, Plan vs Real y Forecast

create table if not exists public.operational_plans (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  period_type text not null check (period_type in ('DAILY','WEEKLY','MONTHLY')),
  status text not null default 'DRAFT' check (status in ('DRAFT','APPROVED','CLOSED')),
  notes text,
  created_by uuid references auth.users(id),
  approved_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  unique(branch_id, period_start, period_end, period_type)
);

create table if not exists public.operational_plan_lines (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.operational_plans(id) on delete cascade,
  product_id uuid references public.products(id),
  metric_code text not null check (metric_code in (
    'DONORS_PRESENTED','DONORS_EFFECTIVE','UNITS_PRODUCED','UNITS_SOLD',
    'REVENUE','TOTAL_COST','GROSS_MARGIN','ENDING_INVENTORY'
  )),
  target_value numeric not null default 0,
  warning_threshold_pct numeric not null default 90,
  critical_threshold_pct numeric not null default 80,
  created_at timestamptz not null default now(),
  unique(plan_id, product_id, metric_code)
);

create table if not exists public.forecast_snapshots (
  id uuid primary key default gen_random_uuid(),
  forecast_date date not null default current_date,
  branch_id uuid not null references public.branches(id) on delete cascade,
  product_id uuid references public.products(id),
  metric_code text not null check (metric_code in ('UNITS_SOLD','ENDING_INVENTORY','DONORS_REQUIRED','TOTAL_COST')),
  horizon_days int not null check (horizon_days in (7,15,30)),
  forecast_value numeric not null,
  method text not null default 'MOVING_AVERAGE',
  source_days int not null default 30,
  confidence_note text,
  created_at timestamptz not null default now(),
  unique(forecast_date, branch_id, product_id, metric_code, horizon_days)
);

create or replace function public.refresh_forecasts(p_forecast_date date default current_date)
returns void
language plpgsql
security invoker
as $$
declare
  h int;
begin
  foreach h in array array[7,15,30]
  loop
    -- Ventas por producto/sucursal: media móvil 30 días escalada al horizonte.
    insert into public.forecast_snapshots(
      forecast_date, branch_id, product_id, metric_code, horizon_days,
      forecast_value, method, source_days, confidence_note
    )
    select p_forecast_date,
           dsl.branch_id,
           dsl.product_id,
           'UNITS_SOLD', h,
           coalesce(sum(dsl.final_units),0) / 30.0 * h,
           'MOVING_AVERAGE', 30,
           'Media móvil simple de 30 días; revisar estacionalidad cuando exista historial suficiente.'
    from public.vw_sale_lines_editable dsl
    where dsl.sale_date >= p_forecast_date - interval '30 days'
      and dsl.sale_date < p_forecast_date
    group by dsl.branch_id, dsl.product_id
    on conflict (forecast_date, branch_id, product_id, metric_code, horizon_days)
    do update set forecast_value=excluded.forecast_value,
                  method=excluded.method,
                  source_days=excluded.source_days,
                  confidence_note=excluded.confidence_note,
                  created_at=now();

    -- Inventario final proyectado: inventario actual menos ventas esperadas.
    insert into public.forecast_snapshots(
      forecast_date, branch_id, product_id, metric_code, horizon_days,
      forecast_value, method, source_days, confidence_note
    )
    select p_forecast_date,
           i.branch_id,
           i.product_id,
           'ENDING_INVENTORY', h,
           greatest(i.theoretical_qty - coalesce(f.forecast_value,0), 0),
           'STOCK_MINUS_FORECAST', 30,
           'Proyección simple sin incorporar compras/transferencias futuras no registradas.'
    from public.vw_inventory_status i
    left join public.forecast_snapshots f
      on f.forecast_date=p_forecast_date and f.branch_id=i.branch_id and f.product_id=i.product_id
     and f.metric_code='UNITS_SOLD' and f.horizon_days=h
    on conflict (forecast_date, branch_id, product_id, metric_code, horizon_days)
    do update set forecast_value=excluded.forecast_value,
                  method=excluded.method,
                  source_days=excluded.source_days,
                  confidence_note=excluded.confidence_note,
                  created_at=now();
  end loop;
end;
$$;

create or replace view public.vw_plan_vs_actual
with (security_invoker=true)
as
select p.id plan_id,
       p.branch_id,
       b.name branch,
       p.period_start,
       p.period_end,
       p.period_type,
       l.product_id,
       bp.code product_code,
       bp.name product_name,
       l.metric_code,
       l.target_value,
       case l.metric_code
         when 'UNITS_SOLD' then coalesce((
           select sum(x.final_units) from public.vw_sale_lines_editable x
           where x.branch_id=p.branch_id
             and (l.product_id is null or x.product_id=l.product_id)
             and x.sale_date between p.period_start and p.period_end
         ),0)
         when 'REVENUE' then coalesce((
           select sum(x.total_amount) from public.vw_sale_lines_editable x
           where x.branch_id=p.branch_id
             and (l.product_id is null or x.product_id=l.product_id)
             and x.sale_date between p.period_start and p.period_end
         ),0)
         when 'TOTAL_COST' then coalesce((
           select sum(x.total_cost) from public.vw_sale_lines_editable x
           where x.branch_id=p.branch_id
             and (l.product_id is null or x.product_id=l.product_id)
             and x.sale_date between p.period_start and p.period_end
         ),0)
         when 'GROSS_MARGIN' then coalesce((
           select sum(x.gross_margin) from public.vw_sale_lines_editable x
           where x.branch_id=p.branch_id
             and (l.product_id is null or x.product_id=l.product_id)
             and x.sale_date between p.period_start and p.period_end
         ),0)
         else null
       end actual_value,
       l.warning_threshold_pct,
       l.critical_threshold_pct
from public.operational_plans p
join public.operational_plan_lines l on l.plan_id=p.id
join public.branches b on b.id=p.branch_id
left join public.products bp on bp.id=l.product_id;

create or replace view public.vw_plan_vs_actual_status
with (security_invoker=true)
as
select v.*,
       case when v.actual_value is null then null
            when v.target_value=0 then null
            else round(v.actual_value / nullif(v.target_value,0) * 100,2) end attainment_pct,
       case when v.actual_value is null or v.target_value=0 then 'N/A'
            when (v.actual_value / nullif(v.target_value,0) * 100) >= 100 then 'GREEN'
            when (v.actual_value / nullif(v.target_value,0) * 100) >= v.warning_threshold_pct then 'YELLOW'
            else 'RED' end status
from public.vw_plan_vs_actual v;

alter table public.operational_plans enable row level security;
alter table public.operational_plan_lines enable row level security;
alter table public.forecast_snapshots enable row level security;

drop policy if exists operational_plans_read on public.operational_plans;
create policy operational_plans_read on public.operational_plans
for select to authenticated using (public.can_access_branch(branch_id));
drop policy if exists operational_plans_write on public.operational_plans;
create policy operational_plans_write on public.operational_plans
for all to authenticated using (public.can_access_branch(branch_id)) with check (public.can_access_branch(branch_id));

drop policy if exists operational_plan_lines_read on public.operational_plan_lines;
create policy operational_plan_lines_read on public.operational_plan_lines
for select to authenticated using (exists (
  select 1 from public.operational_plans p where p.id=plan_id and public.can_access_branch(p.branch_id)
));
drop policy if exists operational_plan_lines_write on public.operational_plan_lines;
create policy operational_plan_lines_write on public.operational_plan_lines
for all to authenticated using (exists (
  select 1 from public.operational_plans p where p.id=plan_id and public.can_access_branch(p.branch_id)
)) with check (exists (
  select 1 from public.operational_plans p where p.id=plan_id and public.can_access_branch(p.branch_id)
));

drop policy if exists forecast_read on public.forecast_snapshots;
create policy forecast_read on public.forecast_snapshots
for select to authenticated using (public.can_access_branch(branch_id));
drop policy if exists forecast_write on public.forecast_snapshots;
create policy forecast_write on public.forecast_snapshots
for all to authenticated using (public.can_access_branch(branch_id)) with check (public.can_access_branch(branch_id));

grant select, insert, update, delete on public.operational_plans to authenticated;
grant select, insert, update, delete on public.operational_plan_lines to authenticated;
grant select, insert, update, delete on public.forecast_snapshots to authenticated;
grant select on public.vw_plan_vs_actual to authenticated;
grant select on public.vw_plan_vs_actual_status to authenticated;
grant execute on function public.refresh_forecasts(date) to authenticated;
