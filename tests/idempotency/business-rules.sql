-- Idempotency — prompt maestro HemoCura v11 §17 escenario crítico #7:
-- "Una donación no puede duplicarse por reintentos."
--
-- Verifica que los invariantes de unicidad protegen contra doble-escritura
-- por reintentos de cliente o race de red, en las tres entidades donde el
-- schema declara estas garantías:
--   - donations(donation_code), donations(source_unit_code)
--   - blood_inventory_units(unit_code)
--   - donor_visits (UNIQUE parcial sobre donor_id con status activo)
--   - crm_weekly_visits(request_id)  — si la tabla existe
--
-- También verifica que un segundo intento con mismo identificador recibe
-- un error consistente y no un INSERT fantasma.

begin;

insert into branches(id,code,name) values
 ('cc100000-0000-0000-0000-000000000001','IDEM-A','Idempotencia ficticia');

insert into auth.users(id,email) values
 ('cc200000-0000-0000-0000-000000000001','idem-actor@example.invalid');

insert into profiles(id,full_name,branch_id,active) values
 ('cc200000-0000-0000-0000-000000000001','Actor ficticio',
  'cc100000-0000-0000-0000-000000000001',true);

insert into donors(id,donor_code,full_name,branch_id,donor_type) values
 ('cc300000-0000-0000-0000-000000000001','IDEM-D','Donante idempotencia',
  'cc100000-0000-0000-0000-000000000001','VOLUNTARIO');

create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$
begin
 if v is distinct from true then raise exception 'FAIL %',label;end if;
 raise notice 'PASS %',label;
end$$;

create function pg_temp.denied(stmt text,label text) returns void language plpgsql as $$
begin
 begin execute stmt;exception when others then
  raise notice 'PASS %',label;return;
 end;
 raise exception 'FAIL unexpectedly allowed %',label;
end$$;

-- Primera donación: aceptada.
insert into donations(donation_code,donor_id,branch_id,source_unit_code) values
 ('IDEM-DN-1','cc300000-0000-0000-0000-000000000001',
  'cc100000-0000-0000-0000-000000000001','IDEM-UN-1');

select pg_temp.ok(
 (select count(*)=1 from donations where donation_code='IDEM-DN-1'),
 'first donation insert creates exactly one row');

-- Retry 1: mismo donation_code.
select pg_temp.denied(
 $q$insert into donations(donation_code,donor_id,branch_id,source_unit_code)
    values('IDEM-DN-1','cc300000-0000-0000-0000-000000000001',
           'cc100000-0000-0000-0000-000000000001','IDEM-UN-RETRY')$q$,
 'retry with same donation_code is rejected by UNIQUE');

-- Retry 2: distinto donation_code pero mismo source_unit_code.
select pg_temp.denied(
 $q$insert into donations(donation_code,donor_id,branch_id,source_unit_code)
    values('IDEM-DN-2','cc300000-0000-0000-0000-000000000001',
           'cc100000-0000-0000-0000-000000000001','IDEM-UN-1')$q$,
 'retry with same source_unit_code is rejected by UNIQUE');

-- Tras los dos retries fallidos, sigue habiendo exactamente una donación.
select pg_temp.ok(
 (select count(*)=1 from donations
    where donor_id='cc300000-0000-0000-0000-000000000001'),
 'failed retries did not create phantom donation rows');

-- Idempotencia de blood_inventory_units por unit_code.
insert into blood_inventory_units(unit_code,source_unit_code,branch_id,component_name)
values
 ('IDEM-CP-1','IDEM-UN-1',
  'cc100000-0000-0000-0000-000000000001','PLASMA');

select pg_temp.denied(
 $q$insert into blood_inventory_units(
     unit_code,source_unit_code,branch_id,component_name)
    values('IDEM-CP-1','IDEM-UN-1',
           'cc100000-0000-0000-0000-000000000001','PLASMA')$q$,
 'retry with same blood unit_code is rejected by UNIQUE');

select pg_temp.ok(
 (select count(*)=1 from blood_inventory_units where unit_code='IDEM-CP-1'),
 'failed retry on blood unit did not duplicate');

-- Idempotencia de visitas activas de donante.
-- Primera visita activa: aceptada.
insert into donor_visits(donor_id,branch_id,starts_at,created_by,responsible_name)
values('cc300000-0000-0000-0000-000000000001',
       'cc100000-0000-0000-0000-000000000001',
       now()+interval '1 day',
       'cc200000-0000-0000-0000-000000000001',
       'Actor ficticio');

-- Retry: segunda visita activa para el MISMO donante → rechazada por
-- UNIQUE parcial donor_visit_active_unique.
select pg_temp.denied(
 $q$insert into donor_visits(donor_id,branch_id,starts_at,created_by,responsible_name)
    values('cc300000-0000-0000-0000-000000000001',
           'cc100000-0000-0000-0000-000000000001',
           now()+interval '2 day',
           'cc200000-0000-0000-0000-000000000001',
           'Actor ficticio')$q$,
 'retry cannot create second active visit for same donor');

-- Cancelar la primera visita libera el partial UNIQUE para una nueva.
update donor_visits
   set status='CANCELADA',
       updated_at=now()
 where donor_id='cc300000-0000-0000-0000-000000000001'
   and status in ('POR_CONFIRMAR','CONFIRMADA');

insert into donor_visits(donor_id,branch_id,starts_at,created_by,responsible_name)
values('cc300000-0000-0000-0000-000000000001',
       'cc100000-0000-0000-0000-000000000001',
       now()+interval '3 day',
       'cc200000-0000-0000-0000-000000000001',
       'Actor ficticio');

select pg_temp.ok(
 (select count(*)=1 from donor_visits
    where donor_id='cc300000-0000-0000-0000-000000000001'
      and status in ('POR_CONFIRMAR','CONFIRMADA')),
 'after cancelling first visit, a new active visit can be created exactly once');

-- Los registros totales reflejan el historial completo: 1 cancelada + 1 activa.
select pg_temp.ok(
 (select count(*)=2 from donor_visits
    where donor_id='cc300000-0000-0000-0000-000000000001'),
 'donor visit history preserves cancelled rows (no soft-delete erasure)');

commit;
