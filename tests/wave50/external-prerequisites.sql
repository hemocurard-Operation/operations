-- Test-only reconstruction of an external prerequisite absent from this checkout.
-- Not evidence of the live schema and not a production migration.
create table public.clinical_demand_requests (
 id uuid primary key default gen_random_uuid(),
 branch_id uuid not null references public.branches(id),
 customer_id uuid references public.customers(id),
 product_id uuid not null references public.products(id),
 blood_group text, rh_factor text,
 requested_units numeric not null check(requested_units>0),
 requested_at timestamptz not null default now(), needed_by timestamptz,
 priority text not null default 'NORMAL' check(priority in ('NORMAL','URGENTE','CRITICA')),
 status text not null default 'ABIERTA' check(status in ('ABIERTA','EN_PROCESO','ATENDIDA','CANCELADA')),
 clinical_order_ref text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
alter table public.clinical_demand_requests enable row level security;
grant select,insert,update,delete on public.clinical_demand_requests to authenticated;
