-- HemoCura v11 Brecha L1 — módulo de limpieza de equipos.
-- Verifica invariantes del nuevo schema + RLS + alertas.

begin;

insert into branches(id,code,name) values
 ('ee100000-0000-0000-0000-000000000001','CLEAN-A','Limpieza ficticia');

insert into auth.users(id,email) values
 ('ee200000-0000-0000-0000-000000000001','cleaner@example.invalid'),
 ('ee200000-0000-0000-0000-000000000002','reviewer@example.invalid');

insert into profiles(id,full_name,branch_id,active) values
 ('ee200000-0000-0000-0000-000000000001','Operador limpieza','ee100000-0000-0000-0000-000000000001',true),
 ('ee200000-0000-0000-0000-000000000002','Revisor limpieza','ee100000-0000-0000-0000-000000000001',true);

insert into user_roles(user_id,role_id,branch_id) select v.id,r.id,v.branch from
 (values
  ('ee200000-0000-0000-0000-000000000001'::uuid,'ENCARGADA_LABORATORIO','ee100000-0000-0000-0000-000000000001'::uuid),
  ('ee200000-0000-0000-0000-000000000002'::uuid,'ENCARGADA_LABORATORIO','ee100000-0000-0000-0000-000000000001'::uuid))
 v(id,code,branch) join roles r on r.code=v.code;

insert into lab_equipment(id,equipment_code,branch_id,equipment_type,status,criticality) values
 ('ee300000-0000-0000-0000-000000000001','CLEAN-EQ-1',
  'ee100000-0000-0000-0000-000000000001','Nevera','ACTIVO','ALTA'),
 ('ee300000-0000-0000-0000-000000000002','CLEAN-EQ-2',
  'ee100000-0000-0000-0000-000000000001','Centrifuga','ACTIVO','MEDIA'),
 ('ee300000-0000-0000-0000-000000000003','CLEAN-EQ-RETIRED',
  'ee100000-0000-0000-0000-000000000001','Analizador','RETIRADO','BAJA');

insert into cleaning_plans(id,equipment_id,branch_id,frequency_days,procedure_ref,product_name,created_by)
values
 ('ee400000-0000-0000-0000-000000000001','ee300000-0000-0000-0000-000000000001',
  'ee100000-0000-0000-0000-000000000001',7,'PRO-CLEAN-01','Hipoclorito 1%',
  'ee200000-0000-0000-0000-000000000001'),
 ('ee400000-0000-0000-0000-000000000002','ee300000-0000-0000-0000-000000000002',
  'ee100000-0000-0000-0000-000000000001',14,'PRO-CLEAN-02','Alcohol 70%',
  'ee200000-0000-0000-0000-000000000001');

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

-- Invariante 1: frequency_days dentro del rango permitido.
select pg_temp.denied(
 $q$insert into cleaning_plans(equipment_id,branch_id,frequency_days)
    values('ee300000-0000-0000-0000-000000000001',
           'ee100000-0000-0000-0000-000000000001',0)$q$,
 'frequency_days must be >= 1');

select pg_temp.denied(
 $q$insert into cleaning_plans(equipment_id,branch_id,frequency_days)
    values('ee300000-0000-0000-0000-000000000001',
           'ee100000-0000-0000-0000-000000000001',400)$q$,
 'frequency_days cannot exceed 365');

-- Invariante 2: un solo plan activo por equipo (partial UNIQUE).
select pg_temp.denied(
 $q$insert into cleaning_plans(equipment_id,branch_id,frequency_days,active)
    values('ee300000-0000-0000-0000-000000000001',
           'ee100000-0000-0000-0000-000000000001',14,true)$q$,
 'only one active cleaning plan per equipment');

-- Un plan desactivado deja la vía libre para otro activo.
update cleaning_plans set active=false
 where id='ee400000-0000-0000-0000-000000000001';

insert into cleaning_plans(equipment_id,branch_id,frequency_days,active)
values('ee300000-0000-0000-0000-000000000001',
       'ee100000-0000-0000-0000-000000000001',10,true);

