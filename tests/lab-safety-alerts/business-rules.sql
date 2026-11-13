-- Lab safety alerts — prompt maestro HemoCura v11 §17 escenarios críticos:
--   #2 "Un equipo con temperatura fuera de rango genera una alerta"
--   #3 "Una lectura inválida no se acepta" (parcial: enums y rangos)
--   #4 "Un mantenimiento vencido se identifica"
--
-- Verifica las vistas vw_cold_chain_excursions (en sql/39) y
-- vw_equipment_alerts (en sql/35) con escenarios positivos y negativos,
-- más los CHECKs de dominio sobre lab_equipment.criticality y .status.

begin;

insert into branches(id,code,name) values
 ('dd100000-0000-0000-0000-000000000001','ALERT-A','Alertas ficticia');

-- Dispositivo de cadena de frío con rango 2-6 °C.
insert into cold_chain_devices(id,device_code,branch_id,device_type,
                                min_temp,max_temp,active)
values('dd200000-0000-0000-0000-000000000001','ALERT-COLD-1',
       'dd100000-0000-0000-0000-000000000001','REFRIGERADOR',
       2,6,true);

-- Lectura dentro de rango.
insert into cold_chain_readings(device_id,temperature) values
 ('dd200000-0000-0000-0000-000000000001',4.5);

-- Lectura fuera de rango (debe quedar persistida; la vista la marca).
insert into cold_chain_readings(device_id,temperature) values
 ('dd200000-0000-0000-0000-000000000001',9.0);

-- Lectura fuera de rango por debajo del mínimo.
insert into cold_chain_readings(device_id,temperature) values
 ('dd200000-0000-0000-0000-000000000001',-1.5);

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

-- #2 — La vista vw_cold_chain_excursions incluye las 2 lecturas fuera de rango.
select pg_temp.ok(
 (select count(*)=2 from vw_cold_chain_excursions
    where device_code='ALERT-COLD-1' and status='FUERA_RANGO'),
 'temperature readings outside allowed band raise excursion signals');

-- #2 — La lectura conforme no aparece como excursión.
select pg_temp.ok(
 (select not exists(
    select 1 from vw_cold_chain_excursions
     where device_code='ALERT-COLD-1' and temperature=4.5)),
 'in-range reading does not raise an excursion');

-- #3 — lab_equipment.criticality solo acepta valores del enum.
select pg_temp.denied(
 $q$insert into lab_equipment(equipment_code,branch_id,equipment_type,criticality)
    values('ALERT-EQ-X','dd100000-0000-0000-0000-000000000001','Analizador','URGENTE')$q$,
 'invalid equipment criticality is rejected');

-- #3 — lab_equipment.status solo acepta valores del enum.
select pg_temp.denied(
 $q$insert into lab_equipment(equipment_code,branch_id,equipment_type,status)
    values('ALERT-EQ-Y','dd100000-0000-0000-0000-000000000001','Analizador','LIBERADO')$q$,
 'invalid equipment status is rejected');

-- Equipos para alertas de calibración/mantenimiento.
insert into lab_equipment(id,equipment_code,branch_id,equipment_type,status,
                           criticality,calibration_required,maintenance_required,
                           next_calibration_date,next_maintenance_date)
values
 ('dd300000-0000-0000-0000-000000000001','ALERT-EQ-OVERDUE-CAL',
  'dd100000-0000-0000-0000-000000000001','Analizador','ACTIVO','ALTA',
  true,true,current_date-10,current_date+45),
 ('dd300000-0000-0000-0000-000000000002','ALERT-EQ-SOON-CAL',
  'dd100000-0000-0000-0000-000000000001','Centrífuga','ACTIVO','MEDIA',
  true,true,current_date+5,current_date+45),
 ('dd300000-0000-0000-0000-000000000003','ALERT-EQ-SOON-MED',
  'dd100000-0000-0000-0000-000000000001','Sellador','ACTIVO','MEDIA',
  false,true,null,current_date+20),
 ('dd300000-0000-0000-0000-000000000004','ALERT-EQ-OVERDUE-MAINT',
  'dd100000-0000-0000-0000-000000000001','Analizador','ACTIVO','CRITICA',
  false,true,null,current_date-5),
 ('dd300000-0000-0000-0000-000000000005','ALERT-EQ-RETIRED',
  'dd100000-0000-0000-0000-000000000001','Analizador','RETIRADO','ALTA',
  true,true,current_date-100,current_date-100),
 ('dd300000-0000-0000-0000-000000000006','ALERT-EQ-NOCAL',
  'dd100000-0000-0000-0000-000000000001','Analizador','ACTIVO','BAJA',
  false,false,current_date-50,null);

-- #4 — Calibración vencida → severidad CRITICA.
select pg_temp.ok(
 (select severity='CRITICA' and alert_type='CALIBRACION'
    from vw_equipment_alerts
   where equipment_code='ALERT-EQ-OVERDUE-CAL' and alert_type='CALIBRACION'),
 'overdue calibration produces CRITICA alert');

-- #4 — Calibración próxima (5 días) → severidad ALTA (<=7 días).
select pg_temp.ok(
 (select severity='ALTA'
    from vw_equipment_alerts
   where equipment_code='ALERT-EQ-SOON-CAL' and alert_type='CALIBRACION'),
 'calibration due within a week produces ALTA alert');

-- #4 — Mantenimiento en 20 días → severidad MEDIA (<=30 días).
select pg_temp.ok(
 (select severity='MEDIA'
    from vw_equipment_alerts
   where equipment_code='ALERT-EQ-SOON-MED' and alert_type='MANTENIMIENTO'),
 'maintenance due within a month produces MEDIA alert');

-- #4 — Mantenimiento vencido → CRITICA.
select pg_temp.ok(
 (select severity='CRITICA'
    from vw_equipment_alerts
   where equipment_code='ALERT-EQ-OVERDUE-MAINT' and alert_type='MANTENIMIENTO'),
 'overdue maintenance produces CRITICA alert');

-- Equipo RETIRADO queda excluido aunque tenga fechas vencidas.
select pg_temp.ok(
 (select not exists(
    select 1 from vw_equipment_alerts
     where equipment_code='ALERT-EQ-RETIRED')),
 'retired equipment is excluded from alerts');

-- Equipo con flags false queda excluido aunque tenga fecha vencida.
select pg_temp.ok(
 (select not exists(
    select 1 from vw_equipment_alerts
     where equipment_code='ALERT-EQ-NOCAL')),
 'equipment without calibration/maintenance flags is excluded');

-- Equipo sin alerta cercana no aparece.
select pg_temp.ok(
 (select not exists(
    select 1 from vw_equipment_alerts
     where equipment_code='ALERT-EQ-OVERDUE-CAL' and alert_type='MANTENIMIENTO')),
 'equipment with maintenance beyond 30 days does not alert for that type');

commit;
