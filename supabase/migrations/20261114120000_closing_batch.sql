-- HemoCura v11 — cierre de pendientes aditivos (L3, CM1, BI2, BI4).
-- Un solo archivo porque cada cambio es pequeño y comparte el patrón de
-- "añadir columnas/vista derivada sin romper nada existente".

begin;

------------------------------------------------------------
-- L3: Expediente completo de equipo (§5.3).
------------------------------------------------------------
-- Prompt §5.3 pide fabricante, serie, fecha adquisición, suplidor,
-- garantía, estado operativo, responsable, documentación, historial.
-- Ya existen: manufacturer, serial_number, acquisition_date,
-- installation_date, status, qualification_status.
-- Agregamos: supplier_id, warranty_until, warranty_notes,
-- documentation_ref, responsible_user_id.

alter table public.lab_equipment add column if not exists supplier_id uuid references public.suppliers(id);
alter table public.lab_equipment add column if not exists warranty_until date;
alter table public.lab_equipment add column if not exists warranty_notes text;
alter table public.lab_equipment add column if not exists documentation_ref text;
alter table public.lab_equipment add column if not exists responsible_user_id uuid references public.profiles(id);

create or replace view public.vw_equipment_dossier with(security_invoker=true) as
select
 e.id,e.equipment_code,e.branch_id,e.equipment_type,e.manufacturer,e.model,
 e.serial_number,e.location,e.criticality,e.status,
 e.acquisition_date,e.installation_date,e.warranty_until,e.warranty_notes,
 e.calibration_required,e.next_calibration_date,
 e.maintenance_required,e.next_maintenance_date,
 e.usage_threshold_hours,e.usage_threshold_services,
 s.name as supplier_name,s.id as supplier_id,
 p.full_name as responsible_name,p.id as responsible_user_id,
 e.documentation_ref,
 case
  when e.warranty_until is null then 'SIN_GARANTIA_REGISTRADA'
  when e.warranty_until<current_date then 'VENCIDA'
  when e.warranty_until<=current_date+30 then 'POR_VENCER'
  else 'VIGENTE'
 end as warranty_status
from public.lab_equipment e
left join public.suppliers s on s.id=e.supplier_id
left join public.profiles p on p.id=e.responsible_user_id;

grant select on public.vw_equipment_dossier to authenticated;

------------------------------------------------------------
-- CM1: Metas comerciales (§9).
------------------------------------------------------------
-- commercial_opportunities ya existe (sql/migrations/20261013120000).
-- Añadimos goals + scoring para comparar objetivos vs logros.

