-- Local-only transactional fixture. The runner never connects to Supabase.
begin;
set local timezone='America/Santo_Domingo';
insert into auth.users(id,email) values
('e1000000-0000-0000-0000-000000000001','operator-a@example.invalid'),
('e1000000-0000-0000-0000-000000000002','operator-b@example.invalid'),
('e1000000-0000-0000-0000-000000000003','reviewer@example.invalid'),
('e1000000-0000-0000-0000-000000000004','clinician@example.invalid');
insert into branches(id,code,name) values
('e2000000-0000-0000-0000-000000000001','WF-A','Workflow test A'),
('e2000000-0000-0000-0000-000000000002','WF-B','Workflow test B');
insert into profiles(id,full_name,branch_id) values
('e1000000-0000-0000-0000-000000000001','Operator A','e2000000-0000-0000-0000-000000000001'),
('e1000000-0000-0000-0000-000000000002','Operator B','e2000000-0000-0000-0000-000000000002'),
('e1000000-0000-0000-0000-000000000003','Reviewer A','e2000000-0000-0000-0000-000000000001'),
('e1000000-0000-0000-0000-000000000004','Clinician A','e2000000-0000-0000-0000-000000000001');
insert into roles(id,code,name) values
('e3000000-0000-0000-0000-000000000001','WF_TEST_OPERATOR','Workflow local operator'),
('e3000000-0000-0000-0000-000000000002','WF_TEST_REVIEWER','Workflow local reviewer'),
('e3000000-0000-0000-0000-000000000003','WF_TEST_CLINICIAN','Workflow local clinician');
insert into user_roles(user_id,role_id,branch_id) values
('e1000000-0000-0000-0000-000000000001','e3000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001'),
('e1000000-0000-0000-0000-000000000002','e3000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000002'),
('e1000000-0000-0000-0000-000000000003','e3000000-0000-0000-0000-000000000002','e2000000-0000-0000-0000-000000000001'),
('e1000000-0000-0000-0000-000000000004','e3000000-0000-0000-0000-000000000003','e2000000-0000-0000-0000-000000000001');
insert into role_permissions(role_id,permission_code)
select 'e3000000-0000-0000-0000-000000000001',permission_code from app_permissions where permission_code in
('REQUISITION_WRITE','SUPPLY_VIEW','ACCESS_ADMIN','COMMERCIAL_VIEW','COMMERCIAL_WRITE','HYPERBARIC_VIEW','HYPERBARIC_WRITE','HYPERBARIC_BILLING','SALES_VIEW','SALES_WRITE','DISPATCH_WRITE','COLLECTIONS_VIEW','COLLECTIONS_WRITE','QUALITY_VIEW','QUALITY_WRITE','QUALITY_DAILY_REVIEW','BLOOD_INVENTORY_VIEW','BLOOD_INVENTORY_WRITE','UNIT_RELEASE','DAILY_REPORT_VIEW','DAILY_REPORT_WRITE','DAILY_REPORT_SUBMIT','DAILY_REPORT_CLOSE','DAILY_REPORT_REOPEN','AUDIT_VIEW');
insert into role_permissions(role_id,permission_code) values
('e3000000-0000-0000-0000-000000000002','QUALITY_VIEW'),('e3000000-0000-0000-0000-000000000002','QUALITY_DAILY_REVIEW'),
('e3000000-0000-0000-0000-000000000003','HYPERBARIC_VIEW'),('e3000000-0000-0000-0000-000000000003','HYPERBARIC_SESSION_WRITE');
insert into customers(id,name) values('e4000000-0000-0000-0000-000000000001','Workflow test client');
insert into blood_inventory_units(id,unit_code,source_unit_code,branch_id,component_name,abo,rh,expiry_date,screening_status,inventory_status)
values('e5000000-0000-0000-0000-000000000001','WF-U1','WF-S1','e2000000-0000-0000-0000-000000000001','PG','O','POSITIVO',current_date+30,'APTO','DISPONIBLE'),
('e5000000-0000-0000-0000-000000000002','WF-U2','WF-S2','e2000000-0000-0000-0000-000000000001','PG','O','POSITIVO',current_date+30,'APTO','DISPONIBLE'),
('e5000000-0000-0000-0000-000000000003','WF-U3','WF-S3','e2000000-0000-0000-0000-000000000001','PG','O','POSITIVO',current_date+30,'PENDIENTE','CUARENTENA'),
('e5000000-0000-0000-0000-000000000004','WF-U4','WF-S4','e2000000-0000-0000-0000-000000000001','PG','O','POSITIVO',current_date+30,'APTO','DISPONIBLE');
create function pg_temp.expect_failure(command text,label text) returns void language plpgsql as $$
begin
 begin execute command;exception when others then
 if sqlstate in ('42601','42702','42703','42883','42P01') then raise;end if;
 raise notice 'PASS %',label;return;end;
 raise exception 'Expected failure: %',label;
