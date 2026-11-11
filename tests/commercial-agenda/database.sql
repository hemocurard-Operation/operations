-- Isolated synthetic fixtures only. The concurrency runner reuses this prefix.
begin;
select set_config('request.jwt.claim.sub','f9200000-0000-0000-0000-000000000001',true);
insert into branches(id,code,name) values('cf100000-0000-0000-0000-000000000001','CA-A','Agenda comercial ficticia A'),('cf100000-0000-0000-0000-000000000002','CA-B','Agenda comercial ficticia B'),('cf100000-0000-0000-0000-000000000003','CA-C','Agenda comercial ficticia C');
insert into auth.users(id,email) values('cf200000-0000-0000-0000-000000000001','ca-agent@example.invalid'),('cf200000-0000-0000-0000-000000000002','ca-other-agent@example.invalid'),('cf200000-0000-0000-0000-000000000003','ca-foreign-agent@example.invalid');
insert into profiles(id,full_name,branch_id,active) values('cf200000-0000-0000-0000-000000000001','Agente ficticio A y B','cf100000-0000-0000-0000-000000000001',true),('cf200000-0000-0000-0000-000000000002','Segundo agente ficticio A','cf100000-0000-0000-0000-000000000001',true),('cf200000-0000-0000-0000-000000000003','Agente ficticio ajeno','cf100000-0000-0000-0000-000000000003',true);
insert into user_roles(user_id,role_id,branch_id) select v.actor,r.id,v.branch from (values('cf200000-0000-0000-0000-000000000001'::uuid,'cf100000-0000-0000-0000-000000000001'::uuid),('cf200000-0000-0000-0000-000000000001'::uuid,'cf100000-0000-0000-0000-000000000002'::uuid),('cf200000-0000-0000-0000-000000000002'::uuid,'cf100000-0000-0000-0000-000000000001'::uuid),('cf200000-0000-0000-0000-000000000003'::uuid,'cf100000-0000-0000-0000-000000000003'::uuid))v(actor,branch) cross join roles r where r.code='ASISTENTE_COMERCIAL';
insert into customers(id,name) values('cf400000-0000-0000-0000-000000000001','Cliente ficticio A'),('cf400000-0000-0000-0000-000000000002','Cliente ficticio B');
insert into commercial_locations(branch_id,customer_id,address,created_by) values('cf100000-0000-0000-0000-000000000001','cf400000-0000-0000-0000-000000000001','Dirección ficticia A','cf200000-0000-0000-0000-000000000001'),('cf100000-0000-0000-0000-000000000002','cf400000-0000-0000-0000-000000000002','Dirección ficticia B','cf200000-0000-0000-0000-000000000001');
insert into crm_contacts(id,branch_id,kind,full_name,center,owner_id) values('cf500000-0000-0000-0000-000000000001','cf100000-0000-0000-0000-000000000001','REFERIDOR','Médico ficticio A','Centro ficticio A','cf200000-0000-0000-0000-000000000001'),('cf500000-0000-0000-0000-000000000002','cf100000-0000-0000-0000-000000000002','REFERIDOR','Médico ficticio B','Centro ficticio B','cf200000-0000-0000-0000-000000000001');
insert into crm_visit_rules(contact_id,branch_id,slots,needs_review,rule_text) values('cf500000-0000-0000-0000-000000000001','cf100000-0000-0000-0000-000000000001','[]',true,'Confirmación ficticia requerida'),('cf500000-0000-0000-0000-000000000002','cf100000-0000-0000-0000-000000000002','[]',true,'Confirmación ficticia requerida');
update app_feature_flags set enabled=true where key='crm_weekly_planner';
-- END_SHARED_FIXTURE
create function pg_temp.ca_ok(v boolean,label text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.ca_denied(stmt text,expected text,label text) returns void language plpgsql as $$declare state text;begin begin execute stmt;exception when others then get stacked diagnostics state=returned_sqlstate;if state<>expected then raise exception 'FAIL % expected SQLSTATE %, got %: %',label,expected,state,sqlerrm;end if;raise notice 'PASS %',label;return;end;raise exception 'FAIL expected denial %',label;end$$;
create function pg_temp.ca_req(n integer) returns uuid language sql as $$select ('cf300000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid$$;
create function pg_temp.ca_time(n integer) returns timestamptz language sql stable as $$select date_trunc('day',now())+interval '15 days 9 hours'+make_interval(mins=>n)$$;
create function pg_temp.ca_legacy(n integer,branch integer default 1) returns jsonb language sql stable as $$select jsonb_build_object('customer_id',case when branch=1 then 'cf400000-0000-0000-0000-000000000001' else 'cf400000-0000-0000-0000-000000000002' end,'scheduled_at',pg_temp.ca_time(n),'duration_minutes',30,'purpose','Visita ficticia de prueba')$$;
create function pg_temp.ca_crm(n integer,branch integer default 1) returns jsonb language sql stable as $$select jsonb_build_object('contact_id',case when branch=1 then 'cf500000-0000-0000-0000-000000000001' else 'cf500000-0000-0000-0000-000000000002' end,'scheduled_at',pg_temp.ca_time(n),'duration_minutes',30,'rule_revision',1,'objective','Visita ficticia de prueba','exception_reason','Horario confirmado en prueba aislada')$$;
grant execute on all functions in schema pg_temp to authenticated,anon;
select pg_temp.ca_ok((select not enabled from app_feature_flags where key='commercial_agenda_union'),'agenda display flag defaults off independently of integrity');
set local role authenticated;select set_config('request.jwt.claim.sub','cf200000-0000-0000-0000-000000000001',true);select set_config('request.jwt.claim.role','authenticated',true);
select pg_temp.ca_ok(not (commercial_agenda('cf100000-0000-0000-0000-000000000001')->>'enabled')::boolean,'disabled agenda display reports its state');
select wf_save_visit('cf100000-0000-0000-0000-000000000001',null,pg_temp.ca_legacy(0)) as legacy_first \gset
select pg_temp.ca_denied($q$select crm_plan_action('cf100000-0000-0000-0000-000000000001','SAVE',pg_temp.ca_crm(10),pg_temp.ca_req(1))$q$,'P0001','legacy then CRM overlapping reservation is rejected');
select pg_temp.ca_ok((select count(*)=0 from crm_weekly_visits where created_by=auth.uid()),'failed CRM overlap creates no reservation');
select crm_plan_action('cf100000-0000-0000-0000-000000000001','SAVE',pg_temp.ca_crm(120),pg_temp.ca_req(2))->>'id' as crm_first \gset
select pg_temp.ca_denied($q$select wf_save_visit('cf100000-0000-0000-0000-000000000001',null,pg_temp.ca_legacy(130))$q$,'23P01','CRM then legacy overlapping reservation is rejected by shared trigger');
select pg_temp.ca_denied($q$select wf_save_visit('cf100000-0000-0000-0000-000000000002',null,pg_temp.ca_legacy(130,2))$q$,'23P01','same responsible cannot overlap across branches');
select pg_temp.ca_denied($q$select wf_save_visit('cf100000-0000-0000-0000-000000000001',null,pg_temp.ca_legacy(10))$q$,'23P01','two legacy overlapping reservations are rejected');
select crm_plan_action('cf100000-0000-0000-0000-000000000001','SAVE',pg_temp.ca_crm(30),pg_temp.ca_req(3));
select wf_save_visit('cf100000-0000-0000-0000-000000000001',null,pg_temp.ca_legacy(60));
select pg_temp.ca_ok((select count(*)=2 from crm_weekly_visits where created_by=auth.uid()),'half-open end and start adjacency is permitted between agendas');
select set_config('request.jwt.claim.sub','cf200000-0000-0000-0000-000000000002',true);
select wf_save_visit('cf100000-0000-0000-0000-000000000001',null,pg_temp.ca_legacy(10));
select pg_temp.ca_ok((select count(*)=1 from commercial_visits where agent_id=auth.uid()),'another responsible can reserve the same time');
select set_config('request.jwt.claim.sub','cf200000-0000-0000-0000-000000000001',true);
select crm_plan_action('cf100000-0000-0000-0000-000000000001','CANCEL',jsonb_build_object('id',:'crm_first','revision',1,'reason','Prueba de liberación'),pg_temp.ca_req(4));
select wf_save_visit('cf100000-0000-0000-0000-000000000001',null,pg_temp.ca_legacy(130));
select pg_temp.ca_ok((select status='CANCELADA' from crm_weekly_visits where id=:'crm_first'),'cancelled CRM visit preserves history and releases reservation');
select wf_save_visit('cf100000-0000-0000-0000-000000000001',:'legacy_first',jsonb_build_object('status','CANCELADA','commitment','Cancelación ficticia'));
select crm_plan_action('cf100000-0000-0000-0000-000000000001','SAVE',pg_temp.ca_crm(0),pg_temp.ca_req(5));
select pg_temp.ca_ok((select status='CANCELADA' from commercial_visits where id=:'legacy_first'),'cancelled legacy visit preserves history and releases reservation');
-- Simulate conflicts that predate this migration in the disposable DB only.
-- Replica mode is restored immediately; no application path can disable the trigger.
reset role;set local session_replication_role=replica;
insert into commercial_visits(id,branch_id,customer_id,agent_id,scheduled_at,duration_minutes,purpose,status) values('cf600000-0000-0000-0000-000000000001','cf100000-0000-0000-0000-000000000001','cf400000-0000-0000-0000-000000000001','cf200000-0000-0000-0000-000000000001',pg_temp.ca_time(600),60,'Conflicto histórico ficticio','PROPUESTA');
insert into crm_weekly_visits(id,branch_id,contact_id,agent_id,scheduled_at,duration_minutes,status,objective,rule_revision,created_by,request_id,payload) values('cf600000-0000-0000-0000-000000000002','cf100000-0000-0000-0000-000000000001','cf500000-0000-0000-0000-000000000001','cf200000-0000-0000-0000-000000000001',pg_temp.ca_time(610),30,'PLANIFICADA','Conflicto histórico ficticio',1,'cf200000-0000-0000-0000-000000000001',pg_temp.ca_req(90),'{}');
set local session_replication_role=origin;set local role authenticated;
select wf_save_visit('cf100000-0000-0000-0000-000000000001','cf600000-0000-0000-0000-000000000001',jsonb_build_object('status','CONFIRMADA','commitment','Nota ficticia sin mover reserva'));
select pg_temp.ca_ok((select commitment='Nota ficticia sin mover reserva' from commercial_visits where id='cf600000-0000-0000-0000-000000000001'),'existing conflict does not block note or active-status change without rescheduling');
select wf_save_visit('cf100000-0000-0000-0000-000000000001','cf600000-0000-0000-0000-000000000001',jsonb_build_object('status','REALIZADA','evidence','EVIDENCIA-FICTICIA'));
select pg_temp.ca_ok((select status='REALIZADA' from commercial_visits where id='cf600000-0000-0000-0000-000000000001'),'existing conflict does not block completed-state transition with evidence');
select crm_plan_action('cf100000-0000-0000-0000-000000000001','CANCEL',jsonb_build_object('id','cf600000-0000-0000-0000-000000000002','revision',1,'reason','Cancelación de conflicto ficticio'),pg_temp.ca_req(91));
reset role;update app_feature_flags set enabled=true where key='commercial_agenda_union';set local role authenticated;
select pg_temp.ca_ok((commercial_agenda('cf100000-0000-0000-0000-000000000001')->>'enabled')::boolean,'agenda display can be enabled without rewriting reservations');
select pg_temp.ca_ok((select bool_and(v->>'source'='crm_weekly_visits' and v->>'full_name' is not null) from jsonb_array_elements(commercial_agenda('cf100000-0000-0000-0000-000000000001')->'visits')v),'linked map agenda exposes source and readable contact within authorized branch');
select pg_temp.ca_denied($q$update commercial_visits set duration_minutes=5$q$,'42501','browser cannot bypass legacy visit contract');
select pg_temp.ca_denied($q$update crm_weekly_visits set duration_minutes=5$q$,'42501','browser cannot bypass CRM reservation contract');
select set_config('request.jwt.claim.sub','cf200000-0000-0000-0000-000000000003',true);
select pg_temp.ca_ok((select count(*)=0 from commercial_visits),'unassigned branch cannot read legacy visits');
select pg_temp.ca_ok((select count(*)=0 from crm_weekly_visits),'unassigned branch cannot read map visits');
select pg_temp.ca_denied($q$select commercial_agenda('cf100000-0000-0000-0000-000000000001')$q$,'42501','union agenda denies foreign branch RPC');
reset role;set local role anon;
select pg_temp.ca_denied($q$select commercial_agenda('cf100000-0000-0000-0000-000000000001')$q$,'42501','anonymous cannot read union agenda');
select pg_temp.ca_denied($q$select * from commercial_visits$q$,'42501','anonymous cannot read legacy visits');
select pg_temp.ca_denied($q$select * from crm_weekly_visits$q$,'42501','anonymous cannot read map visits');
rollback;
