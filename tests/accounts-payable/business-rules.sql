begin;

insert into branches(id,code,name) values ('ca100000-0000-0000-0000-000000000002','AP-A','AP ficticia');
insert into auth.users(id,email) values
 ('ca200000-0000-0000-0000-000000000011','author@example.invalid'),
 ('ca200000-0000-0000-0000-000000000012','authorizer@example.invalid');
insert into profiles(id,full_name,branch_id,active) values
 ('ca200000-0000-0000-0000-000000000011','Autor','ca100000-0000-0000-0000-000000000002',true),
 ('ca200000-0000-0000-0000-000000000012','Autorizador','ca100000-0000-0000-0000-000000000002',true);
insert into suppliers(id,name,active) values('ca400000-0000-0000-0000-000000000001','Proveedor ficticio',true);

create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.denied(stmt text,label text) returns void language plpgsql as $$
begin begin execute stmt;exception when others then raise notice 'PASS %',label;return;end;
 raise exception 'FAIL unexpectedly allowed %',label;end$$;

-- Factura básica.
insert into supplier_payables(supplier_id,branch_id,invoice_number,invoice_date,due_date,
                              currency,amount_total,entered_by)
values('ca400000-0000-0000-0000-000000000001','ca100000-0000-0000-0000-000000000002',
       'INV-001',current_date-10,current_date-5,'DOP',10000,
       'ca200000-0000-0000-0000-000000000011');

-- Invariante 1: due_date < invoice_date es rechazado.
select pg_temp.denied(
 $q$insert into supplier_payables(supplier_id,invoice_number,invoice_date,due_date,currency,amount_total)
    values('ca400000-0000-0000-0000-000000000001','INV-X',current_date,current_date-1,'DOP',500)$q$,
 'due_date cannot be before invoice_date');

-- Invariante 2: factura duplicada por supplier+invoice_number rechazada.
select pg_temp.denied(
 $q$insert into supplier_payables(supplier_id,invoice_number,invoice_date,due_date,currency,amount_total)
    values('ca400000-0000-0000-0000-000000000001','INV-001',current_date,current_date,'DOP',500)$q$,
 'duplicate invoice number per supplier is rejected');

-- Invariante 3: amount_total > 0.
select pg_temp.denied(
 $q$insert into supplier_payables(supplier_id,invoice_number,invoice_date,due_date,currency,amount_total)
    values('ca400000-0000-0000-0000-000000000001','INV-ZERO',current_date,current_date,'DOP',0)$q$,
 'amount_total must be positive');

-- Pago parcial.
insert into supplier_payments(payable_id,supplier_id,amount,payment_method,posted_by,authorized_by)
select id,supplier_id,3000,'TRANSFERENCIA',
       'ca200000-0000-0000-0000-000000000011','ca200000-0000-0000-0000-000000000012'
 from supplier_payables where invoice_number='INV-001';

select pg_temp.ok(
 (select amount_paid=3000 and status='PARCIAL'
    from supplier_payables where invoice_number='INV-001'),
 'partial payment moves payable to PARCIAL with amount_paid synced');

-- Pago que cierra la factura.
insert into supplier_payments(payable_id,supplier_id,amount,payment_method,posted_by,authorized_by)
select id,supplier_id,7000,'EFECTIVO',
       'ca200000-0000-0000-0000-000000000011','ca200000-0000-0000-0000-000000000012'
 from supplier_payables where invoice_number='INV-001';

select pg_temp.ok(
 (select amount_paid=10000 and status='PAGADA'
    from supplier_payables where invoice_number='INV-001'),
 'full payment moves payable to PAGADA');

-- Invariante 4: segregación de funciones en pagos.
select pg_temp.denied(
 $q$insert into supplier_payments(payable_id,supplier_id,amount,payment_method,posted_by,authorized_by)
    select id,supplier_id,100,'EFECTIVO',
           'ca200000-0000-0000-0000-000000000011','ca200000-0000-0000-0000-000000000011'
     from supplier_payables where invoice_number='INV-001'$q$,
 'authorizer and poster must be distinct (segregation of duties)');

-- Aging buckets.
insert into supplier_payables(supplier_id,invoice_number,invoice_date,due_date,currency,amount_total) values
 ('ca400000-0000-0000-0000-000000000001','INV-010',current_date-45,current_date-45,'DOP',5000),
 ('ca400000-0000-0000-0000-000000000001','INV-070',current_date-75,current_date-75,'DOP',3000),
 ('ca400000-0000-0000-0000-000000000001','INV-TODAY',current_date,current_date+30,'DOP',1000);

select pg_temp.ok(
 (select aging_bucket='31-60d' from vw_accounts_payable_aging
   where invoice_number='INV-010'),
 'aging 31-60d bucket computed correctly');

select pg_temp.ok(
 (select aging_bucket='61-90d' from vw_accounts_payable_aging
   where invoice_number='INV-070'),
 'aging 61-90d bucket computed correctly');

select pg_temp.ok(
 (select aging_bucket='Corriente' from vw_accounts_payable_aging
   where invoice_number='INV-TODAY'),
 'current invoice shows in Corriente bucket');

-- outstanding_amount coherente.
select pg_temp.ok(
 (select outstanding_amount=5000 from vw_accounts_payable_aging
   where invoice_number='INV-010'),
 'outstanding_amount equals total minus paid');

commit;
