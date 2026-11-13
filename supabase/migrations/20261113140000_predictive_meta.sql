-- HemoCura v11 Brecha BI1 — Metadata de predicción.
-- Prompt maestro §11 último párrafo exige mostrar junto a cada predicción:
--   datos utilizados · fecha de actualización · horizonte · método ·
--   nivel de incertidumbre · limitaciones.
-- Hoy el UI muestra "stock crítico ALTO" sin decir por qué. Esta migración
-- expone esa metadata en una tabla consultable por el frontend.

begin;

create table public.predictive_meta(
 view_name text primary key,
 title text not null,
 domain text not null check(domain in ('DEMANDA','INVENTARIO','CAJA','CLIENTE','PRODUCTIVIDAD','MERMA','CALIDAD','AGREGADA')),
 method text not null,
 horizon_days integer check(horizon_days is null or horizon_days between 1 and 3650),
 data_sources text[] not null default '{}',
 confidence_level text not null default 'HEURISTICA'
  check(confidence_level in ('HEURISTICA','AGREGACION','ESTADISTICA','MODELO_ML')),
 limitations text not null,
 last_refreshed_at timestamptz not null default now(),
 last_reviewed_at timestamptz,
 reviewed_by uuid references public.profiles(id),
 revision integer not null default 1,
 updated_at timestamptz not null default now()
);

revoke all on public.predictive_meta from public,anon,authenticated;
grant select on public.predictive_meta to authenticated;
alter table public.predictive_meta enable row level security;
create policy predictive_meta_read on public.predictive_meta for select to authenticated
 using(auth.uid() is not null);

-- Seed de las 8 vistas predictivas actuales. Las descripciones son
-- deliberadamente cautas: cada una declara su método como HEURISTICA o
-- AGREGACION y enumera limitaciones conocidas. Si en el futuro una vista
-- pasa a usar un modelo estadístico, se debe actualizar aquí también.
insert into public.predictive_meta(view_name,title,domain,method,horizon_days,data_sources,confidence_level,limitations) values
 ('vw_predictive_demand_30d','Proyección de demanda 30 días','DEMANDA',
  'Agregación de clinical_demand_requests por componente con suavizado simple',30,
  array['clinical_demand_requests','blood_inventory_units','dispatches'],'AGREGACION',
  'No ajusta por estacionalidad; no incluye brotes clínicos o eventos imprevistos; horizonte basado en 90 días previos.'),
 ('vw_stock_risk_projection','Riesgo de stock por componente','INVENTARIO',
  'Comparación de inventario disponible con demanda abierta y vencimientos próximos',30,
  array['blood_inventory_units','clinical_demand_requests','product_lots'],'HEURISTICA',
  'Clasifica CRITICO/ALTO/MEDIO/BAJO por umbrales fijos; no proyecta cadenas de suministro ni cambios de política de reserva.'),
 ('vw_cash_collection_forecast','Pronóstico de cobros','CAJA',
  'Proyección de cobros esperados desde cuentas por cobrar con probabilidad por bucket de aging',90,
  array['operational_sales','collections','vw_accounts_receivable'],'HEURISTICA',
  'Probabilidades por bucket son estimaciones iniciales; no incluye egresos (ver Brecha F1 Cuentas por Pagar); no modela cliente individual.'),
 ('vw_customer_health_score','Score de salud por cliente','CLIENTE',
  'Combinación ponderada de SLA, saldo, deuda >60d y seguimientos abiertos',null,
  array['customers','vw_accounts_receivable','commercial_visits','vw_service_level_performance'],'HEURISTICA',
  'Ponderaciones fijas sin validación estadística; score 0-100 no es predictivo de churn, solo diagnóstico presente.'),
 ('vw_branch_productivity_30d','Productividad por sucursal 30 días','PRODUCTIVIDAD',
  'Agregación de donaciones, tamizajes, liberaciones y despachos por sucursal',30,
  array['donations','screening_tests','blood_inventory_units','operational_sales'],'AGREGACION',
  'No normaliza por tamaño de sucursal ni por mix de servicios; comparaciones entre sucursales requieren contexto operacional.'),
 ('vw_avoidable_loss_signals','Señales de pérdida evitable','MERMA',
  'Detección de unidades próximas a vencer sin reserva ni despacho programado',14,
  array['blood_inventory_units','product_lots','dispatches'],'HEURISTICA',
  'Ventana fija 14 días; no diferencia componentes con criterios clínicos distintos; no propone destinatarios.'),
 ('vw_predictive_action_queue','Cola de señales accionables','AGREGADA',
  'Unión priorizada de señales de las vistas anteriores con score por dominio y severidad',null,
  array['vw_stock_risk_projection','vw_avoidable_loss_signals','vw_customer_health_score','vw_cash_collection_forecast'],'HEURISTICA',
  'La prioridad combinada no es una predicción clínica; cada señal requiere decisión humana registrada en predictive_decision_reviews.'),
 ('vw_service_level_performance','Desempeño de SLA','PRODUCTIVIDAD',
  'Cálculo de tiempos de respuesta y cumplimiento vs acuerdos registrados',null,
  array['clinical_demand_requests','dispatches','customers'],'AGREGACION',
  'SLA por acuerdo manual; no detecta desviaciones de política; ventana rodante de los últimos 30 días.')
 on conflict (view_name) do update set
  title=excluded.title,domain=excluded.domain,method=excluded.method,horizon_days=excluded.horizon_days,
  data_sources=excluded.data_sources,confidence_level=excluded.confidence_level,limitations=excluded.limitations,
  updated_at=now(),revision=public.predictive_meta.revision+1;

create function private.predictive_meta_touch() returns trigger language plpgsql as $$
begin
 new.updated_at:=now();
 if tg_op='UPDATE' and (new.method is distinct from old.method
   or new.horizon_days is distinct from old.horizon_days
   or new.confidence_level is distinct from old.confidence_level
   or new.limitations is distinct from old.limitations)
 then new.revision:=old.revision+1;
 end if;
 return new;
end;$$;

create trigger predictive_meta_touch
 before update on public.predictive_meta
 for each row execute function private.predictive_meta_touch();

notify pgrst,'reload schema';
commit;
