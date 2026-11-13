-- RLS cross-sucursal — prompt maestro HemoCura v11 §17 escenario crítico #5:
-- "Una sucursal no puede consultar datos restringidos de otra."
--
-- Ejercita el aislamiento de can_access_branch(branch_id) contra tres tablas
-- clínicas sensibles: donors, donations, blood_inventory_units. Verifica que:
--   - un usuario de la sucursal A ve lo suyo, pero no lo de B.
--   - un SUPER_USUARIO ve todo.
--   - un intento de INSERT/UPDATE cross-sucursal es rechazado.

begin;

insert into branches(id,code,name) values
 ('cb100000-0000-0000-0000-000000000001','RLS-A','RLS ficticia A'),
 ('cb100000-0000-0000-0000-000000000002','RLS-B','RLS ficticia B');

insert into auth.users(id,email) values
 ('cb200000-0000-0000-0000-000000000001','rls-a@example.invalid'),
 ('cb200000-0000-0000-0000-000000000002','rls-b@example.invalid'),
 ('cb200000-0000-0000-0000-000000000003','rls-super@example.invalid');

insert into profiles(id,full_name,branch_id,active) values
 ('cb200000-0000-0000-0000-000000000001','Operador A','cb100000-0000-0000-0000-000000000001',true),
 ('cb200000-0000-0000-0000-000000000002','Operador B','cb100000-0000-0000-0000-000000000002',true),
 ('cb200000-0000-0000-0000-000000000003','Super ficticio','cb100000-0000-0000-0000-000000000001',true);

insert into user_roles(user_id,role_id,branch_id) select v.id,r.id,v.branch from
 (values
  ('cb200000-0000-0000-0000-000000000001'::uuid,'ENCARGADA_LABORATORIO','cb100000-0000-0000-0000-000000000001'::uuid),
  ('cb200000-0000-0000-0000-000000000002'::uuid,'ENCARGADA_LABORATORIO','cb100000-0000-0000-0000-000000000002'::uuid),
  ('cb200000-0000-0000-0000-000000000003'::uuid,'SUPER_USUARIO','cb100000-0000-0000-0000-000000000001'::uuid)
 ) v(id,code,branch)
 join roles r on r.code=v.code;

-- Semilla clínica: cada sucursal tiene su donante, donación y unidad.
insert into donors(id,donor_code,full_name,branch_id,donor_type) values
 ('cb300000-0000-0000-0000-000000000001','RLS-DA','Donante A','cb100000-0000-0000-0000-000000000001','VOLUNTARIO'),
 ('cb300000-0000-0000-0000-000000000002','RLS-DB','Donante B','cb100000-0000-0000-0000-000000000002','VOLUNTARIO');

insert into donations(donation_code,donor_id,branch_id,source_unit_code) values
 ('RLS-DNA','cb300000-0000-0000-0000-000000000001','cb100000-0000-0000-0000-000000000001','RLS-UA'),
 ('RLS-DNB','cb300000-0000-0000-0000-000000000002','cb100000-0000-0000-0000-000000000002','RLS-UB');

insert into blood_inventory_units(unit_code,source_unit_code,branch_id,component_name,expiry_date) values
 ('RLS-CA','RLS-UA','cb100000-0000-0000-0000-000000000001','PLASMA',current_date+30),
 ('RLS-CB','RLS-UB','cb100000-0000-0000-0000-000000000002','PLASMA',current_date+30);

create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$
begin
 if v is distinct from true then raise exception 'FAIL %',label;end if;
 raise notice 'PASS %',label;
end$$;

create function pg_temp.denied(stmt text,label text,expected text default null) returns void language plpgsql as $$
begin
 begin execute stmt;exception when others then
  if expected is not null and SQLSTATE<>expected then
   raise exception 'FAIL % unexpected SQLSTATE %: %',label,SQLSTATE,SQLERRM;
  end if;
  raise notice 'PASS %',label;return;
 end;
 raise exception 'FAIL unexpectedly allowed %',label;
