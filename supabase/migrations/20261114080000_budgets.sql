-- HemoCura v11 Brecha F3 — Presupuestos y budget vs actual (§10).

begin;

create table public.budgets(
 id uuid primary key default gen_random_uuid(),
 period_month date not null check(extract(day from period_month)=1),
 branch_id uuid references public.branches(id),
 category text not null check(category in (
  'MATERIAL','LABOR','SCREENING','INDIRECT','WASTE','TRANSPORT','OTHER',
  'VENTAS','COMERCIAL','ADMIN','TOTAL'
 )),
 amount_budget numeric(14,2) not null check(amount_budget>=0),
 currency text not null default 'DOP' check(currency in ('DOP','USD')),
 notes text,
 approved_by uuid references public.profiles(id),
 approved_at timestamptz,
 created_by uuid references public.profiles(id),
 revision integer not null default 1,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(period_month,coalesce(branch_id,'00000000-0000-0000-0000-000000000000'::uuid),category)
);

create index budgets_by_period on public.budgets(period_month desc);

alter table public.budgets enable row level security;
revoke all on public.budgets from public,anon,authenticated;
grant select,insert,update on public.budgets to authenticated;

create policy budgets_read on public.budgets for select to authenticated
 using(public.has_permission('FINANCE_VIEW'));
create policy budgets_write on public.budgets for insert to authenticated
 with check(public.has_permission('FINANCE_WRITE')
            and (branch_id is null or public.can_access_branch(branch_id)));
create policy budgets_update on public.budgets for update to authenticated
 using(public.has_permission('FINANCE_WRITE'))
 with check(public.has_permission('FINANCE_WRITE'));

-- Comparación budget vs actual. Para costos tomamos vw_monthly_product_costs,
-- para ventas operational_sales. Las categorías MATERIAL/LABOR/etc salen de
-- la vista de costos; VENTAS de operational_sales.
create or replace view public.vw_budget_vs_actual with(security_invoker=true) as
with
 cost_actuals as (
  select date_trunc('month',v.period_month)::date as period_month,
         v.branch_id,
         'MATERIAL' as category,sum(coalesce(v.material_cost,0)) as actual_amount
   from public.vw_monthly_product_costs v group by 1,2
  union all
  select date_trunc('month',v.period_month)::date,v.branch_id,'LABOR',sum(coalesce(v.labor_cost,0))
   from public.vw_monthly_product_costs v group by 1,2
  union all
  select date_trunc('month',v.period_month)::date,v.branch_id,'SCREENING',sum(coalesce(v.screening_cost,0))
   from public.vw_monthly_product_costs v group by 1,2
  union all
  select date_trunc('month',v.period_month)::date,v.branch_id,'INDIRECT',sum(coalesce(v.indirect_cost,0))
   from public.vw_monthly_product_costs v group by 1,2
  union all
  select date_trunc('month',v.period_month)::date,v.branch_id,'WASTE',sum(coalesce(v.waste_cost,0))
   from public.vw_monthly_product_costs v group by 1,2
  union all
  select date_trunc('month',v.period_month)::date,v.branch_id,'TRANSPORT',sum(coalesce(v.transport_cost,0))
   from public.vw_monthly_product_costs v group by 1,2
  union all
  select date_trunc('month',v.period_month)::date,v.branch_id,'OTHER',sum(coalesce(v.other_cost,0))
   from public.vw_monthly_product_costs v group by 1,2
 ),
 sales_actuals as (
  select date_trunc('month',sale_date)::date as period_month,
         branch_id,
         'VENTAS' as category,
         sum(total_amount) as actual_amount
   from public.operational_sales where status<>'ANULADA'
   group by 1,2
 ),
 actuals as (
  select * from cost_actuals
  union all select * from sales_actuals
 )
select
 b.id as budget_id,b.period_month,b.branch_id,b.category,b.currency,
 b.amount_budget,
 coalesce(a.actual_amount,0) as actual_amount,
 coalesce(a.actual_amount,0)-b.amount_budget as variance_amount,
 case when b.amount_budget>0
      then round(100.0*(coalesce(a.actual_amount,0)-b.amount_budget)/b.amount_budget,1)
      else null end as variance_pct,
 case
  when b.approved_by is null then 'BORRADOR'
  when b.amount_budget=0 then 'SIN_PRESUPUESTO'
  when coalesce(a.actual_amount,0)<=b.amount_budget then 'DENTRO'
  when coalesce(a.actual_amount,0)<=b.amount_budget*1.1 then 'ATENCION'
  else 'DESVIADO'
 end as status
from public.budgets b
left join actuals a on a.period_month=b.period_month
                    and coalesce(a.branch_id,'00000000-0000-0000-0000-000000000000'::uuid)=coalesce(b.branch_id,'00000000-0000-0000-0000-000000000000'::uuid)
                    and a.category=b.category;

grant select on public.vw_budget_vs_actual to authenticated;

notify pgrst,'reload schema';
commit;
