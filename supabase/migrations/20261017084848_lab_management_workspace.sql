begin;
-- Access is granted to the role, never to individual accounts.
insert into public.role_permissions(role_id,permission_code) select r.id,p.permission_code from public.roles r cross join public.app_permissions p where r.code='ENCARGADA_LABORATORIO' and p.permission_code in ('DISPATCH_VIEW','APPROVAL_VIEW','QUALITY_WRITE','QUALITY_DAILY_REVIEW') on conflict do nothing;
insert into public.app_module_catalog(route_key,title,group_name,permission_code) values('laboratory','Gestión del Laboratorio','LABORATORIO Y SANGRE','SCREENING_VIEW');
insert into public.role_module_access(role_id,route_key,enabled) select id,'laboratory',code in ('SUPER_USUARIO','ENCARGADA_LABORATORIO','LABORATORIO','MEDICO_GERENTE_TECNICO','CALIDAD','GERENCIA_OPERATIVA','GERENCIA_GENERAL') from public.roles;
create function public.lab_scope(p_branch uuid,p_permission text,p_write boolean default false) returns boolean language sql stable security invoker set search_path=public,pg_temp as $$
 select auth.uid() is not null and public.wf_active_actor() and public.has_permission(p_permission) and case when p_branch is null then not p_write or public.has_role('SUPER_USUARIO') else public.can_access_branch(p_branch) end;
