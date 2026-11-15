-- HemoCura v11 Brecha BI3 — Proyección de gastos (§11 bullet 5).
--
-- Depende de F1 (supplier_payables), F3 (budgets) y BI1 (predictive_meta).
-- Combina egresos comprometidos (supplier_payables activos agrupados por
-- semana) con egresos presupuestados (budgets del período). Da al cockpit
-- predictivo una visión de "qué vamos a gastar y cuánto queda de presupuesto".

begin;

create or replace view public.vw_expense_forecast with(security_invoker=true) as
with
 payables_by_week as (
  select date_trunc('week',p.due_date)::date as week,
         sum(p.amount_total-p.amount_paid) as committed_outflow,
         count(*) as pending_invoices
   from public.supplier_payables p
   where p.status not in ('PAGADA','ANULADA')
     and p.due_date<=current_date+120
   group by 1
 ),
 month_buckets as (
  select generate_series(
    date_trunc('month',current_date)::date,
    (date_trunc('month',current_date)+interval '3 months')::date,
    interval '1 month'
  )::date as period_month
 ),
 budget_by_month as (
  select b.period_month,sum(b.amount_budget) as total_budget
   from public.budgets b
   where b.approved_by is not null
     and b.period_month>=date_trunc('month',current_date)::date
   group by b.period_month
 ),
 actual_by_month as (
  select date_trunc('month',sp.paid_at)::date as period_month,
         sum(sp.amount) as paid_this_period
   from public.supplier_payments sp
   group by date_trunc('month',sp.paid_at)::date
 )
select
 pw.week,
 pw.committed_outflow,
 pw.pending_invoices,
 (select coalesce(b.total_budget,0) from budget_by_month b
   where b.period_month=date_trunc('month',pw.week)::date) as monthly_budget,
 (select coalesce(a.paid_this_period,0) from actual_by_month a
   where a.period_month=date_trunc('month',pw.week)::date) as monthly_paid_so_far
from payables_by_week pw
order by pw.week;

grant select on public.vw_expense_forecast to authenticated;

do $$ begin
 if to_regclass('public.predictive_meta') is not null then
  insert into public.predictive_meta(view_name,title,domain,method,horizon_days,data_sources,confidence_level,limitations)
  values('vw_expense_forecast','Proyección de gastos 120 días','CAJA',
   'Egresos comprometidos por semana (supplier_payables pendientes) con contexto de budget y pagos del mes',120,
   array['supplier_payables','supplier_payments','budgets'],'AGREGACION',
   'Solo cuenta egresos ya facturados; no proyecta egresos esperados fuera de OC confirmadas. Budget comparado por mes, no semana.')
  on conflict (view_name) do update set
   title=excluded.title,domain=excluded.domain,method=excluded.method,horizon_days=excluded.horizon_days,
   data_sources=excluded.data_sources,confidence_level=excluded.confidence_level,limitations=excluded.limitations,
   updated_at=now();
 end if;
end$$;

notify pgrst,'reload schema';
commit;
