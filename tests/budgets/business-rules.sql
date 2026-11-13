begin;

insert into branches(id,code,name) values ('bg100000-0000-0000-0000-000000000001','BG-A','Budget A');
insert into auth.users(id,email) values('bg200000-0000-0000-0000-000000000001','author@example.invalid');
insert into profiles(id,full_name,branch_id,active) values
 ('bg200000-0000-0000-0000-000000000001','Autor','bg100000-0000-0000-0000-000000000001',true);

create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.denied(stmt text,label text) returns void language plpgsql as $$
begin begin execute stmt;exception when others then raise notice 'PASS %',label;return;end;
 raise exception 'FAIL unexpectedly allowed %',label;end$$;

-- Insertar budget válido.
insert into budgets(period_month,branch_id,category,amount_budget,approved_by,approved_at)
values(date_trunc('month',current_date)::date,'bg100000-0000-0000-0000-000000000001','MATERIAL',50000,
       'bg200000-0000-0000-0000-000000000001',now());

-- Invariante 1: period_month debe ser día 1.
select pg_temp.denied(
 $q$insert into budgets(period_month,branch_id,category,amount_budget)
    values(current_date,'bg100000-0000-0000-0000-000000000001','LABOR',1000)$q$,
 'period_month must be first of month');

-- Invariante 2: amount_budget >= 0.
select pg_temp.denied(
 $q$insert into budgets(period_month,branch_id,category,amount_budget)
    values(date_trunc('month',current_date)::date,'bg100000-0000-0000-0000-000000000001','LABOR',-100)$q$,
 'amount_budget cannot be negative');

-- Invariante 3: category fuera del enum.
select pg_temp.denied(
 $q$insert into budgets(period_month,branch_id,category,amount_budget)
    values(date_trunc('month',current_date)::date,'bg100000-0000-0000-0000-000000000001','PICNIC',100)$q$,
 'category outside enum is rejected');

-- Invariante 4: UNIQUE por period+branch+category.
select pg_temp.denied(
 $q$insert into budgets(period_month,branch_id,category,amount_budget)
    values(date_trunc('month',current_date)::date,'bg100000-0000-0000-0000-000000000001','MATERIAL',99)$q$,
 'duplicate period+branch+category is rejected');

-- Invariante 5: budget sin aprobar aparece como BORRADOR en la vista.
insert into budgets(period_month,branch_id,category,amount_budget)
values(date_trunc('month',current_date)::date,'bg100000-0000-0000-0000-000000000001','LABOR',20000);

select pg_temp.ok(
 (select status='BORRADOR' from vw_budget_vs_actual
   where branch_id='bg100000-0000-0000-0000-000000000001' and category='LABOR'),
 'unapproved budget shows BORRADOR');

-- Invariante 6: budget aprobado sin actuals aparece DENTRO (actual=0 <= budget).
select pg_temp.ok(
 (select status='DENTRO' from vw_budget_vs_actual
   where branch_id='bg100000-0000-0000-0000-000000000001' and category='MATERIAL'),
 'approved budget with no actuals shows DENTRO');

-- Invariante 7: variance se calcula.
select pg_temp.ok(
 (select variance_amount=-50000 from vw_budget_vs_actual
   where branch_id='bg100000-0000-0000-0000-000000000001' and category='MATERIAL'),
 'variance_amount reflects actual - budget');

commit;