create table public.commercial_goals(
 id uuid primary key default gen_random_uuid(),
 period_start date not null,
 period_end date not null check(period_end>period_start),
 branch_id uuid references public.branches(id),
 agent_id uuid references public.profiles(id),
 service_id uuid references public.crm_services(id),
 metric text not null check(metric in (
  'VISITAS_COMPLETADAS','VISITAS_EDUCATIVAS','REFERIDOS_NUEVOS','DONANTES_CAPTADOS',
  'VENTAS_UNIDADES','VENTAS_MONTO','OPORTUNIDADES_ABIERTAS','OPORTUNIDADES_GANADAS',
  'OPORTUNIDADES_MONTO','CLIENTES_ACTIVOS','TASA_CONVERSION_PCT'
 )),
 target_value numeric(14,2) not null check(target_value>0),
 currency text check(currency in ('DOP','USD') or currency is null),
 notes text,
 approved_by uuid references public.profiles(id),
 approved_at timestamptz,
 created_by uuid references public.profiles(id),
 revision integer not null default 1,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create unique index commercial_goals_scope
 on public.commercial_goals(period_start,period_end,
                             coalesce(branch_id,'00000000-0000-0000-0000-000000000000'::uuid),
                             coalesce(agent_id,'00000000-0000-0000-0000-000000000000'::uuid),
                             coalesce(service_id,'00000000-0000-0000-0000-000000000000'::uuid),
                             metric);
create index commercial_goals_period on public.commercial_goals(period_start,period_end);

alter table public.commercial_goals enable row level security;
revoke all on public.commercial_goals from public,anon,authenticated;
grant select,insert,update on public.commercial_goals to authenticated;
create policy commercial_goals_read on public.commercial_goals for select to authenticated
 using(public.has_permission('COMMERCIAL_VIEW'));
create policy commercial_goals_write on public.commercial_goals for insert to authenticated
 with check(public.has_permission('COMMERCIAL_WRITE')
            and (branch_id is null or public.can_access_branch(branch_id)));
create policy commercial_goals_update on public.commercial_goals for update to authenticated
 using(public.has_permission('COMMERCIAL_WRITE'))
 with check(public.has_permission('COMMERCIAL_WRITE'));

-- Vista de progreso: cuenta visitas completadas y ventas por meta aplicable.
-- Solo cubre dos métricas por simplicidad; las demás requieren datasets no
-- siempre pobladas y se calcularán en frontend o en futuras iteraciones.
create or replace view public.vw_commercial_goal_progress with(security_invoker=true) as
select
 g.id as goal_id,g.period_start,g.period_end,g.branch_id,g.agent_id,g.service_id,
 g.metric,g.target_value,
 case g.metric
  when 'VISITAS_COMPLETADAS' then (
   select count(*) from public.commercial_visits v
   where v.status='REALIZADA'
     and v.scheduled_at::date between g.period_start and g.period_end
     and (g.branch_id is null or v.branch_id=g.branch_id)
     and (g.agent_id is null or v.agent_id=g.agent_id))
  when 'VISITAS_EDUCATIVAS' then (
   select count(*) from public.commercial_visits v
   where v.status='REALIZADA' and v.purpose_type='EDUCACION_INSTITUCIONAL'
     and v.scheduled_at::date between g.period_start and g.period_end
     and (g.branch_id is null or v.branch_id=g.branch_id))
  when 'VENTAS_MONTO' then (
   select coalesce(sum(s.total_amount),0) from public.operational_sales s
   where s.status<>'ANULADA'
     and s.sale_date between g.period_start and g.period_end
     and (g.branch_id is null or s.branch_id=g.branch_id))
  when 'OPORTUNIDADES_GANADAS' then (
   select count(*) from public.commercial_opportunities o
   where o.stage='GANADA'
     and o.created_at::date between g.period_start and g.period_end
     and (g.branch_id is null or o.branch_id=g.branch_id))
  else null
 end as actual_value,
 g.approved_by,g.approved_at
from public.commercial_goals g;

grant select on public.vw_commercial_goal_progress to authenticated;

------------------------------------------------------------
-- BI2: Forecast temporal de consumo de insumos (§11 bullet 2).
------------------------------------------------------------
-- Promedio móvil 90 días de consumption events por producto. Cuando el
-- stock disponible dividido por el promedio diario caiga por debajo del
-- lead time, la vista emite alerta.

create or replace view public.vw_supply_consumption_forecast with(security_invoker=true) as
with
 consumption as (
  select im.product_id,im.branch_id,
         sum(abs(im.quantity)) filter(where im.movement_type='CONSUMPTION'
                                        and im.created_at>=now()-interval '90 days') as consumed_90d,
         count(distinct (im.created_at at time zone 'America/Santo_Domingo')::date)
          filter(where im.movement_type='CONSUMPTION'
                 and im.created_at>=now()-interval '90 days') as active_days_90d
   from public.inventory_movements im
   group by im.product_id,im.branch_id
 ),
 stock as (
  select product_id,branch_id,sum(quantity) as available_quantity
   from public.inventory_balances
   group by product_id,branch_id
 )
select
 coalesce(c.product_id,s.product_id) as product_id,
 coalesce(c.branch_id,s.branch_id) as branch_id,
 coalesce(c.consumed_90d,0) as consumed_90d,
 coalesce(c.active_days_90d,0) as active_days_90d,
 case when coalesce(c.active_days_90d,0)>0
      then round(c.consumed_90d/c.active_days_90d,2)
      else 0 end as avg_daily_consumption,
 coalesce(s.available_quantity,0) as available_quantity,
 case when coalesce(c.active_days_90d,0)>0 and c.consumed_90d>0
      then floor(coalesce(s.available_quantity,0) / (c.consumed_90d/c.active_days_90d))
      else null end as days_of_cover,
 case
  when coalesce(c.consumed_90d,0)=0 then 'SIN_HISTORIAL'
  when coalesce(s.available_quantity,0)=0 then 'STOCK_AGOTADO'
  when floor(coalesce(s.available_quantity,0) / (c.consumed_90d/c.active_days_90d))<=7 then 'CRITICA'
  when floor(coalesce(s.available_quantity,0) / (c.consumed_90d/c.active_days_90d))<=14 then 'ALTA'
  when floor(coalesce(s.available_quantity,0) / (c.consumed_90d/c.active_days_90d))<=30 then 'MEDIA'
  else 'BAJA'
 end as severity
from consumption c
full outer join stock s on s.product_id=c.product_id and s.branch_id=c.branch_id;

grant select on public.vw_supply_consumption_forecast to authenticated;

------------------------------------------------------------
-- BI4: Donor outlook — proyección de oferta de donantes (§11 bullet 7).
------------------------------------------------------------
-- Toma el histórico de 90 días de donaciones efectivas por sucursal,
-- calcula promedio semanal y lo proyecta a 4 semanas como señal de oferta
-- esperada. Complementa vw_predictive_demand_30d que ya proyecta demanda.

create or replace view public.vw_donor_outlook with(security_invoker=true) as
with
 history as (
  select d.branch_id,
         count(*) filter(where d.collection_effective) as effective_90d,
         count(*) as total_90d
   from public.donations d
   where d.donation_date>=current_date-90
   group by d.branch_id
 ),
 campaigns as (
  select c.branch_id,
         sum(coalesce(c.target_donors,0)) filter(where c.status='ACTIVA') as active_campaign_targets,
         sum(coalesce(c.donations_captured,0)) filter(where c.status='ACTIVA') as active_campaign_captured
   from public.donor_campaigns c
   where c.branch_id is not null
   group by c.branch_id
 )
select
 b.id as branch_id,b.name as branch_name,
 coalesce(h.effective_90d,0) as effective_donations_90d,
 coalesce(h.total_90d,0) as recorded_donations_90d,
 round(coalesce(h.effective_90d,0)/13.0,1) as avg_weekly_effective,
 round(coalesce(h.effective_90d,0)/13.0*4,1) as projected_next_4w,
 coalesce(ca.active_campaign_targets,0) as active_campaign_targets,
 coalesce(ca.active_campaign_captured,0) as active_campaign_captured,
 case
  when coalesce(h.effective_90d,0)=0 then 'SIN_HISTORIAL'
  when round(coalesce(h.effective_90d,0)/13.0,1)<10 then 'BAJO'
  when round(coalesce(h.effective_90d,0)/13.0,1)<30 then 'MEDIO'
  else 'ALTO'
 end as supply_tier
from public.branches b
left join history h on h.branch_id=b.id
left join campaigns ca on ca.branch_id=b.id
where b.active;

grant select on public.vw_donor_outlook to authenticated;

------------------------------------------------------------
-- Registrar las 3 vistas predictivas nuevas en predictive_meta.
------------------------------------------------------------
do $$ begin
 if to_regclass('public.predictive_meta') is not null then
  insert into public.predictive_meta(view_name,title,domain,method,horizon_days,data_sources,confidence_level,limitations) values
   ('vw_supply_consumption_forecast','Proyección de consumo de insumos','INVENTARIO',
    'Promedio móvil 90 días de inventory_movements con cálculo de días de cobertura',30,
    array['inventory_movements','inventory_balances'],'AGREGACION',
    'No ajusta por estacionalidad clínica; cuenta días activos para evitar inflar con períodos sin consumo.'),
   ('vw_donor_outlook','Proyección de donantes 4 semanas','DEMANDA',
    'Promedio semanal de donaciones efectivas de los últimos 90 días proyectado a 4 semanas',28,
    array['donations','donor_campaigns'],'AGREGACION',
    'No modela estacionalidad ni campañas no activas; no ajusta por conversión por canal.'),
   ('vw_commercial_goal_progress','Progreso de metas comerciales','PRODUCTIVIDAD',
    'Comparación directa de actual_value calculado por metric vs target_value de la meta',null,
    array['commercial_goals','commercial_visits','operational_sales','commercial_opportunities'],'AGREGACION',
    'Solo 4 de 11 métricas se calculan automáticamente; el resto requiere datasets o integraciones futuras.')
  on conflict (view_name) do update set
   title=excluded.title,domain=excluded.domain,method=excluded.method,horizon_days=excluded.horizon_days,
   data_sources=excluded.data_sources,confidence_level=excluded.confidence_level,limitations=excluded.limitations,
   updated_at=now();
 end if;
end$$;

notify pgrst,'reload schema';
commit;
