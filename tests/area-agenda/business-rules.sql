begin;
select set_config('request.jwt.claim.sub','f9200000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
insert into branches(id,code,name) values('ea100000-0000-0000-0000-000000000001','AGENDA-A','Agenda synthetic A'),('ea100000-0000-0000-0000-000000000002','AGENDA-B','Agenda synthetic B');
insert into auth.users(id,email) values('ea200000-0000-0000-0000-000000000001','agenda-operator@example.invalid'),('ea200000-0000-0000-0000-000000000002','agenda-quality@example.invalid'),('ea200000-0000-0000-0000-000000000003','agenda-lab@example.invalid');
insert into profiles(id,full_name,branch_id,active) values('ea200000-0000-0000-0000-000000000001','Operador sintético','ea100000-0000-0000-0000-000000000001',true),('ea200000-0000-0000-0000-000000000002','Calidad sintética','ea100000-0000-0000-0000-000000000001',true),('ea200000-0000-0000-0000-000000000003','Laboratorio sintético','ea100000-0000-0000-0000-000000000001',true);
insert into user_roles(user_id,role_id,branch_id) select v.actor,r.id,'ea100000-0000-0000-0000-000000000001'::uuid from (values('ea200000-0000-0000-0000-000000000001'::uuid,'ASISTENTE_OPERACIONES'),('ea200000-0000-0000-0000-000000000002'::uuid,'CALIDAD'),('ea200000-0000-0000-0000-000000000003'::uuid,'LABORATORIO'))v(actor,code) join roles r on r.code=v.code;
create function pg_temp.ag_ok(b boolean,label text) returns void language plpgsql as $$begin if b is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.ag_fails(q text,expected text,label text) returns void language plpgsql as $$begin begin execute q;exception when others then if position(expected in sqlerrm)=0 then raise exception 'Unexpected [%] for %',sqlerrm,label;end if;raise notice 'PASS %',label;return;end;raise exception 'FAIL expected rejection %',label;end$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','ea200000-0000-0000-0000-000000000001',true);
select pg_temp.ag_ok((select count(*)=4 from vw_my_work_areas),'operations sees its four responsibility areas');
select pg_temp.ag_ok(not work_agenda_access('ea100000-0000-0000-0000-000000000002','OPERACIONES'),'agenda denies other branches');
select pg_temp.ag_ok(not work_agenda_access('ea100000-0000-0000-0000-000000000001','LABORATORIO'),'agenda denies unrelated areas');
select jsonb_build_object('branch_id','ea100000-0000-0000-0000-000000000001','area_code','OPERACIONES','title','Revisar pedidos sintéticos','owner_id','ea200000-0000-0000-0000-000000000001','due_at',now()+interval '2 days','priority','NORMAL','requires_review',true,'request_id',gen_random_uuid(),'checklist',jsonb_build_array(jsonb_build_object('label','Conciliar pendientes','done',true)))::text as payload \gset
select work_task_action('CREATE',:'payload'::jsonb) as created \gset
select (:'created'::jsonb->'ids'->>0) as task \gset
select pg_temp.ag_ok((select status='PENDIENTE' and original_due_at=due_at and revision=1 and not (checklist->0->>'done')::boolean from work_tasks where id=:'task'),'new task has immutable original deadline and unchecked steps');
select pg_temp.ag_ok((work_task_action('CREATE',:'payload'::jsonb)->>'already_created')::boolean,'routine retry does not duplicate tasks');
select pg_temp.ag_fails(format('select work_task_action(''CREATE'',%L::jsonb)',jsonb_set(:'payload'::jsonb,'{title}','"Changed title"')),'otros datos','retry cannot silently change a saved request');
select pg_temp.ag_fails(format('select work_task_action(''CREATE'',%L::jsonb)',jsonb_set(jsonb_set(:'payload'::jsonb,'{request_id}',to_jsonb(gen_random_uuid())),'{branch_id}','"ea100000-0000-0000-0000-000000000002"')),'no autorizada','cross branch task cannot be created');
select pg_temp.ag_fails(format('select work_task_action(''SUBMIT'',%L::jsonb)',jsonb_build_object('id',:'task','revision',1)),'Complete la lista','submission requires evidence and checklist');
select pg_temp.ag_fails(format('update work_tasks set status=''COMPLETADA'' where id=%L',:'task'),'Complete la lista','direct updates cannot bypass evidence');
select pg_temp.ag_fails(format('update work_tasks set reviewed_by=auth.uid() where id=%L',:'task'),'trazabilidad','review identity cannot be forged');
select pg_temp.ag_fails(format('update work_tasks set original_due_at=now() where id=%L',:'task'),'inmutables','original deadline cannot be changed');
select pg_temp.ag_fails(format('select work_task_action(''BLOCK'',%L::jsonb)',jsonb_build_object('id',:'task','revision',1)),'Documente el bloqueo','blocking requires cause and help request');
select work_task_action('START',jsonb_build_object('id',:'task','revision',1));
select work_task_action('BLOCK',jsonb_build_object('id',:'task','revision',2,'last_note','Esperando confirmación'));
select pg_temp.ag_ok((select status='BLOQUEADA' from work_tasks where id=:'task'),'blocked task remains open and traceable');
select work_task_action('SUBMIT',jsonb_build_object('id',:'task','revision',3,'evidence','REF-SYNTHETIC','checklist',jsonb_build_array(jsonb_build_object('label','Conciliar pendientes','done',true))));
select pg_temp.ag_ok((select status='EN_REVISION' and submitted_by=auth.uid() and submitted_at is not null from work_tasks where id=:'task'),'execution submits evidence for independent review');
select pg_temp.ag_fails(format('select work_task_action(''APPROVE'',%L::jsonb)',jsonb_build_object('id',:'task','revision',4,'review_note','My own evidence')),'revisor','executor cannot approve own evidence');
select set_config('request.jwt.claim.sub','ea200000-0000-0000-0000-000000000003',true);
select pg_temp.ag_ok((select count(*)=0 from work_tasks),'laboratory cannot read operations tasks');
select pg_temp.ag_fails(format('select work_task_action(''APPROVE'',%L::jsonb)',jsonb_build_object('id',:'task','revision',4,'review_note','Foreign area')),'no disponible','foreign area action is denied');
select set_config('request.jwt.claim.sub','ea200000-0000-0000-0000-000000000002',true);
select pg_temp.ag_ok((select count(*)=1 from work_tasks),'quality can see cross area evidence in its branch');
select pg_temp.ag_fails(format('select work_task_action(''APPROVE'',%L::jsonb)',jsonb_build_object('id',:'task','revision',4)),'otra persona','review requires an observation');
select work_task_action('RETURN',jsonb_build_object('id',:'task','revision',4,'review_note','Aclarar evidencia'));
select pg_temp.ag_ok((select status='EN_CURSO' and reviewed_by=auth.uid() from work_tasks where id=:'task'),'quality may return work for correction');
select set_config('request.jwt.claim.sub','ea200000-0000-0000-0000-000000000001',true);
select work_task_action('SUBMIT',jsonb_build_object('id',:'task','revision',5,'evidence','REF-CORRECTED','checklist',jsonb_build_array(jsonb_build_object('label','Conciliar pendientes','done',true))));
select pg_temp.ag_ok((select review_note is null and reviewed_by is null from work_tasks where id=:'task'),'new submission clears prior review markers');
select set_config('request.jwt.claim.sub','ea200000-0000-0000-0000-000000000002',true);
select work_task_action('APPROVE',jsonb_build_object('id',:'task','revision',6,'review_note','Evidencia verificada'));
select pg_temp.ag_ok((select status='COMPLETADA' and completed_at is not null and reviewed_by=auth.uid() from work_tasks where id=:'task'),'independent quality reviewer closes the task');
select pg_temp.ag_fails(format('select work_task_action(''SAVE'',%L::jsonb)',jsonb_build_object('id',:'task','revision',7,'evidence','Overwrite','checklist','[]'::jsonb)),'Solo el responsable','closed evidence cannot be overwritten');
select pg_temp.ag_fails('delete from work_task_history','permission denied','task audit history cannot be deleted');
select pg_temp.ag_fails('update work_task_history set actor_name=''forged''','permission denied','task audit history cannot be edited');
select set_config('request.jwt.claim.sub','f9200000-0000-0000-0000-000000000001',true);
select work_task_action('REOPEN',jsonb_build_object('id',:'task','revision',7,'last_note','Nueva verificación requerida'));
select pg_temp.ag_ok((select status='EN_CURSO' and completed_at is null and evidence is null from work_tasks where id=:'task'),'reopening resets evidence while preserving historical records');
select work_task_action('PLAN',jsonb_build_object('id',:'task','revision',8,'title','Revisar pedidos sintéticos','description','Replanificación','owner_id','ea200000-0000-0000-0000-000000000001','due_at',now()+interval '7 days','priority','ALTA','last_note','Proveedor reprogramó entrega'));
select pg_temp.ag_ok((select due_at>original_due_at and last_note='Proveedor reprogramó entrega' from work_tasks where id=:'task'),'replanning preserves original due date and reason');
select pg_temp.ag_fails(format('select work_task_action(''START'',%L::jsonb)',jsonb_build_object('id',:'task','revision',8)),'La tarea cambió','stale task revisions are rejected');
select pg_temp.ag_ok((select count(*)=9 from work_task_history where task_id=:'task'),'every successful task mutation has audit evidence');
select jsonb_set(jsonb_set(jsonb_set(:'payload'::jsonb,'{request_id}',to_jsonb(gen_random_uuid())),'{occurrences}','3'),'{interval_days}','7')::text as series \gset
select work_task_action('CREATE',:'series'::jsonb) as series_result \gset
select pg_temp.ag_ok(jsonb_array_length(:'series_result'::jsonb->'ids')=3,'weekly routine creates three concrete occurrences');
select pg_temp.ag_ok((select max(due_at)-min(due_at)=interval '14 days' from work_tasks where creation_key=(:'series'::jsonb->>'request_id')::uuid),'weekly deadlines have independent seven day spacing');
select pg_temp.ag_fails(format('select work_task_action(''CREATE'',%L::jsonb)',jsonb_set(jsonb_set(:'payload'::jsonb,'{request_id}',to_jsonb(gen_random_uuid())),'{occurrences}','32')),'máximo 31','routine creation is bounded');
select pg_temp.ag_fails(format('select work_task_action(''CREATE'',%L::jsonb)',jsonb_set(jsonb_set(jsonb_set(:'payload'::jsonb,'{request_id}',to_jsonb(gen_random_uuid())),'{area_code}','"CALIDAD"'),'{requires_review}','false')),'requiere revisión','quality work always requires independent review');
select pg_temp.ag_ok((select count(*)=12 from work_task_history),'finite routines keep independent audit records');
select pg_temp.ag_fails(format('select work_task_action(''CREATE'',%L::jsonb)',jsonb_set(jsonb_set(:'payload'::jsonb,'{request_id}',to_jsonb(gen_random_uuid())),'{area_code}','"LABORATORIO"')),'responsable activo','owner must belong to the assigned area');
select jsonb_set(jsonb_set(:'payload'::jsonb,'{request_id}',to_jsonb(gen_random_uuid())),'{requires_review}','false')::text as administrative \gset
select work_task_action('CREATE',:'administrative'::jsonb) as admin_result \gset
select (:'admin_result'::jsonb->'ids'->>0) as admin_task \gset
select set_config('request.jwt.claim.sub','ea200000-0000-0000-0000-000000000001',true);
select work_task_action('SUBMIT',jsonb_build_object('id',:'admin_task','revision',1,'evidence','ADMIN-REFERENCE','checklist',jsonb_build_array(jsonb_build_object('label','Conciliar pendientes','done',true))));
select pg_temp.ag_ok((select status='COMPLETADA' from work_tasks where id=:'admin_task'),'employee can complete an administrative task exempted by management');
select pg_temp.ag_fails(format('select work_task_action(''CREATE'',%L::jsonb)',jsonb_set(:'administrative'::jsonb,'{request_id}',to_jsonb(gen_random_uuid()))),'requiere revisión','employee cannot exempt their own new tasks from review');
select set_config('request.jwt.claim.sub','f9200000-0000-0000-0000-000000000001',true);
reset role;update profiles set active=false where id='ea200000-0000-0000-0000-000000000001';set local role authenticated;
select set_config('request.jwt.claim.sub','ea200000-0000-0000-0000-000000000001',true);
select pg_temp.ag_ok((select count(*)=0 from work_tasks),'inactive employee cannot read the agenda');
select pg_temp.ag_fails('select work_agenda_people(''ea100000-0000-0000-0000-000000000001'',''OPERACIONES'')','no autorizada','inactive employee cannot enumerate team members');
reset role;set local role anon;
select pg_temp.ag_fails('select * from work_tasks','permission denied','anonymous cannot read tasks');
select pg_temp.ag_fails('select work_task_action(''CREATE'',''{}'')','permission denied','anonymous cannot invoke task actions');
reset role;rollback;
