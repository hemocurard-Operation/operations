-- HemoCura Predictive Chain 50 foundation (live migration 20261012120555)
insert into public.app_permissions(permission_code,module,description,risk_level,active)
values ('PREDICTIVE_VIEW','PREDICTIVE','Ver cockpit predictivo y señales priorizadas','NORMAL',true),('PREDICTIVE_WRITE','PREDICTIVE','Registrar decisiones sobre recomendaciones predictivas','SENSIBLE',true)
on conflict (permission_code) do update set module=excluded.module,description=excluded.description,risk_level=excluded.risk_level,active=true;
insert into public.role_permissions(role_id,permission_code)
select r.id,p.code from public.roles r cross join (values ('PREDICTIVE_VIEW'),('PREDICTIVE_WRITE')) p(code)
where r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_GENERAL','GERENCIA_OPERATIVA') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code)
select r.id,'PREDICTIVE_VIEW' from public.roles r where r.code in ('SOCIO','CALIDAD','FINANZAS','MEDICO_GERENTE_TECNICO') on conflict do nothing;

create table if not exists public.predictive_decision_reviews(
 id uuid primary key default gen_random_uuid(),candidate_key text not null,branch_id uuid references public.branches(id),domain text not null,source_table text,source_id uuid,
 decision text not null check (decision in ('ACEPTAR','DIFERIR','DESCARTAR','OBSERVAR')),rationale text,review_due_date date,linked_action_id uuid references public.integrated_actions(id),
 reviewed_by uuid default auth.uid(),reviewed_at timestamptz not null default now(),created_at timestamptz not null default now());
create index if not exists idx_predictive_review_key on public.predictive_decision_reviews(candidate_key,reviewed_at desc);
create index if not exists idx_predictive_review_branch on public.predictive_decision_reviews(branch_id,reviewed_at desc);
alter table public.predictive_decision_reviews enable row level security;
create policy predictive_review_select on public.predictive_decision_reviews for select to authenticated using (has_permission('PREDICTIVE_VIEW') and (branch_id is null or can_access_branch(branch_id)));
create policy predictive_review_insert on public.predictive_decision_reviews for insert to authenticated with check (has_permission('PREDICTIVE_WRITE') and (branch_id is null or can_access_branch(branch_id)) and reviewed_by=(select auth.uid()));
create policy predictive_review_update on public.predictive_decision_reviews for update to authenticated using (has_permission('PREDICTIVE_WRITE') and (branch_id is null or can_access_branch(branch_id))) with check (has_permission('PREDICTIVE_WRITE') and (branch_id is null or can_access_branch(branch_id)));
create policy predictive_review_delete on public.predictive_decision_reviews for delete to authenticated using (has_permission('PREDICTIVE_WRITE') and (branch_id is null or can_access_branch(branch_id)));
grant select,insert,update,delete on public.predictive_decision_reviews to authenticated; revoke all on public.predictive_decision_reviews from anon;

create or replace view public.vw_predictive_demand_30d with (security_invoker=true) as
with d as (
 select branch_id,product_id,blood_group,rh_factor,
        count(*) filter(where requested_at>=now()-interval '30 days')::int requests_30d,
        coalesce(sum(requested_units) filter(where requested_at>=now()-interval '30 days'),0)::numeric units_30d,
        coalesce(sum(requested_units) filter(where requested_at>=now()-interval '7 days'),0)::numeric units_7d,
        coalesce(sum(requested_units) filter(where status in ('ABIERTA','EN_PROCESO')),0)::numeric open_units
 from public.clinical_demand_requests
 group by branch_id,product_id,blood_group,rh_factor
)
select d.*,round(d.units_30d/30.0,2) avg_daily_30d,round(d.units_7d/7.0,2) avg_daily_7d,
       round(greatest(d.units_30d/30.0,d.units_7d/7.0)*7,2) projected_units_7d,
       case when d.units_7d/7.0>d.units_30d/30.0*1.25 then 'ALZA' when d.units_7d/7.0<d.units_30d/30.0*0.75 then 'BAJA' else 'ESTABLE' end trend
from d;
grant select on public.vw_predictive_demand_30d to authenticated; revoke all on public.vw_predictive_demand_30d from anon;

