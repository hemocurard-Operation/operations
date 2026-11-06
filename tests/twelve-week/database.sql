-- Synthetic, rollback-only integration checks for twelve-week execution.
-- The denial helper verifies SQLSTATE; unrelated errors must fail the suite.
begin;
select set_config('request.jwt.claim.sub','f9200000-0000-0000-0000-000000000001',true);
create function pg_temp.tw_ok(v boolean,label text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.tw_denied(stmt text,expected_state text,label text) returns void language plpgsql as $$declare actual_state text;begin begin execute stmt;exception when others then get stacked diagnostics actual_state=returned_sqlstate;if actual_state<>expected_state then raise exception 'FAIL % expected SQLSTATE %, got %: %',label,expected_state,actual_state,sqlerrm;end if;raise notice 'PASS %',label;return;end;raise exception 'FAIL expected denial %',label;end$$;
create function pg_temp.tw_req(n integer) returns uuid language sql as $$select ('ce300000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid$$;
grant execute on all functions in schema pg_temp to authenticated,anon;
insert into branches(id,code,name) values('ce100000-0000-0000-0000-000000000001','TW-A','Plan ficticio A'),('ce100000-0000-0000-0000-000000000002','TW-B','Plan ficticio B');
insert into auth.users(id,email) values('ce200000-0000-0000-0000-000000000001','tw-manager@example.invalid'),('ce200000-0000-0000-0000-000000000002','tw-owner@example.invalid'),('ce200000-0000-0000-0000-000000000003','tw-foreign@example.invalid'),('ce200000-0000-0000-0000-000000000004','tw-other-area@example.invalid');
insert into profiles(id,full_name,branch_id,active) values('ce200000-0000-0000-0000-000000000001','Responsable ficticia de laboratorio','ce100000-0000-0000-0000-000000000001',true),('ce200000-0000-0000-0000-000000000002','Ejecutor ficticio','ce100000-0000-0000-0000-000000000001',true),('ce200000-0000-0000-0000-000000000003','Ejecutor de otra sucursal','ce100000-0000-0000-0000-000000000002',true),('ce200000-0000-0000-0000-000000000004','Otra área ficticia','ce100000-0000-0000-0000-000000000001',true);
insert into user_roles(user_id,role_id,branch_id) select v.actor,r.id,v.branch from (values('ce200000-0000-0000-0000-000000000001'::uuid,'ENCARGADA_LABORATORIO','ce100000-0000-0000-0000-000000000001'::uuid),('ce200000-0000-0000-0000-000000000002'::uuid,'LABORATORIO','ce100000-0000-0000-0000-000000000001'::uuid),('ce200000-0000-0000-0000-000000000003'::uuid,'LABORATORIO','ce100000-0000-0000-0000-000000000002'::uuid),('ce200000-0000-0000-0000-000000000004'::uuid,'ASISTENTE_COMERCIAL','ce100000-0000-0000-0000-000000000001'::uuid))v(actor,code,branch) join roles r on r.code=v.code;
insert into role_permissions(role_id,permission_code) select id,'PROJECTS_VIEW' from roles where code in ('ENCARGADA_LABORATORIO','LABORATORIO') on conflict do nothing;
select pg_temp.tw_ok((select not enabled from app_feature_flags where key='twelve_week_execution'),'twelve-week execution flag defaults off');
set local role authenticated;select set_config('request.jwt.claim.sub','ce200000-0000-0000-0000-000000000001',true);select set_config('request.jwt.claim.role','authenticated',true);
select pg_temp.tw_ok(not (twelve_week_catalog('ce100000-0000-0000-0000-000000000001','LABORATORIO')->>'enabled')::boolean,'catalog reports disabled execution without changing legacy tasks');
select pg_temp.tw_denied($q$select twelve_week_action('ce100000-0000-0000-0000-000000000001','LABORATORIO','CYCLE_SAVE','{}',pg_temp.tw_req(1))$q$,'P0001','disabled execution denies definitive writes');
reset role;update app_feature_flags set enabled=true where key='twelve_week_execution';set local role authenticated;
select pg_temp.tw_ok((twelve_week_catalog('ce100000-0000-0000-0000-000000000001','LABORATORIO')->>'can_manage')::boolean,'area manager can manage execution cycle');
select pg_temp.tw_ok(jsonb_array_length(twelve_week_context()->'branches')=1,'context lists only the assigned branch before a second role is assigned');
select pg_temp.tw_ok((select bool_and(x->'branch_ids'=jsonb_build_array('ce100000-0000-0000-0000-000000000001'::text)) from jsonb_array_elements(twelve_week_context()->'areas') x),'context binds each offered area to its actual authorized branch');
select pg_temp.tw_denied($q$select twelve_week_catalog('ce100000-0000-0000-0000-000000000002','LABORATORIO')$q$,'42501','catalog denies an unassigned branch');
select (date_trunc('week',now() at time zone 'America/Santo_Domingo')::date+7)::text as cycle_start \gset
select jsonb_build_object('title','Ciclo ficticio de laboratorio','start_date',:'cycle_start','objective','Verificar tareas operativas ficticias con evidencia','status','BORRADOR')::text as cycle_payload \gset
select twelve_week_action('ce100000-0000-0000-0000-000000000001','LABORATORIO','CYCLE_SAVE',:'cycle_payload'::jsonb,pg_temp.tw_req(1))->>'id' as cycle_id \gset
select twelve_week_action('ce100000-0000-0000-0000-000000000001','LABORATORIO','CYCLE_SAVE',:'cycle_payload'::jsonb,pg_temp.tw_req(1));
select pg_temp.tw_ok((select count(*)=1 from twelve_week_cycles),'idempotent cycle retry creates one cycle');
select pg_temp.tw_ok((select end_date=start_date+83 and revision=1 from twelve_week_cycles where id=:'cycle_id'),'cycle spans exactly eighty-four local dates');
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(1))','ce100000-0000-0000-0000-000000000001','LABORATORIO','CYCLE_SAVE',jsonb_set(:'cycle_payload'::jsonb,'{title}','"Payload distinto"')),'P0001','request cannot be reused with modified payload');
select jsonb_build_object('cycle_id',:'cycle_id','week_number',1,'title','Preparación ficticia','description','Tarea aislada sin modificación clínica','owner_id','ce200000-0000-0000-0000-000000000002','due_at',(:'cycle_start'::date::timestamp at time zone 'America/Santo_Domingo'),'priority','NORMAL','requires_review',false,'status','COMPLETADA')::text as task_payload \gset
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(2))','ce100000-0000-0000-0000-000000000001','LABORATORIO','TASK_CREATE',:'task_payload'),'P0001','draft cycle cannot create execution task');
select twelve_week_action('ce100000-0000-0000-0000-000000000001','LABORATORIO','CYCLE_SAVE',jsonb_build_object('id',:'cycle_id','revision',1,'title','Ciclo ficticio de laboratorio','start_date',:'cycle_start','objective','Verificar tareas operativas ficticias con evidencia','status','ACTIVO'),pg_temp.tw_req(3));
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(4))','ce100000-0000-0000-0000-000000000001','LABORATORIO','CYCLE_SAVE',jsonb_build_object('id',:'cycle_id','revision',1,'title','Edición obsoleta','start_date',:'cycle_start','objective','No debe guardarse','status','ACTIVO')),'40001','stale cycle revision is rejected');
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(4))','ce100000-0000-0000-0000-000000000001','LABORATORIO','CYCLE_SAVE',jsonb_build_object('id',:'cycle_id','revision',2,'title','Fecha modificada','start_date',(:'cycle_start'::date+7)::text,'objective','No debe mover tareas implícitamente','status','ACTIVO')),'P0001','cycle start date is immutable');
select jsonb_build_object('cycle_id',:'cycle_id','week_number',1,'goal','Revisar registros ficticios','target_metric','revisiones con evidencia','target_value',4)::text as goal_payload \gset
select twelve_week_action('ce100000-0000-0000-0000-000000000001','LABORATORIO','GOAL_SAVE',:'goal_payload'::jsonb,pg_temp.tw_req(5))->>'id' as goal_id \gset
select twelve_week_action('ce100000-0000-0000-0000-000000000001','LABORATORIO','GOAL_SAVE',:'goal_payload'::jsonb,pg_temp.tw_req(5));
select pg_temp.tw_ok((select count(*)=1 from twelve_week_goals),'idempotent goal retry creates one weekly goal');
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(6))','ce100000-0000-0000-0000-000000000001','LABORATORIO','GOAL_SAVE',:'goal_payload'::jsonb||jsonb_build_object('id',:'goal_id','revision',0)),'40001','stale goal revision is rejected');
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(6))','ce100000-0000-0000-0000-000000000001','LABORATORIO','GOAL_SAVE',jsonb_set(:'goal_payload'::jsonb,'{week_number}','13')),'P0001','goal week beyond twelve is rejected');
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(6))','ce100000-0000-0000-0000-000000000001','LABORATORIO','GOAL_SAVE',jsonb_set(jsonb_set(:'goal_payload'::jsonb,'{week_number}','2'),'{target_value}','-1')),'P0001','negative target rejected by finite metric validation');
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(6))','ce100000-0000-0000-0000-000000000001','LABORATORIO','GOAL_SAVE',jsonb_set(jsonb_set(:'goal_payload'::jsonb,'{week_number}','2'),'{target_value}','"NaN"')),'P0001','NaN goal target is rejected');
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(6))','ce100000-0000-0000-0000-000000000001','LABORATORIO','GOAL_SAVE',jsonb_set(jsonb_set(:'goal_payload'::jsonb,'{week_number}','2'),'{target_value}','"Infinity"')),'P0001','infinite goal target is rejected');
select pg_temp.tw_ok((select count(*)=1 from twelve_week_goals),'failed goal validation leaves existing weekly goal unchanged');
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(6))','ce100000-0000-0000-0000-000000000001','LABORATORIO','TASK_CREATE',jsonb_set(:'task_payload'::jsonb,'{week_number}','0')),'P0001','task week below one is rejected');
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(6))','ce100000-0000-0000-0000-000000000001','LABORATORIO','TASK_CREATE',jsonb_set(:'task_payload'::jsonb,'{owner_id}','"ce200000-0000-0000-0000-000000000003"')),'42501','task owner from another branch is rejected');
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(6))','ce100000-0000-0000-0000-000000000001','LABORATORIO','TASK_CREATE',jsonb_set(:'task_payload'::jsonb,'{owner_id}','"ce200000-0000-0000-0000-000000000004"')),'42501','task owner from another area is rejected');
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(6))','ce100000-0000-0000-0000-000000000001','LABORATORIO','TASK_CREATE',jsonb_set(:'task_payload'::jsonb,'{due_at}',to_jsonb(((:'cycle_start'::date+7)::timestamp at time zone 'America/Santo_Domingo')::text))),'P0001','RD midnight at next week is outside selected week');
reset role;update profiles set active=false where id='ce200000-0000-0000-0000-000000000002';set local role authenticated;
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(6))','ce100000-0000-0000-0000-000000000001','LABORATORIO','TASK_CREATE',:'task_payload'),'42501','inactive task owner is rejected');
reset role;update profiles set active=true where id='ce200000-0000-0000-0000-000000000002';set local role authenticated;
select twelve_week_action('ce100000-0000-0000-0000-000000000001','LABORATORIO','TASK_CREATE',:'task_payload'::jsonb,pg_temp.tw_req(7))->>'task_id' as task_id \gset
select twelve_week_action('ce100000-0000-0000-0000-000000000001','LABORATORIO','TASK_CREATE',:'task_payload'::jsonb,pg_temp.tw_req(7));
select pg_temp.tw_ok((select count(*)=1 from twelve_week_task_links),'idempotent execution retry creates one task link');
select pg_temp.tw_ok((select count(*)=1 from work_tasks where id=:'task_id'),'execution task is real work task, not duplicated plan state');
select pg_temp.tw_ok((select status='PENDIENTE' and requires_review and source_route='twelveweek' and owner_id='ce200000-0000-0000-0000-000000000002'::uuid and created_by='ce200000-0000-0000-0000-000000000001'::uuid from work_tasks where id=:'task_id'),'real task preserves canonical status, review and distinct authenticated creator');
select pg_temp.tw_ok((select count(*)=1 from work_task_history where task_id=:'task_id'),'creation retains normal agenda audit history');
select pg_temp.tw_ok(jsonb_array_length(twelve_week_catalog('ce100000-0000-0000-0000-000000000001','LABORATORIO')->'tasks')=1,'catalog exposes linked real work task');
select pg_temp.tw_denied($q$select * from twelve_week_requests$q$,'42501','authenticated clients cannot read idempotency ledger');
select pg_temp.tw_denied($q$update twelve_week_cycles set status='CERRADO'$q$,'42501','browser cannot bypass audited cycle action');
select pg_temp.tw_denied($q$delete from twelve_week_task_links$q$,'42501','browser cannot erase task links');
select pg_temp.tw_ok((select count(*)=1 from work_tasks where source_route='twelveweek'),'failed calls did not create extra execution tasks');
select twelve_week_action('ce100000-0000-0000-0000-000000000001','LABORATORIO','TASK_CREATE',jsonb_set(jsonb_set(:'task_payload'::jsonb,'{week_number}','12'),'{due_at}',to_jsonb((((:'cycle_start'::date+83)::timestamp+interval '23 hours 59 minutes 59 seconds') at time zone 'America/Santo_Domingo')::text)),pg_temp.tw_req(9));
select pg_temp.tw_ok((select count(*)=2 from twelve_week_task_links),'last second of final RD cycle day belongs to week twelve');
reset role;
select set_config('request.jwt.claim.sub','f9200000-0000-0000-0000-000000000001',true);
insert into user_roles(user_id,role_id,branch_id) select 'ce200000-0000-0000-0000-000000000001'::uuid,id,'ce100000-0000-0000-0000-000000000002'::uuid from roles where code='LABORATORIO';
set local role authenticated;
select set_config('request.jwt.claim.sub','ce200000-0000-0000-0000-000000000001',true);
select pg_temp.tw_ok(not (twelve_week_catalog('ce100000-0000-0000-0000-000000000002','LABORATORIO')->>'can_manage')::boolean,'manager in branch A plus reader in B does not compose management authority in B');
select pg_temp.tw_ok((select x->'branch_ids' @> '["ce100000-0000-0000-0000-000000000001","ce100000-0000-0000-0000-000000000002"]'::jsonb from jsonb_array_elements(twelve_week_context()->'areas') x where x->>'code'='LABORATORIO'),'context exposes both genuinely assigned laboratory scopes');
select pg_temp.tw_denied($q$select twelve_week_action('ce100000-0000-0000-0000-000000000002','LABORATORIO','CYCLE_SAVE','{"title":"No autorizado","start_date":"2030-01-07","objective":"Prueba","status":"ACTIVO"}',pg_temp.tw_req(10))$q$,'42501','management permission is bound to the actual branch role');
select set_config('request.jwt.claim.sub','ce200000-0000-0000-0000-000000000002',true);
select pg_temp.tw_ok(not (twelve_week_catalog('ce100000-0000-0000-0000-000000000001','LABORATORIO')->>'can_manage')::boolean,'authorized area reader cannot manage cycles');
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(8))','ce100000-0000-0000-0000-000000000001','LABORATORIO','TASK_CREATE',:'task_payload'),'42501','area executor cannot assign plan execution tasks');
select work_task_action('START',jsonb_build_object('id',:'task_id','revision',1));
select pg_temp.tw_ok((select status='EN_CURSO' from work_tasks where id=:'task_id'),'execution starts through original agenda with canonical EN_CURSO');
select work_task_action('SUBMIT',jsonb_build_object('id',:'task_id','revision',2,'evidence','EVIDENCIA-SINTETICA','checklist','[]'::jsonb));
select pg_temp.tw_ok((select status='EN_REVISION' and completed_at is null from work_tasks where id=:'task_id'),'submission requires independent review instead of false completion');
select pg_temp.tw_denied(format('select work_task_action(%L,%L::jsonb)','APPROVE',jsonb_build_object('id',:'task_id','revision',3,'review_note','No puede aprobarse a sí mismo')),'P0001','task executor cannot approve own evidence');
select set_config('request.jwt.claim.sub','ce200000-0000-0000-0000-000000000001',true);
select twelve_week_action('ce100000-0000-0000-0000-000000000001','LABORATORIO','CYCLE_SAVE',jsonb_build_object('id',:'cycle_id','revision',2,'title','Ciclo ficticio de laboratorio','start_date',:'cycle_start','objective','Cierre de planificación sin aprobación clínica','status','CERRADO'),pg_temp.tw_req(11));
select pg_temp.tw_ok((select status='EN_REVISION' and completed_at is null from work_tasks where id=:'task_id'),'closing cycle does not complete or approve an underlying work task');
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(12))','ce100000-0000-0000-0000-000000000001','LABORATORIO','TASK_CREATE',:'task_payload'),'P0001','closed cycle cannot create execution tasks');
select pg_temp.tw_denied(format('select twelve_week_action(%L::uuid,%L,%L,%L::jsonb,pg_temp.tw_req(12))','ce100000-0000-0000-0000-000000000001','LABORATORIO','CYCLE_SAVE',jsonb_build_object('id',:'cycle_id','revision',3,'title','Intento de reapertura','start_date',:'cycle_start','objective','No debe reabrirse','status','ACTIVO')),'P0001','closed cycle cannot silently reopen');
select set_config('request.jwt.claim.sub','ce200000-0000-0000-0000-000000000003',true);
select pg_temp.tw_ok((select count(*)=0 from twelve_week_cycles),'other branch RLS hides execution cycles');
select pg_temp.tw_ok((select count(*)=0 from twelve_week_goals),'other branch RLS hides weekly goals');
select pg_temp.tw_ok((select count(*)=0 from twelve_week_task_links),'other branch RLS hides execution links');
reset role;
select pg_temp.tw_ok((select count(*)=6 from twelve_week_requests where actor_id='ce200000-0000-0000-0000-000000000001'),'only successful distinct requests enter the private idempotency ledger');
select pg_temp.tw_ok((select count(*)=6 from audit_events where module='TWELVE_WEEK' and user_id='ce200000-0000-0000-0000-000000000001'),'successful plan actions are audited exactly once with actual actor');
set local role anon;
select pg_temp.tw_denied($q$select * from twelve_week_cycles$q$,'42501','anonymous cannot read execution cycles');
select pg_temp.tw_denied($q$select twelve_week_catalog('ce100000-0000-0000-0000-000000000001','LABORATORIO')$q$,'42501','anonymous cannot enumerate cycle catalog');
rollback;
