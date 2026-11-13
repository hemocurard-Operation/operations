-- HemoCura v11 Brecha F1 — Cuentas por Pagar (§10 bullet 2).
--
-- Antes de esta migración, el sistema conocía CxC (collections) pero no
-- CxP: HemoCura no sabía por sistema cuánto debía a sus proveedores ni
-- cuándo, y toda la tesorería del lado egreso vivía en Excel.
--
-- Entidades nuevas:
--   supplier_payables   — factura/obligación por suplidor con aging.
--   supplier_payments   — pagos aplicados, con método y autorización.
--   vw_accounts_payable_aging — aging buckets análogos a los de CxC.
--
-- Aditivo: no rompe suppliers/purchase_orders/purchase_receipts. El
-- vínculo a purchase_orders es opcional (una factura puede llegar sin OC
-- previa). El vínculo a purchase_receipts es sugerente, no obligatorio.

begin;

create table public.supplier_payables(
 id uuid primary key default gen_random_uuid(),
 supplier_id uuid not null references public.suppliers(id) on delete restrict,
 branch_id uuid references public.branches(id),
 purchase_order_id uuid references public.purchase_orders(id),
 invoice_number text not null,
 invoice_date date not null,
 due_date date not null check(due_date>=invoice_date),
 currency text not null check(currency in ('DOP','USD','EUR')),
 amount_total numeric(14,2) not null check(amount_total>0 and amount_total::text not in ('NaN','Infinity','-Infinity')),
 amount_paid numeric(14,2) not null default 0 check(amount_paid>=0),
 status text not null default 'PENDIENTE'
  check(status in ('PENDIENTE','PARCIAL','PAGADA','ANULADA','EN_DISPUTA')),
 payment_terms_days integer check(payment_terms_days is null or payment_terms_days between 0 and 365),
 notes text,
 entered_by uuid references public.profiles(id),
 approved_by uuid references public.profiles(id),
 approved_at timestamptz,
 revision integer not null default 1,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(supplier_id,invoice_number),
 check(amount_paid<=amount_total)
);

create index supplier_payables_due on public.supplier_payables(due_date) where status not in ('PAGADA','ANULADA');
create index supplier_payables_supplier on public.supplier_payables(supplier_id,invoice_date desc);
create index supplier_payables_branch on public.supplier_payables(branch_id) where branch_id is not null;

create table public.supplier_payments(
 id uuid primary key default gen_random_uuid(),
 payable_id uuid not null references public.supplier_payables(id) on delete restrict,
 supplier_id uuid not null references public.suppliers(id),
 paid_at timestamptz not null default now(),
 amount numeric(14,2) not null check(amount>0),
 payment_method text not null check(payment_method in ('EFECTIVO','TRANSFERENCIA','OFICINA','CHEQUE','CREDITO')),
 reference text,
 authorized_by uuid references public.profiles(id),
 posted_by uuid references public.profiles(id),
 notes text,
 created_at timestamptz not null default now(),
 check(authorized_by is null or authorized_by is distinct from posted_by)
);
create index supplier_payments_payable on public.supplier_payments(payable_id,paid_at desc);
create index supplier_payments_supplier on public.supplier_payments(supplier_id,paid_at desc);

alter table public.supplier_payables enable row level security;
alter table public.supplier_payments enable row level security;
revoke all on public.supplier_payables,public.supplier_payments from public,anon,authenticated;
grant select,insert,update on public.supplier_payables to authenticated;
grant select,insert on public.supplier_payments to authenticated;

create policy supplier_payables_read on public.supplier_payables for select to authenticated
 using(auth.uid() is not null);
create policy supplier_payables_write on public.supplier_payables for insert to authenticated
 with check(public.has_permission('FINANCE_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));
create policy supplier_payables_update on public.supplier_payables for update to authenticated
 using(public.has_permission('FINANCE_WRITE'))
 with check(public.has_permission('FINANCE_WRITE'));
create policy supplier_payments_read on public.supplier_payments for select to authenticated
 using(auth.uid() is not null);
create policy supplier_payments_write on public.supplier_payments for insert to authenticated
 with check(public.has_permission('FINANCE_WRITE'));

insert into public.app_permissions(permission_code,active,description) values
 ('FINANCE_VIEW',true,'Consulta de información financiera (AP, AR, costos)'),
 ('FINANCE_WRITE',true,'Registrar y aprobar transacciones financieras'),
 ('AP_AUTHORIZE',true,'Autorizar pagos a proveedores')
 on conflict (permission_code) do update set active=excluded.active,description=excluded.description;

insert into public.role_permissions(role_id,permission_code)
 select r.id,p.permission_code from public.roles r cross join public.app_permissions p
 where r.code in ('GERENCIA_GENERAL','GERENCIA_OPERATIVA','SUPER_USUARIO')
   and p.permission_code in ('FINANCE_VIEW','FINANCE_WRITE','AP_AUTHORIZE')
 on conflict do nothing;

-- Mantener amount_paid y status sincronizados con los pagos aplicados.
create function private.supplier_payable_reconcile() returns trigger language plpgsql security definer
 set search_path=public,pg_temp as $$
declare total numeric(14,2);parent record;
begin
 select payable_id into parent from (select coalesce(new.payable_id,old.payable_id) as payable_id) p;
 select coalesce(sum(amount),0) into total from public.supplier_payments where payable_id=parent.payable_id;
 update public.supplier_payables
  set amount_paid=total,
      status=case when total>=amount_total then 'PAGADA'
                  when total>0 then 'PARCIAL'
                  else status end,
      updated_at=now(),
      revision=revision+1
  where id=parent.payable_id;
 return coalesce(new,old);
end;$$;
revoke all on function private.supplier_payable_reconcile() from public,anon,authenticated;

create trigger supplier_payable_reconcile_after_payment
 after insert on public.supplier_payments
 for each row execute function private.supplier_payable_reconcile();

create or replace view public.vw_accounts_payable_aging with(security_invoker=true) as
select
 p.id as payable_id,p.supplier_id,p.branch_id,p.invoice_number,p.invoice_date,p.due_date,
 p.currency,p.amount_total,p.amount_paid,
 (p.amount_total-p.amount_paid) as outstanding_amount,
 p.status,
 case
  when p.status in ('PAGADA','ANULADA') then 0
  else greatest(0,(current_date-p.due_date))
 end as days_past_due,
 case
  when p.status in ('PAGADA','ANULADA') then 'PAGADA_O_ANULADA'
  when current_date<=p.due_date then 'Corriente'
  when current_date-p.due_date<=30 then '1-30d'
  when current_date-p.due_date<=60 then '31-60d'
  when current_date-p.due_date<=90 then '61-90d'
  else '90d+'
 end as aging_bucket,
 s.name as supplier_name
from public.supplier_payables p
join public.suppliers s on s.id=p.supplier_id;

grant select on public.vw_accounts_payable_aging to authenticated;

notify pgrst,'reload schema';
commit;
