begin;
create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.denied(stmt text,label text) returns void language plpgsql as $$begin begin execute stmt;exception when others then if sqlstate in ('42601','42702','42703','42883','42P01') then raise;end if;raise notice 'PASS %',label;return;end;raise exception 'FAIL unexpectedly allowed %',label;end$$;
insert into branches(id,code,name) values('c8100000-0000-0000-0000-000000000001','BI-A','Synthetic commercial A'),('c8100000-0000-0000-0000-000000000002','BI-B','Synthetic commercial B');
insert into auth.users(id,email) values('c8200000-0000-0000-0000-000000000001','commercial-a@example.invalid'),('c8200000-0000-0000-0000-000000000002','commercial-b@example.invalid');
insert into profiles(id,full_name,branch_id,active) values('c8200000-0000-0000-0000-000000000001','Commercial synthetic A','c8100000-0000-0000-0000-000000000001',true),('c8200000-0000-0000-0000-000000000002','Commercial synthetic B','c8100000-0000-0000-0000-000000000002',true);
insert into roles(id,code,name) values('c8300000-0000-0000-0000-000000000001','BI_TEST','Synthetic commercial');
insert into role_permissions(role_id,permission_code) values('c8300000-0000-0000-0000-000000000001','COMMERCIAL_VIEW'),('c8300000-0000-0000-0000-000000000001','COMMERCIAL_WRITE');
insert into user_roles(user_id,role_id,branch_id) values('c8200000-0000-0000-0000-000000000001','c8300000-0000-0000-0000-000000000001','c8100000-0000-0000-0000-000000000001');
insert into customers(id,name) values('c8400000-0000-0000-0000-000000000001','Synthetic center'),('c8400000-0000-0000-0000-000000000002','Other synthetic center');
select set_config('request.jwt.claim.sub','c8200000-0000-0000-0000-000000000001',true);
insert into operational_sales(id,sale_code,branch_id,customer_id,customer_name,status) values
 ('c8500000-0000-0000-0000-000000000001','BI-OUT','c8100000-0000-0000-0000-000000000001','c8400000-0000-0000-0000-000000000001','Synthetic center','DESPACHADA'),
 ('c8500000-0000-0000-0000-000000000002','BI-NODETAIL','c8100000-0000-0000-0000-000000000001','c8400000-0000-0000-0000-000000000001','Synthetic center','DESPACHADA'),
 ('c8500000-0000-0000-0000-000000000003','BI-CANCEL','c8100000-0000-0000-0000-000000000001','c8400000-0000-0000-0000-000000000001','Synthetic center','ANULADA');
