begin;
create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.denied(stmt text,label text) returns void language plpgsql as $$begin begin execute stmt;exception when others then if sqlstate in ('42601','42702','42703','42883','42P01') then raise;end if;raise notice 'PASS %',label;return;end;raise exception 'FAIL unexpectedly allowed %',label;end$$;
insert into branches(id,code,name) values('ce710000-0000-0000-0000-000000000001','FIX-A','Synthetic fixed A'),('ce710000-0000-0000-0000-000000000002','FIX-B','Synthetic fixed B');
insert into auth.users(id,email) select ('ce720000-0000-0000-0000-00000000000'||i)::uuid,'fixed-'||i||'@example.invalid' from generate_series(1,3)i;
insert into profiles(id,full_name,branch_id,active) select ('ce720000-0000-0000-0000-00000000000'||i)::uuid,'Synthetic fixed '||i,'ce710000-0000-0000-0000-000000000001',true from generate_series(1,3)i;
insert into roles(id,code,name) values('ce730000-0000-0000-0000-000000000001','FIX_WORKER','Fixed worker'),('ce730000-0000-0000-0000-000000000002','FIX_REVIEW','Fixed reviewer'),('ce730000-0000-0000-0000-000000000003','FIX_ADMIN','Fixed config test');
insert into role_permissions(role_id,permission_code) select ('ce730000-0000-0000-0000-00000000000'||i)::uuid,p from generate_series(1,3)i cross join (values('TRIPS_VIEW'),('TRIPS_WRITE'))v(p);
insert into role_permissions(role_id,permission_code) values('ce730000-0000-0000-0000-000000000002','TRIPS_REVIEW'),('ce730000-0000-0000-0000-000000000002','TRIPS_SETTLE'),('ce730000-0000-0000-0000-000000000003','TRIPS_RATE_WRITE');
insert into user_roles(user_id,role_id,branch_id) select ('ce720000-0000-0000-0000-00000000000'||i)::uuid,('ce730000-0000-0000-0000-00000000000'||i)::uuid,'ce710000-0000-0000-0000-000000000001' from generate_series(1,3)i;
grant execute on all functions in schema pg_temp to authenticated,anon;
set local role authenticated;
select set_config('request.jwt.claim.sub','ce720000-0000-0000-0000-000000000001',true);
select pg_temp.denied($q$select logistics_trip_rate_save('{"branch_id":"ce710000-0000-0000-0000-000000000001","purpose":"ENTREGA","amount":500}')$q$,'worker cannot configure fixed incentives');
select logistics_trip_action('CREATE','{"branch_id":"ce710000-0000-0000-0000-000000000001","request_id":"ce740000-0000-0000-0000-000000000001","origin":"Synthetic origin","destination":"Synthetic destination","departure_local":"2026-11-02T07:00","arrival_local":"2026-11-02T10:00","purpose":"ENTREGA"}')->>'id' as trip \gset
select pg_temp.denied(format($q$select logistics_trip_action('APPROVE',jsonb_build_object('id',%L,'revision',1,'review_note','Self approval'))$q$,:'trip'),'worker cannot self authorize');
select set_config('request.jwt.claim.sub','ce720000-0000-0000-0000-000000000003',true);
select logistics_trip_rate_save('{"branch_id":"ce710000-0000-0000-0000-000000000001","purpose":"ENTREGA","amount":500}') ->>'id' as rate \gset
select pg_temp.ok((select amount=500 and revision=1 and created_by=auth.uid() from logistics_trip_rates where id=:'rate'),'configured fixed tariff stamps actor and revision');
select pg_temp.denied($q$select logistics_trip_rate_save('{"branch_id":"ce710000-0000-0000-0000-000000000002","purpose":"ENTREGA","amount":500}')$q$,'fixed tariff cannot cross branch scope');
select set_config('request.jwt.claim.sub','ce720000-0000-0000-0000-000000000002',true);
select logistics_trip_action('APPROVE',jsonb_build_object('id',:'trip','revision',1,'review_note','Trip authorized','amount',99999));
select pg_temp.ok((select status='APROBADO' and amount=500 and incentive_rule_id=:'rate'::uuid and (incentive_rule_snapshot->>'amount')::numeric=500 from logistics_trips where id=:'trip'),'one trip authorization applies fixed tariff for an outside start and ignores caller amount');
select pg_temp.denied(format($q$update logistics_trips set incentive_rule_snapshot='{}' where id=%L$q$,:'trip'),'applied incentive evidence cannot be rewritten');
select set_config('request.jwt.claim.sub','ce720000-0000-0000-0000-000000000003',true);
select logistics_trip_rate_save(jsonb_build_object('id',:'rate','revision',1,'branch_id','ce710000-0000-0000-0000-000000000001','amount',700,'active',true));
select pg_temp.ok((select count(*)=2 from logistics_trip_rate_history where rate_id=:'rate'),'tariff changes preserve audit history');
select pg_temp.denied(format($q$select logistics_trip_rate_save(jsonb_build_object('id',%L,'revision',1,'branch_id','ce710000-0000-0000-0000-000000000001','amount',900))$q$,:'rate'),'stale tariff revision rejected');
select set_config('request.jwt.claim.sub','ce720000-0000-0000-0000-000000000002',true);
select pg_temp.ok((select amount=500 and (incentive_rule_snapshot->>'revision')::integer=1 from logistics_trips where id=:'trip'),'tariff update never revalues an authorized historical trip');
select set_config('request.jwt.claim.sub','ce720000-0000-0000-0000-000000000001',true);
select logistics_trip_action('CREATE','{"branch_id":"ce710000-0000-0000-0000-000000000001","request_id":"ce740000-0000-0000-0000-000000000002","origin":"Second origin","destination":"Second destination","departure_local":"2026-11-03T09:00","arrival_local":"2026-11-03T10:00","purpose":"RECOGIDA"}')->>'id' as no_rate \gset
select set_config('request.jwt.claim.sub','ce720000-0000-0000-0000-000000000002',true);
select logistics_trip_action('APPROVE',jsonb_build_object('id',:'no_rate','revision',1,'review_note','Authorized without configured tariff'));
select pg_temp.ok((select status='APROBADO' and amount is null and incentive_rule_snapshot->>'status'='NO_APLICA_DENTRO_HORARIO' from logistics_trips where id=:'no_rate'),'inside-hours trip is authorized without incentive');
select pg_temp.denied(format($q$select logistics_trip_action('SETTLE',jsonb_build_object('branch_id','ce710000-0000-0000-0000-000000000001','payroll_reference','TEST','trips',jsonb_build_array(jsonb_build_object('id',%L,'revision',2))))$q$,:'no_rate'),'inside-hours trip cannot enter incentive settlement');
select logistics_trip_action('SETTLE',jsonb_build_object('branch_id','ce710000-0000-0000-0000-000000000001','payroll_reference','TEST-LEGACY','trips',jsonb_build_array(jsonb_build_object('id',:'trip','revision',2))));
select pg_temp.ok((select status='LIQUIDADO' and amount=500 from logistics_trips where id=:'trip'),'legacy settlement preserves authorized fixed amount');
select set_config('request.jwt.claim.sub','ce720000-0000-0000-0000-000000000001',true);
select logistics_trip_action('CREATE','{"branch_id":"ce710000-0000-0000-0000-000000000001","request_id":"ce740000-0000-0000-0000-000000000003","origin":"Base origin","destination":"Base destination","departure_local":"2026-11-04T17:00","arrival_local":"2026-11-04T19:00","purpose":"RECOGIDA"}')->>'id' as base_trip \gset
select set_config('request.jwt.claim.sub','ce720000-0000-0000-0000-000000000002',true);
select logistics_trip_action('APPROVE',jsonb_build_object('id',:'base_trip','revision',1,'review_note','Outside finish','amount',99999));
select pg_temp.ok((select amount=1000 and currency='DOP' and incentive_rule_id is null and incentive_rule_snapshot->>'status'='TARIFA_BASE_FUERA_HORARIO' from logistics_trips where id=:'base_trip'),'outside finish applies business-authorized DOP 1000 base and ignores caller amount');
select set_config('request.jwt.claim.sub','ce720000-0000-0000-0000-000000000003',true);
select logistics_trip_rate_save('{"branch_id":"ce710000-0000-0000-0000-000000000001","purpose":"TRASLADO","amount":800,"active":false}');
select set_config('request.jwt.claim.sub','ce720000-0000-0000-0000-000000000001',true);
select logistics_trip_action('CREATE','{"branch_id":"ce710000-0000-0000-0000-000000000001","request_id":"ce740000-0000-0000-0000-000000000004","origin":"Inactive origin","destination":"Inactive destination","departure_local":"2026-11-05T18:01","arrival_local":"2026-11-05T19:00","purpose":"TRASLADO"}')->>'id' as inactive_trip \gset
select set_config('request.jwt.claim.sub','ce720000-0000-0000-0000-000000000002',true);
select logistics_trip_action('APPROVE',jsonb_build_object('id',:'inactive_trip','revision',1,'review_note','Inactive rule'));
select pg_temp.ok((select amount is null and incentive_rule_snapshot->>'status'='TARIFA_INACTIVA' from logistics_trips where id=:'inactive_trip'),'inactive override suspends base incentive without blocking trip authorization');
select pg_temp.ok(not has_function_privilege('anon','public.logistics_trip_rate_save(jsonb)','execute'),'anonymous fixed tariff mutation denied');
reset role;
select pg_temp.ok((select relrowsecurity from pg_class where oid='public.logistics_trip_rates'::regclass) and (select relrowsecurity from pg_class where oid='public.logistics_trip_rate_history'::regclass),'rate and audit tables retain RLS');
rollback;
