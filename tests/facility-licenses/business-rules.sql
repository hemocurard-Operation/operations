begin;

insert into branches(id,code,name) values ('fl100000-0000-0000-0000-000000000001','FL-A','Licencia A');

create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.denied(stmt text,label text) returns void language plpgsql as $$
begin begin execute stmt;exception when others then raise notice 'PASS %',label;return;end;
 raise exception 'FAIL unexpectedly allowed %',label;end$$;

-- Insertar licencias con vencimientos distintos.
insert into facility_licenses(branch_id,license_type,authority,license_number,issued_at,expires_at) values
 ('fl100000-0000-0000-0000-000000000001','HABILITACION_BANCO_SANGRE','MSP RD','RES-123',
  current_date-365,current_date+120), -- OK
 ('fl100000-0000-0000-0000-000000000001','HABILITACION_LABORATORIO','MSP RD','RES-124',
  current_date-365,current_date+45),  -- MEDIA
 ('fl100000-0000-0000-0000-000000000001','HABILITACION_CAMARA_HIPERBARICA','MSP RD','RES-125',
  current_date-365,current_date+20),  -- ALTA
 ('fl100000-0000-0000-0000-000000000001','REGISTRO_MSP','MSP RD','REG-100',
  current_date-365,current_date-5);   -- CRITICA (vencida)

-- Invariante 1: severidad calculada por días hasta vencimiento.
select pg_temp.ok(
 (select severity='OK' from vw_license_alerts where license_number='RES-123'),
 'license expiring beyond 90 days shows OK');

select pg_temp.ok(
 (select severity='MEDIA' from vw_license_alerts where license_number='RES-124'),
 'license expiring in 45 days shows MEDIA');

select pg_temp.ok(
 (select severity='ALTA' from vw_license_alerts where license_number='RES-125'),
 'license expiring in 20 days shows ALTA');

select pg_temp.ok(
 (select severity='CRITICA' from vw_license_alerts where license_number='REG-100'),
 'expired license shows CRITICA');

-- Invariante 2: tipo fuera del enum rechazado.
select pg_temp.denied(
 $q$insert into facility_licenses(branch_id,license_type,authority,license_number,issued_at)
    values('fl100000-0000-0000-0000-000000000001','LICENCIA_PIRATA','MSP','X',current_date)$q$,
 'invalid license_type is rejected');

-- Invariante 3: expires_at anterior a issued_at es rechazado.
select pg_temp.denied(
 $q$insert into facility_licenses(branch_id,license_type,authority,license_number,issued_at,expires_at)
    values('fl100000-0000-0000-0000-000000000001','REGISTRO_MSP','MSP','REG-BAD',
           current_date,current_date-1)$q$,
 'expires_at before issued_at is rejected');

-- Invariante 4: UNIQUE sobre branch+type+number.
select pg_temp.denied(
 $q$insert into facility_licenses(branch_id,license_type,authority,license_number,issued_at)
    values('fl100000-0000-0000-0000-000000000001','HABILITACION_BANCO_SANGRE','MSP','RES-123',
           current_date)$q$,
 'duplicate branch+type+number is rejected');

-- Invariante 5: licencias ANULADAS no aparecen en alertas.
update facility_licenses set status='ANULADA' where license_number='RES-123';
select pg_temp.ok(
 (select not exists(select 1 from vw_license_alerts where license_number='RES-123')),
 'ANULADA licenses are excluded from alerts');

-- Invariante 6: días hasta vencimiento calculado correctamente.
select pg_temp.ok(
 (select days_to_expiry between 19 and 21 from vw_license_alerts where license_number='RES-125'),
 'days_to_expiry correctly computed');

commit;
