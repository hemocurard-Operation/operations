-- HemoCura v11 Brecha L2 — equipment_usage.

begin;

insert into branches(id,code,name) values
 ('ab100000-0000-0000-0000-000000000001','USG-A','Usage ficticia');

insert into auth.users(id,email) values
 ('ab200000-0000-0000-0000-000000000001','tech@example.invalid');
insert into profiles(id,full_name,branch_id,active) values
 ('ab200000-0000-0000-0000-000000000001','Técnico ficticio','ab100000-0000-0000-0000-000000000001',true);

insert into lab_equipment(id,equipment_code,branch_id,equipment_type,status,criticality,
                          usage_threshold_hours,usage_threshold_services) values
 ('ab300000-0000-0000-0000-000000000001','USG-EQ-1',
  'ab100000-0000-0000-0000-000000000001','Centrifuga','ACTIVO','ALTA',
  1000,500),
 ('ab300000-0000-0000-0000-000000000002','USG-EQ-SIN-UMBRAL',
  'ab100000-0000-0000-0000-000000000001','Analizador','ACTIVO','MEDIA',null,null);

create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;

create function pg_temp.denied(stmt text,label text) returns void language plpgsql as $$
begin begin execute stmt;exception when others then raise notice 'PASS %',label;return;end;
 raise exception 'FAIL unexpectedly allowed %',label;end$$;

-- Invariante 1: al menos uno de hours/services requerido.
select pg_temp.denied(
 $q$insert into equipment_usage(equipment_id,branch_id)
    values('ab300000-0000-0000-0000-000000000001','ab100000-0000-0000-0000-000000000001')$q$,
 'at least one counter required');

-- Primera lectura.
insert into equipment_usage(equipment_id,branch_id,hours_counter,services_counter,recorded_by)
values('ab300000-0000-0000-0000-000000000001','ab100000-0000-0000-0000-000000000001',
       400,150,'ab200000-0000-0000-0000-000000000001');

-- Invariante 2: lecturas monotónicas (no retroceder sin reset documentado).
select pg_temp.denied(
 $q$insert into equipment_usage(equipment_id,branch_id,hours_counter,recorded_by)
    values('ab300000-0000-0000-0000-000000000001','ab100000-0000-0000-0000-000000000001',
           200,'ab200000-0000-0000-0000-000000000001')$q$,
 'non-monotonic hours without reset documentation is rejected');

-- Invariante 3: reset documentado en observations se acepta.
insert into equipment_usage(equipment_id,branch_id,hours_counter,observations,recorded_by)
values('ab300000-0000-0000-0000-000000000001','ab100000-0000-0000-0000-000000000001',
       10,'Reemplazo del módulo contador — ticket SRV-123',
       'ab200000-0000-0000-0000-000000000001');

select pg_temp.ok(
 (select count(*)=2 from equipment_usage
    where equipment_id='ab300000-0000-0000-0000-000000000001'),
 'documented reset allows lower counter reading');

-- Invariante 4: alerta DENTRO_UMBRAL tras reset (10 < 1000).
select pg_temp.ok(
 (select usage_status='DENTRO_UMBRAL' and severity='BAJA'
    from vw_equipment_usage_alerts where equipment_code='USG-EQ-1'),
 'after documented reset, usage within threshold reports BAJA');

-- Simulamos uso que cruza el umbral: nueva lectura 1200 h.
insert into equipment_usage(equipment_id,branch_id,hours_counter,recorded_by)
values('ab300000-0000-0000-0000-000000000001','ab100000-0000-0000-0000-000000000001',
       1200,'ab200000-0000-0000-0000-000000000001');

select pg_temp.ok(
 (select usage_status='UMBRAL_HORAS' and severity='CRITICA'
    from vw_equipment_usage_alerts where equipment_code='USG-EQ-1'),
 'crossing hours threshold raises UMBRAL_HORAS CRITICA');

-- Invariante 5: equipo sin umbrales no aparece en la vista.
select pg_temp.ok(
 (select not exists(select 1 from vw_equipment_usage_alerts
                     where equipment_code='USG-EQ-SIN-UMBRAL')),
 'equipment without thresholds is excluded from usage alerts');

-- Invariante 6: umbral de servicios funciona independiente.
insert into equipment_usage(equipment_id,branch_id,services_counter,recorded_by)
values('ab300000-0000-0000-0000-000000000001','ab100000-0000-0000-0000-000000000001',
       600,'ab200000-0000-0000-0000-000000000001');

select pg_temp.ok(
 (select severity='CRITICA' from vw_equipment_usage_alerts where equipment_code='USG-EQ-1'),
 'service counter threshold also raises CRITICA');

-- Invariante 7: usage_threshold_hours fuera de rango rechazado.
select pg_temp.denied(
 $q$update lab_equipment set usage_threshold_hours=200000
    where equipment_code='USG-EQ-1'$q$,
 'threshold hours out of range is rejected');

commit;
