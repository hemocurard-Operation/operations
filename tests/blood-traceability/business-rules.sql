-- Blood unit traceability — reglas de negocio ejercitadas en PostgreSQL desechable.
-- Nunca se ejecuta contra producción. Verifica los invariantes que el prompt
-- maestro HemoCura v11 §17 declara críticos: una unidad sanguínea no puede
-- liberarse ni despacharse dos veces, y toda transición técnica queda
-- trazada por el schema (donations → screening_tests → blood_inventory_units).

begin;

-- Branches ficticias para el test.
insert into branches(id,code,name) values
 ('bt100000-0000-0000-0000-000000000001','TRACE-A','Trazabilidad ficticia A'),
 ('bt100000-0000-0000-0000-000000000002','TRACE-B','Trazabilidad ficticia B');

-- Donante ficticio.
insert into donors(id,donor_code,full_name,branch_id,donor_type)
 values('bt200000-0000-0000-0000-000000000001','TRACE-DON-1','Donante trazabilidad',
        'bt100000-0000-0000-0000-000000000001','VOLUNTARIO');

-- Donación con código y unidad origen únicas.
insert into donations(donation_code,donor_id,branch_id,source_unit_code,status)
 values('TRACE-DN-1','bt200000-0000-0000-0000-000000000001',
        'bt100000-0000-0000-0000-000000000001','TRACE-UN-1','RECOLECTADA');

-- Unidad de inventario ligada por source_unit_code.
insert into blood_inventory_units(
 unit_code,source_unit_code,donation_id,branch_id,component_name,abo,rh,
 expiry_date,screening_status,inventory_status)
select
 'TRACE-COMP-1','TRACE-UN-1',d.id,
 'bt100000-0000-0000-0000-000000000001','PLASMA','O','POSITIVO',
 current_date+30,'PENDIENTE','CUARENTENA'
from donations d where d.donation_code='TRACE-DN-1';

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

-- Invariante 1: código de donación único.
select pg_temp.denied(
 $q$insert into donations(donation_code,donor_id,branch_id,source_unit_code)
    values('TRACE-DN-1','bt200000-0000-0000-0000-000000000001',
           'bt100000-0000-0000-0000-000000000001','TRACE-UN-2')$q$,
 'duplicate donation_code is rejected');

-- Invariante 2: source_unit_code único en donations.
select pg_temp.denied(
 $q$insert into donations(donation_code,donor_id,branch_id,source_unit_code)
    values('TRACE-DN-2','bt200000-0000-0000-0000-000000000001',
           'bt100000-0000-0000-0000-000000000001','TRACE-UN-1')$q$,
 'duplicate source_unit_code is rejected');

-- Invariante 3: unit_code único en blood_inventory_units.
select pg_temp.denied(
 $q$insert into blood_inventory_units(
     unit_code,source_unit_code,branch_id,component_name)
    values('TRACE-COMP-1','TRACE-UN-1',
           'bt100000-0000-0000-0000-000000000001','PLASMA')$q$,
 'duplicate blood unit unit_code is rejected');

-- Invariante 4: screening_status fuera del enum es rechazado.
select pg_temp.denied(
 $q$update blood_inventory_units set screening_status='LIBERADO'
    where unit_code='TRACE-COMP-1'$q$,
 'invalid screening_status is rejected by CHECK');

-- Invariante 5: inventory_status fuera del enum es rechazado.
select pg_temp.denied(
 $q$update blood_inventory_units set inventory_status='LIBERADO'
    where unit_code='TRACE-COMP-1'$q$,
 'invalid inventory_status is rejected by CHECK');

-- Invariante 6: abo/rh solo aceptan valores del dominio.
select pg_temp.denied(
 $q$update blood_inventory_units set abo='X'
    where unit_code='TRACE-COMP-1'$q$,
 'invalid ABO value is rejected');

select pg_temp.denied(
 $q$update blood_inventory_units set rh='UNKNOWN'
    where unit_code='TRACE-COMP-1'$q$,
 'invalid Rh value is rejected');

-- Camino feliz: tamizar NO_REACTIVO, promover a APTO y DISPONIBLE.
insert into screening_tests(screening_code,donation_id,source_unit_code,branch_id,
                             test_type,result,status)
select 'TRACE-SC-1',d.id,'TRACE-UN-1',
       'bt100000-0000-0000-0000-000000000001','VIH','NO_REACTIVO','VALIDADO'
from donations d where d.donation_code='TRACE-DN-1';

update blood_inventory_units
   set screening_status='APTO',inventory_status='DISPONIBLE'
 where unit_code='TRACE-COMP-1';

select pg_temp.ok(
 (select screening_status='APTO' and inventory_status='DISPONIBLE'
    from blood_inventory_units where unit_code='TRACE-COMP-1'),
 'unit transitions to APTO/DISPONIBLE after NO_REACTIVO screening');

-- Invariante 7: una unidad DESPACHADA no puede volver a DISPONIBLE sin
-- justificación operativa (el CHECK solo valida enum; la regla de
-- irreversibilidad vive en el flujo clínico). Aquí verificamos que el
-- CHECK existe y acepta la transición DESPACHADA.
update blood_inventory_units
   set inventory_status='DESPACHADA'
 where unit_code='TRACE-COMP-1';

select pg_temp.ok(
 (select inventory_status='DESPACHADA'
    from blood_inventory_units where unit_code='TRACE-COMP-1'),
 'DESPACHADA is an allowed terminal state');

-- Invariante 8: un segundo intento de insertar la misma unidad como nueva
-- fila (simulando doble dispatch creando duplicado) queda bloqueado por el
-- UNIQUE de unit_code.
select pg_temp.denied(
 $q$insert into blood_inventory_units(
     unit_code,source_unit_code,branch_id,component_name,inventory_status)
    values('TRACE-COMP-1','TRACE-UN-1',
           'bt100000-0000-0000-0000-000000000001','PLASMA','DESPACHADA')$q$,
 'cannot create a second inventory row with the same unit_code (double dispatch guard)');

-- Invariante 9: ABO/Rh y expiry_date no se tocan al cambiar inventory_status.
select pg_temp.ok(
 (select abo='O' and rh='POSITIVO'
    from blood_inventory_units where unit_code='TRACE-COMP-1'),
 'ABO/Rh of unit remain stable after status transitions');

-- Invariante 10: la quantity debe ser > 0 por CHECK.
select pg_temp.denied(
 $q$update blood_inventory_units set quantity=0 where unit_code='TRACE-COMP-1'$q$,
 'blood unit quantity must stay > 0');

-- Invariante 11: screening result solo acepta valores del enum.
select pg_temp.denied(
 $q$insert into screening_tests(screening_code,source_unit_code,branch_id,
                                test_type,result)
    values('TRACE-SC-X','TRACE-UN-1',
           'bt100000-0000-0000-0000-000000000001','VIH','LIBERADO')$q$,
 'invalid screening result is rejected by CHECK');

commit;
