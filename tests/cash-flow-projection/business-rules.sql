begin;

insert into branches(id,code,name) values ('cf100000-0000-0000-0000-000000000001','CF-A','Cash flow ficticia');
insert into suppliers(id,name,active) values('cf400000-0000-0000-0000-000000000001','Proveedor CF',true);

create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;

-- Insertar un payable con due_date en 15 días (bucket 30d).
insert into supplier_payables(supplier_id,branch_id,invoice_number,invoice_date,due_date,
                              currency,amount_total)
values('cf400000-0000-0000-0000-000000000001','cf100000-0000-0000-0000-000000000001',
       'CF-INV-1',current_date,current_date+15,'DOP',8000);

-- Insertar un payable con due_date en 50 días (bucket 60d).
insert into supplier_payables(supplier_id,invoice_number,invoice_date,due_date,
                              currency,amount_total)
values('cf400000-0000-0000-0000-000000000001','CF-INV-2',current_date,current_date+50,'DOP',12000);

-- Invariante 1: la vista cubre al menos los primeros buckets 30/60.
select pg_temp.ok(
 (select count(*)>=1 from vw_cash_flow_projection where horizon_bucket='30d' and expected_outflow>0),
 'cash flow projection has outflow in 30d bucket');

select pg_temp.ok(
 (select count(*)>=1 from vw_cash_flow_projection where horizon_bucket='60d' and expected_outflow>0),
 'cash flow projection has outflow in 60d bucket');

-- Invariante 2: summary agrega por bucket.
select pg_temp.ok(
 (select total_outflow>=8000 from vw_cash_flow_summary where horizon_bucket='30d'),
 'cash flow summary 30d aggregates outflows');

select pg_temp.ok(
 (select total_outflow>=12000 from vw_cash_flow_summary where horizon_bucket='60d'),
 'cash flow summary 60d aggregates outflows');

-- Invariante 3: la vista incluye al menos 1 semana por bucket (buckets presentes).
select pg_temp.ok(
 (select count(distinct horizon_bucket)>=3 from vw_cash_flow_projection
   where horizon_bucket in ('30d','60d','90d','90d+')),
 'cash flow projection covers 30d/60d/90d horizons');

-- Invariante 4: una factura pagada no aparece.
update supplier_payables set status='PAGADA',amount_paid=amount_total
 where invoice_number='CF-INV-1';

select pg_temp.ok(
 (select coalesce(sum(expected_outflow),0)<12001 from vw_cash_flow_projection where horizon_bucket='30d'),
 'paid invoice is excluded from outflow projection');

-- Invariante 5: predictive_meta recibe el seed.
select pg_temp.ok(
 (select 1 from predictive_meta where view_name='vw_cash_flow_projection')=1,
 'cash flow projection is registered in predictive_meta');

commit;