end $$;
create function pg_temp.check_true(ok boolean,label text) returns void language plpgsql as $$
begin if ok is not true then raise exception 'Assertion failed: %',label;end if;raise notice 'PASS %',label;end $$;
set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000001',true);
select pg_temp.expect_failure($q$insert into hyperbaric_appointments(branch_id) values('e2000000-0000-0000-0000-000000000001')$q$,'direct appointment writes denied');
select pg_temp.expect_failure($q$select wf_create_resource('e2000000-0000-0000-0000-000000000002','{"name":"Outside","capacity":1,"procedure_reference":"PROC"}')$q$,'RPC rejects other branch');
select wf_create_resource('e2000000-0000-0000-0000-000000000001','{"name":"Test chamber","capacity":1,"procedure_reference":"PROC-LOCAL-TEST"}') as resource_id \gset
select wf_save_appointment('e2000000-0000-0000-0000-000000000001',null,jsonb_build_object(
 'resource_id',:'resource_id','patient_name','Fixture patient','patient_phone','000-000-0000',
 'starts_at',now()-interval '3 hours','ends_at',now()-interval '2 hours','operational_date',((now()-interval '3 hours') at time zone 'America/Santo_Domingo')::date,
 'shift','DIURNO','price',100,'currency','USD','session_label','1 por el momento','referrer_name','Fixture doctor')) as appointment_id \gset
