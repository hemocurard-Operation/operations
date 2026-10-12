insert into public.role_permissions (role_id, permission_code)
select r.id, p.permission_code
from public.roles r
cross join (values
  ('VALUE_CHAIN_VIEW'),('VALUE_CHAIN_WRITE'),('DONOR_OUTREACH_VIEW'),('DONOR_OUTREACH_WRITE'),
  ('CUSTOMER_VIEW'),('CUSTOMER_WRITE'),('ACTIONS_VIEW'),('ACTIONS_WRITE')
) as p(permission_code)
where (
  p.permission_code='VALUE_CHAIN_VIEW' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_GENERAL','GERENCIA_OPERATIVA','SOCIO','CALIDAD','FINANZAS','ENCARGADA_LABORATORIO','ASISTENTE_OPERACIONES','SUCURSAL')
) or (
  p.permission_code='VALUE_CHAIN_WRITE' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','ENCARGADA_LABORATORIO','ASISTENTE_OPERACIONES')
) or (
  p.permission_code='DONOR_OUTREACH_VIEW' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','ENCARGADA_LABORATORIO','ASISTENTE_OPERACIONES','LABORATORIO')
) or (
  p.permission_code='DONOR_OUTREACH_WRITE' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','ENCARGADA_LABORATORIO','ASISTENTE_OPERACIONES')
) or (
  p.permission_code='CUSTOMER_VIEW' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_GENERAL','GERENCIA_OPERATIVA','SOCIO','FINANZAS','ASISTENTE_OPERACIONES')
) or (
  p.permission_code='CUSTOMER_WRITE' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','FINANZAS','ASISTENTE_OPERACIONES')
) or (
  p.permission_code='ACTIONS_VIEW' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_GENERAL','GERENCIA_OPERATIVA','CALIDAD','ENCARGADA_LABORATORIO','ASISTENTE_OPERACIONES','MEDICO_GERENTE_TECNICO')
) or (
  p.permission_code='ACTIONS_WRITE' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','CALIDAD','ENCARGADA_LABORATORIO')
)
on conflict do nothing;

