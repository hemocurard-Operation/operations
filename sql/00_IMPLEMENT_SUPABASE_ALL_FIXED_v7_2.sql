-- HEMOCURA OPERATIONS & QUALITY INTELLIGENCE SYSTEM
-- Instalador consolidado v7
-- Ejecutar en una base Supabase NUEVA.
-- Revise docs/IMPLEMENTATION_RUNBOOK.md antes de usar en producción.


-- ============================================================
-- 01_schema.sql
-- ============================================================

create extension if not exists pgcrypto;

create type sale_status as enum ('BORRADOR','CONFIRMADO','CERRADO','REABIERTO');
create type period_status as enum ('ABIERTO','VALIDACION','CONFIRMADO','CERRADO','REABIERTO');
create type movement_type as enum ('INITIAL','PURCHASE','TRANSFER_IN','TRANSFER_OUT','CONSUMPTION','DISPATCH','RETURN','DISCARD','ADJUSTMENT_POSITIVE','ADJUSTMENT_NEGATIVE');
create type severity_level as enum ('INFO','MEDIA','ALTA','CRITICA');

create table branches (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  branch_id uuid references branches(id),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table roles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  created_at timestamptz not null default now()
);

create table user_roles (
  user_id uuid not null references profiles(id) on delete cascade,
  role_id uuid not null references roles(id) on delete cascade,
  branch_id uuid references branches(id),
  primary key (user_id, role_id, branch_id)
);