select pg_temp.check_true((select count(*)=0 from hyperbaric_charges),'appointment does not create revenue');
select pg_temp.expect_failure(format($q$select wf_save_appointment('e2000000-0000-0000-0000-000000000001',null,jsonb_build_object('resource_id',%L,'patient_name','Other','patient_phone','000','starts_at',now()-interval '3 hours','ends_at',now()-interval '2 hours','operational_date',current_date,'shift','DIURNO','price',100,'currency','USD','session_label','1','referrer_name','Doctor'))$q$,:'resource_id'),'double booking rejected');
select pg_temp.expect_failure(format($q$select wf_record_session(%L,'{"clinical_authorization":"AUTH","consent_reference":"CONS","evidence":"EVID","performed_at":"2026-01-01T10:00:00Z","operational_date":"2026-01-01","shift":"DIURNO","status":"REALIZADA"}')$q$,:'appointment_id'),'administration does not imply clinical execution');
select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000004',true);
select wf_record_session(:'appointment_id',jsonb_build_object('clinical_authorization','AUTH-TEST','consent_reference','CONS-TEST','evidence','SESSION-TEST','performed_at',now()-interval '2 hours','operational_date',((now()-interval '2 hours') at time zone 'America/Santo_Domingo')::date,'shift','DIURNO','status','REALIZADA')) as session_id \gset
select pg_temp.check_true((select count(*)=4 from blood_inventory_units),'session leaves blood inventory intact');
select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000001',true);
select wf_invoice_session(:'session_id','WF-INVOICE',current_date) as charge_id \gset
select pg_temp.check_true(wf_invoice_session(:'session_id','WF-INVOICE',current_date)=:'charge_id'::uuid,'invoice retry reuses unique service origin');
select wf_pay_session(:'charge_id','e6000000-0000-0000-0000-000000000001',jsonb_build_object('amount',60,'currency','USD','receipt_number','WF-R1','payment_date',current_date));
select wf_pay_session(:'charge_id','e6000000-0000-0000-0000-000000000001',jsonb_build_object('amount',60,'currency','USD','receipt_number','WF-R1','payment_date',current_date));
select pg_temp.check_true((select paid=60 and outstanding=40 from vw_hyperbaric_finance where id=:'charge_id'),'payment retry does not duplicate balance');
select pg_temp.expect_failure(format($q$select wf_pay_session(%L,'e6000000-0000-0000-0000-000000000002',jsonb_build_object('amount',41,'currency','USD','receipt_number','WF-R2','payment_date',current_date))$q$,:'charge_id'),'overpayment rejected');
select pg_temp.expect_failure(format($q$select wf_pay_session(%L,'e6000000-0000-0000-0000-000000000002',jsonb_build_object('amount',10,'currency','DOP','receipt_number','WF-R2','payment_date',current_date))$q$,:'charge_id'),'payment currency mismatch rejected');
select pg_temp.check_true((select currency='USD' and shift='DIURNO' and client_name='Servicio hiperbárico' from vw_workflow_shift_sales where source_type='CAMARA_HIPERBARICA'),'sales report has service shift and omits patient identity');
select wf_quality_task('e2000000-0000-0000-0000-000000000001',null,jsonb_build_object('task_date',current_date,'shift','DIURNO','title','Cold chain','process','Storage','procedure_reference','PROC-TEST','priority','CRITICA','due_at',now()+interval '1 hour')) as task_id \gset
select pg_temp.expect_failure(format($q$select wf_quality_task('e2000000-0000-0000-0000-000000000001',%L,'{"status":"EN_REVISION","evidence":""}')$q$,:'task_id'),'quality evidence required');
select wf_quality_task('e2000000-0000-0000-0000-000000000001',:'task_id','{"status":"EN_REVISION","evidence":"REG-QC-01"}');
select pg_temp.expect_failure(format($q$select wf_quality_task('e2000000-0000-0000-0000-000000000001',%L,'{"status":"ACEPTADA","review_note":"Conforme"}')$q$,:'task_id'),'self review rejected even with reviewer permission');
select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000003',true);
select wf_quality_task('e2000000-0000-0000-0000-000000000001',:'task_id','{"status":"ACEPTADA","review_note":"Evidencia revisada"}');
select pg_temp.check_true((select status='ACEPTADA' and reviewed_by<>owner_id from blood_quality_tasks where id=:'task_id'),'independent quality review stored');
select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000002',true);
select pg_temp.check_true((select count(*)=0 from hyperbaric_appointments),'RLS hides other branch patients');
select pg_temp.check_true((select count(*)=0 from blood_quality_tasks),'RLS hides other branch quality records');
select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000001',true);
select pg_temp.expect_failure($q$select wf_send_transfer('e2000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000002','WF-BAD',array['e5000000-0000-0000-0000-000000000003']::uuid[],'TEMP-TEST')$q$,'pending blood cannot transfer as released');
select wf_send_transfer('e2000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000002','WF-TRANSFER',array['e5000000-0000-0000-0000-000000000001','e5000000-0000-0000-0000-000000000002']::uuid[],'TRANSPORT-TEST') as transfer_id \gset
select pg_temp.check_true((select count(*)=0 from blood_inventory_units where id in ('e5000000-0000-0000-0000-000000000001','e5000000-0000-0000-0000-000000000002') and inventory_status='DISPONIBLE'),'transit removed from available inventory');
select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000002',true);
select wf_receive_transfer(:'transfer_id',array['e5000000-0000-0000-0000-000000000001']::uuid[],'RECEIPT-TEST','Sin desviación observada; verificar');
select wf_receive_transfer(:'transfer_id',array['e5000000-0000-0000-0000-000000000001']::uuid[],'RECEIPT-TEST','Sin desviación observada; verificar');
select pg_temp.check_true((select status='PARCIAL' from blood_transfers where id=:'transfer_id'),'partial receipt preserves remaining transit');
select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000001',true);
select pg_temp.check_true((select inventory_status='RESERVADA' and branch_id='e2000000-0000-0000-0000-000000000001' from blood_inventory_units where id='e5000000-0000-0000-0000-000000000002'),'unreceived unit remains reserved at origin');
select pg_temp.check_true((select inventory_status='DISPONIBLE' and branch_id='e2000000-0000-0000-0000-000000000001' from blood_inventory_units where id='e5000000-0000-0000-0000-000000000004'),'receipt cannot change unrelated unit or branch');
select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000002',true);
select pg_temp.check_true((select inventory_status='CUARENTENA' from blood_inventory_units where id='e5000000-0000-0000-0000-000000000001'),'receipt is not automatic release');
select wf_review_transfer_receipt(:'transfer_id','e5000000-0000-0000-0000-000000000001',true,'HUMAN-REVIEW-PROC');
select pg_temp.check_true((select inventory_status='DISPONIBLE' and branch_id='e2000000-0000-0000-0000-000000000002' from blood_inventory_units where id='e5000000-0000-0000-0000-000000000001'),'authorized receipt review makes unit available only at destination');
select pg_temp.expect_failure(format($q$select wf_review_transfer_receipt(%L,'e5000000-0000-0000-0000-000000000001',true,'RETRY')$q$,:'transfer_id'),'receipt review cannot be repeated to alter disposition');

