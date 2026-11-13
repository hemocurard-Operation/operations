begin;

insert into branches(id,code,name) values ('rm100000-0000-0000-0000-000000000001','REG-A','Reg ficticia');
insert into auth.users(id,email) values
 ('rm200000-0000-0000-0000-000000000001','regowner@example.invalid'),
 ('rm200000-0000-0000-0000-000000000002','regreviewer@example.invalid');
insert into profiles(id,full_name,branch_id,active) values
 ('rm200000-0000-0000-0000-000000000001','Owner','rm100000-0000-0000-0000-000000000001',true),
 ('rm200000-0000-0000-0000-000000000002','Reviewer','rm100000-0000-0000-0000-000000000001',true);

create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.denied(stmt text,label text) returns void language plpgsql as $$
begin begin execute stmt;exception when others then raise notice 'PASS %',label;return;end;
 raise exception 'FAIL unexpectedly allowed %',label;end$$;

-- Seed presente.
select pg_temp.ok(
 (select count(*)>=11 from regulatory_requirements),
 'seed includes at least 11 regulatory requirements');

select pg_temp.ok(
 (select count(distinct domain)>=7 from regulatory_requirements),
 'seed covers at least 7 domains');

-- Invariante 1: assessments scope UNIQUE por requirement+branch.
insert into regulatory_assessments(requirement_id,branch_id,status,maturity,owner_user_id)
 select id,'rm100000-0000-0000-0000-000000000001','EN_DESARROLLO',2,'rm200000-0000-0000-0000-000000000001'
  from regulatory_requirements where requirement_code='LEY-42-01-GEN';

select pg_temp.denied(
 $q$insert into regulatory_assessments(requirement_id,branch_id,status,maturity)
    select id,'rm100000-0000-0000-0000-000000000001','IMPLEMENTADO',3
     from regulatory_requirements where requirement_code='LEY-42-01-GEN'$q$,
 'cannot create two assessments for same requirement+branch');

-- Invariante 2: status fuera del enum rechazado.
select pg_temp.denied(
 $q$update regulatory_assessments set status='INVENTADO'
    where requirement_id=(select id from regulatory_requirements where requirement_code='LEY-42-01-GEN')$q$,
 'invalid assessment status is rejected');

-- Invariante 3: maturity fuera de rango.
select pg_temp.denied(
 $q$update regulatory_assessments set maturity=7
    where requirement_id=(select id from regulatory_requirements where requirement_code='LEY-42-01-GEN')$q$,
 'maturity > 4 is rejected');

-- Invariante 4: segregación de funciones en acciones.
insert into regulatory_actions(requirement_id,branch_id,title,owner_user_id)
 select id,'rm100000-0000-0000-0000-000000000001','Preparar renovación de habilitación',
        'rm200000-0000-0000-0000-000000000001'
  from regulatory_requirements where requirement_code='LEY-42-01-GEN';

select pg_temp.denied(
 $q$update regulatory_actions
   set verified_by='rm200000-0000-0000-0000-000000000001',verified_at=now()
   where owner_user_id='rm200000-0000-0000-0000-000000000001'$q$,
 'verifier must be distinct from owner');

update regulatory_actions
 set verified_by='rm200000-0000-0000-0000-000000000002',verified_at=now()
 where owner_user_id='rm200000-0000-0000-0000-000000000001';

select pg_temp.ok(
 (select verified_by='rm200000-0000-0000-0000-000000000002' from regulatory_actions
   where owner_user_id='rm200000-0000-0000-0000-000000000001'),
 'independent verifier is accepted');

-- Invariante 5: matrix view combina correctamente.
select pg_temp.ok(
 (select overall_state='PENDIENTE' from vw_regulatory_matrix
   where requirement_code='LEY-42-01-GEN'),
 'requirement with EN_DESARROLLO assessment shows PENDIENTE');

-- Verificar transición a VERIFICADO con última revisión reciente → AL_DIA.
update regulatory_assessments
 set status='VERIFICADO',last_reviewed_at=now(),
     reviewed_by='rm200000-0000-0000-0000-000000000002'
 where requirement_id=(select id from regulatory_requirements where requirement_code='LEY-42-01-GEN');

select pg_temp.ok(
 (select overall_state='AL_DIA' from vw_regulatory_matrix
   where requirement_code='LEY-42-01-GEN'),
 'VERIFICADO + recent review shows AL_DIA');

-- Requisito sin assessment → SIN_EVALUAR.
select pg_temp.ok(
 (select overall_state='SIN_EVALUAR' from vw_regulatory_matrix
   where requirement_code='LEY-172-13-DP'),
 'requirement without assessment shows SIN_EVALUAR');

commit;