create table if not exists public.value_chain_stage_catalog (
  stage_code text primary key,
  sequence_no integer not null unique check (sequence_no between 1 and 20),
  stage_name text not null,
  objective text not null,
  owner_domain text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
insert into public.value_chain_stage_catalog(stage_code,sequence_no,stage_name,objective,owner_domain)
values
 ('VC-01',1,'Demanda','Capturar y priorizar necesidades reales de componentes y servicios','COMERCIAL_OPERACIONES'),
 ('VC-02',2,'Planificación','Convertir demanda en metas de abastecimiento y capacidad','OPERACIONES'),
 ('VC-03',3,'Captación de donantes','Movilizar donantes según brechas de inventario y demanda','DONANTES'),
 ('VC-04',4,'Donación','Capturar la donación y mantener trazabilidad','LABORATORIO'),
 ('VC-05',5,'Tamizaje','Verificar seguridad analítica antes de liberar','LABORATORIO'),
 ('VC-06',6,'Producción','Transformar unidades en componentes trazables','LABORATORIO'),
 ('VC-07',7,'Liberación e inventario','Disponibilizar únicamente componentes liberados y vigentes','LABORATORIO'),
 ('VC-08',8,'Despacho','Cumplir solicitudes con segregación, trazabilidad y tiempo objetivo','OPERACIONES'),
 ('VC-09',9,'Venta y cobro','Convertir el servicio cumplido en ingreso conciliado','FINANZAS'),
 ('VC-10',10,'Experiencia y mejora','Capturar retroalimentación, incidentes y acciones de mejora','SGC')
on conflict(stage_code) do update set stage_name=excluded.stage_name,objective=excluded.objective,owner_domain=excluded.owner_domain,active=true;

create table if not exists public.donor_campaigns (
  id uuid primary key default gen_random_uuid(), campaign_code text not null unique, branch_id uuid null references public.branches(id),
  name text not null, channel text not null default 'MIXTO', audience text null, start_date date not null, end_date date null,
  target_donors integer not null default 0 check (target_donors >= 0), status text not null default 'PLANIFICADA' check (status in ('PLANIFICADA','ACTIVA','PAUSADA','CERRADA','CANCELADA')),
  notes text null, created_by uuid null references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.donations add column if not exists campaign_id uuid null references public.donor_campaigns(id);
create index if not exists idx_donations_campaign_id on public.donations(campaign_id);
create index if not exists idx_donor_campaigns_branch_status on public.donor_campaigns(branch_id,status,start_date);

create table if not exists public.customer_service_agreements (
  id uuid primary key default gen_random_uuid(), agreement_code text not null unique, customer_id uuid not null references public.customers(id), branch_id uuid null references public.branches(id),
  start_date date not null, end_date date null, priority_level text not null default 'NORMAL' check (priority_level in ('NORMAL','PREFERENTE','CRITICA')),
  target_response_minutes integer null check (target_response_minutes is null or target_response_minutes > 0), active boolean not null default true,
  notes text null, created_by uuid null references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists idx_customer_agreements_customer on public.customer_service_agreements(customer_id,active);

create table if not exists public.integrated_actions (
  id uuid primary key default gen_random_uuid(), action_code text not null unique, branch_id uuid null references public.branches(id), source_domain text not null,
  source_table text null, source_id uuid null, title text not null, description text null,
  priority text not null default 'MEDIA' check (priority in ('BAJA','MEDIA','ALTA','CRITICA')), owner_user_id uuid null references auth.users(id), due_date date null,
  status text not null default 'ABIERTA' check (status in ('ABIERTA','EN_PROGRESO','BLOQUEADA','COMPLETADA','CERRADA','CANCELADA')),
  evidence_url text null, effectiveness_status text not null default 'PENDIENTE' check (effectiveness_status in ('PENDIENTE','EFICAZ','NO_EFICAZ','NO_APLICA')),
  verified_by uuid null references auth.users(id), verified_at timestamptz null, closed_at timestamptz null,
  created_by uuid null references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists idx_integrated_actions_open on public.integrated_actions(branch_id,status,due_date);
create index if not exists idx_integrated_actions_source on public.integrated_actions(source_domain,source_table,source_id);

create table if not exists public.customer_feedback (
  id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.customers(id), branch_id uuid null references public.branches(id),
  feedback_date date not null default current_date, feedback_type text not null default 'SERVICIO' check (feedback_type in ('SERVICIO','QUEJA','RECONOCIMIENTO','SUGERENCIA','ENCUESTA')),
  rating integer null check (rating between 1 and 5), description text not null, requires_followup boolean not null default false,
  status text not null default 'ABIERTO' check (status in ('ABIERTO','EN_SEGUIMIENTO','CERRADO')), linked_action_id uuid null references public.integrated_actions(id),
  created_by uuid null references auth.users(id), created_at timestamptz not null default now()
);
create index if not exists idx_customer_feedback_customer on public.customer_feedback(customer_id,feedback_date desc);

alter table public.value_chain_stage_catalog enable row level security;
alter table public.donor_campaigns enable row level security;
alter table public.customer_service_agreements enable row level security;
alter table public.integrated_actions enable row level security;
alter table public.customer_feedback enable row level security;

drop policy if exists value_chain_stage_read on public.value_chain_stage_catalog;
create policy value_chain_stage_read on public.value_chain_stage_catalog for select to authenticated using (public.has_permission('VALUE_CHAIN_VIEW'));
drop policy if exists donor_campaigns_read on public.donor_campaigns;
create policy donor_campaigns_read on public.donor_campaigns for select to authenticated using (public.has_permission('DONOR_OUTREACH_VIEW') and (branch_id is null or public.can_access_branch(branch_id)));
drop policy if exists donor_campaigns_write on public.donor_campaigns;
create policy donor_campaigns_write on public.donor_campaigns for all to authenticated using (public.has_permission('DONOR_OUTREACH_WRITE') and (branch_id is null or public.can_access_branch(branch_id))) with check (public.has_permission('DONOR_OUTREACH_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));
drop policy if exists customer_agreements_read on public.customer_service_agreements;
create policy customer_agreements_read on public.customer_service_agreements for select to authenticated using (public.has_permission('CUSTOMER_VIEW') and (branch_id is null or public.can_access_branch(branch_id)));
drop policy if exists customer_agreements_write on public.customer_service_agreements;
create policy customer_agreements_write on public.customer_service_agreements for all to authenticated using (public.has_permission('CUSTOMER_WRITE') and (branch_id is null or public.can_access_branch(branch_id))) with check (public.has_permission('CUSTOMER_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));
drop policy if exists integrated_actions_read on public.integrated_actions;
create policy integrated_actions_read on public.integrated_actions for select to authenticated using (public.has_permission('ACTIONS_VIEW') and (branch_id is null or public.can_access_branch(branch_id)));
drop policy if exists integrated_actions_write on public.integrated_actions;
create policy integrated_actions_write on public.integrated_actions for all to authenticated using (public.has_permission('ACTIONS_WRITE') and (branch_id is null or public.can_access_branch(branch_id))) with check (public.has_permission('ACTIONS_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));
drop policy if exists customer_feedback_read on public.customer_feedback;
create policy customer_feedback_read on public.customer_feedback for select to authenticated using (public.has_permission('CUSTOMER_VIEW') and (branch_id is null or public.can_access_branch(branch_id)));
drop policy if exists customer_feedback_write on public.customer_feedback;
create policy customer_feedback_write on public.customer_feedback for all to authenticated using (public.has_permission('CUSTOMER_WRITE') and (branch_id is null or public.can_access_branch(branch_id))) with check (public.has_permission('CUSTOMER_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));

drop policy if exists customers_read on public.customers;
create policy customers_read on public.customers for select to authenticated using (public.has_permission('CUSTOMER_VIEW') or public.has_permission('SALES_VIEW') or public.has_permission('DISPATCH_VIEW'));
drop policy if exists customers_write on public.customers;
create policy customers_write on public.customers for all to authenticated using (public.has_permission('CUSTOMER_WRITE')) with check (public.has_permission('CUSTOMER_WRITE'));
drop policy if exists demand_branch_read on public.clinical_demand_requests;
create policy demand_branch_read on public.clinical_demand_requests for select to authenticated using (public.can_access_branch(branch_id) and (public.has_permission('VALUE_CHAIN_VIEW') or public.has_permission('SUPPLY_VIEW') or public.has_permission('DISPATCH_VIEW')));
drop policy if exists demand_branch_write on public.clinical_demand_requests;
create policy demand_branch_write on public.clinical_demand_requests for all to authenticated using (public.can_access_branch(branch_id) and (public.has_permission('VALUE_CHAIN_WRITE') or public.has_permission('SUPPLY_WRITE') or public.has_permission('DISPATCH_WRITE'))) with check (public.can_access_branch(branch_id) and (public.has_permission('VALUE_CHAIN_WRITE') or public.has_permission('SUPPLY_WRITE') or public.has_permission('DISPATCH_WRITE')));

create or replace view public.vw_donor_campaign_performance with (security_invoker=true) as
select c.id,c.campaign_code,c.branch_id,c.name,c.channel,c.start_date,c.end_date,c.target_donors,c.status,
       count(d.id)::integer as donations_captured, greatest(c.target_donors-count(d.id),0)::integer as remaining_to_target,
       case when c.target_donors>0 then round((count(d.id)::numeric/c.target_donors)*100,1) else 0 end as attainment_pct
from public.donor_campaigns c left join public.donations d on d.campaign_id=c.id group by c.id;

create or replace view public.vw_integrated_actions_open with (security_invoker=true) as
select a.*, case when a.due_date is not null and a.due_date<current_date and a.status not in ('CERRADA','CANCELADA') then true else false end as overdue
from public.integrated_actions a where a.status not in ('CERRADA','CANCELADA');

create or replace view public.vw_customer_value_summary with (security_invoker=true) as
select c.id as customer_id,c.name,c.customer_type,c.active,
       coalesce(sum(s.total_amount),0)::numeric as billed_amount, coalesce(sum(s.collected_amount),0)::numeric as collected_amount,
       count(distinct s.id)::integer as sales_count, count(distinct f.id) filter (where f.status<>'CERRADO')::integer as open_feedback,
       round(avg(f.rating)::numeric,2) as avg_rating
from public.customers c left join public.operational_sales s on lower(s.customer_name)=lower(c.name)
left join public.customer_feedback f on f.customer_id=c.id group by c.id;

create or replace view public.vw_value_chain_scorecard with (security_invoker=true) as
select b.id as branch_id,b.code as branch_code,b.name as branch_name,
  (select count(*) from public.clinical_demand_requests d where d.branch_id=b.id and d.status not in ('CERRADA','CANCELADA','ATENDIDA'))::integer as open_demand,
  (select coalesce(sum(i.quantity),0) from public.blood_inventory_units i where i.branch_id=b.id and i.inventory_status='AVAILABLE')::numeric as available_units,
  (select count(*) from public.dispatches x where x.branch_id=b.id and x.dispatch_date>=current_date-30 and x.status not in ('CANCELADO','CANCELADA'))::integer as dispatches_30d,
  (select coalesce(sum(s.total_amount),0) from public.operational_sales s where s.branch_id=b.id and s.sale_date>=current_date-30)::numeric as billed_30d,
  (select coalesce(sum(s.collected_amount),0) from public.operational_sales s where s.branch_id=b.id and s.sale_date>=current_date-30)::numeric as collected_30d,
  (select count(*) from public.donor_campaigns c where (c.branch_id=b.id or c.branch_id is null) and c.status='ACTIVA')::integer as active_campaigns,
  (select count(*) from public.customer_feedback f where (f.branch_id=b.id or f.branch_id is null) and f.status<>'CERRADO')::integer as open_feedback,
  (select count(*) from public.integrated_actions a where (a.branch_id=b.id or a.branch_id is null) and a.status not in ('CERRADA','CANCELADA'))::integer as open_actions
from public.branches b where b.active=true;

grant select on public.value_chain_stage_catalog, public.donor_campaigns, public.customer_service_agreements, public.integrated_actions, public.customer_feedback, public.vw_donor_campaign_performance, public.vw_integrated_actions_open, public.vw_customer_value_summary, public.vw_value_chain_scorecard to authenticated;
grant insert,update,delete on public.donor_campaigns, public.customer_service_agreements, public.integrated_actions, public.customer_feedback to authenticated;
grant insert,update,delete on public.customers, public.clinical_demand_requests to authenticated;
