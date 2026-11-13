begin;

insert into auth.users(id,email) values
 ('ba200000-0000-0000-0000-000000000001','medico@example.invalid'),
 ('ba200000-0000-0000-0000-000000000002','autor@example.invalid');
insert into branches(id,code,name) values('ba100000-0000-0000-0000-000000000001','DI-A','Donor intervals');
insert into profiles(id,full_name,branch_id,active) values
 ('ba200000-0000-0000-0000-000000000001','Médico ficticio','ba100000-0000-0000-0000-000000000001',true),
 ('ba200000-0000-0000-0000-000000000002','Autor ficticio','ba100000-0000-0000-0000-000000000001',true);

create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;

create function pg_temp.denied(stmt text,label text) returns void language plpgsql as $$
begin begin execute stmt;exception when others then raise notice 'PASS %',label;return;end;
 raise exception 'FAIL unexpectedly allowed %',label;end$$;

-- Seed presente.
select pg_temp.ok(
 (select count(*)>=7 from donation_interval_rules where active),
 'seed includes at least 7 donation types');

-- Sin aprobación, la función devuelve NULL (fallback al 84 hardcoded en la vista).
select pg_temp.ok(
 (select donor_min_interval_days('SANGRE_TOTAL') is null),
 'unapproved rules do not activate donor_min_interval_days');

-- Aprobar una regla.
update donation_interval_rules
   set approved_by='ba200000-0000-0000-0000-000000000001',approved_at=now()
 where donation_type='AFERESIS_PLAQUETAS';

select pg_temp.ok(
 (select donor_min_interval_days('AFERESIS_PLAQUETAS')=2),
 'approved rule exposes min_days via function');

-- Invariante: no se puede modificar min_days de una regla aprobada.
select pg_temp.denied(
 $q$update donation_interval_rules set min_days=5
    where donation_type='AFERESIS_PLAQUETAS'$q$,
 'approved rule is immutable on min_days');

-- Se puede desactivar.
update donation_interval_rules set active=false,superseded_at=now()
 where donation_type='AFERESIS_PLAQUETAS';

select pg_temp.ok(
 (select not active from donation_interval_rules where donation_type='AFERESIS_PLAQUETAS'),
 'approved rule can be deactivated (supersede pattern)');

-- Crear nueva versión aprobada y confirmar que la función ahora la devuelve.
insert into donation_interval_rules(donation_type,min_days,max_per_year,source_norm,active,
                                    approved_by,approved_at)
values('AFERESIS_PLAQUETAS',3,20,'AABB Technical Manual v31 — revisión 2026',true,
       'ba200000-0000-0000-0000-000000000001',now());

select pg_temp.ok(
 (select donor_min_interval_days('AFERESIS_PLAQUETAS')=3),
 'new approved version replaces the superseded one');

-- Range checks.
select pg_temp.denied(
 $q$insert into donation_interval_rules(donation_type,min_days,source_norm)
    values('EXP','TEST',0,'test')$q$,
 'invalid insert syntax rejected');

select pg_temp.denied(
 $q$insert into donation_interval_rules(donation_type,min_days,source_norm)
    values('EXP',0,'test')$q$,
 'min_days < 1 rejected');

select pg_temp.denied(
 $q$insert into donation_interval_rules(donation_type,min_days,source_norm)
    values('EXP',800,'test')$q$,
 'min_days > 730 rejected');

-- Unicidad: solo una regla activa por tipo.
select pg_temp.denied(
 $q$insert into donation_interval_rules(donation_type,min_days,source_norm,active,
                                       approved_by,approved_at)
    values('AFERESIS_PLAQUETAS',4,'test',true,
           'ba200000-0000-0000-0000-000000000001',now())$q$,
 'cannot have two active rules for same donation_type');

commit;