$$;
revoke all on function public.lab_scope(uuid,text,boolean) from public,anon;grant execute on function public.lab_scope(uuid,text,boolean) to authenticated;
create table public.lab_event_log(id uuid primary key default gen_random_uuid(),branch_id uuid references public.branches(id),table_name text not null,record_id uuid not null,actor_id uuid not null references public.profiles(id),occurred_at timestamptz not null default now(),before_data jsonb,after_data jsonb not null);
create index lab_event_record_idx on public.lab_event_log(table_name,record_id,occurred_at,id);
create index lab_event_branch_idx on public.lab_event_log(branch_id,occurred_at,id);
alter table public.lab_event_log enable row level security;
revoke all on public.lab_event_log from public,anon,authenticated;grant select on public.lab_event_log to authenticated;
create policy lab_event_read on public.lab_event_log for select to authenticated using(public.lab_scope(branch_id,'QUALITY_VIEW'));
alter table public.screening_tests add column entered_by uuid references public.profiles(id);
alter table public.reagent_lots add column entered_by uuid references public.profiles(id);
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='lab_equipment' loop execute format('drop policy %I on public.lab_equipment',p.policyname);end loop;end$$;
alter table public.lab_equipment enable row level security;
create policy lab_read on public.lab_equipment for select to authenticated using(public.lab_scope(branch_id,'RESOURCES_VIEW'));
create policy lab_insert on public.lab_equipment for insert to authenticated with check(public.lab_scope(branch_id,'RESOURCES_WRITE',true));
create policy lab_update on public.lab_equipment for update to authenticated using(public.lab_scope(branch_id,'RESOURCES_WRITE',true)) with check(public.lab_scope(branch_id,'RESOURCES_WRITE',true));
revoke all on public.lab_equipment from public,anon;revoke delete on public.lab_equipment from authenticated;grant select,insert,update on public.lab_equipment to authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='reagent_lots' loop execute format('drop policy %I on public.reagent_lots',p.policyname);end loop;end$$;
alter table public.reagent_lots enable row level security;
create policy lab_read on public.reagent_lots for select to authenticated using(public.lab_scope(branch_id,'RESOURCES_VIEW'));
create policy lab_insert on public.reagent_lots for insert to authenticated with check(public.lab_scope(branch_id,'RESOURCES_WRITE',true));
create policy lab_update on public.reagent_lots for update to authenticated using(public.lab_scope(branch_id,'RESOURCES_WRITE',true)) with check(public.lab_scope(branch_id,'RESOURCES_WRITE',true));
revoke all on public.reagent_lots from public,anon;revoke delete on public.reagent_lots from authenticated;grant select,insert,update on public.reagent_lots to authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='environmental_points' loop execute format('drop policy %I on public.environmental_points',p.policyname);end loop;end$$;
alter table public.environmental_points enable row level security;
create policy lab_read on public.environmental_points for select to authenticated using(public.lab_scope(branch_id,'RESOURCES_VIEW'));
create policy lab_insert on public.environmental_points for insert to authenticated with check(public.lab_scope(branch_id,'RESOURCES_WRITE',true));
create policy lab_update on public.environmental_points for update to authenticated using(public.lab_scope(branch_id,'RESOURCES_WRITE',true)) with check(public.lab_scope(branch_id,'RESOURCES_WRITE',true));
revoke all on public.environmental_points from public,anon;revoke delete on public.environmental_points from authenticated;grant select,insert,update on public.environmental_points to authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='equipment_service_events' loop execute format('drop policy %I on public.equipment_service_events',p.policyname);end loop;end$$;
alter table public.equipment_service_events enable row level security;
create policy lab_read on public.equipment_service_events for select to authenticated using(public.lab_scope((select e.branch_id from public.lab_equipment e where e.id=equipment_id),'RESOURCES_VIEW'));
create policy lab_insert on public.equipment_service_events for insert to authenticated with check(public.lab_scope((select e.branch_id from public.lab_equipment e where e.id=equipment_id),'RESOURCES_WRITE',true));
create policy lab_update on public.equipment_service_events for update to authenticated using(public.lab_scope((select e.branch_id from public.lab_equipment e where e.id=equipment_id),'RESOURCES_WRITE',true)) with check(public.lab_scope((select e.branch_id from public.lab_equipment e where e.id=equipment_id),'RESOURCES_WRITE',true));
revoke all on public.equipment_service_events from public,anon;revoke delete on public.equipment_service_events from authenticated;grant select,insert,update on public.equipment_service_events to authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='environmental_readings' loop execute format('drop policy %I on public.environmental_readings',p.policyname);end loop;end$$;
alter table public.environmental_readings enable row level security;
create policy lab_read on public.environmental_readings for select to authenticated using(public.lab_scope((select e.branch_id from public.environmental_points e where e.id=point_id),'RESOURCES_VIEW'));
create policy lab_insert on public.environmental_readings for insert to authenticated with check(public.lab_scope((select e.branch_id from public.environmental_points e where e.id=point_id),'RESOURCES_WRITE',true));
create policy lab_update on public.environmental_readings for update to authenticated using(public.lab_scope((select e.branch_id from public.environmental_points e where e.id=point_id),'RESOURCES_WRITE',true)) with check(public.lab_scope((select e.branch_id from public.environmental_points e where e.id=point_id),'RESOURCES_WRITE',true));
revoke all on public.environmental_readings from public,anon;revoke delete on public.environmental_readings from authenticated;grant select,insert,update on public.environmental_readings to authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='lab_methods' loop execute format('drop policy %I on public.lab_methods',p.policyname);end loop;end$$;
alter table public.lab_methods enable row level security;
create policy lab_read on public.lab_methods for select to authenticated using(public.lab_scope(branch_id,'ANALYTICAL_QC_VIEW'));
create policy lab_insert on public.lab_methods for insert to authenticated with check(public.lab_scope(branch_id,'ANALYTICAL_QC_WRITE',true));
create policy lab_update on public.lab_methods for update to authenticated using(public.lab_scope(branch_id,'ANALYTICAL_QC_WRITE',true)) with check(public.lab_scope(branch_id,'ANALYTICAL_QC_WRITE',true));
revoke all on public.lab_methods from public,anon;revoke delete on public.lab_methods from authenticated;grant select,insert,update on public.lab_methods to authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='iqc_plans' loop execute format('drop policy %I on public.iqc_plans',p.policyname);end loop;end$$;
alter table public.iqc_plans enable row level security;
create policy lab_read on public.iqc_plans for select to authenticated using(public.lab_scope((select m.branch_id from public.lab_methods m where m.id=method_id),'ANALYTICAL_QC_VIEW'));
create policy lab_insert on public.iqc_plans for insert to authenticated with check(public.lab_scope((select m.branch_id from public.lab_methods m where m.id=method_id),'ANALYTICAL_QC_WRITE',true));
create policy lab_update on public.iqc_plans for update to authenticated using(public.lab_scope((select m.branch_id from public.lab_methods m where m.id=method_id),'ANALYTICAL_QC_WRITE',true)) with check(public.lab_scope((select m.branch_id from public.lab_methods m where m.id=method_id),'ANALYTICAL_QC_WRITE',true));
revoke all on public.iqc_plans from public,anon;revoke delete on public.iqc_plans from authenticated;grant select,insert,update on public.iqc_plans to authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='iqc_results' loop execute format('drop policy %I on public.iqc_results',p.policyname);end loop;end$$;
alter table public.iqc_results enable row level security;
create policy lab_read on public.iqc_results for select to authenticated using(public.lab_scope((select m.branch_id from public.iqc_plans p join public.lab_methods m on m.id=p.method_id where p.id=plan_id),'ANALYTICAL_QC_VIEW'));
create policy lab_insert on public.iqc_results for insert to authenticated with check(public.lab_scope((select m.branch_id from public.iqc_plans p join public.lab_methods m on m.id=p.method_id where p.id=plan_id),'ANALYTICAL_QC_WRITE',true));
create policy lab_update on public.iqc_results for update to authenticated using(public.lab_scope((select m.branch_id from public.iqc_plans p join public.lab_methods m on m.id=p.method_id where p.id=plan_id),'ANALYTICAL_QC_WRITE',true)) with check(public.lab_scope((select m.branch_id from public.iqc_plans p join public.lab_methods m on m.id=p.method_id where p.id=plan_id),'ANALYTICAL_QC_WRITE',true));
revoke all on public.iqc_results from public,anon;revoke delete on public.iqc_results from authenticated;grant select,insert,update on public.iqc_results to authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='qc_deviations' loop execute format('drop policy %I on public.qc_deviations',p.policyname);end loop;end$$;
alter table public.qc_deviations enable row level security;
create policy lab_read on public.qc_deviations for select to authenticated using(public.lab_scope(branch_id,'ANALYTICAL_QC_VIEW'));
create policy lab_insert on public.qc_deviations for insert to authenticated with check(public.lab_scope(branch_id,'ANALYTICAL_QC_WRITE',true));
create policy lab_update on public.qc_deviations for update to authenticated using(public.lab_scope(branch_id,'ANALYTICAL_QC_WRITE',true)) with check(public.lab_scope(branch_id,'ANALYTICAL_QC_WRITE',true));
revoke all on public.qc_deviations from public,anon;revoke delete on public.qc_deviations from authenticated;grant select,insert,update on public.qc_deviations to authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='eqa_events' loop execute format('drop policy %I on public.eqa_events',p.policyname);end loop;end$$;
alter table public.eqa_events enable row level security;
create policy lab_read on public.eqa_events for select to authenticated using(public.lab_scope(branch_id,'ANALYTICAL_QC_VIEW'));
create policy lab_insert on public.eqa_events for insert to authenticated with check(public.lab_scope(branch_id,'ANALYTICAL_QC_WRITE',true));
create policy lab_update on public.eqa_events for update to authenticated using(public.lab_scope(branch_id,'ANALYTICAL_QC_WRITE',true)) with check(public.lab_scope(branch_id,'ANALYTICAL_QC_WRITE',true));
revoke all on public.eqa_events from public,anon;revoke delete on public.eqa_events from authenticated;grant select,insert,update on public.eqa_events to authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='cold_chain_devices' loop execute format('drop policy %I on public.cold_chain_devices',p.policyname);end loop;end$$;
alter table public.cold_chain_devices enable row level security;
create policy lab_read on public.cold_chain_devices for select to authenticated using(public.lab_scope(branch_id,'COLD_CHAIN_VIEW'));
create policy lab_insert on public.cold_chain_devices for insert to authenticated with check(public.lab_scope(branch_id,'COLD_CHAIN_WRITE',true));
create policy lab_update on public.cold_chain_devices for update to authenticated using(public.lab_scope(branch_id,'COLD_CHAIN_WRITE',true)) with check(public.lab_scope(branch_id,'COLD_CHAIN_WRITE',true));
revoke all on public.cold_chain_devices from public,anon;revoke delete on public.cold_chain_devices from authenticated;grant select,insert,update on public.cold_chain_devices to authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='cold_chain_readings' loop execute format('drop policy %I on public.cold_chain_readings',p.policyname);end loop;end$$;
alter table public.cold_chain_readings enable row level security;
create policy lab_read on public.cold_chain_readings for select to authenticated using(public.lab_scope((select d.branch_id from public.cold_chain_devices d where d.id=device_id),'COLD_CHAIN_VIEW'));
create policy lab_insert on public.cold_chain_readings for insert to authenticated with check(public.lab_scope((select d.branch_id from public.cold_chain_devices d where d.id=device_id),'COLD_CHAIN_WRITE',true));
create policy lab_update on public.cold_chain_readings for update to authenticated using(public.lab_scope((select d.branch_id from public.cold_chain_devices d where d.id=device_id),'COLD_CHAIN_WRITE',true)) with check(public.lab_scope((select d.branch_id from public.cold_chain_devices d where d.id=device_id),'COLD_CHAIN_WRITE',true));
revoke all on public.cold_chain_readings from public,anon;revoke delete on public.cold_chain_readings from authenticated;grant select,insert,update on public.cold_chain_readings to authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='transport_events' loop execute format('drop policy %I on public.transport_events',p.policyname);end loop;end$$;
alter table public.transport_events enable row level security;
create policy lab_read on public.transport_events for select to authenticated using(public.lab_scope(branch_id,'COLD_CHAIN_VIEW'));
create policy lab_insert on public.transport_events for insert to authenticated with check(public.lab_scope(branch_id,'COLD_CHAIN_WRITE',true));
create policy lab_update on public.transport_events for update to authenticated using(public.lab_scope(branch_id,'COLD_CHAIN_WRITE',true)) with check(public.lab_scope(branch_id,'COLD_CHAIN_WRITE',true));
revoke all on public.transport_events from public,anon;revoke delete on public.transport_events from authenticated;grant select,insert,update on public.transport_events to authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='transport_temperature_readings' loop execute format('drop policy %I on public.transport_temperature_readings',p.policyname);end loop;end$$;
alter table public.transport_temperature_readings enable row level security;
create policy lab_read on public.transport_temperature_readings for select to authenticated using(public.lab_scope((select t.branch_id from public.transport_events t where t.id=transport_id),'COLD_CHAIN_VIEW'));
create policy lab_insert on public.transport_temperature_readings for insert to authenticated with check(public.lab_scope((select t.branch_id from public.transport_events t where t.id=transport_id),'COLD_CHAIN_WRITE',true));
create policy lab_update on public.transport_temperature_readings for update to authenticated using(public.lab_scope((select t.branch_id from public.transport_events t where t.id=transport_id),'COLD_CHAIN_WRITE',true)) with check(public.lab_scope((select t.branch_id from public.transport_events t where t.id=transport_id),'COLD_CHAIN_WRITE',true));
revoke all on public.transport_temperature_readings from public,anon;revoke delete on public.transport_temperature_readings from authenticated;grant select,insert,update on public.transport_temperature_readings to authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='screening_tests' loop execute format('drop policy %I on public.screening_tests',p.policyname);end loop;end$$;
alter table public.screening_tests enable row level security;
create policy lab_read on public.screening_tests for select to authenticated using(public.lab_scope(branch_id,'SCREENING_VIEW'));
create policy lab_insert on public.screening_tests for insert to authenticated with check(public.lab_scope(branch_id,'SCREENING_WRITE',true));
create policy lab_update on public.screening_tests for update to authenticated using(public.lab_scope(branch_id,'SCREENING_WRITE',true)) with check(public.lab_scope(branch_id,'SCREENING_WRITE',true));
revoke all on public.screening_tests from public,anon;revoke delete on public.screening_tests from authenticated;grant select,insert,update on public.screening_tests to authenticated;

