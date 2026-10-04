begin;
create table if not exists public.suppliers(
 id uuid primary key default gen_random_uuid(), supplier_code text not null unique,
 legal_name text not null, supplier_type text not null default 'GENERAL',
 tax_id text, contact_name text, phone text, email text, address text,
 critical boolean not null default false,
 status text not null default 'ACTIVO' check(status in ('ACTIVO','CONDICIONAL','SUSPENDIDO','INACTIVO')),
 created_at timestamptz not null default now()
);
create table if not exists public.supplier_evaluations(
 id uuid primary key default gen_random_uuid(), supplier_id uuid not null references public.suppliers(id) on delete cascade,
 evaluation_date date not null default current_date, evaluator_user_id uuid references public.profiles(id),
 quality_score numeric, delivery_score numeric, service_score numeric, compliance_score numeric,
 total_score numeric, result text check(result in ('APROBADO','CONDICIONAL','NO_APROBADO')),
 evidence_reference text, next_review_date date, notes text
);
create table if not exists public.purchase_orders(
 id uuid primary key default gen_random_uuid(), po_code text not null unique,
 branch_id uuid references public.branches(id), supplier_id uuid not null references public.suppliers(id),
 order_date date not null default current_date, required_date date, status text not null default 'BORRADOR'
 check(status in ('BORRADOR','APROBADA','ENVIADA','PARCIAL','RECIBIDA','CANCELADA')),
 requested_by uuid references public.profiles(id), approved_by uuid references public.profiles(id),
 total_amount numeric default 0, currency text default 'DOP', notes text
);
create table if not exists public.purchase_order_lines(
 id uuid primary key default gen_random_uuid(), purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
 item_type text not null, item_reference text, description text not null, quantity numeric not null check(quantity>0),
 unit text, unit_price numeric default 0, received_quantity numeric default 0
);
create table if not exists public.supplier_incidents(
 id uuid primary key default gen_random_uuid(), incident_code text not null unique,
 supplier_id uuid not null references public.suppliers(id), branch_id uuid references public.branches(id),
 incident_date date not null default current_date, severity text not null default 'MEDIA',
 description text not null, nonconformity_id uuid references public.nonconformities(id),
 capa_id uuid references public.capa(id), status text not null default 'ABIERTO'
);
alter table public.suppliers enable row level security;
alter table public.supplier_evaluations enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_order_lines enable row level security;
alter table public.supplier_incidents enable row level security;
drop policy if exists suppliers_auth on public.suppliers;
create policy suppliers_auth on public.suppliers for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
drop policy if exists supplier_evaluations_auth on public.supplier_evaluations;
create policy supplier_evaluations_auth on public.supplier_evaluations for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
drop policy if exists purchase_orders_auth on public.purchase_orders;
create policy purchase_orders_auth on public.purchase_orders for all using(branch_id is null or public.can_access_branch(branch_id)) with check(branch_id is null or public.can_access_branch(branch_id));
drop policy if exists purchase_order_lines_auth on public.purchase_order_lines;
create policy purchase_order_lines_auth on public.purchase_order_lines for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
drop policy if exists supplier_incidents_auth on public.supplier_incidents;
create policy supplier_incidents_auth on public.supplier_incidents for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
grant select,insert,update on public.suppliers,public.supplier_evaluations,public.purchase_orders,public.purchase_order_lines,public.supplier_incidents to authenticated;
create or replace view public.vw_supplier_performance as
select s.id,s.supplier_code,s.legal_name,s.critical,s.status,
 e.evaluation_date,e.total_score,e.result,e.next_review_date,
 case when e.next_review_date is not null and e.next_review_date<current_date then true else false end review_overdue
from public.suppliers s
left join lateral(select * from public.supplier_evaluations x where x.supplier_id=s.id order by evaluation_date desc limit 1)e on true;
grant select on public.vw_supplier_performance to authenticated;
insert into public.app_permissions(permission_code,module,description,risk_level) values
('SUPPLIERS_VIEW','SUPPLIERS','Ver proveedores y compras','SENSIBLE'),
('SUPPLIERS_WRITE','SUPPLIERS','Gestionar proveedores y compras','CRITICO')
on conflict(permission_code) do update set active=true;
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r join public.app_permissions p on p.permission_code in ('SUPPLIERS_VIEW','SUPPLIERS_WRITE')
where r.code in ('ADMIN','GERENCIA_OPERATIVA','CALIDAD','INVENTARIO') on conflict do nothing;
insert into public.app_migrations(migration_code,version,description,applied_by)
values('37_SUPPLIERS_PROCUREMENT_v0_37','0.37.0','Proveedores, compras y evaluación',auth.uid())
on conflict(migration_code) do update set applied_at=now(),version=excluded.version,description=excluded.description,applied_by=auth.uid();
commit;