end$$;

-- Actor A: operador de sucursal A.
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','cb200000-0000-0000-0000-000000000001',true);

select pg_temp.ok(
 (select count(*)=1 from donors where branch_id='cb100000-0000-0000-0000-000000000001'),
 'operator A sees own branch donors');

select pg_temp.ok(
 (select count(*)=0 from donors where branch_id='cb100000-0000-0000-0000-000000000002'),
 'operator A does not see other branch donors');

select pg_temp.ok(
 (select count(*)=1 from donations where branch_id='cb100000-0000-0000-0000-000000000001'),
 'operator A sees own branch donations');

select pg_temp.ok(
 (select count(*)=0 from donations where branch_id='cb100000-0000-0000-0000-000000000002'),
 'operator A does not see other branch donations');

select pg_temp.ok(
 (select count(*)=1 from blood_inventory_units where branch_id='cb100000-0000-0000-0000-000000000001'),
 'operator A sees own branch blood units');

select pg_temp.ok(
 (select count(*)=0 from blood_inventory_units where branch_id='cb100000-0000-0000-0000-000000000002'),
 'operator A does not see other branch blood units');

-- INSERT cross-sucursal debe fallar por RLS (with check).
select pg_temp.denied(
 $q$insert into blood_inventory_units(unit_code,source_unit_code,branch_id,component_name)
    values('RLS-CROSS','RLS-UA','cb100000-0000-0000-0000-000000000002','PLASMA')$q$,
 'operator A cannot INSERT into other branch');

-- UPDATE cross-sucursal: la fila ni siquiera es visible → no afecta filas.
select pg_temp.ok(
 (with up as (
   update blood_inventory_units set component_name='X'
    where branch_id='cb100000-0000-0000-0000-000000000002' returning 1
  ) select count(*)=0 from up),
 'operator A UPDATE on other branch affects zero rows (RLS invisible)');

-- Actor B: operador de sucursal B.
select set_config('request.jwt.claim.sub','cb200000-0000-0000-0000-000000000002',true);

select pg_temp.ok(
 (select count(*)=1 from donors where branch_id='cb100000-0000-0000-0000-000000000002'),
 'operator B sees own branch donors');

select pg_temp.ok(
 (select count(*)=0 from donors where branch_id='cb100000-0000-0000-0000-000000000001'),
 'operator B does not see other branch donors');

select pg_temp.ok(
 (select count(*)=1 from blood_inventory_units where branch_id='cb100000-0000-0000-0000-000000000002'),
 'operator B sees own branch blood units');

select pg_temp.ok(
 (select count(*)=0 from blood_inventory_units where branch_id='cb100000-0000-0000-0000-000000000001'),
 'operator B does not see other branch blood units');

-- SUPER_USUARIO ve ambas sucursales.
select set_config('request.jwt.claim.sub','cb200000-0000-0000-0000-000000000003',true);

select pg_temp.ok(
 (select count(*)>=2 from donors
   where branch_id in ('cb100000-0000-0000-0000-000000000001',
                       'cb100000-0000-0000-0000-000000000002')),
 'SUPER_USUARIO sees donors across branches');

select pg_temp.ok(
 (select count(*)>=2 from blood_inventory_units
   where branch_id in ('cb100000-0000-0000-0000-000000000001',
                       'cb100000-0000-0000-0000-000000000002')),
 'SUPER_USUARIO sees blood units across branches');

-- Profile desactivado pierde acceso incluso en su propia sucursal.
reset role;
update profiles set active=false where id='cb200000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','cb200000-0000-0000-0000-000000000001',true);

select pg_temp.ok(
 (select count(*)=0 from donors where branch_id='cb100000-0000-0000-0000-000000000001'),
 'deactivated profile loses access to its own branch donors');

commit;