-- Append-only audit writer: trigger only, inaccessible as an RPC.
create function private.lab_record_audit() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare j jsonb:=to_jsonb(new);b uuid:=nullif(j->>'branch_id','')::uuid;
begin
 if tg_table_name='method_verifications' then select branch_id into b from public.lab_methods where id=new.method_id;
 elsif tg_table_name='equipment_service_events' then select branch_id into b from public.lab_equipment where id=new.equipment_id;
 elsif tg_table_name='environmental_readings' then select branch_id into b from public.environmental_points where id=new.point_id;
 elsif tg_table_name='iqc_plans' then select branch_id into b from public.lab_methods where id=new.method_id;
 elsif tg_table_name='iqc_results' then select m.branch_id into b from public.iqc_plans p join public.lab_methods m on m.id=p.method_id where p.id=new.plan_id;
 elsif tg_table_name='cold_chain_readings' then select branch_id into b from public.cold_chain_devices where id=new.device_id;
 elsif tg_table_name='transport_temperature_readings' then select branch_id into b from public.transport_events where id=new.transport_id;end if;
 insert into public.lab_event_log(branch_id,table_name,record_id,actor_id,before_data,after_data) values(b,tg_table_name,(j->>'id')::uuid,auth.uid(),case when tg_op='UPDATE' then to_jsonb(old) end,j);return new;
