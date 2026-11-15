begin;

insert into branches(id,code,name) values ('da810000-0000-0000-0000-000000000001','DR-A','Daily reports');
insert into auth.users(id,email) values
 ('da820000-0000-0000-0000-000000000001','actor@example.invalid');
insert into profiles(id,full_name,branch_id,active) values
 ('da820000-0000-0000-0000-000000000001','Actor','da810000-0000-0000-0000-000000000001',true);

insert into user_roles(user_id,role_id,branch_id) select 'da820000-0000-0000-0000-000000000001',id,'da810000-0000-0000-0000-000000000001' from roles where code='ENCARGADA_LABORATORIO';
insert into role_permissions(role_id,permission_code) select id,p from roles cross join (values('DONORS_VIEW'),('DONORS_WRITE')) v(p) where code='ENCARGADA_LABORATORIO' on conflict do nothing;

create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;

select set_config('request.jwt.claim.sub','da820000-0000-0000-0000-000000000001',true);
-- Seed donantes: 3 aceptados, 2 diferidos con razones distintas, 1 rechazado.
insert into donors(donor_code,branch_id,donor_type,status,registration_date) values
 ('DR-OK-1','da810000-0000-0000-0000-000000000001','VOLUNTARIO','ACEPTADO',current_date),
 ('DR-OK-2','da810000-0000-0000-0000-000000000001','VOLUNTARIO','ACEPTADO',current_date),
 ('DR-OK-3','da810000-0000-0000-0000-000000000001','VOLUNTARIO','ACEPTADO',current_date);
insert into donors(donor_code,branch_id,donor_type,status,deferral_reason,registration_date) values
 ('DR-DEF-1','da810000-0000-0000-0000-000000000001','VOLUNTARIO','DIFERIDO_TEMPORAL','Hemoglobina baja hoy',current_date),
 ('DR-DEF-2','da810000-0000-0000-0000-000000000001','VOLUNTARIO','DIFERIDO_TEMPORAL','Medicamento reciente',current_date),
 ('DR-REJ-1','da810000-0000-0000-0000-000000000001','VOLUNTARIO','RECHAZADO','Edad fuera de rango',current_date);

-- Seed visitas: 5 asistidas, 1 no asistió.
insert into donor_visits(donor_id,branch_id,starts_at,status,created_by,responsible_name)
 select d.id,'da810000-0000-0000-0000-000000000001',
        clock_timestamp()+interval '30 milliseconds',
        'CONFIRMADA',
        'da820000-0000-0000-0000-000000000001','Receptor'
   from donors d where d.donor_code like 'DR-%';

select pg_sleep(0.1);
update donor_visits v set status=case when d.donor_code='DR-DEF-2' then 'NO_ASISTIO' else 'ASISTIO' end from donors d where v.donor_id=d.id and v.branch_id='da810000-0000-0000-0000-000000000001';
-- Seed donaciones efectivas: 3.
insert into donations(donation_code,donor_id,branch_id,source_unit_code,donation_date,collection_effective)
 select 'DR-DON-'||d.donor_code,d.id,'da810000-0000-0000-0000-000000000001',
        'DR-UNIT-'||d.donor_code,current_date,true
  from donors d where d.donor_code in ('DR-OK-1','DR-OK-2','DR-OK-3');

-- Test D1: la vista agrega correctamente.
select pg_temp.ok(
 (select effective_donations=3 from vw_daily_donor_report
   where branch_id='da810000-0000-0000-0000-000000000001' and day=current_date),
 'effective_donations counts 3 successful donations today');

select pg_temp.ok(
 (select attended_count=5 from vw_daily_donor_report
   where branch_id='da810000-0000-0000-0000-000000000001' and day=current_date),
 'attended_count reflects 5 ASISTIO visits');

select pg_temp.ok(
 (select no_show_count=1 from vw_daily_donor_report
   where branch_id='da810000-0000-0000-0000-000000000001' and day=current_date),
 'no_show_count reflects 1 NO_ASISTIO visit');

select pg_temp.ok(
 (select deferred_count>=2 from vw_daily_donor_report
   where branch_id='da810000-0000-0000-0000-000000000001' and day=current_date),
 'deferred_count captures DIFERIDO_TEMPORAL');

select pg_temp.ok(
 (select rejected_count>=1 from vw_daily_donor_report
   where branch_id='da810000-0000-0000-0000-000000000001' and day=current_date),
 'rejected_count captures RECHAZADO');

-- Tasa de aceptación = 3 efectivas / 5 asistidas = 60%
select pg_temp.ok(
 (select acceptance_rate_pct=60.0 from vw_daily_donor_report
   where branch_id='da810000-0000-0000-0000-000000000001' and day=current_date),
 'acceptance_rate_pct computed correctly');

-- Motivos de diferimiento aparecen en el JSON.
select pg_temp.ok(
 (select deferral_reasons ? 'Hemoglobina baja hoy' from vw_daily_donor_report
   where branch_id='da810000-0000-0000-0000-000000000001' and day=current_date),
 'deferral reasons include the ones registered');

rollback;
