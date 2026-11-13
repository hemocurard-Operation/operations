begin;

insert into branches(id,code,name) values ('ef100000-0000-0000-0000-000000000001','EF-A','Expense ficticia');
insert into suppliers(id,name,active) values('ef400000-0000-0000-0000-000000000001','Proveedor EF',true);
insert into auth.users(id,email) values('ef200000-0000-0000-0000-000000000001','author@example.invalid');
insert into profiles(id,full_name,branch_id,active) values
 ('ef200000-0000-0000-0000-000000000001','Autor','ef100000-0000-0000-0000-000000000001',true);

create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;

-- Factura con vencimiento en 10 días.
insert into supplier_payables(supplier_id,branch_id,invoice_number,invoice_date,due_date,currency,amount_total)
values('ef400000-0000-0000-0000-000000000001','ef100000-0000-0000-0000-000000000001',
       'EF-INV-1',current_date,current_date+10,'DOP',5000);

select pg_temp.ok(
 (select committed_outflow>=5000 from vw_expense_forecast
   where week<=current_date+10 order by week desc limit 1),
 'expense forecast reports committed outflow from active payables');

-- Budget del mes actual aprobado.
insert into budgets(period_month,branch_id,category,amount_budget,approved_by,approved_at)
values(date_trunc('month',current_date)::date,'ef100000-0000-0000-0000-000000000001','MATERIAL',20000,
       'ef200000-0000-0000-0000-000000000001',now());

select pg_temp.ok(
 (select monthly_budget>=20000 from vw_expense_forecast
   where date_trunc('month',week)=date_trunc('month',current_date) limit 1),
 'expense forecast joins monthly budget');

-- Meta registrada en predictive_meta.
select pg_temp.ok(
 (select 1 from predictive_meta where view_name='vw_expense_forecast')=1,
 'expense forecast registered in predictive_meta');

-- Factura pagada no cuenta.
insert into supplier_payables(supplier_id,invoice_number,invoice_date,due_date,currency,amount_total,status,amount_paid)
values('ef400000-0000-0000-0000-000000000001','EF-INV-PAID',current_date,current_date+10,'DOP',1000,'PAGADA',1000);

select pg_temp.ok(
 (select coalesce(sum(committed_outflow),0) from vw_expense_forecast
   where week<=current_date+10) = 5000,
 'paid invoice excluded from committed outflow');

commit;