select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000001',true);
select wf_save_location('e2000000-0000-0000-0000-000000000001','e4000000-0000-0000-0000-000000000001',
 '{"address":"Verified clinic","latitude":19.45,"longitude":-70.69,"verified":true}');
select pg_temp.expect_failure($q$select wf_save_location('e2000000-0000-0000-0000-000000000001','e4000000-0000-0000-0000-000000000001','{"address":"Missing coords","verified":true}')$q$,'verified location requires actual coordinates');
select wf_create_plan('e2000000-0000-0000-0000-000000000001',jsonb_build_object('cycle_start',current_date,'goal','Validated visits','target_visits',12,'tactics','Weekly followup')) as plan_id \gset
select wf_save_visit('e2000000-0000-0000-0000-000000000001',null,jsonb_build_object('customer_id','e4000000-0000-0000-0000-000000000001','plan_id',:'plan_id',
 'scheduled_at',now()+interval '1 day','duration_minutes',30,'purpose','Assess demand','commitment','Call back','followup_at',now()+interval '2 days')) as visit_id \gset
select pg_temp.expect_failure(format($q$select wf_save_visit('e2000000-0000-0000-0000-000000000001',%L,'{"status":"REALIZADA","evidence":""}')$q$,:'visit_id'),'completed visit requires evidence');
select wf_save_visit('e2000000-0000-0000-0000-000000000001',:'visit_id',jsonb_build_object('status','REALIZADA','evidence','VISIT-REG','commitment','Confirm demand','followup_at',now()+interval '1 day'));
select wf_close_commitment('e2000000-0000-0000-0000-000000000001',:'visit_id','FOLLOW-UP-REG');
select pg_temp.check_true((select commitment_closed_at is not null and evidence='VISIT-REG' from commercial_visits where id=:'visit_id'),'visit and previous commitment have separate evidence');
select pg_temp.expect_failure($q$select wf_save_opportunity('e2000000-0000-0000-0000-000000000001',null,'{"customer_id":"e4000000-0000-0000-0000-000000000001","title":"Not earned","stage":"GANADA","currency":"DOP","estimated_amount":100}')$q$,'won opportunity requires real sale');
select wf_save_opportunity('e2000000-0000-0000-0000-000000000001',null,'{"customer_id":"e4000000-0000-0000-0000-000000000001","title":"Prospect","stage":"PROSPECTO","currency":"DOP","estimated_amount":100}') as opportunity_id \gset
select wf_save_opportunity('e2000000-0000-0000-0000-000000000001',:'opportunity_id','{"customer_id":"e4000000-0000-0000-0000-000000000001","title":"Lost","stage":"PERDIDA","currency":"DOP","estimated_amount":100,"loss_reason":"No demand"}');
select pg_temp.check_true((select stage='PERDIDA' and loss_reason='No demand' from commercial_opportunities where id=:'opportunity_id'),'lost opportunity preserves reason');
select pg_temp.expect_failure($q$select wf_save_opportunity('e2000000-0000-0000-0000-000000000001',null,'{"customer_id":"e4000000-0000-0000-0000-000000000001","title":"Lost without reason","stage":"PERDIDA","currency":"DOP","estimated_amount":100}')$q$,'lost opportunity requires reason');
select wf_create_quality_template('e2000000-0000-0000-0000-000000000001','{"title":"Daily opening","process":"Continuity","procedure_reference":"PROC-02/v1","priority":"ALTA","frequency":"POR_TURNO","due_time":"10:00","due_next_day":false}') as template_id \gset
select pg_temp.check_true(wf_generate_quality_tasks('e2000000-0000-0000-0000-000000000001',current_date,'DIURNO')=0,'unreviewed routine is not generated');
select pg_temp.expect_failure(format($q$select wf_review_quality_template('e2000000-0000-0000-0000-000000000001',%L,'Self review')$q$,:'template_id'),'template also requires independent review');
select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000003',true);
select wf_review_quality_template('e2000000-0000-0000-0000-000000000001',:'template_id','Document and periodicity verified');
select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000001',true);
select pg_temp.check_true(wf_generate_quality_tasks('e2000000-0000-0000-0000-000000000001',current_date,'DIURNO')=1,'approved routine generates daily task');
select pg_temp.check_true(wf_generate_quality_tasks('e2000000-0000-0000-0000-000000000001',current_date,'DIURNO')=0,'repeat routine generation is idempotent');
select save_daily_operational_report(current_date,'e2000000-0000-0000-0000-000000000001','Operator A') as report_id \gset
select pg_temp.expect_failure(format('select submit_daily_operational_report(%L)',:'report_id'),'daily report cannot submit without donor and marker section');
select jsonb_build_object('donor_batch','CAP-LOCAL','accepted',12,'deferred',3,'discarded',1,
 'markers',(select jsonb_agg(jsonb_build_object('marker',v,'tested',0,'nonreactive',0,'reactive',0,'platform','AutoLumo','reagent_lot','','control_reference','')) from unnest(array['VIH (Ag/Ac)','HBsAg','Anti-HCV','Sífilis','HTLV I/II','CORE'])v),
 'receipts',(select jsonb_agg(jsonb_build_object('group',v,'received',0,'pending',0,'discarded',0)) from unnest(array['A+','A-','B+','B-','O+','O-','AB+','AB-'])v)) as daily_json \gset