end$$;
revoke all on function private.lab_record_audit() from public,anon,authenticated;
create function private.lab_record_guard() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
begin
 if auth.uid() is null or not public.wf_active_actor() then raise exception 'Usuario inactivo o no autenticado' using errcode='42501';end if;
 if tg_table_name in ('screening_tests','reagent_lots') then
  if tg_op='INSERT' then new.entered_by:=auth.uid();elsif new.entered_by is distinct from old.entered_by then raise exception 'Autor inmutable';end if;
 end if;
 if tg_table_name='screening_tests' then
  perform 1 from public.donations where source_unit_code=new.source_unit_code and branch_id=new.branch_id for update;if not found then raise exception 'Primero registre la donación y sucursal de la unidad';end if;
  if new.status='VALIDADO' and (tg_op='INSERT' or old.status is distinct from new.status) and (new.entered_by is null or new.entered_by=auth.uid() or not public.has_permission('QUALITY_DAILY_REVIEW')) then raise exception 'La prueba debe validarla otro revisor autorizado';end if;
  if new.reagent_expiry is not null and new.reagent_expiry<new.screening_date then raise exception 'Reactivo vencido en la fecha del ensayo';end if;
  if tg_op='UPDATE' and row(new.branch_id,new.source_unit_code,new.screening_code) is distinct from row(old.branch_id,old.source_unit_code,old.screening_code) then raise exception 'Identidad de tamizaje inmutable';end if;
 elsif tg_table_name='iqc_plans' then
  if new.lower_limit is null or new.upper_limit is null or new.lower_limit>=new.upper_limit then raise exception 'Defina límites inferior y superior válidos según procedimiento';end if;
 elsif tg_table_name='cold_chain_devices' then
  if new.min_temp>=new.max_temp then raise exception 'Rango térmico no válido';end if;
 elsif tg_table_name='reagent_lots' then
  if new.quantity_available>new.quantity_received then raise exception 'Disponible no puede superar recibido';end if;
  if new.verification_status='APROBADO' and new.expiry_date<(now() at time zone 'America/Santo_Domingo')::date then raise exception 'Reactivo vencido';end if;
  if new.verification_status='APROBADO' and (tg_op='INSERT' or old.verification_status is distinct from new.verification_status) then
   if new.entered_by is null or new.entered_by=auth.uid() or not public.has_permission('QUALITY_DAILY_REVIEW') or nullif(trim(new.certificate_reference),'') is null then raise exception 'Aprobación de lote requiere revisor independiente, autor identificado y evidencia';end if;
   new.verified_by:=auth.uid();new.verified_at:=now();
  end if;
 end if;
 return new;
end$$;
revoke all on function private.lab_record_guard() from public,anon,authenticated;
create trigger lab_audit after insert or update on public.lab_equipment for each row execute function private.lab_record_audit();
create trigger lab_audit after insert or update on public.reagent_lots for each row execute function private.lab_record_audit();
create trigger lab_guard before insert or update on public.reagent_lots for each row execute function private.lab_record_guard();
create trigger lab_audit after insert or update on public.environmental_points for each row execute function private.lab_record_audit();
create trigger lab_audit after insert or update on public.equipment_service_events for each row execute function private.lab_record_audit();
create trigger lab_audit after insert or update on public.environmental_readings for each row execute function private.lab_record_audit();
create trigger lab_audit after insert or update on public.lab_methods for each row execute function private.lab_record_audit();
create trigger lab_audit after insert or update on public.iqc_plans for each row execute function private.lab_record_audit();
create trigger lab_guard before insert or update on public.iqc_plans for each row execute function private.lab_record_guard();
create trigger lab_audit after insert or update on public.iqc_results for each row execute function private.lab_record_audit();
create trigger lab_audit after insert or update on public.qc_deviations for each row execute function private.lab_record_audit();
create trigger lab_audit after insert or update on public.eqa_events for each row execute function private.lab_record_audit();
create trigger lab_audit after insert or update on public.cold_chain_devices for each row execute function private.lab_record_audit();
create trigger lab_guard before insert or update on public.cold_chain_devices for each row execute function private.lab_record_guard();
create trigger lab_audit after insert or update on public.cold_chain_readings for each row execute function private.lab_record_audit();
create trigger lab_audit after insert or update on public.transport_events for each row execute function private.lab_record_audit();
create trigger lab_audit after insert or update on public.transport_temperature_readings for each row execute function private.lab_record_audit();
create trigger lab_audit after insert or update on public.screening_tests for each row execute function private.lab_record_audit();
create trigger lab_guard before insert or update on public.screening_tests for each row execute function private.lab_record_guard();