insert into operational_sale_lines(sale_id,component_name,quantity,unit_price) values('c8500000-0000-0000-0000-000000000001','PG',3,0),('c8500000-0000-0000-0000-000000000003','PG',1,0);
insert into hyperbaric_resources(id,branch_id,name,capacity,procedure_reference,created_by) values('c8600000-0000-0000-0000-000000000001','c8100000-0000-0000-0000-000000000001','Synthetic chamber',1,'TEST','c8200000-0000-0000-0000-000000000001');
insert into hyperbaric_appointments(id,branch_id,resource_id,customer_id,patient_name,patient_phone,starts_at,ends_at,operational_date,shift,price,currency,session_label,referrer_name,created_by) values('c8700000-0000-0000-0000-000000000001','c8100000-0000-0000-0000-000000000001','c8600000-0000-0000-0000-000000000001','c8400000-0000-0000-0000-000000000001','SYNTHETIC','000',now()-interval '2 hours',now()-interval '1 hour',current_date,'DIURNO',0,'DOP','TEST','TEST','c8200000-0000-0000-0000-000000000001');
insert into hyperbaric_sessions(id,branch_id,appointment_id,performed_at,operational_date,shift,provider_id,clinical_authorization,consent_reference,evidence,status) values('c8800000-0000-0000-0000-000000000001','c8100000-0000-0000-0000-000000000001','c8700000-0000-0000-0000-000000000001',now()-interval '1 hour',current_date,'DIURNO','c8200000-0000-0000-0000-000000000001','TEST-AUTH','TEST-CONSENT','TEST-EVIDENCE','REALIZADA');
grant execute on all functions in schema pg_temp to authenticated,anon;
set local role authenticated;
select wf_save_opportunity('c8100000-0000-0000-0000-000000000001',null,'{"customer_id":"c8400000-0000-0000-0000-000000000001","title":"Physical delivery","stage":"GANADA","sale_id":"c8500000-0000-0000-0000-000000000001","target_units":3,"target_date":"2027-01-01","estimated_amount":999999,"currency":"USD"}') as won \gset
select pg_temp.ok((select stage='GANADA' and target_units=3 and estimated_amount=0 and currency='DOP' from commercial_opportunities where id=:'won'),'opportunity won with physical delivery without money');
select pg_temp.denied($q$select wf_save_opportunity('c8100000-0000-0000-0000-000000000001',null,'{"customer_id":"c8400000-0000-0000-0000-000000000001","title":"No evidence","stage":"GANADA"}')$q$,'won opportunity requires evidence');
select pg_temp.denied($q$select wf_save_opportunity('c8100000-0000-0000-0000-000000000001',null,'{"customer_id":"c8400000-0000-0000-0000-000000000001","title":"No detail","stage":"GANADA","sale_id":"c8500000-0000-0000-0000-000000000002"}')$q$,'delivery without physical lines cannot win');
select pg_temp.denied($q$select wf_save_opportunity('c8100000-0000-0000-0000-000000000001',null,'{"customer_id":"c8400000-0000-0000-0000-000000000001","title":"Cancelled","stage":"GANADA","sale_id":"c8500000-0000-0000-0000-000000000003"}')$q$,'cancelled delivery cannot win');
select pg_temp.denied($q$select wf_save_opportunity('c8100000-0000-0000-0000-000000000001',null,'{"customer_id":"c8400000-0000-0000-0000-000000000002","title":"Other center","stage":"GANADA","sale_id":"c8500000-0000-0000-0000-000000000001"}')$q$,'delivery evidence cannot cross centers');
select pg_temp.denied($q$select wf_save_opportunity('c8100000-0000-0000-0000-000000000002',null,'{"customer_id":"c8400000-0000-0000-0000-000000000001","title":"Other branch","stage":"PROSPECTO"}')$q$,'opportunity cannot cross branch permissions');
select wf_save_opportunity('c8100000-0000-0000-0000-000000000001',null,'{"customer_id":"c8400000-0000-0000-0000-000000000001","title":"Performed session","stage":"GANADA","service_type":"CAMARA_HIPERBARICA","hyperbaric_session_id":"c8800000-0000-0000-0000-000000000001"}') as service \gset
select pg_temp.ok((select hyperbaric_session_id is not null and hyperbaric_charge_id is null from commercial_opportunities where id=:'service'),'session evidence requires no invoice or charge');
select pg_temp.denied($q$select wf_save_opportunity('c8100000-0000-0000-0000-000000000001',null,'{"customer_id":"c8400000-0000-0000-0000-000000000002","title":"Wrong session center","stage":"GANADA","service_type":"CAMARA_HIPERBARICA","hyperbaric_session_id":"c8800000-0000-0000-0000-000000000001"}')$q$,'session evidence cannot cross centers');
select pg_temp.denied($q$select wf_save_opportunity('c8100000-0000-0000-0000-000000000001',null,'{"customer_id":"c8400000-0000-0000-0000-000000000001","title":"Bad plan","stage":"PROSPECTO","target_units":-1}')$q$,'negative planned quantities denied');
reset role;
update commercial_opportunities set estimated_amount=55,currency='USD' where id=:'won';
set local role authenticated;
select wf_save_opportunity('c8100000-0000-0000-0000-000000000001',:'won','{"customer_id":"c8400000-0000-0000-0000-000000000001","title":"Preserve history","stage":"GANADA","sale_id":"c8500000-0000-0000-0000-000000000001","estimated_amount":0,"currency":"DOP"}');
select pg_temp.ok((select estimated_amount=55 and currency='USD' and target_units=3 from commercial_opportunities where id=:'won'),'editing preserves legacy values and omitted unit targets');
select set_config('request.jwt.claim.sub','c8200000-0000-0000-0000-000000000002',true);
select pg_temp.denied(format($q$select wf_save_opportunity('c8100000-0000-0000-0000-000000000001',%L,'{"customer_id":"c8400000-0000-0000-0000-000000000001","title":"Unauthorized","stage":"PROSPECTO"}')$q$,:'won'),'unassigned actor cannot edit another opportunity');
reset role;
select pg_temp.ok(not has_function_privilege('anon','public.wf_save_opportunity(uuid,uuid,jsonb)','execute'),'anonymous opportunity RPC denied');
rollback;