select wf_save_daily_sections(:'report_id',:'daily_json');
select pg_temp.check_true((select snapshot->'workflow_sections'->>'donor_batch'='CAP-LOCAL' from daily_operational_report_versions where report_id=:'report_id' order by report_version desc limit 1),'daily extension is captured in immutable report version');
select submit_daily_operational_report(:'report_id');
select close_daily_operational_report(:'report_id');
select pg_temp.expect_failure(format('select wf_save_daily_sections(%L,%L)',:'report_id',:'daily_json'),'closed donor section cannot be changed');
select reopen_daily_operational_report(:'report_id','Correct capture source reference');
select wf_save_daily_sections(:'report_id',(:'daily_json')::jsonb||'{"donor_batch":"CAP-CORRECTED"}');
select pg_temp.check_true((select count(distinct snapshot->'workflow_sections'->>'donor_batch')=2 from daily_operational_report_versions where report_id=:'report_id'),'reopen preserves previous section versions');
select id as item_id from workflow_supply_catalog where code='HC-SUP-001' \gset
select wf_map_supply_item('e2000000-0000-0000-0000-000000000001',:'item_id','{"name":"Reviewed collection bag","unit":"unidad","minimum":5,"warning":10,"target":20}') as supply_product \gset
select pg_temp.check_true((select reviewed_by is not null and product_id=:'supply_product'::uuid from workflow_supply_catalog where id=:'item_id'),'reviewed supply maps to a real product');
select pg_temp.check_true((select count(*)=0 from inventory_movements where product_id=:'supply_product'),'catalog approval does not invent inventory');
select pg_temp.expect_failure(format($q$select wf_map_supply_item('e2000000-0000-0000-0000-000000000001',%L,'{"name":"Bag","unit":"unidad","minimum":10,"warning":5,"target":20}')$q$,:'item_id'),'incoherent supply thresholds rejected');
select pg_temp.expect_failure($q$select wf_create_blood_sale('{"branch_id":"e2000000-0000-0000-0000-000000000001","customer_id":"e4000000-0000-0000-0000-000000000001","sale_code":"WF-ORPHAN","sale_date":"2026-10-12","shift":"DIURNO","treating_doctor":"Fixture MD","status":"DESPACHADA"}','[{"blood_inventory_unit_id":"e5000000-0000-0000-0000-000000000003","quantity":1,"unit_price":100}]')$q$,'blood sale rejects pending unit');
select pg_temp.check_true((select count(*)=0 from operational_sales where sale_code='WF-ORPHAN'),'failed blood line leaves no orphan sale');

