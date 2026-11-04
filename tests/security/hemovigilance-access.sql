-- Synthetic fixtures only. Run after the integrated local schema and patch.
begin;
select set_config('request.jwt.claim.sub','f9200000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
insert into branches(id,code,name) values
 ('ad100000-0000-0000-0000-000000000001','HV-A','Hemovigilancia ficticia A'),
 ('ad100000-0000-0000-0000-000000000002','HV-B','Hemovigilancia ficticia B');
insert into auth.users(id,email) values
 ('ad200000-0000-0000-0000-000000000001','hv-write@example.invalid'),
 ('ad200000-0000-0000-0000-000000000002','hv-reader@example.invalid'),
 ('ad200000-0000-0000-0000-000000000003','hv-other@example.invalid');
insert into profiles(id,full_name,branch_id,active) values
 ('ad200000-0000-0000-0000-000000000001','Operadora ficticia','ad100000-0000-0000-0000-000000000001',true),
 ('ad200000-0000-0000-0000-000000000002','Lector ficticio','ad100000-0000-0000-0000-000000000001',true),
 ('ad200000-0000-0000-0000-000000000003','Otra sucursal ficticia','ad100000-0000-0000-0000-000000000002',true);
insert into roles(code,name) values('HV_READER_TEST','Lector ficticio de hemovigilancia');
insert into role_permissions(role_id,permission_code) select id,'HEMOVIGILANCE_VIEW' from roles where code='HV_READER_TEST';
insert into user_roles(user_id,role_id,branch_id) select v.id,r.id,v.branch from
 (values ('ad200000-0000-0000-0000-000000000001'::uuid,'ENCARGADA_LABORATORIO','ad100000-0000-0000-0000-000000000001'::uuid),
 ('ad200000-0000-0000-0000-000000000002'::uuid,'HV_READER_TEST','ad100000-0000-0000-0000-000000000001'::uuid),
 ('ad200000-0000-0000-0000-000000000003'::uuid,'ENCARGADA_LABORATORIO','ad100000-0000-0000-0000-000000000002'::uuid)) v(id,code,branch)
 join roles r on r.code=v.code;
create function pg_temp.hv_ok(v boolean,label text) returns void language plpgsql as $$begin
 if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.hv_denied(stmt text,label text,expected text default '42501') returns void language plpgsql as $$begin
 begin execute stmt;exception when others then
  if SQLSTATE<>expected then raise exception 'FAIL % unexpected SQLSTATE %: %',label,SQLSTATE,SQLERRM;end if;
  raise notice 'PASS %',label;return;end;raise exception 'FAIL unexpectedly allowed %',label;end$$;
create function pg_temp.hv_payload(code text) returns jsonb language sql as $$select jsonb_build_object(
 'event_code',code,'description','Descripción ficticia confidencial','patient_name','Paciente ficticio confidencial',
 'health_center','Centro ficticio','reporter_name','Reportante ficticio','reporter_role','Laboratorio',
 'reporter_phone','000-000-0000','component_type','PLASMA','units',1,'abo','O','rh','POSITIVO',
 'nc_category','transporte','nc_subtype','Falla ficticia','product_returned',true)$$;
set local role anon;
select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claim.role','anon',true);
select pg_temp.hv_denied('select count(*) from public.vw_donor_summary','anonymous summary is denied');
select pg_temp.hv_denied('select count(*) from public.hemovigilance_delivery_details','anonymous details are denied');
select pg_temp.hv_denied($q$select public.hemovig_delivery_nc_create('ad100000-0000-0000-0000-000000000001',pg_temp.hv_payload('HV-ANON'))$q$,'anonymous RPC is denied');
set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','ad200000-0000-0000-0000-000000000001',true);
select pg_temp.hv_ok(public.wf_active_actor() and public.has_permission('HEMOVIGILANCE_WRITE'),'operator permission remains valid');
select public.hemovig_delivery_nc_create('ad100000-0000-0000-0000-000000000001',pg_temp.hv_payload('HV-VALID'));
select pg_temp.hv_ok((select count(*)=1 from public.hemovigilance_delivery_details),'authorized operator sees own branch');
select pg_temp.hv_denied($q$select public.hemovig_delivery_nc_create('ad100000-0000-0000-0000-000000000002',pg_temp.hv_payload('HV-FOREIGN'))$q$,'RPC rejects another branch');
select pg_temp.hv_denied($q$select public.hemovig_delivery_nc_create(null,pg_temp.hv_payload('HV-NULL'))$q$,'delivery RPC requires branch');
select pg_temp.hv_denied($q$select public.hemovig_delivery_nc_create('ad100000-0000-0000-0000-000000000001',pg_temp.hv_payload('HV-VALID'))$q$,'retry cannot duplicate same event code','23505');
select pg_temp.hv_denied('delete from public.hemovigilance_delivery_details','ordinary deletion is denied');
select pg_temp.hv_ok(not has_table_privilege('authenticated','public.hemovigilance_delivery_details','TRUNCATE'),'browser has no truncate privilege');
update public.hemovigilance_delivery_details set units=2;
select pg_temp.hv_ok((select count(*)=3 from public.audit_events where module='HEMOVIGILANCE' and branch_id='ad100000-0000-0000-0000-000000000001'),'creation and correction are audited atomically');
select pg_temp.hv_ok((select bool_and(user_id=auth.uid()) from public.audit_events where module='HEMOVIGILANCE' and branch_id='ad100000-0000-0000-0000-000000000001'),'audit retains real actor');
select pg_temp.hv_ok(not exists(select 1 from public.audit_events where module='HEMOVIGILANCE'
 and (before_data::text||after_data::text||metadata::text) like '%Paciente ficticio confidencial%'),'audit does not duplicate patient identity');
select pg_temp.hv_ok(exists(select 1 from public.audit_events where module='HEMOVIGILANCE' and action='UPDATE'
 and before_data->>'units'='1' and after_data->>'units'='2'),'audit preserves operational before and after values');
select set_config('request.jwt.claim.sub','ad200000-0000-0000-0000-000000000003',true);
select pg_temp.hv_ok((select count(*)=0 from public.hemovigilance_delivery_details),'other branch cannot read details');
select pg_temp.hv_ok((select count(*)=0 from public.hemovigilance_events where event_code='HV-VALID'),'other branch cannot read event');
select set_config('request.jwt.claim.sub','ad200000-0000-0000-0000-000000000002',true);
select pg_temp.hv_ok((select count(*)=1 from public.hemovigilance_delivery_details),'reader retains authorized read');
select pg_temp.hv_denied($q$select public.hemovig_delivery_nc_create('ad100000-0000-0000-0000-000000000001',pg_temp.hv_payload('HV-READER'))$q$,'reader cannot create NC');
with changes as (update public.hemovigilance_delivery_details set units=7 returning id)
 select pg_temp.hv_ok((select count(*)=0 from changes),'reader cannot edit details');
reset role;
update public.profiles set active=false where id='ad200000-0000-0000-0000-000000000001';
set local role authenticated;select set_config('request.jwt.claim.sub','ad200000-0000-0000-0000-000000000001',true);
select pg_temp.hv_ok((select count(*)=0 from public.hemovigilance_delivery_details),'inactive actor loses read');
select pg_temp.hv_denied($q$select public.hemovig_delivery_nc_create('ad100000-0000-0000-0000-000000000001',pg_temp.hv_payload('HV-INACTIVE'))$q$,'inactive actor cannot call RPC');
reset role;
update public.profiles set active=true where id='ad200000-0000-0000-0000-000000000001';
create function pg_temp.fail_hv_audit() returns trigger language plpgsql as $$begin
 if NEW.module='HEMOVIGILANCE' then raise exception 'Synthetic audit unavailable';end if;return NEW;end$$;
create trigger synthetic_audit_failure before insert on public.audit_events for each row execute function pg_temp.fail_hv_audit();
set local role authenticated;
select pg_temp.hv_denied($q$select public.hemovig_delivery_nc_create('ad100000-0000-0000-0000-000000000001',pg_temp.hv_payload('HV-AUDIT-FAIL'))$q$,'audit failure rejects definitive save','P0001');
select pg_temp.hv_ok(not exists(select 1 from public.hemovigilance_events where event_code='HV-AUDIT-FAIL'),'audit failure leaves no partial event');
reset role;
select pg_temp.hv_ok(not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relkind='v' and not coalesce(c.reloptions @> array['security_invoker=true'],false)
 and has_table_privilege('anon',c.oid,'SELECT')),'all owner views deny anonymous access');
select pg_temp.hv_ok(has_table_privilege('authenticated','public.vw_donor_summary','SELECT'),'authenticated dashboard ACL retained');
drop trigger synthetic_audit_failure on public.audit_events;
set local role authenticated;
select set_config('request.jwt.claim.sub','ad200000-0000-0000-0000-000000000001',true);
insert into public.hemovigilance_events(event_code,event_type,severity,description,status)
 values('HV-LEGACY','OTRO','MEDIA','Evento general ficticio','ABIERTO');
select pg_temp.hv_ok(exists(select 1 from public.hemovigilance_events where event_code='HV-LEGACY'),'legacy general event form remains compatible');
rollback;