-- Verification execution and approval have distinct actors.
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='method_verifications' loop execute format('drop policy %I on public.method_verifications',p.policyname);end loop;end$$;
create policy lab_read on public.method_verifications for select to authenticated using(public.lab_scope((select branch_id from public.lab_methods where id=method_id),'ANALYTICAL_QC_VIEW'));
create policy lab_write on public.method_verifications for all to authenticated using(public.lab_scope((select branch_id from public.lab_methods where id=method_id),'ANALYTICAL_QC_WRITE',true)) with check(public.lab_scope((select branch_id from public.lab_methods where id=method_id),'ANALYTICAL_QC_WRITE',true));
create policy lab_program_insert on public.eqa_programs for insert to authenticated with check(public.wf_active_actor() and public.has_permission('ANALYTICAL_QC_WRITE'));
create function private.lab_method_guard() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
begin
 if tg_table_name='method_verifications' then
  if tg_op='INSERT' then new.responsible_user_id:=auth.uid();if new.status='CERRADO' then raise exception 'Envíe primero la verificación a revisión';end if;
  else
   if new.responsible_user_id is distinct from old.responsible_user_id then raise exception 'Ejecutor inmutable';end if;
   if new.responsible_user_id<>auth.uid() and (to_jsonb(new)-array['status','reviewer_user_id']) is distinct from (to_jsonb(old)-array['status','reviewer_user_id']) then raise exception 'El revisor no modifica la evidencia del ejecutor';end if;
  end if;
  if new.status='CERRADO' then
   if new.responsible_user_id is null or new.responsible_user_id=auth.uid() or not public.has_permission('QUALITY_DAILY_REVIEW') or nullif(trim(new.evidence_reference),'') is null then raise exception 'Revisión independiente y evidencia requeridas';end if;new.reviewer_user_id:=auth.uid();
  end if;
 elsif new.status='APROBADO' and (tg_op='INSERT' or old.status is distinct from new.status) then
  if not public.has_permission('QUALITY_DAILY_REVIEW') or not exists(select 1 from public.method_verifications v where v.method_id=new.id and v.status='CERRADO' and v.result='ACEPTADO' and v.reviewer_user_id=auth.uid() and v.responsible_user_id<>auth.uid() and nullif(trim(v.evidence_reference),'') is not null) then raise exception 'Verifique el método y obtenga revisión independiente antes de aprobar';end if;new.approved_by:=auth.uid();new.approved_at:=now();
 end if;return new;