select wf_create_blood_sale(jsonb_build_object('branch_id','e2000000-0000-0000-0000-000000000001','customer_id','e4000000-0000-0000-0000-000000000001',
 'customer_name','Untrusted name ignored','sale_code','WF-VALID','sale_date',current_date,'shift','NOCTURNO','treating_doctor','Fixture treating MD','status','FACTURADA',
 'invoice_number','WF-BLOOD-INVOICE','collected_amount',40),
 '[{"blood_inventory_unit_id":"e5000000-0000-0000-0000-000000000004","quantity":1,"unit_price":100}]') as blood_sale_id \gset
select pg_temp.check_true((select total_amount=100 and customer_name='Workflow test client' and shift='NOCTURNO' from operational_sales where id=:'blood_sale_id'),'blood sale uses actual client, source quantity and explicit shift');
select pg_temp.check_true((select inventory_status='DESPACHADA' from blood_inventory_units where id='e5000000-0000-0000-0000-000000000004'),'atomic blood sale marks released source as dispatched');
select pg_temp.check_true((select sum(amount)=40 from customer_payments where sale_id=:'blood_sale_id'),'initial blood receipt recorded once in existing ledger');
select pg_temp.check_true((select count(distinct currency)=2 from vw_workflow_receipts),'cash report retains USD and DOP as separate currencies');
select pg_temp.check_true(not has_table_privilege('anon','public.hyperbaric_appointments','SELECT') and not has_table_privilege('authenticated','public.hyperbaric_appointments','TRIGGER'),'new tables revoke anonymous read and authenticated trigger privileges');
select pg_temp.check_true((select count(*)>=15 from workflow_audit),'workflow mutations leave actor and event audit trail');

reset role;
update profiles set active=false where id='e1000000-0000-0000-0000-000000000001';
set local role authenticated;
select pg_temp.check_true((select count(*)=0 from hyperbaric_appointments),'inactive profile cannot read nominative agenda');
select pg_temp.expect_failure($q$select wf_create_plan('e2000000-0000-0000-0000-000000000001','{"cycle_start":"2026-10-12","goal":"Inactive","target_visits":1,"tactics":"No"}')$q$,'inactive profile cannot invoke workflow writer');
reset role;
update profiles set active=true where id='e1000000-0000-0000-0000-000000000001';
set local role authenticated;