create or replace view public.vw_stock_risk_projection with (security_invoker=true) as
with stock as (
 select branch_id,product_id,abo,rh,coalesce(sum(quantity),0)::numeric available_units
 from public.blood_inventory_units
 where upper(coalesce(inventory_status,'')) in ('AVAILABLE','DISPONIBLE','LIBERADA','LIBERADO') and (expiry_date is null or expiry_date>=current_date)
 group by branch_id,product_id,abo,rh
), demand as (
 select branch_id,product_id,blood_group abo,rh_factor rh,avg_daily_30d,avg_daily_7d,open_units,trend from public.vw_predictive_demand_30d
)
select coalesce(s.branch_id,d.branch_id) branch_id,coalesce(s.product_id,d.product_id) product_id,coalesce(s.abo,d.abo) abo,coalesce(s.rh,d.rh) rh,
       coalesce(s.available_units,0) available_units,coalesce(d.avg_daily_30d,0) avg_daily_30d,coalesce(d.avg_daily_7d,0) avg_daily_7d,coalesce(d.open_units,0) open_units,
       case when greatest(coalesce(d.avg_daily_30d,0),coalesce(d.avg_daily_7d,0))>0 then round(coalesce(s.available_units,0)/greatest(d.avg_daily_30d,d.avg_daily_7d),1) else null end days_cover,
       d.trend,
       case when coalesce(s.available_units,0)<=coalesce(d.open_units,0) and coalesce(d.open_units,0)>0 then 'CRITICO'
            when greatest(coalesce(d.avg_daily_30d,0),coalesce(d.avg_daily_7d,0))>0 and coalesce(s.available_units,0)/greatest(d.avg_daily_30d,d.avg_daily_7d)<3 then 'ALTO'
            when greatest(coalesce(d.avg_daily_30d,0),coalesce(d.avg_daily_7d,0))>0 and coalesce(s.available_units,0)/greatest(d.avg_daily_30d,d.avg_daily_7d)<7 then 'MEDIO' else 'CONTROLADO' end risk_level
from stock s full join demand d on d.branch_id=s.branch_id and d.product_id=s.product_id and coalesce(d.abo,'')=coalesce(s.abo,'') and coalesce(d.rh,'')=coalesce(s.rh,'');
grant select on public.vw_stock_risk_projection to authenticated; revoke all on public.vw_stock_risk_projection from anon;

create or replace view public.vw_cash_collection_forecast with (security_invoker=true) as
select branch_id,date_trunc('week',coalesce(payment_due_date,sale_date))::date forecast_week,count(*)::int invoices,
       sum(greatest(coalesce(total_amount,0)-coalesce(collected_amount,0),0))::numeric expected_cash,
       sum(case when coalesce(payment_due_date,sale_date)<current_date then greatest(coalesce(total_amount,0)-coalesce(collected_amount,0),0) else 0 end)::numeric overdue_cash
from public.operational_sales
where greatest(coalesce(total_amount,0)-coalesce(collected_amount,0),0)>0 and coalesce(payment_due_date,sale_date)<=current_date+interval '60 days'
group by branch_id,date_trunc('week',coalesce(payment_due_date,sale_date))::date;
grant select on public.vw_cash_collection_forecast to authenticated; revoke all on public.vw_cash_collection_forecast from anon;

create or replace view public.vw_customer_health_score with (security_invoker=true) as
with ar as (
 select customer_id,branch_id,sum(outstanding_amount)::numeric balance,
        sum(case when aging_bucket in ('61-90','>90') then outstanding_amount else 0 end)::numeric old_debt
 from public.vw_accounts_receivable group by customer_id,branch_id
), fb as (
 select customer_id,branch_id,avg(rating)::numeric avg_rating,
        count(*) filter(where requires_followup and status not in ('CERRADO','RESUELTO'))::int open_followups
 from public.customer_feedback group by customer_id,branch_id
), sla as (
 select customer_id,branch_id,avg(case when sla_status='CUMPLE' then 1 else 0 end)::numeric sla_ratio
 from public.vw_service_level_performance where customer_id is not null group by customer_id,branch_id
)
select c.id customer_id,c.name customer_name,coalesce(ar.branch_id,fb.branch_id,sla.branch_id) branch_id,
       coalesce(ar.balance,0) balance,coalesce(ar.old_debt,0) old_debt,round(coalesce(fb.avg_rating,0),2) avg_rating,
       coalesce(fb.open_followups,0) open_followups,round(coalesce(sla.sla_ratio,0)*100,1) sla_pct,
       greatest(0,least(100,100-case when coalesce(ar.old_debt,0)>0 then 30 else 0 end-least(coalesce(fb.open_followups,0)*10,30)-case when coalesce(sla.sla_ratio,1)<0.8 then 20 else 0 end+case when coalesce(fb.avg_rating,0)>=4 then 10 else 0 end))::int health_score
from public.customers c
left join ar on ar.customer_id=c.id
left join fb on fb.customer_id=c.id and (fb.branch_id=ar.branch_id or ar.branch_id is null)
left join sla on sla.customer_id=c.id and (sla.branch_id=coalesce(ar.branch_id,fb.branch_id) or coalesce(ar.branch_id,fb.branch_id) is null);
grant select on public.vw_customer_health_score to authenticated; revoke all on public.vw_customer_health_score from anon;

create or replace view public.vw_branch_productivity_30d with (security_invoker=true) as
with s as (select branch_id,count(*)::int sales_count,coalesce(sum(total_amount),0)::numeric revenue from public.operational_sales where sale_date>=current_date-29 group by branch_id),
 d as (select branch_id,count(*)::int dispatch_count from public.dispatches where dispatch_date>=current_date-29 group by branch_id),
 don as (select branch_id,count(*)::int donations_count from public.donations where donation_date>=current_date-29 group by branch_id),
 l as (select branch_id,coalesce(sum(estimated_loss),0)::numeric loss from public.inventory_loss_events where event_date>=current_date-29 group by branch_id)