end$$;
revoke all on function private.lab_method_guard() from public,anon,authenticated;
create trigger lab_method_guard before insert or update on public.lab_methods for each row execute function private.lab_method_guard();
create trigger lab_method_guard before insert or update on public.method_verifications for each row execute function private.lab_method_guard();
create trigger lab_audit after insert or update on public.method_verifications for each row execute function private.lab_record_audit();
-- Preserve invoker semantics. All writes remain constrained by entity RLS.
create function public.lab_operation(p_branch uuid,p_action text,p_data jsonb) returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare actor uuid:=auth.uid();rid uuid;permission text;rec record;oldj jsonb;today date:=(now() at time zone 'America/Santo_Domingo')::date;
begin
 if jsonb_typeof(p_data) is distinct from 'object' then raise exception 'Datos inválidos';end if;
 permission:=case when p_action in ('METHOD','METHOD_VERIFY','METHOD_APPROVE','EQA_PROGRAM','IQC_PLAN','IQC_RESULT','EQA_EVENT','EQA_RESULT') then 'ANALYTICAL_QC_WRITE' when p_action in ('TEMPERATURE','DEVICE','TRANSPORT','TRANSPORT_RECEIVE') then 'COLD_CHAIN_WRITE' when p_action='SCREENING_REVIEW' then 'SCREENING_WRITE' else 'RESOURCES_WRITE' end;
 if p_branch is null or not public.lab_scope(p_branch,permission,true) then raise exception 'Operación o sucursal no autorizada' using errcode='42501';end if;
 if p_action in ('IQC_RESULT','TEMPERATURE','TRANSPORT_RECEIVE') and coalesce(p_data->>'value','') !~ '^[+-]?[0-9]+(\.[0-9]+)?$' then raise exception 'Valor numérico finito requerido';end if;
 if p_action='METHOD' then
  insert into public.lab_methods(method_code,test_name,branch_id,status,principle) values(trim(p_data->>'code'),trim(p_data->>'test_name'),p_branch,'EN_VERIFICACION',trim(p_data->>'principle')) returning id into rid;
 elsif p_action='METHOD_VERIFY' then
  perform 1 from public.lab_methods where id=(p_data->>'method_id')::uuid and branch_id=p_branch;if not found then raise exception 'Método no autorizado';end if;
  insert into public.method_verifications(verification_code,method_id,verification_type,start_date,completion_date,parameters_evaluated,acceptance_criteria,result_summary,conclusion,result,responsible_user_id,evidence_reference,status) values(trim(p_data->>'code'),(p_data->>'method_id')::uuid,'VERIFICACION',today,today,trim(p_data->>'parameters'),trim(p_data->>'criteria'),trim(p_data->>'summary'),trim(p_data->>'conclusion'),p_data->>'result',actor,trim(p_data->>'evidence'),'REVISION') returning id into rid;
 elsif p_action='METHOD_APPROVE' then
  select v.* into rec from public.method_verifications v join public.lab_methods m on m.id=v.method_id where v.id=(p_data->>'id')::uuid and m.branch_id=p_branch for update of v;if not found then raise exception 'Verificación no autorizada';end if;
  if to_jsonb(rec) is distinct from p_data->'before' then raise exception 'Verificación modificada; actualice antes de aprobar';end if;
  if rec.status<>'REVISION' or rec.result<>'ACEPTADO' or rec.responsible_user_id=actor or not public.has_permission('QUALITY_DAILY_REVIEW') then raise exception 'Se requiere verificación aceptada y revisor independiente';end if;
  if nullif(trim(p_data->>'evidence'),'') is null then raise exception 'Referencia de revisión requerida';end if;
  update public.method_verifications set status='CERRADO',reviewer_user_id=actor where id=rec.id;
  update public.lab_methods set status='APROBADO',approved_by=actor,approved_at=now(),notes=concat_ws(E'\n',notes,p_data->>'evidence') where id=rec.method_id returning id into rid;
 elsif p_action='EQA_PROGRAM' then
  insert into public.eqa_programs(program_code,provider,program_name) values(trim(p_data->>'code'),trim(p_data->>'provider'),trim(p_data->>'name')) returning id into rid;
 elsif p_action='IQC_PLAN' then
  perform 1 from public.lab_methods where id=(p_data->>'method_id')::uuid and branch_id=p_branch and status='APROBADO';if not found then raise exception 'Seleccione un método aprobado de la sucursal';end if;
  insert into public.iqc_plans(plan_code,method_id,control_name,control_lot,lower_limit,upper_limit,frequency,effective_date) values(trim(p_data->>'code'),(p_data->>'method_id')::uuid,trim(p_data->>'control_name'),trim(p_data->>'control_lot'),(p_data->>'lower_limit')::numeric,(p_data->>'upper_limit')::numeric,p_data->>'frequency',today) returning id into rid;
 elsif p_action='IQC_RESULT' then
  perform 1 from public.iqc_plans p join public.lab_methods m on m.id=p.method_id where p.id=(p_data->>'plan_id')::uuid and p.active and m.branch_id=p_branch and m.status='APROBADO';if not found then raise exception 'Plan activo y método aprobado requeridos';end if;
  insert into public.iqc_results(plan_id,value,operator_user_id,comment) values((p_data->>'plan_id')::uuid,(p_data->>'value')::numeric,actor,p_data->>'evidence') returning id into rid;
 elsif p_action='EQA_EVENT' then
  perform 1 from public.eqa_programs where id=(p_data->>'program_id')::uuid and active;if not found then raise exception 'Programa EQA activo requerido';end if;
  insert into public.eqa_events(event_code,program_id,branch_id,cycle,due_date,status) values(trim(p_data->>'code'),(p_data->>'program_id')::uuid,p_branch,p_data->>'cycle',(p_data->>'due_date')::date,'PENDIENTE') returning id into rid;
 elsif p_action='EQA_RESULT' then
  select * into rec from public.eqa_events where id=(p_data->>'id')::uuid and branch_id=p_branch for update;if not found then raise exception 'Evento no autorizado';end if;
  if to_jsonb(rec) is distinct from p_data->'before' then raise exception 'Registro modificado; actualice antes de guardar';end if;
  if coalesce(p_data->>'result','') not in ('SATISFACTORIO','NO_SATISFACTORIO','NO_EVALUABLE') or nullif(trim(p_data->>'evidence'),'') is null then raise exception 'Resultado y referencia de informe requeridos';end if;
  update public.eqa_events set result=p_data->>'result',provider_result_date=today,evidence_reference=trim(p_data->>'evidence'),investigation_required=(p_data->>'result')='NO_SATISFACTORIO',status='EVALUADO' where id=rec.id returning id into rid;
 elsif p_action='SERVICE' then
  select * into rec from public.lab_equipment where id=(p_data->>'equipment_id')::uuid and branch_id=p_branch for update;if not found then raise exception 'Equipo no autorizado';end if;
  if nullif(trim(p_data->>'performed_date'),'') is null or nullif(trim(p_data->>'next_due_date'),'') is null or nullif(trim(p_data->>'evidence'),'') is null or (p_data->>'performed_date')::date>today or (p_data->>'next_due_date')::date<=(p_data->>'performed_date')::date then raise exception 'Revise certificado y fechas del servicio';end if;
  insert into public.equipment_service_events(service_code,equipment_id,event_type,performed_date,provider,responsible,result,certificate_reference,findings,next_due_date,status) values(trim(p_data->>'code'),rec.id,p_data->>'event_type',(p_data->>'performed_date')::date,p_data->>'provider',actor::text,p_data->>'result',p_data->>'evidence',p_data->>'findings',(p_data->>'next_due_date')::date,'COMPLETADO') returning id into rid;
  -- Recording service never returns an instrument to service automatically.
  if p_data->>'result'='CONFORME' then
   update public.lab_equipment set next_calibration_date=case when p_data->>'event_type'='CALIBRACION' then (p_data->>'next_due_date')::date else next_calibration_date end,next_maintenance_date=case when p_data->>'event_type' in ('MANTENIMIENTO_PREVENTIVO','MANTENIMIENTO_CORRECTIVO') then (p_data->>'next_due_date')::date else next_maintenance_date end where id=rec.id;
  else update public.lab_equipment set status='FUERA_SERVICIO' where id=rec.id;end if;
 elsif p_action='REAGENT' then
  insert into public.reagent_lots(reagent_code,reagent_name,branch_id,lot_number,expiry_date,received_date,quantity_received,quantity_available,unit,verification_status,certificate_reference) values(trim(p_data->>'code'),trim(p_data->>'name'),p_branch,trim(p_data->>'lot'),(p_data->>'expiry_date')::date,today,(p_data->>'quantity')::numeric,(p_data->>'quantity')::numeric,p_data->>'unit','PENDIENTE',p_data->>'evidence') returning id into rid;
 elsif p_action='REAGENT_REVIEW' then
  select * into rec from public.reagent_lots where id=(p_data->>'id')::uuid and branch_id=p_branch for update;if not found then raise exception 'Lote no autorizado';end if;
  if to_jsonb(rec) is distinct from p_data->'before' then raise exception 'Registro modificado; actualice antes de guardar';end if;
  if not public.has_permission('QUALITY_DAILY_REVIEW') or rec.entered_by is null or rec.entered_by=actor or nullif(trim(p_data->>'evidence'),'') is null then raise exception 'Revisión independiente y evidencia requeridas';end if;
  if p_data->>'decision' not in ('APROBADO','RECHAZADO','CUARENTENA') then raise exception 'Decisión de lote inválida';end if;
  if p_data->>'decision'='APROBADO' and rec.expiry_date<today then raise exception 'No se aprueba un reactivo vencido';end if;
  update public.reagent_lots set verification_status=p_data->>'decision',verified_by=actor,verified_at=now(),certificate_reference=p_data->>'evidence' where id=rec.id returning id into rid;
 elsif p_action='DEVICE' then
  insert into public.cold_chain_devices(device_code,branch_id,device_type,location,min_temp,max_temp) values(trim(p_data->>'code'),p_branch,p_data->>'type',p_data->>'location',(p_data->>'min_temp')::numeric,(p_data->>'max_temp')::numeric) returning id into rid;
 elsif p_action='TEMPERATURE' then
  perform 1 from public.cold_chain_devices where id=(p_data->>'device_id')::uuid and branch_id=p_branch and active;if not found then raise exception 'Dispositivo activo de la sucursal requerido';end if;
  insert into public.cold_chain_readings(device_id,temperature,source,recorded_by,observation) values((p_data->>'device_id')::uuid,(p_data->>'value')::numeric,'MANUAL',actor,p_data->>'evidence') returning id into rid;
 elsif p_action='TRANSPORT' then
  if (p_data->>'min_temp')::numeric>=(p_data->>'max_temp')::numeric then raise exception 'Rango térmico inválido';end if;
  insert into public.transport_events(transport_code,branch_id,origin,destination,departure_at,container_reference,responsible,min_temp,max_temp,status,notes) values(trim(p_data->>'code'),p_branch,p_data->>'origin',p_data->>'destination',now(),p_data->>'container',actor::text,(p_data->>'min_temp')::numeric,(p_data->>'max_temp')::numeric,'EN_TRANSITO',p_data->>'evidence') returning id into rid;
 elsif p_action='TRANSPORT_RECEIVE' then
  select * into rec from public.transport_events where id=(p_data->>'id')::uuid and branch_id=p_branch for update;if not found or rec.status<>'EN_TRANSITO' then raise exception 'Transporte en tránsito requerido';end if;
  if nullif(trim(p_data->>'evidence'),'') is null or p_data->>'condition' not in ('CONFORME','NO_CONFORME') then raise exception 'Condición y evidencia de recepción requeridas';end if;
  insert into public.transport_temperature_readings(transport_id,temperature,source) values(rec.id,(p_data->>'value')::numeric,'MANUAL');
  update public.transport_events set arrival_at=now(),status=case when p_data->>'condition'='CONFORME' and (p_data->>'value')::numeric between rec.min_temp and rec.max_temp then 'RECIBIDO' else 'CUARENTENA' end,notes=concat_ws(E'\n',notes,p_data->>'evidence') where id=rec.id returning id into rid;
 elsif p_action='SCREENING_REVIEW' then
  select * into rec from public.screening_tests where id=(p_data->>'id')::uuid and branch_id=p_branch for update;if not found then raise exception 'Tamizaje no autorizado';end if;
  if to_jsonb(rec) is distinct from p_data->'before' then raise exception 'Registro modificado; actualice antes de guardar';end if;
  if not public.has_permission('QUALITY_DAILY_REVIEW') or rec.entered_by is null or rec.entered_by=actor or nullif(trim(p_data->>'evidence'),'') is null then raise exception 'Validación independiente y evidencia requeridas';end if;
  if p_data->>'decision' not in ('VALIDADO','REPETIR') then raise exception 'Decisión inválida';end if;
  update public.screening_tests set status=p_data->>'decision',observations=concat_ws(E'\n',observations,'Revisión: '||(p_data->>'evidence')) where id=rec.id returning id into rid;
 else raise exception 'Acción no reconocida';end if;
 return jsonb_build_object('id',rid);