select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000001',true);
select wf_save_daily_sections(:'report_id',jsonb_set(:'daily_json'::jsonb,'{markers,0}','{"marker":"VIH (Ag/Ac)","tested":3,"nonreactive":2,"reactive":1,"platforms":[{"platform":"AutoLumo","tested":2,"nonreactive":2,"reactive":0,"reagent_lot":"L1","control_reference":"QC1"},{"platform":"MiniVidas","tested":1,"nonreactive":0,"reactive":1,"reagent_lot":"L2","control_reference":"QC2"}]}'::jsonb));
select pg_temp.check_true((select markers->0->>'tested'='3' and jsonb_array_length(markers->0->'platforms')=2 from workflow_daily_sections where report_id=:'report_id'),'multiple platforms persist with separate evidence');
select markers as saved_markers from workflow_daily_sections where report_id=:'report_id' \gset
select pg_temp.expect_failure(format('select wf_save_daily_sections(%L,%L)',:'report_id',jsonb_set(:'daily_json'::jsonb,'{markers}',jsonb_set(:'saved_markers'::jsonb,'{0,tested}','4'))),'platform totals must reconcile');
select pg_temp.expect_failure(format('select wf_save_daily_sections(%L,%L)',:'report_id',jsonb_set(:'daily_json'::jsonb,'{markers}',jsonb_set(:'saved_markers'::jsonb,'{0,platforms,1,platform}','"AutoLumo"'))),'duplicate platform rejected');
select pg_temp.expect_failure(format('select wf_save_daily_sections(%L,%L)',:'report_id',jsonb_set(:'daily_json'::jsonb,'{markers}',jsonb_set(:'saved_markers'::jsonb,'{0,platforms,1,control_reference}','""'))),'missing evidence on second platform rejected');
select id as unapproved_item from workflow_supply_catalog where code='HC-SUP-003' \gset
select jsonb_build_object('requisition_code','WF-REQ-ORPHAN','request_date',current_date,'priority','NORMAL','requesting_branch_id','e2000000-0000-0000-0000-000000000001') as req_header \gset
select pg_temp.expect_failure(format('select wf_create_catalog_requisition(%L,%L)',:'req_header',jsonb_build_array(jsonb_build_object('catalog_item_id',:'item_id','requested_qty',2),jsonb_build_object('catalog_item_id',:'unapproved_item','requested_qty',1))),'unapproved line rolls back entire catalogue requisition');
select pg_temp.check_true((select count(*)=0 from requisitions where requisition_code='WF-REQ-ORPHAN'),'invalid catalogue line leaves no orphan header');
select pg_temp.expect_failure(format('select wf_create_catalog_requisition(%L,%L)',:'req_header',jsonb_build_array(jsonb_build_object('catalog_item_id',:'item_id','requested_qty','NaN'))),'nonfinite requisition quantity rejected');
select pg_temp.expect_failure(format('select wf_create_catalog_requisition(%L,%L)',:'req_header',jsonb_build_array(jsonb_build_object('catalog_item_id',:'item_id','requested_qty',1),jsonb_build_object('catalog_item_id',:'item_id','requested_qty',2))),'duplicate catalogue lines rejected');
select wf_create_catalog_requisition((:'req_header')::jsonb||'{"requisition_code":"WF-REQ-VALID"}',jsonb_build_array(jsonb_build_object('catalog_item_id',:'item_id','requested_qty',2,'item_name','Forged name','unit','Forged unit'))) as req_id \gset
select pg_temp.check_true((select item_name='Reviewed collection bag' and unit='unidad' and product_id=:'supply_product'::uuid and requested_qty=2 from requisition_lines where requisition_id=:'req_id'),'catalog requisition snapshots authoritative product name and unit');
select pg_temp.check_true((select status='PENDIENTE' and requested_by=auth.uid() from requisitions where id=:'req_id'),'catalog requisition keeps actual requesting actor');
select pg_temp.check_true((select count(*)=0 from inventory_movements where product_id=:'supply_product'),'requisition does not create stock');
select id as second_item from workflow_supply_catalog where code='HC-SUP-002' \gset
select wf_map_supply_item('e2000000-0000-0000-0000-000000000001',:'second_item','{"name":"Reviewed second supply","unit":"caja","minimum":1,"warning":2,"target":3}');
select wf_create_catalog_requisition((:'req_header')::jsonb||'{"requisition_code":"WF-REQ-MULTI"}',jsonb_build_array(jsonb_build_object('catalog_item_id',:'item_id','requested_qty',2),jsonb_build_object('catalog_item_id',:'second_item','requested_qty',3))) as multi_req \gset
select pg_temp.check_true((select count(*)=2 and sum(requested_qty)=5 from requisition_lines where requisition_id=:'multi_req'),'multiple approved catalogue lines commit in one requisition');
select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000002',true);
select pg_temp.expect_failure(format('select wf_create_catalog_requisition(%L,%L)',:'req_header',jsonb_build_array(jsonb_build_object('catalog_item_id',:'item_id','requested_qty',1))),'catalog requisition rejects other branch');
select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000003',true);
select pg_temp.expect_failure(format('select wf_create_catalog_requisition(%L,%L)',:'req_header',jsonb_build_array(jsonb_build_object('catalog_item_id',:'item_id','requested_qty',1))),'quality reviewer cannot create requisition without permission');
select pg_temp.check_true(not has_function_privilege('anon','public.wf_create_catalog_requisition(jsonb,jsonb)','EXECUTE'),'catalog requisition RPC denies anonymous execution');
rollback;