create table products (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  category text,
  unit_of_measure text not null default 'unidad',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  customer_type text,
  tax_id text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table services (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table operational_periods (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references branches(id),
  period_date date not null,
  status period_status not null default 'ABIERTO',
  opened_at timestamptz not null default now(),
  confirmed_at timestamptz,
  closed_at timestamptz,
  reopened_at timestamptz,
  reopen_reason text,
  unique(branch_id, period_date)
);

create table dispatches (
  id uuid primary key default gen_random_uuid(),
  dispatch_date date not null,
  branch_id uuid not null references branches(id),
  customer_id uuid references customers(id),
  shift text,
  dispatch_type text not null default 'venta',
  status text not null default 'BORRADOR',
  notes text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  confirmed_at timestamptz
);

create table dispatch_lines (
  id uuid primary key default gen_random_uuid(),
  dispatch_id uuid not null references dispatches(id) on delete cascade,
  product_id uuid not null references products(id),
  units numeric(12,2) not null check (units >= 0),
  is_sale boolean not null default true,
  sale_generated boolean not null default false,
  created_at timestamptz not null default now()
);

create table inventory_movements (
  id uuid primary key default gen_random_uuid(),
  movement_date date not null,
  branch_id uuid not null references branches(id),
  product_id uuid not null references products(id),
  movement_type movement_type not null,
  quantity numeric(12,2) not null check (quantity >= 0),
  source_table text,
  source_id uuid,
  notes text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

create table cost_snapshots (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references products(id),
  service_id uuid references services(id),
  effective_from date not null,
  effective_to date,
  cost_per_unit numeric(14,4) not null check (cost_per_unit >= 0),
  status text not null default 'VALIDADO',
  source text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

create table price_versions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references products(id),
  service_id uuid references services(id),
  customer_type text,
  effective_from date not null,
  effective_to date,
  list_price numeric(14,2) not null check (list_price >= 0),
  created_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

create table daily_sales (
  id uuid primary key default gen_random_uuid(),
  sale_date date not null,
  branch_id uuid not null references branches(id),
  status sale_status not null default 'BORRADOR',
  total_units numeric(14,2) not null default 0,
  total_revenue numeric(14,2) not null default 0,
  total_cost numeric(14,2) not null default 0,
  gross_margin numeric(14,2) not null default 0,
  gross_margin_pct numeric(8,4),
  notes text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  confirmed_by uuid references profiles(id),
  confirmed_at timestamptz,
  closed_by uuid references profiles(id),
  closed_at timestamptz,
  reopened_by uuid references profiles(id),
  reopened_at timestamptz,
  reopen_reason text,
  unique(sale_date, branch_id)
);

create table daily_sale_lines (
  id uuid primary key default gen_random_uuid(),
  daily_sale_id uuid not null references daily_sales(id) on delete cascade,
  product_id uuid not null references products(id),
  service_id uuid references services(id),
  customer_id uuid references customers(id),
  source_type text not null default 'MANUAL',
  source_dispatch_line_id uuid references dispatch_lines(id),
  source_units numeric(12,2) not null default 0,
  adjustment_units numeric(12,2) not null default 0,
  final_units numeric(12,2) generated always as (source_units + adjustment_units) stored,
  adjustment_reason text,
  unit_price numeric(14,2) not null default 0,
  list_price numeric(14,2),
  price_variance numeric(14,2) generated always as (unit_price - coalesce(list_price,unit_price)) stored,
  cost_snapshot_id uuid references cost_snapshots(id),
  cost_per_unit numeric(14,4) not null default 0,
  total_amount numeric(14,2) generated always as ((source_units + adjustment_units) * unit_price) stored,
  total_cost numeric(14,2) generated always as ((source_units + adjustment_units) * cost_per_unit) stored,
  gross_margin numeric(14,2) generated always as (((source_units + adjustment_units) * unit_price) - ((source_units + adjustment_units) * cost_per_unit)) stored,
  invoice_date date,
  revenue_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (source_units + adjustment_units >= 0),
  check (adjustment_units = 0 or adjustment_reason is not null)
);

create unique index ux_daily_sale_source_dispatch
on daily_sale_lines(source_dispatch_line_id)
where source_dispatch_line_id is not null;

create table sales_targets (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references branches(id),
  product_id uuid references products(id),
  period_type text not null check (period_type in ('DIARIO','SEMANAL','MENSUAL')),
  period_start date not null,
  period_end date not null,
  target_units numeric(14,2),
  target_revenue numeric(14,2),
  created_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

create table kpi_thresholds (
  id uuid primary key default gen_random_uuid(),
  kpi_code text not null unique,
  green_min numeric,
  yellow_min numeric,
  red_max numeric,
  config jsonb not null default '{}'::jsonb,
  active boolean not null default true
);

create table incidents (
  id uuid primary key default gen_random_uuid(),
  incident_code text unique,
  incident_date date not null,
  incident_time time,
  branch_id uuid references branches(id),
  reported_by uuid references profiles(id),
  classification text,
  process_name text,
  severity integer check (severity between 1 and 5),
  description text not null,
  patient_or_donor_affected boolean,
  impact_detail text,
  immediate_action text,
  evidence_url text,
  requires_quality_followup boolean not null default false,
  created_at timestamptz not null default now()
);

create table alerts (
  id uuid primary key default gen_random_uuid(),
  alert_date timestamptz not null default now(),
  branch_id uuid references branches(id),
  category text not null,
  severity severity_level not null,
  source_table text,
  source_id uuid,
  title text not null,
  description text,
  status text not null default 'ABIERTA',
  assigned_to uuid references profiles(id),
  due_at timestamptz,
  closed_at timestamptz
);

create table approvals (
  id uuid primary key default gen_random_uuid(),
  approval_type text not null,
  source_table text not null,
  source_id uuid not null,
  requested_by uuid references profiles(id),
  requested_at timestamptz not null default now(),
  approved_by uuid references profiles(id),
  approved_at timestamptz,
  status text not null default 'PENDIENTE',
  reason text
);

create table audit_log (
  id bigserial primary key,
  table_name text not null,
  record_id uuid,
  action text not null,
  field_name text,
  old_value jsonb,
  new_value jsonb,
  reason text,
  user_id uuid,
  branch_id uuid,
  created_at timestamptz not null default now()
);

create index idx_dispatches_branch_date on dispatches(branch_id, dispatch_date);
create index idx_inventory_movements_branch_date on inventory_movements(branch_id, movement_date);
create index idx_daily_sales_branch_date on daily_sales(branch_id, sale_date);
create index idx_daily_sale_lines_product on daily_sale_lines(product_id);
create index idx_cost_snapshots_effective on cost_snapshots(product_id, effective_from, effective_to);


-- ============================================================
-- 02_rls.sql
-- ============================================================

alter table profiles enable row level security;
alter table branches enable row level security;
alter table products enable row level security;
alter table customers enable row level security;
alter table services enable row level security;
alter table dispatches enable row level security;
alter table dispatch_lines enable row level security;
alter table inventory_movements enable row level security;
alter table daily_sales enable row level security;
alter table daily_sale_lines enable row level security;
alter table incidents enable row level security;
alter table alerts enable row level security;

create or replace function public.current_branch_id()
returns uuid language sql stable security definer set search_path=public as $$
  select branch_id from profiles where id = auth.uid();
$$;

create or replace function public.has_role(role_code text)
returns boolean language sql stable security definer set search_path=public as $$
  select exists (
    select 1 from user_roles ur
    join roles r on r.id = ur.role_id
    where ur.user_id = auth.uid() and r.code = role_code
  );
$$;

create or replace function public.can_access_branch(target_branch uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select public.has_role('ADMIN')
      or public.has_role('GERENCIA_OPERATIVA')
      or public.has_role('GERENCIA_GENERAL')
      or public.has_role('CALIDAD')
      or public.has_role('FINANZAS')
      or target_branch = public.current_branch_id();
$$;

create policy branches_read on branches for select using (auth.role()='authenticated');
create policy products_read on products for select using (auth.role()='authenticated');
create policy services_read on services for select using (auth.role()='authenticated');
create policy customers_read on customers for select using (auth.role()='authenticated');

create policy dispatches_branch_select on dispatches for select using (public.can_access_branch(branch_id));
create policy dispatches_branch_insert on dispatches for insert with check (public.can_access_branch(branch_id));
create policy dispatches_branch_update on dispatches for update using (public.can_access_branch(branch_id)) with check (public.can_access_branch(branch_id));

create policy dispatch_lines_select on dispatch_lines for select using (
  exists(select 1 from dispatches d where d.id=dispatch_id and public.can_access_branch(d.branch_id))
);
create policy dispatch_lines_write on dispatch_lines for all using (
  exists(select 1 from dispatches d where d.id=dispatch_id and public.can_access_branch(d.branch_id))
) with check (
  exists(select 1 from dispatches d where d.id=dispatch_id and public.can_access_branch(d.branch_id))
);

create policy inventory_movements_select on inventory_movements for select using (public.can_access_branch(branch_id));
create policy inventory_movements_insert on inventory_movements for insert with check (public.can_access_branch(branch_id));

create policy daily_sales_select on daily_sales for select using (public.can_access_branch(branch_id));
create policy daily_sales_insert on daily_sales for insert with check (public.can_access_branch(branch_id));
create policy daily_sales_update on daily_sales for update using (
  public.can_access_branch(branch_id)
  and (status in ('BORRADOR','REABIERTO') or public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA'))
) with check (public.can_access_branch(branch_id));

create policy daily_sale_lines_select on daily_sale_lines for select using (
  exists(select 1 from daily_sales ds where ds.id=daily_sale_id and public.can_access_branch(ds.branch_id))
);
create policy daily_sale_lines_write on daily_sale_lines for all using (
  exists(select 1 from daily_sales ds where ds.id=daily_sale_id and public.can_access_branch(ds.branch_id)
    and (ds.status in ('BORRADOR','REABIERTO') or public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA')))
) with check (
  exists(select 1 from daily_sales ds where ds.id=daily_sale_id and public.can_access_branch(ds.branch_id))
);

create policy incidents_select on incidents for select using (branch_id is null or public.can_access_branch(branch_id));
create policy incidents_insert on incidents for insert with check (branch_id is null or public.can_access_branch(branch_id));
create policy alerts_select on alerts for select using (branch_id is null or public.can_access_branch(branch_id));


-- ============================================================
-- 03_functions.sql
-- ============================================================

create or replace function public.recalc_daily_sale(p_daily_sale_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  update daily_sales ds
  set total_units = x.units,
      total_revenue = x.revenue,
      total_cost = x.cost,
      gross_margin = x.margin,
      gross_margin_pct = case when x.revenue = 0 then null else x.margin/x.revenue end,
      updated_at = now()
  from (
    select coalesce(sum(final_units),0) units,
           coalesce(sum(total_amount),0) revenue,
           coalesce(sum(total_cost),0) cost,
           coalesce(sum(gross_margin),0) margin
    from daily_sale_lines where daily_sale_id=p_daily_sale_id
  ) x
  where ds.id=p_daily_sale_id;
end $$;

create or replace function public.generate_sale_from_dispatch(p_dispatch_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare
  v_dispatch dispatches%rowtype;
  v_sale_id uuid;
begin
  select * into v_dispatch from dispatches where id=p_dispatch_id;
  if not found then raise exception 'Despacho no existe'; end if;
  if v_dispatch.status <> 'CONFIRMADO' then raise exception 'El despacho debe estar CONFIRMADO'; end if;

  insert into daily_sales(sale_date, branch_id, created_by)
  values(v_dispatch.dispatch_date, v_dispatch.branch_id, auth.uid())
  on conflict (sale_date,branch_id) do update set updated_at=now()
  returning id into v_sale_id;

  insert into daily_sale_lines(
    daily_sale_id, product_id, customer_id, source_type,
    source_dispatch_line_id, source_units, unit_price, cost_per_unit
  )
  select v_sale_id, dl.product_id, v_dispatch.customer_id, 'DISPATCH', dl.id, dl.units,
         coalesce((select pv.list_price from price_versions pv
                   where pv.product_id=dl.product_id
                     and pv.effective_from<=v_dispatch.dispatch_date
                     and (pv.effective_to is null or pv.effective_to>=v_dispatch.dispatch_date)
                   order by pv.effective_from desc limit 1),0),
         coalesce((select cs.cost_per_unit from cost_snapshots cs
                   where cs.product_id=dl.product_id
                     and cs.effective_from<=v_dispatch.dispatch_date
                     and (cs.effective_to is null or cs.effective_to>=v_dispatch.dispatch_date)
                   order by cs.effective_from desc limit 1),0)
  from dispatch_lines dl
  where dl.dispatch_id=p_dispatch_id and dl.is_sale=true
  on conflict (source_dispatch_line_id) do nothing;

  update dispatch_lines set sale_generated=true where dispatch_id=p_dispatch_id and is_sale=true;
  perform public.recalc_daily_sale(v_sale_id);
  return v_sale_id;
end $$;

create or replace function public.reconcile_inventory(p_branch_id uuid, p_date date)
returns table(product_id uuid, theoretical_qty numeric, physical_qty numeric, variance numeric)
language sql stable as $$
  with mv as (
    select im.product_id,
      sum(case im.movement_type
        when 'INITIAL' then im.quantity
        when 'PURCHASE' then im.quantity
        when 'TRANSFER_IN' then im.quantity
        when 'RETURN' then im.quantity
        when 'ADJUSTMENT_POSITIVE' then im.quantity
        when 'TRANSFER_OUT' then -im.quantity
        when 'CONSUMPTION' then -im.quantity
        when 'DISPATCH' then -im.quantity
        when 'DISCARD' then -im.quantity
        when 'ADJUSTMENT_NEGATIVE' then -im.quantity end) theoretical_qty
    from inventory_movements im
    where im.branch_id=p_branch_id and im.movement_date<=p_date
    group by im.product_id
  )
  select mv.product_id, mv.theoretical_qty, null::numeric physical_qty, null::numeric variance from mv;
$$;


-- ============================================================
-- 04_triggers.sql
-- ============================================================

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;

create trigger trg_daily_sales_updated before update on daily_sales
for each row execute function public.set_updated_at();
create trigger trg_daily_sale_lines_updated before update on daily_sale_lines
for each row execute function public.set_updated_at();

create or replace function public.trg_recalc_daily_sale()
returns trigger language plpgsql as $$
begin
  if TG_OP = 'DELETE' then
    perform public.recalc_daily_sale(old.daily_sale_id);
    return old;
  else
    perform public.recalc_daily_sale(new.daily_sale_id);
    return new;
  end if;
end $$;

create trigger trg_sale_line_recalc
after insert or update or delete on daily_sale_lines
for each row execute function public.trg_recalc_daily_sale();

create or replace function public.audit_row_change()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into audit_log(table_name,record_id,action,old_value,new_value,user_id,created_at)
  values(TG_TABLE_NAME, coalesce(new.id,old.id), TG_OP,
         case when TG_OP in ('UPDATE','DELETE') then to_jsonb(old) else null end,
         case when TG_OP in ('INSERT','UPDATE') then to_jsonb(new) else null end,
         auth.uid(), now());
  if TG_OP = 'DELETE' then return old; else return new; end if;
end $$;

create trigger audit_daily_sales after insert or update or delete on daily_sales
for each row execute function public.audit_row_change();
create trigger audit_daily_sale_lines after insert or update or delete on daily_sale_lines
for each row execute function public.audit_row_change();
create trigger audit_dispatches after insert or update or delete on dispatches
for each row execute function public.audit_row_change();


-- ============================================================
-- 05_views.sql
-- ============================================================

create or replace view vw_daily_sales as
select ds.sale_date, b.id branch_id, b.name branch,
       ds.status, ds.total_units, ds.total_revenue, ds.total_cost,
       ds.gross_margin, ds.gross_margin_pct
from daily_sales ds join branches b on b.id=ds.branch_id;

create or replace view vw_sales_by_product as
select ds.sale_date, ds.branch_id, dsl.product_id, p.code product_code, p.name product_name,
       sum(dsl.final_units) units,
       sum(dsl.total_amount) revenue,
       sum(dsl.total_cost) cost,
       sum(dsl.gross_margin) margin
from daily_sales ds
join daily_sale_lines dsl on dsl.daily_sale_id=ds.id
join products p on p.id=dsl.product_id
group by ds.sale_date, ds.branch_id, dsl.product_id, p.code, p.name;

create or replace view vw_dispatch_sales_reconciliation as
select d.dispatch_date, d.branch_id, dl.product_id,
       sum(dl.units) filter (where dl.is_sale) dispatched_sale_units,
       coalesce(sum(dsl.final_units),0) recognized_sale_units,
       sum(dl.units) filter (where dl.is_sale) - coalesce(sum(dsl.final_units),0) difference_units
from dispatches d
join dispatch_lines dl on dl.dispatch_id=d.id
left join daily_sale_lines dsl on dsl.source_dispatch_line_id=dl.id
group by d.dispatch_date,d.branch_id,dl.product_id;

create or replace view vw_pending_invoice as
select ds.sale_date, ds.branch_id, dsl.customer_id, dsl.product_id,
       dsl.final_units, dsl.total_amount,
       current_date - ds.sale_date age_days
from daily_sales ds
join daily_sale_lines dsl on dsl.daily_sale_id=ds.id
where dsl.invoice_date is null and dsl.final_units>0;

create or replace view vw_daily_operations as
select ds.sale_date as operation_date, ds.branch_id,
       ds.total_units sold_units, ds.total_revenue revenue,
       ds.total_cost cost, ds.gross_margin margin,
       coalesce(x.dispatched_units,0) dispatched_units
from daily_sales ds
left join (
  select d.dispatch_date, d.branch_id, sum(dl.units) dispatched_units
  from dispatches d join dispatch_lines dl on dl.dispatch_id=d.id
  group by d.dispatch_date,d.branch_id
) x on x.dispatch_date=ds.sale_date and x.branch_id=ds.branch_id;


-- ============================================================
-- 06_seed.sql
-- ============================================================

insert into branches(code,name) values
('STI','Santiago'),('POP','Puerto Plata'),('TEN','Tenares')
on conflict do nothing;

insert into roles(code,name) values
('ADMIN','Administrador'),
('GERENCIA_OPERATIVA','Gerencia Operativa'),
('GERENCIA_GENERAL','Gerencia General'),
('CALIDAD','Calidad'),
('LABORATORIO','Laboratorio'),
('INVENTARIO','Inventario'),
('FINANZAS','Finanzas'),
('SUCURSAL','Sucursal'),
('CONSULTA','Consulta')
on conflict do nothing;

insert into products(code,name) values
('SANGRE_TOTAL','Sangre Total'),
('PG','Paquete Globular'),
('PG_LEUCO','Paquete Globular Leucorreducido'),
('PLASMA','Plasma'),
('PLAQUETAS_AFERESIS','Plaquetas por Aféresis'),
('HEMATIES_LAVADOS','Lavado de Hematíes')
on conflict do nothing;

insert into kpi_thresholds(kpi_code,green_min,yellow_min,red_max,config) values
('SALES_TARGET_PCT',100,80,79.999,'{"unit":"percent"}'),
('DISPATCH_SALE_RATIO',98,95,94.999,'{"unit":"percent"}')
on conflict do nothing;


-- ============================================================
-- 07_migration.sql
-- ============================================================

-- Staging tables: load Excel/CSV exports here before normalization.
create table if not exists stg_resp_despachos(
  source_row bigint,
  timestamp_raw text,
  fecha_raw text,
  turno text,
  pg_leuco text,
  sangre_total text,
  paquete_globular text,
  plaquetas_aferesis text,
  hematies_lavados text,
  observaciones text,
  sucursal text
);

create table if not exists stg_requerimientos(
  source_row bigint,
  payload jsonb not null,
  imported_at timestamptz not null default now()
);

-- Example normalization pattern for wide dispatch rows -> line items.
-- Implement after CSV import and branch/product mapping validation.
-- Do not infer sale_date or invoice_date from dispatch_date when observations indicate a different date.

create table if not exists migration_issues(
  id bigserial primary key,
  source_name text not null,
  source_row text,
  issue_type text not null,
  details text,
  status text not null default 'OPEN',
  created_at timestamptz not null default now()
);


-- ============================================================
-- 08_security_hardening.sql
-- ============================================================

-- HemoCura v4 - endurecimiento del Data API y vistas BI
alter table roles enable row level security;
alter table user_roles enable row level security;
alter table operational_periods enable row level security;
alter table cost_snapshots enable row level security;
alter table price_versions enable row level security;
alter table sales_targets enable row level security;
alter table kpi_thresholds enable row level security;
alter table approvals enable row level security;
alter table audit_log enable row level security;

create policy profiles_self_or_management_select on profiles for select using (
  id = auth.uid() or public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('GERENCIA_GENERAL')
);
create policy roles_authenticated_select on roles for select using (auth.role()='authenticated');
create policy user_roles_self_or_admin_select on user_roles for select using (
  user_id = auth.uid() or public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA')
);
create policy operational_periods_select on operational_periods for select using (public.can_access_branch(branch_id));
create policy operational_periods_write on operational_periods for all using (public.can_access_branch(branch_id)) with check (public.can_access_branch(branch_id));
create policy cost_snapshots_select on cost_snapshots for select using (auth.role()='authenticated');
create policy price_versions_select on price_versions for select using (auth.role()='authenticated');
create policy sales_targets_select on sales_targets for select using (public.can_access_branch(branch_id));
create policy kpi_thresholds_select on kpi_thresholds for select using (auth.role()='authenticated');
create policy approvals_select on approvals for select using (auth.role()='authenticated');
create policy audit_log_management_select on audit_log for select using (
  public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('CALIDAD')
);

-- Permisos mínimos del Data API. RLS sigue siendo la barrera efectiva por fila.
grant usage on schema public to authenticated;
grant select on branches, products, customers, services, roles, user_roles, profiles,
  operational_periods, cost_snapshots, price_versions, sales_targets, kpi_thresholds,
  incidents, alerts, approvals, audit_log to authenticated;
grant select, insert, update on dispatches, dispatch_lines, inventory_movements, daily_sales, daily_sale_lines to authenticated;
grant execute on function public.current_branch_id() to authenticated;
grant execute on function public.has_role(text) to authenticated;
grant execute on function public.can_access_branch(uuid) to authenticated;
grant execute on function public.generate_sale_from_dispatch(uuid) to authenticated;
grant execute on function public.reconcile_inventory(uuid,date) to authenticated;

-- Recrear vistas como security_invoker para que respeten permisos/RLS del usuario invocante.
create or replace view vw_daily_sales with (security_invoker=true) as
select ds.sale_date, b.id branch_id, b.name branch,
       ds.status, ds.total_units, ds.total_revenue, ds.total_cost,
       ds.gross_margin, ds.gross_margin_pct
from daily_sales ds join branches b on b.id=ds.branch_id;

create or replace view vw_sales_by_product with (security_invoker=true) as
select ds.sale_date, ds.branch_id, dsl.product_id, p.code product_code, p.name product_name,
       sum(dsl.final_units) units,
       sum(dsl.total_amount) revenue,
       sum(dsl.total_cost) cost,
       sum(dsl.gross_margin) margin
from daily_sales ds
join daily_sale_lines dsl on dsl.daily_sale_id=ds.id
join products p on p.id=dsl.product_id
group by ds.sale_date, ds.branch_id, dsl.product_id, p.code, p.name;

create or replace view vw_dispatch_sales_reconciliation with (security_invoker=true) as
select d.dispatch_date, d.branch_id, dl.product_id,
       sum(dl.units) filter (where dl.is_sale) dispatched_sale_units,
       coalesce(sum(dsl.final_units),0) recognized_sale_units,
       sum(dl.units) filter (where dl.is_sale) - coalesce(sum(dsl.final_units),0) difference_units
from dispatches d
join dispatch_lines dl on dl.dispatch_id=d.id
left join daily_sale_lines dsl on dsl.source_dispatch_line_id=dl.id
group by d.dispatch_date,d.branch_id,dl.product_id;

create or replace view vw_pending_invoice with (security_invoker=true) as
select ds.sale_date, ds.branch_id, dsl.customer_id, dsl.product_id,
       dsl.final_units, dsl.total_amount,
       current_date - ds.sale_date age_days
from daily_sales ds
join daily_sale_lines dsl on dsl.daily_sale_id=ds.id
where dsl.invoice_date is null and dsl.final_units>0;

create or replace view vw_daily_operations with (security_invoker=true) as
select ds.sale_date as operation_date, ds.branch_id,
       ds.total_units sold_units, ds.total_revenue revenue,
       ds.total_cost cost, ds.gross_margin margin,
       coalesce(x.dispatched_units,0) dispatched_units
from daily_sales ds
left join (
  select d.dispatch_date, d.branch_id, sum(dl.units) dispatched_units
  from dispatches d join dispatch_lines dl on dl.dispatch_id=d.id
  group by d.dispatch_date,d.branch_id
) x on x.dispatch_date=ds.sale_date and x.branch_id=ds.branch_id;

grant select on vw_daily_sales, vw_sales_by_product, vw_dispatch_sales_reconciliation, vw_pending_invoice, vw_daily_operations to authenticated;


-- ============================================================
-- 09_quality_core.sql
-- ============================================================

-- HemoCura v4 - núcleo mínimo del Sistema de Gestión de Calidad
create table if not exists quality_processes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  process_type text not null check(process_type in ('ESTRATEGICO','OPERATIVO','APOYO')),
  owner_user_id uuid references profiles(id),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists quality_indicators (
  id uuid primary key default gen_random_uuid(),
  process_id uuid not null references quality_processes(id),
  code text not null unique,
  name text not null,
  formula_description text,
  frequency text not null default 'DIARIO',
  target_value numeric,
  warning_value numeric,
  direction text not null default 'HIGHER_IS_BETTER' check(direction in ('HIGHER_IS_BETTER','LOWER_IS_BETTER','RANGE')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists quality_measurements (
  id uuid primary key default gen_random_uuid(),
  indicator_id uuid not null references quality_indicators(id),
  branch_id uuid references branches(id),
  measurement_date date not null,
  value numeric not null,
  numerator numeric,
  denominator numeric,
  status text not null default 'PENDIENTE',
  source_table text,
  source_id uuid,
  notes text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  unique(indicator_id, branch_id, measurement_date)
);

create table if not exists nonconformities (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  incident_id uuid references incidents(id),
  branch_id uuid references branches(id),
  process_id uuid references quality_processes(id),
  detected_at timestamptz not null default now(),
  description text not null,
  root_cause text,
  status text not null default 'ABIERTA',
  owner_user_id uuid references profiles(id),
  due_date date,
  created_at timestamptz not null default now()
);

create table if not exists capa (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  nonconformity_id uuid references nonconformities(id),
  problem text not null,
  root_cause text,
  action_plan text not null,
  owner_user_id uuid references profiles(id),
  due_date date,
  status text not null default 'ABIERTA',
  effectiveness_status text not null default 'PENDIENTE',
  effectiveness_notes text,
  closed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table quality_processes enable row level security;
alter table quality_indicators enable row level security;
alter table quality_measurements enable row level security;
alter table nonconformities enable row level security;
alter table capa enable row level security;

create policy quality_processes_read on quality_processes for select using (auth.role()='authenticated');
create policy quality_indicators_read on quality_indicators for select using (auth.role()='authenticated');
create policy quality_measurements_read on quality_measurements for select using (branch_id is null or public.can_access_branch(branch_id));
create policy quality_measurements_write on quality_measurements for all using (
  branch_id is null or public.can_access_branch(branch_id)
) with check (branch_id is null or public.can_access_branch(branch_id));
create policy nonconformities_read on nonconformities for select using (branch_id is null or public.can_access_branch(branch_id));
create policy capa_quality_read on capa for select using (auth.role()='authenticated');
create policy quality_management_write on nonconformities for all using (
  public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')
) with check (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
create policy capa_management_write on capa for all using (
  public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')
) with check (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));

grant select on quality_processes, quality_indicators, quality_measurements, nonconformities, capa to authenticated;
grant insert, update on quality_measurements to authenticated;
grant insert, update on nonconformities, capa to authenticated;

create or replace view vw_quality_today with (security_invoker=true) as
select qm.measurement_date, qm.branch_id, qi.code indicator_code, qi.name indicator_name,
       qm.value, qm.status, qp.code process_code, qp.name process_name
from quality_measurements qm
join quality_indicators qi on qi.id=qm.indicator_id
join quality_processes qp on qp.id=qi.process_id;
grant select on vw_quality_today to authenticated;


-- ============================================================
-- 10_operational_v5.sql
-- ============================================================

-- HemoCura v5 - flujos operativos ejecutables

-- Conteos físicos para conciliación real de inventario
create table if not exists physical_inventory_counts (
  id uuid primary key default gen_random_uuid(),
  count_date date not null,
  branch_id uuid not null references branches(id),
  product_id uuid not null references products(id),
  physical_qty numeric(12,2) not null check (physical_qty >= 0),
  notes text,
  counted_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  unique(count_date, branch_id, product_id)
);

-- Evidencia diaria de conciliación/cierre
create table if not exists daily_close_checks (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references branches(id),
  check_date date not null,
  inventory_ok boolean not null default false,
  commercial_ok boolean not null default false,
  quality_ok boolean not null default false,
  inventory_variances integer not null default 0,
  commercial_variances integer not null default 0,
  open_critical_quality integer not null default 0,
  notes text,
  checked_by uuid references profiles(id),
  checked_at timestamptz not null default now(),
  unique(branch_id, check_date)
);

alter table physical_inventory_counts enable row level security;
alter table daily_close_checks enable row level security;

create policy physical_inventory_counts_select on physical_inventory_counts
for select using (public.can_access_branch(branch_id));
create policy physical_inventory_counts_write on physical_inventory_counts
for all using (public.can_access_branch(branch_id))
with check (public.can_access_branch(branch_id));

create policy daily_close_checks_select on daily_close_checks
for select using (public.can_access_branch(branch_id));
create policy daily_close_checks_write on daily_close_checks
for all using (public.can_access_branch(branch_id))
with check (public.can_access_branch(branch_id));

grant select, insert, update on physical_inventory_counts, daily_close_checks to authenticated;

-- Un movimiento generado por una línea de despacho sólo puede existir una vez.
create unique index if not exists ux_inventory_dispatch_line
on inventory_movements(source_table, source_id, movement_type)
where source_table='dispatch_lines' and movement_type='DISPATCH';

-- Confirma despacho, crea movimientos físicos y genera ventas comerciales una sola vez.
create or replace function public.confirm_dispatch(p_dispatch_id uuid)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_dispatch dispatches%rowtype;
  v_sale_id uuid;
begin
  select * into v_dispatch from dispatches where id=p_dispatch_id for update;
  if not found then raise exception 'Despacho no existe'; end if;
  if not public.can_access_branch(v_dispatch.branch_id) then raise exception 'Sin acceso a la sucursal'; end if;
  if v_dispatch.status='CONFIRMADO' then
    select ds.id into v_sale_id from daily_sales ds
    join daily_sale_lines dsl on dsl.daily_sale_id=ds.id
    join dispatch_lines dl on dl.id=dsl.source_dispatch_line_id
    where dl.dispatch_id=p_dispatch_id limit 1;
    return v_sale_id;
  end if;
  if not exists(select 1 from dispatch_lines where dispatch_id=p_dispatch_id and units>0) then
    raise exception 'El despacho no tiene líneas';
  end if;

  update dispatches set status='CONFIRMADO', confirmed_at=now() where id=p_dispatch_id;

  insert into inventory_movements(movement_date,branch_id,product_id,movement_type,quantity,source_table,source_id,notes,created_by)
  select v_dispatch.dispatch_date, v_dispatch.branch_id, dl.product_id, 'DISPATCH', dl.units,
         'dispatch_lines', dl.id, 'Generado al confirmar despacho', auth.uid()
  from dispatch_lines dl
  where dl.dispatch_id=p_dispatch_id
  on conflict (source_table,source_id,movement_type) where source_table='dispatch_lines' and movement_type='DISPATCH'
  do nothing;

  if exists(select 1 from dispatch_lines where dispatch_id=p_dispatch_id and is_sale=true) then
    v_sale_id := public.generate_sale_from_dispatch(p_dispatch_id);
  end if;
  return v_sale_id;
end $$;

grant execute on function public.confirm_dispatch(uuid) to authenticated;

-- Ajuste controlado de una línea de venta: siempre requiere motivo.
create or replace function public.adjust_sale_line(p_line_id uuid, p_adjustment numeric, p_reason text)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_branch uuid;
  v_status sale_status;
begin
  if p_reason is null or length(trim(p_reason))<3 then raise exception 'El motivo es obligatorio'; end if;
  select ds.branch_id, ds.status into v_branch, v_status
  from daily_sale_lines dsl join daily_sales ds on ds.id=dsl.daily_sale_id
  where dsl.id=p_line_id;
  if v_branch is null then raise exception 'Línea no existe'; end if;
  if not public.can_access_branch(v_branch) then raise exception 'Sin acceso'; end if;
  if v_status not in ('BORRADOR','REABIERTO') and not (public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA')) then
    raise exception 'La venta no está editable';
  end if;
  update daily_sale_lines set adjustment_units=p_adjustment, adjustment_reason=p_reason where id=p_line_id;
end $$;
grant execute on function public.adjust_sale_line(uuid,numeric,text) to authenticated;

-- Inventario teórico + último conteo físico del día.
create or replace view vw_inventory_status with (security_invoker=true) as
with mv as (
  select im.branch_id, im.product_id,
    sum(case im.movement_type
      when 'INITIAL' then im.quantity when 'PURCHASE' then im.quantity when 'TRANSFER_IN' then im.quantity
      when 'RETURN' then im.quantity when 'ADJUSTMENT_POSITIVE' then im.quantity
      when 'TRANSFER_OUT' then -im.quantity when 'CONSUMPTION' then -im.quantity when 'DISPATCH' then -im.quantity
      when 'DISCARD' then -im.quantity when 'ADJUSTMENT_NEGATIVE' then -im.quantity else 0 end) theoretical_qty
  from inventory_movements im group by im.branch_id, im.product_id
), pc as (
  select distinct on (branch_id,product_id) branch_id,product_id,count_date,physical_qty
  from physical_inventory_counts order by branch_id,product_id,count_date desc,created_at desc
)
select b.id branch_id,b.name branch,p.id product_id,p.code product_code,p.name product_name,
       coalesce(mv.theoretical_qty,0) theoretical_qty,pc.physical_qty,pc.count_date,
       case when pc.physical_qty is null then null else pc.physical_qty-coalesce(mv.theoretical_qty,0) end variance
from branches b cross join products p
left join mv on mv.branch_id=b.id and mv.product_id=p.id
left join pc on pc.branch_id=b.id and pc.product_id=p.id
where b.active and p.active;
grant select on vw_inventory_status to authenticated;

-- Venta editable con trazabilidad de fuente.
create or replace view vw_sale_lines_editable with (security_invoker=true) as
select dsl.id line_id, ds.id daily_sale_id, ds.sale_date, ds.branch_id, ds.status,
       dsl.product_id, dsl.customer_id,
       p.code product_code,p.name product_name,c.name customer,
       dsl.source_type,dsl.source_units,dsl.adjustment_units,dsl.final_units,dsl.adjustment_reason,
       dsl.unit_price,dsl.cost_per_unit,dsl.total_amount,dsl.total_cost,dsl.gross_margin,
       dsl.invoice_date,dsl.revenue_date,dsl.source_dispatch_line_id
from daily_sale_lines dsl
join daily_sales ds on ds.id=dsl.daily_sale_id
join products p on p.id=dsl.product_id
left join customers c on c.id=dsl.customer_id;
grant select on vw_sale_lines_editable to authenticated;

-- Cierre: evalúa conciliaciones y bloquea si hay diferencias injustificadas o alertas críticas abiertas.
create or replace function public.evaluate_daily_close(p_branch_id uuid, p_date date)
returns daily_close_checks
language plpgsql
security definer
set search_path=public
as $$
declare
  v_inventory integer;
  v_commercial integer;
  v_quality integer;
  v_row daily_close_checks;
begin
  if not public.can_access_branch(p_branch_id) then raise exception 'Sin acceso'; end if;

  select count(*) into v_inventory
  from vw_inventory_status v
  where v.branch_id=p_branch_id and v.count_date=p_date and coalesce(abs(v.variance),0)>0;

  select count(*) into v_commercial
  from vw_dispatch_sales_reconciliation r
  where r.branch_id=p_branch_id and r.dispatch_date=p_date and coalesce(abs(r.difference_units),0)>0;

  select count(*) into v_quality
  from alerts a
  where a.branch_id=p_branch_id and a.status='ABIERTA' and a.severity='CRITICA' and a.alert_date::date<=p_date;

  insert into daily_close_checks(branch_id,check_date,inventory_ok,commercial_ok,quality_ok,
    inventory_variances,commercial_variances,open_critical_quality,checked_by,checked_at)
  values(p_branch_id,p_date,v_inventory=0,v_commercial=0,v_quality=0,v_inventory,v_commercial,v_quality,auth.uid(),now())
  on conflict(branch_id,check_date) do update set
    inventory_ok=excluded.inventory_ok,commercial_ok=excluded.commercial_ok,quality_ok=excluded.quality_ok,
    inventory_variances=excluded.inventory_variances,commercial_variances=excluded.commercial_variances,
    open_critical_quality=excluded.open_critical_quality,checked_by=excluded.checked_by,checked_at=excluded.checked_at
  returning * into v_row;
  return v_row;
end $$;
grant execute on function public.evaluate_daily_close(uuid,date) to authenticated;

create or replace function public.close_operational_day(p_branch_id uuid,p_date date)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare v_check daily_close_checks; begin
  select * into v_check from public.evaluate_daily_close(p_branch_id,p_date);
  if not (v_check.inventory_ok and v_check.commercial_ok and v_check.quality_ok) then
    raise exception 'No se puede cerrar: existen conciliaciones o alertas críticas pendientes';
  end if;
  insert into operational_periods(branch_id,period_date,status,opened_at,closed_at)
  values(p_branch_id,p_date,'CERRADO',now(),now())
  on conflict(branch_id,period_date) do update set status='CERRADO',closed_at=now();
  update daily_sales set status='CERRADO',closed_by=auth.uid(),closed_at=now()
  where branch_id=p_branch_id and sale_date=p_date;
end $$;
grant execute on function public.close_operational_day(uuid,date) to authenticated;

-- Reconciliación histórica por fecha: no depende de la vista de stock actual.
create or replace function public.reconcile_inventory(p_branch_id uuid, p_date date)
returns table(product_id uuid, theoretical_qty numeric, physical_qty numeric, variance numeric)
language sql stable security invoker as $$
  with mv as (
    select im.product_id,
      sum(case im.movement_type
        when 'INITIAL' then im.quantity when 'PURCHASE' then im.quantity when 'TRANSFER_IN' then im.quantity
        when 'RETURN' then im.quantity when 'ADJUSTMENT_POSITIVE' then im.quantity
        when 'TRANSFER_OUT' then -im.quantity when 'CONSUMPTION' then -im.quantity when 'DISPATCH' then -im.quantity
        when 'DISCARD' then -im.quantity when 'ADJUSTMENT_NEGATIVE' then -im.quantity else 0 end) theoretical_qty
    from inventory_movements im
    where im.branch_id=p_branch_id and im.movement_date<=p_date
    group by im.product_id
  ), pc as (
    select product_id, physical_qty from physical_inventory_counts
    where branch_id=p_branch_id and count_date=p_date
  )
  select coalesce(mv.product_id,pc.product_id),coalesce(mv.theoretical_qty,0),pc.physical_qty,
         case when pc.physical_qty is null then null else pc.physical_qty-coalesce(mv.theoretical_qty,0) end
  from mv full join pc on pc.product_id=mv.product_id;
$$;

grant execute on function public.reconcile_inventory(uuid,date) to authenticated;

create or replace function public.evaluate_daily_close(p_branch_id uuid, p_date date)
returns daily_close_checks
language plpgsql
security definer
set search_path=public
as $$
declare
  v_inventory integer;
  v_missing_counts integer;
  v_commercial integer;
  v_quality integer;
  v_row daily_close_checks;
begin
  if not public.can_access_branch(p_branch_id) then raise exception 'Sin acceso'; end if;
  select count(*) filter(where physical_qty is not null and coalesce(abs(variance),0)>0),
         count(*) filter(where physical_qty is null)
  into v_inventory,v_missing_counts
  from public.reconcile_inventory(p_branch_id,p_date);
  v_inventory := coalesce(v_inventory,0)+coalesce(v_missing_counts,0);
  select count(*) into v_commercial from vw_dispatch_sales_reconciliation r
    where r.branch_id=p_branch_id and r.dispatch_date=p_date and coalesce(abs(r.difference_units),0)>0;
  select count(*) into v_quality from alerts a
    where a.branch_id=p_branch_id and a.status='ABIERTA' and a.severity='CRITICA' and a.alert_date::date<=p_date;
  insert into daily_close_checks(branch_id,check_date,inventory_ok,commercial_ok,quality_ok,inventory_variances,commercial_variances,open_critical_quality,checked_by,checked_at)
  values(p_branch_id,p_date,v_inventory=0,v_commercial=0,v_quality=0,v_inventory,v_commercial,v_quality,auth.uid(),now())
  on conflict(branch_id,check_date) do update set inventory_ok=excluded.inventory_ok,commercial_ok=excluded.commercial_ok,quality_ok=excluded.quality_ok,
    inventory_variances=excluded.inventory_variances,commercial_variances=excluded.commercial_variances,open_critical_quality=excluded.open_critical_quality,checked_by=excluded.checked_by,checked_at=excluded.checked_at
  returning * into v_row;
  return v_row;
end $$;


-- ============================================================
-- 11_costs_bi_alerts_v6.sql
-- ============================================================

-- HemoCura v6 - motor mensual de costos, Command Center y alertas gerenciales

create table if not exists monthly_cost_periods (
  id uuid primary key default gen_random_uuid(),
  period_month date not null,
  branch_id uuid references branches(id),
  status text not null default 'ABIERTO' check(status in ('ABIERTO','PRECIERRE','VALIDACION','APROBADO','CERRADO','REABIERTO')),
  opened_at timestamptz not null default now(),
  approved_by uuid references profiles(id),
  approved_at timestamptz,
  closed_by uuid references profiles(id),
  closed_at timestamptz,
  notes text,
  unique(period_month, branch_id),
  check (date_trunc('month',period_month)::date=period_month)
);

create table if not exists monthly_cost_entries (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references monthly_cost_periods(id) on delete cascade,
  branch_id uuid references branches(id),
  product_id uuid references products(id),
  category text not null check(category in ('MATERIAL','MANO_OBRA','TAMIZAJE','INDIRECTO','MERMA','TRANSPORTE','OTRO')),
  driver_code text,
  description text not null,
  quantity numeric(16,4) not null default 1,
  unit_cost numeric(16,4) not null default 0,
  total_cost numeric(16,2) generated always as (quantity*unit_cost) stored,
  source text,
  source_reference text,
  status text not null default 'PENDIENTE' check(status in ('PENDIENTE','ESTIMADO','VALIDADO','VENCIDO')),
  created_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists monthly_product_costs (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references monthly_cost_periods(id) on delete cascade,
  branch_id uuid references branches(id),
  product_id uuid not null references products(id),
  units_basis numeric(16,2) not null default 0,
  material_cost numeric(16,2) not null default 0,
  labor_cost numeric(16,2) not null default 0,
  screening_cost numeric(16,2) not null default 0,
  indirect_cost numeric(16,2) not null default 0,
  waste_cost numeric(16,2) not null default 0,
  transport_cost numeric(16,2) not null default 0,
  other_cost numeric(16,2) not null default 0,
  total_cost numeric(16,2) not null default 0,
  cost_per_unit numeric(16,4) not null default 0,
  previous_cost_per_unit numeric(16,4),
  variance_amount numeric(16,4),
  variance_pct numeric(12,4),
  status text not null default 'CALCULADO' check(status in ('CALCULADO','VALIDADO','APROBADO','CERRADO')),
  calculated_at timestamptz not null default now(),
  approved_by uuid references profiles(id),
  approved_at timestamptz,
  unique(period_id, branch_id, product_id)
);

create table if not exists inventory_policies (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references branches(id),
  product_id uuid not null references products(id),
  minimum_stock numeric(14,2) not null default 0,
  warning_stock numeric(14,2),
  target_stock numeric(14,2),
  active boolean not null default true,
  unique(branch_id, product_id)
);

alter table alerts add column if not exists alert_key text;
create unique index if not exists ux_alert_key_open on alerts(alert_key) where status='ABIERTA' and alert_key is not null;

create or replace function public.calculate_monthly_product_costs(p_period_id uuid)
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare
  v_period monthly_cost_periods;
  v_count integer:=0;
begin
  select * into v_period from monthly_cost_periods where id=p_period_id;
  if not found then raise exception 'Período no existe'; end if;
  if v_period.branch_id is not null and not public.can_access_branch(v_period.branch_id) then raise exception 'Sin acceso'; end if;
  if v_period.status='CERRADO' then raise exception 'Período cerrado'; end if;

  with units as (
    select p.id product_id,
      coalesce(sum(dsl.final_units) filter(where ds.id is not null),0)::numeric units_basis
    from products p
    left join daily_sale_lines dsl on dsl.product_id=p.id
    left join daily_sales ds on ds.id=dsl.daily_sale_id
      and date_trunc('month',ds.sale_date)::date=v_period.period_month
      and (v_period.branch_id is null or ds.branch_id=v_period.branch_id)
    where p.active
    group by p.id
  ), total_units as (
    select coalesce(sum(units_basis),0)::numeric total from units
  ), specific as (
    select product_id,
      coalesce(sum(total_cost) filter(where category='MATERIAL'),0) material,
      coalesce(sum(total_cost) filter(where category='MANO_OBRA'),0) labor,
      coalesce(sum(total_cost) filter(where category='TAMIZAJE'),0) screening,
      coalesce(sum(total_cost) filter(where category='INDIRECTO'),0) indirect,
      coalesce(sum(total_cost) filter(where category='MERMA'),0) waste,
      coalesce(sum(total_cost) filter(where category='TRANSPORTE'),0) transport,
      coalesce(sum(total_cost) filter(where category='OTRO'),0) other
    from monthly_cost_entries where period_id=p_period_id and product_id is not null group by product_id
  ), shared as (
    select
      coalesce(sum(total_cost) filter(where category='MATERIAL'),0) material,
      coalesce(sum(total_cost) filter(where category='MANO_OBRA'),0) labor,
      coalesce(sum(total_cost) filter(where category='TAMIZAJE'),0) screening,
      coalesce(sum(total_cost) filter(where category='INDIRECTO'),0) indirect,
      coalesce(sum(total_cost) filter(where category='MERMA'),0) waste,
      coalesce(sum(total_cost) filter(where category='TRANSPORTE'),0) transport,
      coalesce(sum(total_cost) filter(where category='OTRO'),0) other
    from monthly_cost_entries where period_id=p_period_id and product_id is null
  ), calc as (
    select u.product_id,u.units_basis,
      coalesce(s.material,0)+case when tu.total>0 then sh.material*u.units_basis/tu.total else 0 end material,
      coalesce(s.labor,0)+case when tu.total>0 then sh.labor*u.units_basis/tu.total else 0 end labor,
      coalesce(s.screening,0)+case when tu.total>0 then sh.screening*u.units_basis/tu.total else 0 end screening,
      coalesce(s.indirect,0)+case when tu.total>0 then sh.indirect*u.units_basis/tu.total else 0 end indirect,
      coalesce(s.waste,0)+case when tu.total>0 then sh.waste*u.units_basis/tu.total else 0 end waste,
      coalesce(s.transport,0)+case when tu.total>0 then sh.transport*u.units_basis/tu.total else 0 end transport,
      coalesce(s.other,0)+case when tu.total>0 then sh.other*u.units_basis/tu.total else 0 end other
    from units u cross join total_units tu cross join shared sh left join specific s on s.product_id=u.product_id
  ), final as (
    select c.*, (material+labor+screening+indirect+waste+transport+other) total,
      case when c.units_basis>0 then (material+labor+screening+indirect+waste+transport+other)/c.units_basis else 0 end cpu
    from calc c
  )
  insert into monthly_product_costs(period_id,branch_id,product_id,units_basis,material_cost,labor_cost,screening_cost,indirect_cost,waste_cost,transport_cost,other_cost,total_cost,cost_per_unit,previous_cost_per_unit,variance_amount,variance_pct,status,calculated_at)
  select p_period_id,v_period.branch_id,f.product_id,f.units_basis,f.material,f.labor,f.screening,f.indirect,f.waste,f.transport,f.other,f.total,f.cpu,
    prev.cost_per_unit,
    f.cpu-coalesce(prev.cost_per_unit,f.cpu),
    case when coalesce(prev.cost_per_unit,0)<>0 then ((f.cpu-prev.cost_per_unit)/prev.cost_per_unit)*100 else null end,
    'CALCULADO',now()
  from final f
  left join lateral (
    select mpc.cost_per_unit from monthly_product_costs mpc join monthly_cost_periods mcp on mcp.id=mpc.period_id
    where mpc.product_id=f.product_id and mcp.period_month<v_period.period_month and (mpc.branch_id is not distinct from v_period.branch_id)
    order by mcp.period_month desc limit 1
  ) prev on true
  on conflict(period_id,branch_id,product_id) do update set
    units_basis=excluded.units_basis,material_cost=excluded.material_cost,labor_cost=excluded.labor_cost,screening_cost=excluded.screening_cost,indirect_cost=excluded.indirect_cost,waste_cost=excluded.waste_cost,transport_cost=excluded.transport_cost,other_cost=excluded.other_cost,total_cost=excluded.total_cost,cost_per_unit=excluded.cost_per_unit,previous_cost_per_unit=excluded.previous_cost_per_unit,variance_amount=excluded.variance_amount,variance_pct=excluded.variance_pct,calculated_at=now(),status='CALCULADO';
  get diagnostics v_count=row_count;
  return v_count;
end $$;
grant execute on function public.calculate_monthly_product_costs(uuid) to authenticated;

create or replace function public.approve_monthly_cost_period(p_period_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v monthly_cost_periods; begin
  select * into v from monthly_cost_periods where id=p_period_id for update;
  if not found then raise exception 'Período no existe'; end if;
  if not (public.has_role('ADMIN') or public.has_role('FINANZAS') or public.has_role('GERENCIA_OPERATIVA')) then raise exception 'Sin permiso'; end if;
  if exists(select 1 from monthly_cost_entries where period_id=p_period_id and status='PENDIENTE') then raise exception 'Existen costos pendientes de validar'; end if;
  update monthly_product_costs set status='APROBADO',approved_by=auth.uid(),approved_at=now() where period_id=p_period_id;
  update monthly_cost_periods set status='APROBADO',approved_by=auth.uid(),approved_at=now() where id=p_period_id;
  insert into cost_snapshots(product_id,effective_from,effective_to,cost_per_unit,status,source,created_by)
  select product_id,v.period_month,(v.period_month+interval '1 month - 1 day')::date,cost_per_unit,'VALIDADO','CIERRE_MENSUAL:'||p_period_id,auth.uid()
  from monthly_product_costs where period_id=p_period_id and branch_id is null
  on conflict do nothing;
end $$;
grant execute on function public.approve_monthly_cost_period(uuid) to authenticated;

create or replace function public.generate_management_alerts(p_date date default current_date)
returns integer language plpgsql security definer set search_path=public as $$
declare v_count integer:=0; v integer; begin
  -- inventario crítico
  insert into alerts(alert_date,branch_id,category,severity,source_table,source_id,title,description,status,alert_key)
  select now(),v.branch_id,'INVENTARIO','CRITICA','inventory_policies',ip.id,'Stock crítico: '||v.product_name,
         'Stock teórico '||v.theoretical_qty||' <= mínimo '||ip.minimum_stock,'ABIERTA','STOCK:'||v.branch_id||':'||v.product_id
  from vw_inventory_status v join inventory_policies ip on ip.branch_id=v.branch_id and ip.product_id=v.product_id and ip.active
  where v.theoretical_qty<=ip.minimum_stock
  on conflict do nothing;
  get diagnostics v=row_count; v_count:=v_count+v;

  -- precio bajo costo
  insert into alerts(alert_date,branch_id,category,severity,source_table,source_id,title,description,status,alert_key)
  select now(),ds.branch_id,'COSTO','ALTA','daily_sale_lines',dsl.id,'Venta por debajo del costo: '||p.name,
         'Precio '||dsl.unit_price||' < costo '||dsl.cost_per_unit,'ABIERTA','BELOWCOST:'||dsl.id
  from daily_sale_lines dsl join daily_sales ds on ds.id=dsl.daily_sale_id join products p on p.id=dsl.product_id
  where ds.sale_date=p_date and dsl.final_units>0 and dsl.unit_price<dsl.cost_per_unit
  on conflict do nothing;
  get diagnostics v=row_count; v_count:=v_count+v;

  -- diferencia despacho-venta
  insert into alerts(alert_date,branch_id,category,severity,source_table,title,description,status,alert_key)
  select now(),r.branch_id,'OPERACION','ALTA','dispatches','Diferencia despacho vs venta',
         'Producto '||p.name||': diferencia '||r.difference_units||' unidades','ABIERTA','DISPSALE:'||r.dispatch_date||':'||r.branch_id||':'||r.product_id
  from vw_dispatch_sales_reconciliation r join products p on p.id=r.product_id
  where r.dispatch_date=p_date and abs(coalesce(r.difference_units,0))>0
  on conflict do nothing;
  get diagnostics v=row_count; v_count:=v_count+v;

  -- CAPA vencida
  insert into alerts(alert_date,category,severity,source_table,source_id,title,description,status,alert_key)
  select now(),'CALIDAD','CRITICA','capa',c.id,'CAPA vencida: '||c.code,
         'Fecha compromiso '||c.due_date,'ABIERTA','CAPA:'||c.id
  from capa c where c.due_date<p_date and c.status not in ('CERRADA','CANCELADA')
  on conflict do nothing;
  get diagnostics v=row_count; v_count:=v_count+v;
  return v_count;
end $$;
grant execute on function public.generate_management_alerts(date) to authenticated;

alter table monthly_cost_periods enable row level security;
alter table monthly_cost_entries enable row level security;
alter table monthly_product_costs enable row level security;
alter table inventory_policies enable row level security;

create policy mcp_read on monthly_cost_periods for select using (branch_id is null or public.can_access_branch(branch_id));
create policy mcp_write on monthly_cost_periods for all using (public.has_role('ADMIN') or public.has_role('FINANZAS') or public.has_role('GERENCIA_OPERATIVA')) with check (public.has_role('ADMIN') or public.has_role('FINANZAS') or public.has_role('GERENCIA_OPERATIVA'));
create policy mce_read on monthly_cost_entries for select using (branch_id is null or public.can_access_branch(branch_id));
create policy mce_write on monthly_cost_entries for all using (public.has_role('ADMIN') or public.has_role('FINANZAS') or public.has_role('GERENCIA_OPERATIVA')) with check (public.has_role('ADMIN') or public.has_role('FINANZAS') or public.has_role('GERENCIA_OPERATIVA'));
create policy mpc_read on monthly_product_costs for select using (branch_id is null or public.can_access_branch(branch_id));
create policy invpol_read on inventory_policies for select using (public.can_access_branch(branch_id));
create policy invpol_write on inventory_policies for all using (public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('INVENTARIO')) with check (public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('INVENTARIO'));

grant select,insert,update on monthly_cost_periods,monthly_cost_entries to authenticated;
grant select on monthly_product_costs to authenticated;
grant select,insert,update on inventory_policies to authenticated;

create or replace view vw_monthly_product_costs with (security_invoker=true) as
select mcp.period_month,mpc.branch_id,b.name branch,p.id product_id,p.code product_code,p.name product_name,
       mpc.units_basis,mpc.material_cost,mpc.labor_cost,mpc.screening_cost,mpc.indirect_cost,mpc.waste_cost,mpc.transport_cost,mpc.other_cost,
       mpc.total_cost,mpc.cost_per_unit,mpc.previous_cost_per_unit,mpc.variance_amount,mpc.variance_pct,mpc.status
from monthly_product_costs mpc join monthly_cost_periods mcp on mcp.id=mpc.period_id
join products p on p.id=mpc.product_id left join branches b on b.id=mpc.branch_id;
grant select on vw_monthly_product_costs to authenticated;

create or replace view vw_command_center_today with (security_invoker=true) as
with sales as (
 select branch_id,sum(total_units) units_sold,sum(total_revenue) revenue,sum(total_cost) cost,sum(gross_margin) margin
 from daily_sales where sale_date=current_date group by branch_id
), disp as (
 select branch_id,sum(dl.units) units_dispatched from dispatches d join dispatch_lines dl on dl.dispatch_id=d.id
 where d.dispatch_date=current_date and d.status='CONFIRMADO' group by branch_id
), inc as (
 select branch_id,count(*) incidents from incidents where incident_date=current_date group by branch_id
), al as (
 select branch_id,count(*) filter(where status='ABIERTA') open_alerts,count(*) filter(where status='ABIERTA' and severity='CRITICA') critical_alerts
 from alerts group by branch_id
)
select b.id branch_id,b.name branch,coalesce(s.units_sold,0) units_sold,coalesce(d.units_dispatched,0) units_dispatched,
       coalesce(s.revenue,0) revenue,coalesce(s.cost,0) cost,coalesce(s.margin,0) margin,coalesce(i.incidents,0) incidents,
       coalesce(a.open_alerts,0) open_alerts,coalesce(a.critical_alerts,0) critical_alerts
from branches b left join sales s on s.branch_id=b.id left join disp d on d.branch_id=b.id left join inc i on i.branch_id=b.id left join al a on a.branch_id=b.id
where b.active;
grant select on vw_command_center_today to authenticated;

create or replace view vw_open_management_alerts with (security_invoker=true) as
select a.id,a.alert_date,a.branch_id,b.name branch,a.category,a.severity,a.title,a.description,a.status,a.due_at
from alerts a left join branches b on b.id=a.branch_id where a.status='ABIERTA';
grant select on vw_open_management_alerts to authenticated;

-- Integridad para periodos corporativos con branch_id NULL (PostgreSQL trata NULL como distinto en UNIQUE tradicional).
create unique index if not exists ux_monthly_cost_period_global on monthly_cost_periods(period_month) where branch_id is null;
create unique index if not exists ux_monthly_cost_period_branch on monthly_cost_periods(period_month,branch_id) where branch_id is not null;
create unique index if not exists ux_monthly_product_cost_global on monthly_product_costs(period_id,product_id) where branch_id is null;
create unique index if not exists ux_monthly_product_cost_branch on monthly_product_costs(period_id,branch_id,product_id) where branch_id is not null;
create unique index if not exists ux_cost_snapshot_month_source on cost_snapshots(product_id,effective_from,source) where product_id is not null;

-- Endurecimiento de lectura financiera: solo roles financieros/gerenciales pueden consultar costos.
drop policy if exists mcp_read on monthly_cost_periods;
drop policy if exists mce_read on monthly_cost_entries;
drop policy if exists mpc_read on monthly_product_costs;
create policy mcp_read on monthly_cost_periods for select using (
  public.has_role('ADMIN') or public.has_role('FINANZAS') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('GERENCIA_GENERAL')
);
create policy mce_read on monthly_cost_entries for select using (
  public.has_role('ADMIN') or public.has_role('FINANZAS') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('GERENCIA_GENERAL')
);
create policy mpc_read on monthly_product_costs for select using (
  public.has_role('ADMIN') or public.has_role('FINANZAS') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('GERENCIA_GENERAL')
);


-- ============================================================
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
