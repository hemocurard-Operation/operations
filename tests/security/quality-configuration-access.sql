-- Synthetic fixtures only; all changes roll back.
begin;
select set_config('request.jwt.claim.sub','f9200000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
insert into branches(id,code,name) values
 ('ae100000-0000-0000-0000-000000000001','QC-A','Calidad ficticia A'),
 ('ae100000-0000-0000-0000-000000000002','QC-B','Calidad ficticia B');
insert into auth.users(id,email) select id,'quality-'||suffix||'@example.invalid' from(values
 ('ae200000-0000-0000-0000-000000000001'::uuid,'write'),('ae200000-0000-0000-0000-000000000002'::uuid,'read'),
 ('ae200000-0000-0000-0000-000000000003'::uuid,'foreign'),('ae200000-0000-0000-0000-000000000004'::uuid,'learner')) v(id,suffix);
insert into profiles(id,full_name,branch_id,active) select id,'Persona ficticia '||suffix,
 case when suffix='foreign' then 'ae100000-0000-0000-0000-000000000002'::uuid else 'ae100000-0000-0000-0000-000000000001'::uuid end,true
 from(values('ae200000-0000-0000-0000-000000000001'::uuid,'write'),('ae200000-0000-0000-0000-000000000002'::uuid,'read'),
 ('ae200000-0000-0000-0000-000000000003'::uuid,'foreign'),('ae200000-0000-0000-0000-000000000004'::uuid,'learner')) v(id,suffix);
insert into roles(code,name) values('QUALITY_SCOPED_TEST','Editor ficticio limitado a sucursal');
insert into role_permissions(role_id,permission_code) select r.id,p.permission_code from roles r cross join app_permissions p
 where r.code='QUALITY_SCOPED_TEST' and p.permission_code in ('INTERNAL_AUDIT_VIEW','INTERNAL_AUDIT_WRITE','COMPETENCY_VIEW','COMPETENCY_WRITE');
insert into user_roles(user_id,role_id,branch_id) select p.id,r.id,p.branch_id from profiles p
 join (values('ae200000-0000-0000-0000-000000000001'::uuid,'QUALITY_SCOPED_TEST'),('ae200000-0000-0000-0000-000000000002'::uuid,'GERENCIA_GENERAL'),
 ('ae200000-0000-0000-0000-000000000003'::uuid,'QUALITY_SCOPED_TEST'),('ae200000-0000-0000-0000-000000000004'::uuid,'CONSULTA'))v(id,code) on v.id=p.id
 join roles r on r.code=v.code;
insert into internal_audits(id,audit_code,branch_id,title,objective,lead_auditor_id,planned_date) values
 ('ae300000-0000-0000-0000-000000000001','QC-AUDIT-A','ae100000-0000-0000-0000-000000000001','Auditoría ficticia A','Objetivo ficticio','ae200000-0000-0000-0000-000000000001',current_date),
 ('ae300000-0000-0000-0000-000000000002','QC-AUDIT-B','ae100000-0000-0000-0000-000000000002','Auditoría ficticia B','Objetivo ficticio','ae200000-0000-0000-0000-000000000003',current_date),
 ('ae300000-0000-0000-0000-000000000003','QC-AUDIT-GLOBAL',null,'Auditoría global ficticia','Objetivo ficticio','ae200000-0000-0000-0000-000000000001',current_date);
insert into job_roles(id,role_code,title) values('ae400000-0000-0000-0000-000000000001','QC-JOB','Puesto ficticio');
insert into competency_catalog(id,competency_code,title,description) values('ae500000-0000-0000-0000-000000000001','QC-COMP','Competencia ficticia','Descripción ficticia');
create function pg_temp.q_ok(v boolean,label text) returns void language plpgsql as $$begin
 if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.q_denied(stmt text,label text,expected text default '42501') returns void language plpgsql as $$begin
 begin execute stmt;exception when others then
 if SQLSTATE<>expected then raise exception 'FAIL % unexpected SQLSTATE %: %',label,SQLSTATE,SQLERRM;end if;
 raise notice 'PASS %',label;return;end;raise exception 'FAIL unexpectedly allowed %',label;end$$;
set local role anon;select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claim.role','anon',true);
select pg_temp.q_denied('select count(*) from public.audit_plan_criteria','anonymous audit criteria denied');
select pg_temp.q_denied('select count(*) from public.job_role_competencies','anonymous competency matrix denied');
set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','ae200000-0000-0000-0000-000000000001',true);
insert into audit_plan_criteria(audit_id,criterion_id,result) select 'ae300000-0000-0000-0000-000000000001',id,'C' from audit_criteria_catalog where criterion_code='ISO15189-4-GEN';
update audit_plan_criteria set result='OBS',observation='Texto libre ficticio no copiado a bitácora' where audit_id='ae300000-0000-0000-0000-000000000001';
select pg_temp.q_ok((select count(*)=1 from audit_plan_criteria where audit_id='ae300000-0000-0000-0000-000000000001'),'authorized audit create and edit preserved');
select pg_temp.q_denied($q$insert into audit_plan_criteria(audit_id,criterion_id) select 'ae300000-0000-0000-0000-000000000002',id from audit_criteria_catalog where criterion_code='ISO15189-4-GEN'$q$,'foreign branch audit insert blocked');
select pg_temp.q_denied($q$update audit_plan_criteria set audit_id='ae300000-0000-0000-0000-000000000002' where audit_id='ae300000-0000-0000-0000-000000000001'$q$,'audit update cannot move record to foreign branch');
insert into job_role_competencies(job_role_id,competency_id,required_level) values('ae400000-0000-0000-0000-000000000001','ae500000-0000-0000-0000-000000000001',3);
insert into job_role_competencies(job_role_id,competency_id,required_level) values('ae400000-0000-0000-0000-000000000001','ae500000-0000-0000-0000-000000000001',4)
 on conflict(job_role_id,competency_id) do update set required_level=excluded.required_level;
select pg_temp.q_ok((select required_level=4 from job_role_competencies where job_role_id='ae400000-0000-0000-0000-000000000001'),'competency upsert contract preserved');
insert into job_role_competencies(job_role_id,competency_id,required_level) values('ae400000-0000-0000-0000-000000000001','ae500000-0000-0000-0000-000000000001',4)
 on conflict(job_role_id,competency_id) do update set required_level=excluded.required_level;
select pg_temp.q_ok((select count(*)=4 from audit_events where entity_reference in ('ae300000-0000-0000-0000-000000000001','ae400000-0000-0000-0000-000000000001')),'audit has before after and no duplicate on unchanged retry');
select pg_temp.q_ok(exists(select 1 from audit_events where entity_reference='ae400000-0000-0000-0000-000000000001' and before_data->>'required_level'='3' and after_data->>'required_level'='4'),'competency changes retain operational before after');
select pg_temp.q_ok(not exists(select 1 from audit_events where before_data::text||after_data::text like '%Texto libre ficticio%'),'audit avoids copying free text');
select pg_temp.q_denied('delete from audit_plan_criteria','ordinary audit deletion blocked');
select pg_temp.q_denied('delete from job_role_competencies','ordinary competency deletion blocked');
select set_config('request.jwt.claim.sub','ae200000-0000-0000-0000-000000000003',true);
select pg_temp.q_ok((select count(*)=0 from audit_plan_criteria where audit_id='ae300000-0000-0000-0000-000000000001'),'foreign branch cannot read criteria');
select set_config('request.jwt.claim.sub','ae200000-0000-0000-0000-000000000002',true);
select pg_temp.q_ok(exists(select 1 from audit_plan_criteria where audit_id='ae300000-0000-0000-0000-000000000001'),'authorized audit reader retains access');
with changes as(update audit_plan_criteria set result='NC' where audit_id='ae300000-0000-0000-0000-000000000001' returning id)
 select pg_temp.q_ok((select count(*)=0 from changes),'audit reader cannot edit');
with changes as(update job_role_competencies set required_level=5 where job_role_id='ae400000-0000-0000-0000-000000000001' returning id)
 select pg_temp.q_ok((select count(*)=0 from changes),'competency reader cannot edit');
select set_config('request.jwt.claim.sub','ae200000-0000-0000-0000-000000000004',true);
select pg_temp.q_ok(not has_permission('COMPETENCY_VIEW'),'learner has no competency management permission');
select pg_temp.q_ok(exists(select 1 from job_role_competencies where job_role_id='ae400000-0000-0000-0000-000000000001'),'training catalog remains readable by active learner');
select pg_temp.q_ok((select count(*)=0 from audit_plan_criteria),'learner cannot read audit criteria');
reset role;
update profiles set active=false where id='ae200000-0000-0000-0000-000000000001';
set local role authenticated;select set_config('request.jwt.claim.sub','ae200000-0000-0000-0000-000000000001',true);
select pg_temp.q_ok((select count(*)=0 from audit_plan_criteria),'inactive actor cannot read audit criteria');
select pg_temp.q_ok((select count(*)=0 from job_role_competencies),'inactive actor cannot read competency matrix');
reset role;update profiles set active=true where id='ae200000-0000-0000-0000-000000000001';
create function pg_temp.fail_quality_audit() returns trigger language plpgsql as $$begin
 if NEW.entity_table in ('audit_plan_criteria','job_role_competencies') then raise exception 'Synthetic audit failure';end if;return NEW;end$$;
create trigger synthetic_quality_audit_failure before insert on audit_events for each row execute function pg_temp.fail_quality_audit();
set local role authenticated;
select pg_temp.q_denied($q$update job_role_competencies set required_level=5 where job_role_id='ae400000-0000-0000-0000-000000000001'$q$,'audit failure prevents definitive configuration change','P0001');
select pg_temp.q_ok((select required_level=4 from job_role_competencies where job_role_id='ae400000-0000-0000-0000-000000000001'),'audit failure preserves previous value');
reset role;drop trigger synthetic_quality_audit_failure on audit_events;
set local role authenticated;
select set_config('request.jwt.claim.sub','f9200000-0000-0000-0000-000000000001',true);
insert into audit_plan_criteria(audit_id,criterion_id) select 'ae300000-0000-0000-0000-000000000002',id from audit_criteria_catalog where criterion_code='ISO15189-4-GEN';
select pg_temp.q_ok(exists(select 1 from audit_plan_criteria where audit_id='ae300000-0000-0000-0000-000000000002'),'global supervisor scope remains supported');
select set_config('request.jwt.claim.sub','ae200000-0000-0000-0000-000000000001',true);
insert into audit_plan_criteria(audit_id,criterion_id) select 'ae300000-0000-0000-0000-000000000003',id from audit_criteria_catalog where criterion_code='ISO15189-4-GEN';
select pg_temp.q_ok(exists(select 1 from audit_plan_criteria where audit_id='ae300000-0000-0000-0000-000000000003'),'authorized global audit remains supported');
rollback;
