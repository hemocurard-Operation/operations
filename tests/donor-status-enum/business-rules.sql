-- HemoCura v11 Brecha D4 — enum ampliado donors.status.

begin;

insert into branches(id,code,name) values
 ('ff100000-0000-0000-0000-000000000001','DS-A','Donor status ficticia');

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

-- Legacy sigue válido.
insert into donors(donor_code,branch_id,donor_type,status) values
 ('DS-LEGACY1','ff100000-0000-0000-0000-000000000001','VOLUNTARIO','ACEPTADO'),
 ('DS-LEGACY2','ff100000-0000-0000-0000-000000000001','VOLUNTARIO','DIFERIDO');

select pg_temp.ok(
 (select count(*)=2 from donors where donor_code like 'DS-LEGACY%'),
 'legacy ACEPTADO/DIFERIDO values still accepted');

-- Nuevos estados funcionan con reason/deferral_type.
insert into donors(donor_code,branch_id,donor_type,status,deferral_reason) values
 ('DS-NEW-TEMP','ff100000-0000-0000-0000-000000000001','VOLUNTARIO','DIFERIDO_TEMPORAL','Hemoglobina baja hoy'),
 ('DS-NEW-PERM','ff100000-0000-0000-0000-000000000001','VOLUNTARIO','DIFERIDO_PERMANENTE','Conducta de riesgo');

insert into donors(donor_code,branch_id,donor_type,status,deferral_type) values
 ('DS-HEMO','ff100000-0000-0000-0000-000000000001','VOLUNTARIO','HEMOGLOBINA_BAJA','HEMOGLOBINA_BAJA');

insert into donors(donor_code,branch_id,donor_type,status) values
 ('DS-PENDING','ff100000-0000-0000-0000-000000000001','VOLUNTARIO','PENDIENTE');

select pg_temp.ok(
 (select count(*)=4 from donors where donor_code like 'DS-NEW%' or donor_code like 'DS-HEMO' or donor_code like 'DS-PENDING'),
 'new extended status values are accepted');

-- Status fuera del enum es rechazado.
select pg_temp.denied(
 $q$insert into donors(donor_code,branch_id,donor_type,status)
    values('DS-BAD','ff100000-0000-0000-0000-000000000001','VOLUNTARIO','INVENTADO')$q$,
 'status outside enum is rejected');

-- deferral_type fuera del enum es rechazado.
select pg_temp.denied(
 $q$insert into donors(donor_code,branch_id,donor_type,status,deferral_type)
    values('DS-BAD2','ff100000-0000-0000-0000-000000000001','VOLUNTARIO','DIFERIDO_TEMPORAL','PIRATEADO')$q$,
 'deferral_type outside enum is rejected');

-- Diferimiento sin reason ni type es rechazado.
select pg_temp.denied(
 $q$insert into donors(donor_code,branch_id,donor_type,status)
    values('DS-BAD3','ff100000-0000-0000-0000-000000000001','VOLUNTARIO','DIFERIDO_TEMPORAL')$q$,
 'extended deferral without reason or type is rejected');

-- HEMOGLOBINA_BAJA sin razón ni tipo es rechazado.
select pg_temp.denied(
 $q$insert into donors(donor_code,branch_id,donor_type,status)
    values('DS-BAD4','ff100000-0000-0000-0000-000000000001','VOLUNTARIO','HEMOGLOBINA_BAJA')$q$,
 'HEMOGLOBINA_BAJA without reason/type is rejected');

-- ACEPTADO sin razón sigue aceptado (no es un diferimiento).
insert into donors(donor_code,branch_id,donor_type,status)
 values('DS-OK','ff100000-0000-0000-0000-000000000001','VOLUNTARIO','ACEPTADO');

select pg_temp.ok(
 (select count(*)=1 from donors where donor_code='DS-OK'),
 'ACEPTADO without reason still allowed');

-- Índice parcial creado.
select pg_temp.ok(
 (select 1 from pg_indexes where indexname='donors_status_idx')=1,
 'partial index on non-ACEPTADO status exists');

commit;
