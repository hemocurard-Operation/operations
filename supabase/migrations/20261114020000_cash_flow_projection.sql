-- HemoCura v11 Brecha F2 — Proyección de caja 30/60/90 (§10 bullet "proyecciones").
--
-- Depende de F1 (accounts_payable) que ya está aplicada.
-- Esta migración añade:
--   vw_cash_flow_projection    — bucket por semana de ingresos esperados
--                                (collections pendientes con probabilidad por
--                                aging) menos egresos esperados (payables
--                                pendientes con due_date dentro del horizonte).
--   vw_cash_flow_summary       — totales acumulados 30/60/90 días.
--
-- Las probabilidades de cobro son parámetros declarados en la vista (no
-- en una tabla de reglas todavía — Brecha de iteración futura). Marcadas
-- como HEURISTICA y documentadas con predictive_meta.

begin;

create or replace view public.vw_cash_flow_projection with(security_invoker=true) as
with
 inflows as (
  select date_trunc('week',coalesce(a.due_date,current_date+(a.days_past_due)))::date as week,
         sum(
          case
           when a.days_past_due<=0 then a.outstanding_amount*0.85
           when a.days_past_due<=30 then a.outstanding_amount*0.70
           when a.days_past_due<=60 then a.outstanding_amount*0.50
           when a.days_past_due<=90 then a.outstanding_amount*0.30
           else a.outstanding_amount*0.15
          end
         ) as expected_amount
   from public.vw_accounts_receivable a
   where coalesce(a.outstanding_amount,0)>0
   group by 1
 ),
 outflows as (
  select date_trunc('week',p.due_date)::date as week,
         sum(p.amount_total-p.amount_paid) as expected_amount
   from public.supplier_payables p
   where p.status not in ('PAGADA','ANULADA')
     and p.due_date<=current_date+120
   group by 1
 ),
 weeks as (
  select generate_series(
    date_trunc('week',current_date)::date,
    date_trunc('week',current_date+120)::date,
    interval '7 days'
  )::date as week
 )
select
 w.week,
 coalesce(i.expected_amount,0) as expected_inflow,
 coalesce(o.expected_amount,0) as expected_outflow,
 coalesce(i.expected_amount,0)-coalesce(o.expected_amount,0) as net,
 case when w.week<=current_date+30 then '30d'
      when w.week<=current_date+60 then '60d'
      when w.week<=current_date+90 then '90d'
      else '90d+' end as horizon_bucket
from weeks w
left join inflows i on i.week=w.week
left join outflows o on o.week=w.week
order by w.week;

grant select on public.vw_cash_flow_projection to authenticated;

create or replace view public.vw_cash_flow_summary with(security_invoker=true) as
select
 horizon_bucket,
 sum(expected_inflow) as total_inflow,
 sum(expected_outflow) as total_outflow,
 sum(net) as net_flow
from public.vw_cash_flow_projection
group by horizon_bucket
order by horizon_bucket;

grant select on public.vw_cash_flow_summary to authenticated;

-- Registrar la nueva vista en predictive_meta si la tabla existe.
do $$ begin
 if to_regclass('public.predictive_meta') is not null then
  insert into public.predictive_meta(view_name,title,domain,method,horizon_days,data_sources,confidence_level,limitations)
  values('vw_cash_flow_projection','Proyección de caja 30/60/90','CAJA',
   'Semanal: cobros esperados por aging bucket × probabilidad; egresos esperados por due_date',120,
   array['vw_accounts_receivable','supplier_payables','collections','operational_sales'],
   'HEURISTICA',
   'Probabilidades por bucket son fijas (0.85/0.70/0.50/0.30/0.15) y no están calibradas con histórico de cliente; la ventana termina a 120 días.')
  on conflict (view_name) do update set
   title=excluded.title,domain=excluded.domain,method=excluded.method,horizon_days=excluded.horizon_days,
   data_sources=excluded.data_sources,confidence_level=excluded.confidence_level,limitations=excluded.limitations,
   updated_at=now();
 end if;
end$$;

notify pgrst,'reload schema';
commit;
