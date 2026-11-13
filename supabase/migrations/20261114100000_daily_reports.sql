-- HemoCura v11 Brechas F4 + D1 — Reportes operacionales diarios.
--
-- F4 (§10): conciliación de ingresos diaria por sucursal × método de pago.
-- D1 (§6.4): reporte diario de donantes (programados, recibidos, aceptados,
--            diferidos, rechazados, motivos, tasa de aceptación).
--
-- Solo vistas. Sin schema change. Toma datos existentes.

begin;

-- F4: Conciliación diaria de ingresos consolidada.
create or replace view public.vw_daily_cash_reconciliation with(security_invoker=true) as
with
 sales_by_method as (
  select sale_date::date as day,branch_id,
         coalesce(payment_status,'PENDIENTE') as payment_status,
         case
          when invoice_number ilike '%EFECTIVO%' then 'EFECTIVO'
          when invoice_number ilike '%TRANSFER%' then 'TRANSFERENCIA'
          when invoice_number ilike '%OFICINA%' then 'OFICINA'
          when status='COBRADA' then 'COBRO_DIRECTO'
          else 'POR_CLASIFICAR'
         end as payment_method,
         sum(total_amount) as total,
         sum(collected_amount) as collected,
         count(*) as count
   from public.operational_sales
   where status<>'ANULADA'
   group by 1,2,3,4
 )
select day,branch_id,payment_status,payment_method,total,collected,count
 from sales_by_method;

grant select on public.vw_daily_cash_reconciliation to authenticated;

-- D1: Reporte diario de donantes.
-- Combina donor_visits (programados/recibidos) con donations (efectivas) y
-- donors.status/deferral_reason para separar diferidos de rechazados.
create or replace view public.vw_daily_donor_report with(security_invoker=true) as
with
 scheduled as (
  select (starts_at at time zone 'America/Santo_Domingo')::date as day,
         branch_id,count(*) as scheduled_count
   from public.donor_visits
   group by 1,2
 ),
 received as (
  select (starts_at at time zone 'America/Santo_Domingo')::date as day,
         branch_id,
         count(*) filter(where status='ASISTIO') as attended_count,
         count(*) filter(where status='NO_ASISTIO') as no_show_count,
         count(*) filter(where status='CANCELADA') as cancelled_count
   from public.donor_visits
   group by 1,2
 ),
 donations_today as (
  select donation_date as day,branch_id,
         count(*) filter(where collection_effective) as effective_count,
         count(*) as total_count
   from public.donations
   group by 1,2
 ),
 deferrals as (
  -- Contar donantes con estado diferido/rechazado creados hoy.
  select registration_date as day,branch_id,
         count(*) filter(where status in ('DIFERIDO','DIFERIDO_TEMPORAL','DIFERIDO_PERMANENTE','HEMOGLOBINA_BAJA')) as deferred_count,
         count(*) filter(where status='RECHAZADO') as rejected_count,
         jsonb_object_agg(coalesce(nullif(trim(deferral_reason),''),deferral_type,'Sin especificar'),count) filter(where status<>'ACEPTADO' and status<>'PENDIENTE') as reasons
   from (
    select d.branch_id,d.registration_date,d.status,d.deferral_reason,d.deferral_type,
           count(*) over(partition by d.branch_id,d.registration_date,coalesce(nullif(trim(d.deferral_reason),''),d.deferral_type,'Sin especificar')) as count
     from public.donors d
   ) t
   group by 1,2
 )
select
 coalesce(s.day,r.day,dt.day,df.day) as day,
 coalesce(s.branch_id,r.branch_id,dt.branch_id,df.branch_id) as branch_id,
 coalesce(s.scheduled_count,0) as scheduled_count,
 coalesce(r.attended_count,0) as attended_count,
 coalesce(r.no_show_count,0) as no_show_count,
 coalesce(r.cancelled_count,0) as cancelled_count,
 coalesce(dt.effective_count,0) as effective_donations,
 coalesce(dt.total_count,0) as recorded_donations,
 coalesce(df.deferred_count,0) as deferred_count,
 coalesce(df.rejected_count,0) as rejected_count,
 df.reasons as deferral_reasons,
 case when coalesce(r.attended_count,0)>0
      then round(100.0*coalesce(dt.effective_count,0)/r.attended_count,1)
      else null end as acceptance_rate_pct
from scheduled s
full outer join received r on r.day=s.day and r.branch_id=s.branch_id
full outer join donations_today dt on dt.day=coalesce(s.day,r.day) and dt.branch_id=coalesce(s.branch_id,r.branch_id)
full outer join deferrals df on df.day=coalesce(s.day,r.day,dt.day) and df.branch_id=coalesce(s.branch_id,r.branch_id,dt.branch_id);

grant select on public.vw_daily_donor_report to authenticated;

notify pgrst,'reload schema';
commit;
