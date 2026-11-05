begin;
select set_config('request.jwt.claim.sub','f9200000-0000-0000-0000-000000000001',true);select set_config('request.jwt.claim.role','authenticated',true);
create function pg_temp.job_ok(v boolean,label text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.job_denied(stmt text,label text) returns void language plpgsql as $$begin begin execute stmt;exception when others then raise notice 'PASS %',label;return;end;raise exception 'FAIL unexpected authorization %',label;end$$;
grant execute on all functions in schema pg_temp to authenticated;
select pg_temp.job_ok((select count(*)=2 from roles where code in ('CAMARISTA_HIPERBARICA','ASISTENTE_COMERCIAL')),'both job roles are in catalog');
select pg_temp.job_ok(not exists(select 1 from user_roles ur join roles r on r.id=ur.role_id where r.code in ('CAMARISTA_HIPERBARICA','ASISTENTE_COMERCIAL')),'catalog migration assigns no real accounts');
insert into branches(id,code,name) values('ad100000-0000-0000-0000-000000000001','JOB-A','Sucursal ficticia A'),('ad100000-0000-0000-0000-000000000002','JOB-B','Sucursal ficticia B');
insert into auth.users(id,email) values('ad200000-0000-0000-0000-000000000001','camarista-ficticio@example.invalid'),('ad200000-0000-0000-0000-000000000002','asistente-ficticio@example.invalid');
insert into profiles(id,full_name,branch_id,active) values('ad200000-0000-0000-0000-000000000001','Camarista ficticio','ad100000-0000-0000-0000-000000000001',true),('ad200000-0000-0000-0000-000000000002','Asistente ficticio','ad100000-0000-0000-0000-000000000001',true);
insert into user_roles(user_id,role_id,branch_id) select p.id,r.id,p.branch_id from profiles p join roles r on r.code=case when p.id='ad200000-0000-0000-0000-000000000001' then 'CAMARISTA_HIPERBARICA' else 'ASISTENTE_COMERCIAL' end where p.id in ('ad200000-0000-0000-0000-000000000001','ad200000-0000-0000-0000-000000000002');
insert into hyperbaric_resources(id,branch_id,name,capacity,procedure_reference,created_by) values('ad300000-0000-0000-0000-000000000001','ad100000-0000-0000-0000-000000000001','Cámara ficticia',1,'PROCEDIMIENTO-FICTICIO','ad200000-0000-0000-0000-000000000001');
set local role authenticated;select set_config('request.jwt.claim.sub','ad200000-0000-0000-0000-000000000001',true);
select pg_temp.job_ok(has_permission('HYPERBARIC_SESSION_WRITE') and has_permission('HYPERBARIC_WRITE') and has_permission('HYPERBARIC_PATIENT_PII'),'camarista can document sessions and manage clinical agenda');
select pg_temp.job_ok(not has_permission('HYPERBARIC_BILLING') and not has_permission('ACCESS_ADMIN') and not has_permission('UNIT_RELEASE'),'camarista has no billing, identity administration or blood release');
select pg_temp.job_ok((select count(*)=4 from vw_my_module_access where enabled),'camarista has four role windows');
select pg_temp.job_ok(not can_access_branch('ad100000-0000-0000-0000-000000000002'),'camarista cannot cross unassigned branch');
select wf_save_appointment('ad100000-0000-0000-0000-000000000001',null,jsonb_build_object('resource_id','ad300000-0000-0000-0000-000000000001','patient_name','Paciente ficticio','patient_phone','0000000000','starts_at',((current_date-1)::text||' 09:00-04')::timestamptz,'ends_at',((current_date-1)::text||' 10:00-04')::timestamptz,'operational_date',current_date-1,'shift','DIURNO','price',100,'currency','DOP','session_label','DEMO','referrer_name','Referidor ficticio')) as job_appointment \gset
select pg_temp.job_denied(format($q$select wf_record_session(%L,'{"performed_at":"2026-01-01T13:00Z","operational_date":"2026-01-01","shift":"DIURNO","status":"REALIZADA"}')$q$,:'job_appointment'),'session without clinical authorization consent and evidence rejected');
select wf_record_session(:'job_appointment',jsonb_build_object('clinical_authorization','AUTORIZACION-FICTICIA','consent_reference','CONSENTIMIENTO-FICTICIO','evidence','EVIDENCIA-FICTICIA','performed_at',((current_date-1)::text||' 09:00-04')::timestamptz,'operational_date',current_date-1,'shift','DIURNO','status','REALIZADA')) as job_session \gset
select pg_temp.job_ok((select provider_id=auth.uid() from hyperbaric_sessions where id=:'job_session'),'session stamps actual camarista account');
select set_config('request.jwt.claim.sub','ad200000-0000-0000-0000-000000000002',true);
select pg_temp.job_ok(has_permission('COMMERCIAL_WRITE') and not has_permission('HYPERBARIC_SESSION_WRITE') and not has_permission('HYPERBARIC_PATIENT_PII') and not has_permission('HYPERBARIC_BILLING') and not has_permission('ACCESS_ADMIN'),'commercial assistant has commercial scope without clinical financial or admin authority');
select pg_temp.job_ok((select count(*)=7 from vw_my_module_access where enabled),'commercial assistant has seven role windows');
select pg_temp.job_ok(not can_access_branch('ad100000-0000-0000-0000-000000000002'),'commercial assistant cannot cross unassigned branch');
select pg_temp.job_ok((select count(*)=0 from hyperbaric_sessions),'commercial assistant cannot read clinical sessions');
rollback;
