begin;

insert into branches(id,code,name) values ('ca100000-0000-0000-0000-000000000001','CM-A','Comercial purpose');
insert into auth.users(id,email) values('ca200000-0000-0000-0000-000000000001','agent@example.invalid');
insert into profiles(id,full_name,branch_id,active) values
 ('ca200000-0000-0000-0000-000000000001','Agente','ca100000-0000-0000-0000-000000000001',true);
insert into customers(id,name,active) values('ca300000-0000-0000-0000-000000000001','Hospital ficticio',true);

create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.denied(stmt text,label text) returns void language plpgsql as $$
begin begin execute stmt;exception when others then raise notice 'PASS %',label;return;end;
 raise exception 'FAIL unexpectedly allowed %',label;end$$;

-- Visita sin purpose_type (legacy) sigue aceptada.
insert into commercial_visits(branch_id,customer_id,agent_id,scheduled_at,purpose)
 values('ca100000-0000-0000-0000-000000000001','ca300000-0000-0000-0000-000000000001',
        'ca200000-0000-0000-0000-000000000001',now()+interval '1 day','Visita general sin tipificar');

select pg_temp.ok(
 (select count(*)=1 from commercial_visits where purpose_type is null),
 'legacy visit without purpose_type is still accepted');

-- Nuevos valores aceptados.
insert into commercial_visits(branch_id,customer_id,agent_id,scheduled_at,purpose,purpose_type)
 values
  ('ca100000-0000-0000-0000-000000000001','ca300000-0000-0000-0000-000000000001',
   'ca200000-0000-0000-0000-000000000001',now()+interval '2 day','Promoción donación','PROMOCION_DONACION'),
  ('ca100000-0000-0000-0000-000000000001','ca300000-0000-0000-0000-000000000001',
   'ca200000-0000-0000-0000-000000000001',now()+interval '3 day','Educación residentes','EDUCACION_INSTITUCIONAL'),
  ('ca100000-0000-0000-0000-000000000001','ca300000-0000-0000-0000-000000000001',
   'ca200000-0000-0000-0000-000000000001',now()+interval '4 day','Cámara hiperbárica','CAMARA_HIPERBARICA');

select pg_temp.ok(
 (select count(*)=3 from commercial_visits where purpose_type in ('PROMOCION_DONACION','EDUCACION_INSTITUCIONAL','CAMARA_HIPERBARICA')),
 'new purpose_type values are accepted');

-- Valor fuera del enum es rechazado.
select pg_temp.denied(
 $q$insert into commercial_visits(branch_id,customer_id,agent_id,scheduled_at,purpose,purpose_type)
    values('ca100000-0000-0000-0000-000000000001','ca300000-0000-0000-0000-000000000001',
           'ca200000-0000-0000-0000-000000000001',now()+interval '5 day','X','PICNIC')$q$,
 'invalid purpose_type is rejected');

-- Vista agrega correctamente.
select pg_temp.ok(
 (select count(distinct purpose_type)>=4 from vw_commercial_activity_mix
    where branch_id='ca100000-0000-0000-0000-000000000001'),
 'vw_commercial_activity_mix groups by purpose_type including SIN_TIPIFICAR');

select pg_temp.ok(
 (select visits_count=1 from vw_commercial_activity_mix
    where purpose_type='PROMOCION_DONACION'
      and branch_id='ca100000-0000-0000-0000-000000000001'),
 'activity mix reports one visit per purpose_type as expected');

commit;