end$$;
revoke all on function public.lab_operation(uuid,text,jsonb) from public,anon;grant execute on function public.lab_operation(uuid,text,jsonb) to authenticated;
create or replace function public.review_and_release_unit(
  p_source_unit_code text,
  p_decision text,
  p_rationale text,
  p_evidence_reference text default null
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_branch uuid;
  v_profile uuid;
  v_review_id uuid;
begin
  if p_decision not in ('APTO','NO_APTO','RETENER') then
    raise exception 'Decisión inválida';
  end if;

  if trim(coalesce(p_rationale,''))='' then
    raise exception 'La justificación es obligatoria';
  end if;

  select branch_id into v_branch
  from public.donations
  where source_unit_code=p_source_unit_code
  limit 1;

  if v_branch is null then
    raise exception 'Unidad origen no encontrada';
  end if;

  if not public.can_access_branch(v_branch) then
    raise exception 'Sin acceso a la sucursal';
  end if;

  if auth.uid() is null or not public.wf_active_actor() or not public.has_permission('UNIT_RELEASE') then raise exception 'Sin autorización técnica de liberación' using errcode='42501';end if;
  perform 1 from public.donations where source_unit_code=p_source_unit_code for update;
  if nullif(trim(p_evidence_reference),'') is null then raise exception 'Referencia de evidencia requerida para la decisión';end if;
  if p_decision='APTO' then
   if exists(select 1 from public.blood_inventory_units where source_unit_code=p_source_unit_code and (expiry_date is null or expiry_date<(now() at time zone 'America/Santo_Domingo')::date)) then raise exception 'Compruebe el vencimiento de todos los componentes';end if;
   if not exists(select 1 from public.screening_tests where source_unit_code=p_source_unit_code and branch_id=v_branch) or exists(select 1 from public.screening_tests where source_unit_code=p_source_unit_code and branch_id=v_branch and (status<>'VALIDADO' or result<>'NO_REACTIVO')) then raise exception 'Hay pruebas pendientes, reactivas o indeterminadas; no se permite APTO';end if;
   if exists(select 1 from public.screening_tests where source_unit_code=p_source_unit_code and entered_by=auth.uid()) then raise exception 'La liberación requiere independencia del ejecutor de tamizaje';end if;
  end if;

  v_profile := auth.uid();

  insert into public.unit_release_reviews(
    source_unit_code,branch_id,reviewed_by,decision,rationale,evidence_reference
  )
  values(
    p_source_unit_code,v_branch,v_profile,p_decision,p_rationale,p_evidence_reference
  )
  returning id into v_review_id;

  update public.donations
  set status = case
      when p_decision='APTO' then 'APTA'
      when p_decision='NO_APTO' then 'NO_APTA'
      else status
    end
  where source_unit_code=p_source_unit_code;

  update public.blood_inventory_units
  set
    screening_status = case
      when p_decision='APTO' then 'APTO'
      when p_decision='NO_APTO' then 'NO_APTO'
      else screening_status
    end,
    inventory_status = case
      when p_decision='APTO' and inventory_status='CUARENTENA' then 'DISPONIBLE'
      when p_decision='NO_APTO' then 'DESCARTADA'
      when p_decision='RETENER' and inventory_status='DISPONIBLE' then 'CUARENTENA'
      else inventory_status
    end
  where source_unit_code=p_source_unit_code;

  return v_review_id;
end;
$$;

grant execute on function public.review_and_release_unit(text,text,text,text) to authenticated;

revoke all on function public.review_and_release_unit(text,text,text,text) from public,anon;grant execute on function public.review_and_release_unit(text,text,text,text) to authenticated;
drop policy unit_release_reviews_write on public.unit_release_reviews;
create policy unit_release_reviews_write on public.unit_release_reviews for insert to authenticated with check(public.lab_scope(branch_id,'UNIT_RELEASE',true) and reviewed_by=auth.uid());
create function private.lab_release_guard() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
begin
 if not public.lab_scope(new.branch_id,'UNIT_RELEASE',true) or new.reviewed_by<>auth.uid() or nullif(trim(new.evidence_reference),'') is null or nullif(trim(new.rationale),'') is null then raise exception 'Revisión técnica y evidencia requeridas';end if;
 perform 1 from public.donations where source_unit_code=new.source_unit_code and branch_id=new.branch_id for update;if not found then raise exception 'Unidad no autorizada';end if;
 if new.decision='APTO' and (not exists(select 1 from public.screening_tests where source_unit_code=new.source_unit_code and branch_id=new.branch_id) or exists(select 1 from public.screening_tests where source_unit_code=new.source_unit_code and branch_id=new.branch_id and (status<>'VALIDADO' or result<>'NO_REACTIVO' or entered_by=auth.uid()))) then raise exception 'Pruebas no aptas o ejecutor no independiente';end if;
 return new;
end$$;
revoke all on function private.lab_release_guard() from public,anon,authenticated;
create trigger lab_release_guard before insert on public.unit_release_reviews for each row execute function private.lab_release_guard();
create trigger lab_audit after insert on public.unit_release_reviews for each row execute function private.lab_record_audit();
create function private.lab_unit_guard() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
begin
 if new.screening_status='APTO' and (tg_op='INSERT' or old.screening_status is distinct from new.screening_status or old.inventory_status='CUARENTENA' and new.inventory_status='DISPONIBLE') then
  if not public.lab_scope(new.branch_id,'BLOOD_INVENTORY_WRITE',true) or new.expiry_date is null or new.expiry_date<(now() at time zone 'America/Santo_Domingo')::date then raise exception 'Unidad sin vigencia o permiso';end if;
  if (select decision from public.unit_release_reviews where source_unit_code=new.source_unit_code and branch_id=new.branch_id order by review_date desc,id desc limit 1) is distinct from 'APTO' or exists(select 1 from public.screening_tests where source_unit_code=new.source_unit_code and branch_id=new.branch_id and (status<>'VALIDADO' or result<>'NO_REACTIVO')) then raise exception 'Se requiere decisión técnica vigente y pruebas validadas';end if;
 end if;
 return new;
end$$;
revoke all on function private.lab_unit_guard() from public,anon,authenticated;
create trigger lab_unit_guard before insert or update on public.blood_inventory_units for each row execute function private.lab_unit_guard();
create function private.lab_screening_hold() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
begin
 if new.status<>'VALIDADO' or new.result<>'NO_REACTIVO' then
  update public.blood_inventory_units set inventory_status='CUARENTENA',screening_status='INDETERMINADO' where branch_id=new.branch_id and source_unit_code=new.source_unit_code and inventory_status in ('DISPONIBLE','RESERVADA');
 end if;return new;
end$$;
revoke all on function private.lab_screening_hold() from public,anon,authenticated;
create trigger lab_screening_hold after insert or update on public.screening_tests for each row execute function private.lab_screening_hold();
create trigger lab_audit after insert or update on public.blood_inventory_units for each row execute function private.lab_record_audit();
commit;