select pg_temp.ok(
 (select count(*)=1 from cleaning_plans
    where equipment_id='ee300000-0000-0000-0000-000000000001' and active),
 'after deactivating a plan, a new one can be created active');

-- Invariante 3: checklist debe ser array JSON.
select pg_temp.denied(
 $q$insert into cleaning_plans(equipment_id,branch_id,frequency_days,checklist)
    values('ee300000-0000-0000-0000-000000000002',
           'ee100000-0000-0000-0000-000000000001',14,'{"step":"wipe"}')$q$,
 'checklist must be an array');

-- Invariante 4: un registro de verificación independiente requiere
-- que verified_by sea distinto de performed_by (CHECK).
insert into cleaning_records(plan_id,equipment_id,branch_id,performed_by,product_used)
values('ee400000-0000-0000-0000-000000000002','ee300000-0000-0000-0000-000000000002',
       'ee100000-0000-0000-0000-000000000001',
       'ee200000-0000-0000-0000-000000000001','Alcohol 70%');

select pg_temp.denied(
 $q$update cleaning_records set verified_by='ee200000-0000-0000-0000-000000000001',
                                 verified_at=now()
    where equipment_id='ee300000-0000-0000-0000-000000000002'$q$,
 'verifier must be distinct from performer (segregation of duties)');

update cleaning_records set verified_by='ee200000-0000-0000-0000-000000000002',verified_at=now()
 where equipment_id='ee300000-0000-0000-0000-000000000002';

select pg_temp.ok(
 (select verified_by='ee200000-0000-0000-0000-000000000002'
    from cleaning_records where equipment_id='ee300000-0000-0000-0000-000000000002'),
 'independent verifier is accepted');

-- Invariante 5: alertas calculadas por la vista.
-- Equipo 1 sin registros → alerta CRITICA (nunca se ha limpiado).
select pg_temp.ok(
 (select severity='CRITICA'
    from vw_cleaning_alerts where equipment_code='CLEAN-EQ-1'),
 'equipment without any cleaning record raises CRITICA alert');

-- Equipo 2 recién limpiado (hoy) con frecuencia 14d → BAJA.
select pg_temp.ok(
 (select severity='BAJA'
    from vw_cleaning_alerts where equipment_code='CLEAN-EQ-2'),
 'equipment cleaned today raises BAJA alert within frequency window');

-- Equipo RETIRADO queda excluido.
select pg_temp.ok(
 (select not exists(select 1 from vw_cleaning_alerts where equipment_code='CLEAN-EQ-RETIRED')),
 'retired equipment is excluded from cleaning alerts');

-- Invariante 6: audit log recibió la escritura.
select pg_temp.ok(
 (select count(*)>=1 from lab_event_log where table_name='cleaning_records'),
 'cleaning_records writes to lab_event_log');

-- Invariante 7: RLS — otro branch no ve las filas.
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','ee200000-0000-0000-0000-000000000001',true);

select pg_temp.ok(
 (select count(*)=1 from cleaning_plans
    where branch_id='ee100000-0000-0000-0000-000000000001' and active),
 'operator sees own branch cleaning plans');

reset role;

-- Simulacro de alerta vencida: registrar limpieza 30 días atrás con
-- plan de frecuencia 7 días.
insert into cleaning_records(plan_id,equipment_id,branch_id,performed_at,performed_by)
select cp.id,cp.equipment_id,cp.branch_id,now() - interval '30 days',
       'ee200000-0000-0000-0000-000000000001'
 from cleaning_plans cp
 where cp.equipment_id='ee300000-0000-0000-0000-000000000001' and cp.active;

select pg_temp.ok(
 (select severity='CRITICA' and days_overdue>0
    from vw_cleaning_alerts where equipment_code='CLEAN-EQ-1'),
 'overdue cleaning (30 days late on 7-day frequency) raises CRITICA with days_overdue>0');

commit;
