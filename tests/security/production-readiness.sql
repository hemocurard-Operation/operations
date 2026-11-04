-- Santiago pilot with synthetic identities. Everything rolls back; no real sign-offs.
begin;
select set_config('request.jwt.claim.sub','f9200000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
create function pg_temp.go_ok(v boolean,label text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.go_denied(stmt text,label text,expected text default '42501') returns void language plpgsql as $$begin begin execute stmt;exception when others then if SQLSTATE<>expected then raise exception 'FAIL % [%] %',label,SQLSTATE,SQLERRM;end if;raise notice 'PASS %',label;return;end;raise exception 'FAIL unexpectedly allowed %',label;end$$;
grant execute on function pg_temp.go_ok(boolean,text),pg_temp.go_denied(text,text,text) to authenticated,anon;
insert into auth.users(id,email) select ('af200000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'pilot-sti-'||n||'@example.invalid' from generate_series(1,6)n;
insert into profiles(id,full_name,branch_id,active) select u.id,'Usuario ficticio Santiago '||right(u.id::text,1),b.id,true from auth.users u cross join branches b where u.email like 'pilot-sti-%@example.invalid' and b.code='STI';
insert into roles(code,name) values('PILOT_STI_READER','Lector ficticio sin identidad'),('PILOT_STI_CLINICAL','Clínico ficticio');
insert into role_permissions(role_id,permission_code) select r.id,p.permission_code from roles r cross join app_permissions p where
 (r.code='PILOT_STI_READER' and p.permission_code='HYPERBARIC_VIEW') or
 (r.code='PILOT_STI_CLINICAL' and p.permission_code in ('HYPERBARIC_VIEW','HYPERBARIC_WRITE','HYPERBARIC_SESSION_WRITE','HYPERBARIC_PATIENT_PII'));
insert into user_roles(user_id,role_id,branch_id) select p.id,r.id,p.branch_id from profiles p join (values
 ('af200000-0000-0000-0000-000000000001'::uuid,'GERENCIA_OPERATIVA'),('af200000-0000-0000-0000-000000000002'::uuid,'CALIDAD'),
 ('af200000-0000-0000-0000-000000000003'::uuid,'TI'),('af200000-0000-0000-0000-000000000004'::uuid,'GERENCIA_GENERAL'),
 ('af200000-0000-0000-0000-000000000005'::uuid,'PILOT_STI_READER'),('af200000-0000-0000-0000-000000000006'::uuid,'PILOT_STI_CLINICAL'))v(id,code) on v.id=p.id join roles r on r.code=v.code;
insert into hyperbaric_resources(id,branch_id,name,capacity,procedure_reference,created_by) select 'af300000-0000-0000-0000-000000000001',id,'Cámara ficticia Santiago',1,'SIMULACION-STI','af200000-0000-0000-0000-000000000006' from branches where code='STI';
set local role authenticated;
select set_config('request.jwt.claim.sub','af200000-0000-0000-0000-000000000006',true);
select wf_save_appointment((select id from branches where code='STI'),null,jsonb_build_object('resource_id','af300000-0000-0000-0000-000000000001','patient_name','Paciente ficticio privado','patient_phone','000000000','starts_at',now()+interval '1 day','ends_at',now()+interval '25 hours','operational_date',((now()+interval '1 day') at time zone 'America/Santo_Domingo')::date,'shift','DIURNO','price',100,'currency','DOP','session_label','Plan ficticio privado','referrer_name','Referidor ficticio','note','Nota ficticia privada'));
select pg_temp.go_ok(exists(select 1 from vw_hyperbaric_appointments_display where patient_name='Paciente ficticio privado'),'authorized clinical user sees identity through checked projection');
select set_config('request.jwt.claim.sub','af200000-0000-0000-0000-000000000005',true);
select pg_temp.go_ok(exists(select 1 from vw_hyperbaric_appointments_display where patient_name like 'PX-%' and length(patient_code)=35 and patient_phone is null and note is null and session_label='Sesión programada'),'reader sees opaque tracking code and no identity or free text');
select pg_temp.go_denied('select patient_name from public.hyperbaric_appointments','raw identity bypass denied');
select pg_temp.go_denied('select * from public.hyperbaric_appointments','raw select star denied');
select pg_temp.go_ok(not exists(select 1 from audit_events where entity_table='hyperbaric_appointments'),'audit snapshots cannot bypass patient privacy');
select pg_temp.go_denied($q$select public.production_healthcheck()$q$,'legacy health RPC retired');
select pg_temp.go_denied($q$select public.calculate_monthly_product_costs(gen_random_uuid())$q$,'legacy costing bypass retired');
select public.log_audit_event('TEST','CLIENT_REPORTED',null,null,null,null);
select pg_temp.go_ok(exists(select 1 from audit_events where module='TEST' and action='CLIENT_REPORTED' and user_id=auth.uid()),'compatible audit API binds the authenticated actor');
select pg_temp.go_denied($q$select public.reserve_blood_units_fefo(gen_random_uuid())$q$,'unprivileged FEFO denied');
reset role;
update profiles set active=false where id='af200000-0000-0000-0000-000000000006';
set local role authenticated;select set_config('request.jwt.claim.sub','af200000-0000-0000-0000-000000000006',true);
select pg_temp.go_ok((select count(*)=0 from vw_hyperbaric_appointments_display),'inactive clinician loses identity access');
select pg_temp.go_denied($q$select public.wf_create_resource((select id from branches where code='STI'),'{}')$q$,'inactive privileged entry point denied');
reset role;update profiles set active=true where id='af200000-0000-0000-0000-000000000006';
set local role authenticated;select set_config('request.jwt.claim.sub','f9200000-0000-0000-0000-000000000001',true);
do $$declare v record;n int:=0;begin
 for v in select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='v' loop
 execute format('select count(*) from (select * from public.%I limit 1)x',v.relname);n:=n+1;end loop;
 perform pg_temp.go_ok(n>=137,'all reconstructed views work for authorized user');end$$;
select pg_temp.go_ok((public.hc_release_readiness_v1('1.0.0')->>'technical_ready')::boolean,'technical checks pass on isolated production parity schema');
select pg_temp.go_ok(not (public.hc_release_readiness_v1('1.0.0')->>'go_live_ready')::boolean,'production is not ready without real evidence and signers');
select pg_temp.go_denied($q$select public.reserve_blood_units_fefo(gen_random_uuid())$q$,'FEFO remains blocked while either switch is off');
select set_config('request.jwt.claim.sub','af200000-0000-0000-0000-000000000001',true);
select hc_uat_start_run('PRUEBA-STI-INCOMPLETE','PRUEBA:incomplete') as incomplete_id \gset
select pg_temp.go_ok(hc_uat_complete_run(:'incomplete_id','Simulación incompleta')='BLOQUEADO','missing cases cannot produce UAT PASS');
select hc_uat_start_run('PRUEBA-STI-COMPLETE','PRUEBA:1.0.0') as run_id \gset
select pg_temp.go_denied(format($q$select hc_uat_record_result(%L,(select id from uat_test_cases where active limit 1),'PASS','Resultado ficticio',null)$q$,:'run_id'),'UAT PASS requires evidence','22023');
select set_config('request.jwt.claim.sub','af200000-0000-0000-0000-000000000002',true);
select pg_temp.go_denied(format($q$select hc_uat_record_result(%L,(select id from uat_test_cases where active limit 1),'PASS','Resultado ficticio','fixture://STI')$q$,:'run_id'),'another tester cannot overwrite run');
select pg_temp.go_denied($q$select hc_v044_release_signoff('PRUEBA:1.0.0','CALIDAD','APROBADO','Simulación sin UAT completa')$q$,'approval cannot precede evidence');
select set_config('request.jwt.claim.sub','af200000-0000-0000-0000-000000000001',true);
select hc_uat_record_result(:'run_id',id,'PASS','Simulación aislada aprobada; no constituye validación clínica real','fixture://STI/'||test_code) from uat_test_cases where active;
select pg_temp.go_ok(hc_uat_complete_run(:'run_id','Piloto ficticio Santiago')='PASS','complete isolated pilot produces test UAT PASS');
select hc_v044_release_signoff('PRUEBA:1.0.0','OPERACIONES','APROBADO','Firma ficticia exclusiva de esta prueba aislada');
select pg_temp.go_denied($q$select hc_v044_release_signoff('PRUEBA:1.0.0','CALIDAD','APROBADO','Intento sin permiso')$q$,'signer cannot sign another area');
select set_config('request.jwt.claim.sub','af200000-0000-0000-0000-000000000002',true);
select hc_v044_release_signoff('PRUEBA:1.0.0','CALIDAD','APROBADO','Firma ficticia exclusiva de esta prueba aislada');
select set_config('request.jwt.claim.sub','af200000-0000-0000-0000-000000000003',true);
select hc_v044_release_signoff('PRUEBA:1.0.0','TI','APROBADO','Firma ficticia exclusiva de esta prueba aislada');
select set_config('request.jwt.claim.sub','af200000-0000-0000-0000-000000000004',true);
select hc_v044_release_signoff('PRUEBA:1.0.0','GERENCIA','APROBADO','Firma ficticia exclusiva de esta prueba aislada');
select pg_temp.go_ok((hc_release_readiness_v1('PRUEBA:1.0.0')->>'signoffs_ready')::boolean,'test pilot collects four independent area signers');
select pg_temp.go_ok(not (hc_release_readiness_v1('PRUEBA:1.0.0')->>'production_eligible')::boolean,'test release is not production eligible');
select pg_temp.go_ok(not (hc_release_readiness_v1('PRUEBA:1.0.0')->>'go_live_ready')::boolean,'test identities never mark production ready');
select pg_temp.go_ok(not (hc_release_readiness_v1('1.0.0')->>'uat_ready')::boolean,'production version still has no fabricated UAT');
reset role;
-- Legacy serialized temperature path: schema parity fixtures, never real units.
insert into storage_devices(id,branch_id,device_code,name,device_type,hold_on_excursion)
 select 'af400000-0000-0000-0000-000000000001',id,'PRUEBA-STI-COLD','Equipo ficticio','REFRIGERATOR',true from branches where code='STI';
insert into temperature_policies(storage_device_id,min_temp,max_temp)
 values('af400000-0000-0000-0000-000000000001',2,6);
insert into blood_units(unit_code,donation_id,product_id,branch_id,collected_at,expires_at,release_status,inventory_status,storage_device_id)
 select 'PRUEBA-STI-UNIT',gen_random_uuid(),p.id,b.id,now(),now()+interval '10 days','RELEASED','AVAILABLE','af400000-0000-0000-0000-000000000001'
 from products p cross join branches b where b.code='STI' limit 1;
create trigger synthetic_temperature_guard after insert on temperature_readings for each row execute function public.evaluate_temperature_reading();
insert into temperature_readings(storage_device_id,measured_at,temperature_c) values('af400000-0000-0000-0000-000000000001',clock_timestamp(),9);
select pg_temp.go_ok((select inventory_status='AVAILABLE' from blood_units where unit_code='PRUEBA-STI-UNIT'),'thermal alert does not auto quarantine with disabled flags');
update app_feature_flags set enabled=true,mode='LIVE' where key='cold_chain_auto_block';
insert into temperature_readings(storage_device_id,measured_at,temperature_c) values('af400000-0000-0000-0000-000000000001',clock_timestamp(),10);
select pg_temp.go_ok((select inventory_status='AVAILABLE' from blood_units where unit_code='PRUEBA-STI-UNIT'),'feature flag alone cannot enable automatic quarantine');
update system_operating_mode set temperature_blocking_enabled=true where id=1;
insert into temperature_readings(storage_device_id,measured_at,temperature_c) values('af400000-0000-0000-0000-000000000001',clock_timestamp(),11);
select pg_temp.go_ok((select inventory_status='QUARANTINE' and release_status='BLOCKED' from blood_units where unit_code='PRUEBA-STI-UNIT'),'two explicitly enabled test gates permit the guarded action');
update app_feature_flags set enabled=false,mode='SHADOW' where key='cold_chain_auto_block';
update system_operating_mode set temperature_blocking_enabled=false where id=1;
select pg_temp.go_ok(not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','v') and has_table_privilege('anon',c.oid,'SELECT')),'anonymous data surface is closed');
select pg_temp.go_ok(not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and has_table_privilege('authenticated',c.oid,'TRUNCATE')),'browser truncate grants are removed');
create table public.synthetic_future_acl(id int);create function public.synthetic_future_rpc() returns int language sql as $$select 1$$;
select pg_temp.go_ok(not has_table_privilege('anon','public.synthetic_future_acl','SELECT') and not has_table_privilege('authenticated','public.synthetic_future_acl','INSERT'),'future tables require explicit grants');
select pg_temp.go_ok(not has_function_privilege('anon','public.synthetic_future_rpc()','EXECUTE'),'future functions do not inherit anonymous execution');
rollback;