select b.id branch_id,b.name branch_name,coalesce(s.sales_count,0) sales_count,coalesce(s.revenue,0) revenue,
       coalesce(d.dispatch_count,0) dispatch_count,coalesce(don.donations_count,0) donations_count,coalesce(l.loss,0) loss,
       round(coalesce(s.revenue,0)-coalesce(l.loss,0),2) net_value_proxy
from public.branches b left join s on s.branch_id=b.id left join d on d.branch_id=b.id left join don on don.branch_id=b.id left join l on l.branch_id=b.id;
grant select on public.vw_branch_productivity_30d to authenticated; revoke all on public.vw_branch_productivity_30d from anon;

create or replace view public.vw_avoidable_loss_signals with (security_invoker=true) as
select branch_id,product_id,loss_type,count(*)::int events,sum(quantity)::numeric units_lost,sum(estimated_loss)::numeric loss_value,
       case when upper(coalesce(loss_type,'')) in ('VENCIMIENTO','CADENA_FRIO','ERROR_OPERATIVO','ROTURA','MERMA_EVITABLE') then true else false end avoidable,
       case when sum(estimated_loss)>=50000 then 'CRITICA' when sum(estimated_loss)>=15000 then 'ALTA' when sum(estimated_loss)>0 then 'MEDIA' else 'BAJA' end priority
from public.inventory_loss_events where event_date>=current_date-89 group by branch_id,product_id,loss_type;
grant select on public.vw_avoidable_loss_signals to authenticated; revoke all on public.vw_avoidable_loss_signals from anon;

create or replace view public.vw_predictive_action_candidates with (security_invoker=true) as
select 'STOCK:'||coalesce(branch_id::text,'')||':'||coalesce(product_id::text,'')||':'||coalesce(abo,'')||coalesce(rh,'') candidate_key,branch_id,'ABASTECIMIENTO' domain,'vw_stock_risk_projection' source_table,null::uuid source_id,
       case when risk_level='CRITICO' then 'CRITICA' else 'ALTA' end priority,'Riesgo de cobertura de inventario '||coalesce(abo,'')||coalesce(rh,'') title,
       'Cobertura estimada: '||coalesce(days_cover::text,'N/D')||' días; demanda abierta: '||open_units::text description,current_date due_date,
       'Revisar captación, producción, reservas y demanda antes de tomar decisión.' recommended_action
from public.vw_stock_risk_projection where risk_level in ('CRITICO','ALTO')
union all
select 'CASH:'||coalesce(branch_id::text,'')||':'||forecast_week::text,branch_id,'FINANZAS','vw_cash_collection_forecast',null::uuid,
       case when overdue_cash>=100000 then 'CRITICA' else 'ALTA' end,'Cobranza vencida requiere intervención','Monto vencido proyectado: RD$ '||round(overdue_cash,2)::text,
       forecast_week,'Priorizar contacto, conciliación y compromiso de pago.' from public.vw_cash_collection_forecast where overdue_cash>0
union all
select 'LOSS:'||coalesce(branch_id::text,'')||':'||coalesce(product_id::text,'')||':'||coalesce(loss_type,''),branch_id,'MERMA','vw_avoidable_loss_signals',null::uuid,
       priority,'Pérdida evitable: '||coalesce(loss_type,''),'Valor 90 días: RD$ '||round(loss_value,2)::text,current_date+7,
       'Analizar causa y definir acción para reducir recurrencia.' from public.vw_avoidable_loss_signals where avoidable and loss_value>0
union all
select 'CAPA:'||c.id::text,n.branch_id,'CALIDAD','capa',c.id,case when c.due_date<current_date then 'CRITICA' else 'ALTA' end,
       'CAPA pendiente: '||coalesce(c.code,c.id::text),coalesce(c.problem,'Sin descripción'),coalesce(c.due_date,current_date+7),
       'Completar acción, evidencia y verificación de eficacia.'
from public.capa c left join public.nonconformities n on n.id=c.nonconformity_id
where upper(coalesce(c.status,'')) not in ('CERRADA','CERRADO','EFICAZ') and (c.due_date is null or c.due_date<=current_date+7)
union all
select 'COMP:'||a.id::text,a.branch_id,'COMPLIANCE','compliance_penal_actions',a.id,case when a.due_date<current_date then 'CRITICA' else coalesce(a.priority,'ALTA') end,
       'Compliance penal: '||a.title,coalesce(a.description,'Sin descripción'),coalesce(a.due_date,current_date+7),
       'Completar evidencia y revisión del requisito aplicable.'
from public.compliance_penal_actions a
where upper(coalesce(a.status,'')) not in ('CERRADA','CERRADO','VERIFICADA','VERIFICADO') and (a.due_date is null or a.due_date<=current_date+7);
grant select on public.vw_predictive_action_candidates to authenticated; revoke all on public.vw_predictive_action_candidates from anon;
