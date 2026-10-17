begin;
set local lock_timeout='5s';
alter table public.capa add column original_due_date date,add column original_due_known boolean not null default false,add column revision integer not null default 1,add column executed_by uuid references public.profiles(id),add column verified_by uuid references public.profiles(id);
alter table public.nonconformities add column revision integer not null default 1,add column closure_evidence text,add column closed_at timestamptz,add column closed_by uuid references public.profiles(id);
alter table public.risk_register add column revision integer not null default 1;
alter table public.document_changes add column revision integer not null default 1;
-- Historical dates are intentionally NOT inferred or backfilled.
alter table public.management_reviews add column branch_id uuid references public.branches(id),add column revision integer not null default 1;
alter table public.management_review_actions add column original_due_date date,add column original_due_known boolean not null default false,add column closed_at timestamptz,add column revision integer not null default 1,add column replan_reason text;
create index qms_nc_branch_idx on public.nonconformities(branch_id,id);
create index qms_capa_nc_idx on public.capa(nonconformity_id,id);
create index qms_review_branch_idx on public.management_reviews(branch_id,review_date,id);
create index qms_review_actions_idx on public.management_review_actions(review_id,due_date,id);
-- Replace permissive legacy role policies. No roles or permission mappings are granted.
do $$declare t text;p record;begin
 foreach t in array array['nonconformities','capa','risk_register','management_reviews','management_review_actions','quality_objectives','document_changes'] loop
  for p in select policyname from pg_policies where schemaname='public' and tablename=t loop execute format('drop policy %I on public.%I',p.policyname,t);end loop;
 end loop;
end$$;
create policy qms_nc_read on public.nonconformities for select to authenticated using((select public.wf_active_actor()) and (select public.has_permission('QUALITY_VIEW')) and (branch_id is null or public.can_access_branch(branch_id)));
create policy qms_nc_write on public.nonconformities for all to authenticated using((select public.wf_active_actor()) and (select public.has_permission('QUALITY_WRITE')) and (branch_id is null or public.can_access_branch(branch_id))) with check((select public.wf_active_actor()) and (select public.has_permission('QUALITY_WRITE')) and (branch_id is null or public.can_access_branch(branch_id)));
create policy qms_capa_read on public.capa for select to authenticated using((select public.wf_active_actor()) and (select public.has_permission('QUALITY_VIEW')) and (nonconformity_id is null or exists(select 1 from public.nonconformities n where n.id=nonconformity_id)));
create policy qms_capa_write on public.capa for all to authenticated using((select public.wf_active_actor()) and (select public.has_permission('QUALITY_WRITE')) and (nonconformity_id is null or exists(select 1 from public.nonconformities n where n.id=nonconformity_id))) with check((select public.wf_active_actor()) and (select public.has_permission('QUALITY_WRITE')) and (nonconformity_id is null or exists(select 1 from public.nonconformities n where n.id=nonconformity_id)));
create policy qms_risk_read on public.risk_register for select to authenticated using((select public.wf_active_actor()) and (select public.has_permission('QUALITY_VIEW')) and (branch_id is null or public.can_access_branch(branch_id)));
create policy qms_risk_write on public.risk_register for all to authenticated using((select public.wf_active_actor()) and (select public.has_permission('QUALITY_WRITE')) and (branch_id is null or public.can_access_branch(branch_id))) with check((select public.wf_active_actor()) and (select public.has_permission('QUALITY_WRITE')) and (branch_id is null or public.can_access_branch(branch_id)));
create policy qms_review_read on public.management_reviews for select to authenticated using((select public.wf_active_actor()) and (select public.has_permission('MANAGEMENT_REVIEW_VIEW')) and (branch_id is null or public.can_access_branch(branch_id)));
create policy qms_review_write on public.management_reviews for all to authenticated using((select public.wf_active_actor()) and (select public.has_permission('MANAGEMENT_REVIEW_WRITE')) and (branch_id is null or public.can_access_branch(branch_id))) with check((select public.wf_active_actor()) and (select public.has_permission('MANAGEMENT_REVIEW_WRITE')) and (branch_id is null or public.can_access_branch(branch_id)));
create policy qms_commitment_read on public.management_review_actions for select to authenticated using((select public.wf_active_actor()) and (select public.has_permission('MANAGEMENT_REVIEW_VIEW')) and exists(select 1 from public.management_reviews r where r.id=review_id));
create policy qms_commitment_write on public.management_review_actions for all to authenticated using((select public.wf_active_actor()) and (select public.has_permission('MANAGEMENT_REVIEW_WRITE')) and exists(select 1 from public.management_reviews r where r.id=review_id)) with check((select public.wf_active_actor()) and (select public.has_permission('MANAGEMENT_REVIEW_WRITE')) and exists(select 1 from public.management_reviews r where r.id=review_id));
create policy qms_objective_read on public.quality_objectives for select to authenticated using((select public.wf_active_actor()) and (select public.has_permission('MANAGEMENT_REVIEW_VIEW')));
create policy qms_objective_write on public.quality_objectives for all to authenticated using((select public.wf_active_actor()) and (select public.has_permission('MANAGEMENT_REVIEW_WRITE'))) with check((select public.wf_active_actor()) and (select public.has_permission('MANAGEMENT_REVIEW_WRITE')));
create policy qms_changes_read on public.document_changes for select to authenticated using((select public.wf_active_actor()) and ((select public.has_permission('DOCUMENTS_VIEW')) or (select public.has_permission('QUALITY_VIEW'))));
create policy qms_changes_write on public.document_changes for all to authenticated using((select public.wf_active_actor()) and (select public.has_permission('DOCUMENTS_WRITE'))) with check((select public.wf_active_actor()) and (select public.has_permission('DOCUMENTS_WRITE')));
create policy qms_incident_scope on public.incidents as restrictive for all to authenticated using((select public.wf_active_actor()) and (branch_id is null or public.can_access_branch(branch_id))) with check((select public.wf_active_actor()) and (branch_id is null or public.can_access_branch(branch_id)));
create policy qms_measurement_scope on public.quality_measurements as restrictive for all to authenticated using((select public.wf_active_actor()) and (branch_id is null or public.can_access_branch(branch_id))) with check((select public.wf_active_actor()) and (branch_id is null or public.can_access_branch(branch_id)));
create or replace view public.vw_quality_today with(security_invoker=true) as select qm.measurement_date,qm.branch_id,qi.code indicator_code,qi.name indicator_name,qm.value,qm.status,qp.code process_code,qp.name process_name,qm.id from public.quality_measurements qm join public.quality_indicators qi on qi.id=qm.indicator_id join public.quality_processes qp on qp.id=qi.process_id;
-- Invoker views retain the caller's scope instead of reporting other branches.
alter view public.vw_audit_findings_open set (security_invoker=true);
alter view public.vw_staff_competency_gaps set (security_invoker=true);
alter view public.vw_open_management_alerts set (security_invoker=true);
alter view public.vw_quality_today set (security_invoker=true);
alter view public.vw_capa_control_status set (security_invoker=true);
alter view public.vw_document_control_status set (security_invoker=true);
alter view public.vw_qms_governance_summary set (security_invoker=true);
alter view public.vw_management_review_inputs set (security_invoker=true);
create table public.qms_change_history(id uuid primary key default gen_random_uuid(),source_table text not null,record_id uuid not null,branch_id uuid references public.branches(id),actor_id uuid not null references public.profiles(id),changed_at timestamptz not null default now(),before_data jsonb,after_data jsonb not null);
create index qms_history_record_idx on public.qms_change_history(source_table,record_id,changed_at,id);
alter table public.qms_change_history enable row level security;
revoke all on public.qms_change_history from public,anon,authenticated;
grant select on public.qms_change_history to authenticated;
create policy qms_history_read on public.qms_change_history for select to authenticated using((select public.wf_active_actor()) and (branch_id is null or public.can_access_branch(branch_id)) and (case when source_table in ('management_reviews','management_review_actions') then public.has_permission('MANAGEMENT_REVIEW_VIEW') when source_table='document_changes' then public.has_permission('DOCUMENTS_VIEW') else public.has_permission('QUALITY_VIEW') end));
create function private.qms_audit() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare j jsonb:=to_jsonb(new);b uuid;begin
 b:=nullif(j->>'branch_id','')::uuid;
 if tg_table_name='capa' then select branch_id into b from public.nonconformities where id=new.nonconformity_id;end if;
 if tg_table_name='management_review_actions' then select branch_id into b from public.management_reviews where id=new.review_id;end if;
 insert into public.qms_change_history(source_table,record_id,branch_id,actor_id,before_data,after_data) values(tg_table_name,new.id,b,auth.uid(),case when tg_op='UPDATE' then to_jsonb(old) end,j);return new;
end$$;
revoke all on function private.qms_audit() from public,anon,authenticated;
create function private.qms_guard() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
declare parent_state text;begin
 if tg_table_name='nonconformities' then
  new.revision:=case when tg_op='INSERT' then 1 else old.revision+1 end;
  if tg_op='UPDATE' and old.status='CERRADA' then raise exception 'La no conformidad cerrada conserva su expediente';end if;
  if new.status='CERRADA' then
   if tg_op='INSERT' or new.owner_user_id is null or auth.uid()=new.owner_user_id or nullif(trim(new.closure_evidence),'') is null or nullif(trim(new.root_cause),'') is null or exists(select 1 from public.capa c where c.nonconformity_id=new.id and c.status not in ('CERRADA','CANCELADA')) then raise exception 'Cierre NC: responsable, causa, evidencia, revisor independiente y CAPA resueltas requeridos';end if;
   new.closed_at:=now();new.closed_by:=auth.uid();
  elsif tg_op='UPDATE' and (new.closed_at is distinct from old.closed_at or new.closed_by is distinct from old.closed_by) then raise exception 'No puede alterar la identidad de cierre';end if;
 elsif tg_table_name='risk_register' then
  new.revision:=case when tg_op='INSERT' then 1 else old.revision+1 end;
  if new.status in ('ACEPTADO','CERRADO') and (not public.has_permission('MANAGEMENT_REVIEW_WRITE') or new.residual_probability is null or new.residual_impact is null or nullif(trim(new.evidence_url),'') is null) then raise exception 'Aceptar o cerrar riesgos requiere gestión, evaluación residual y evidencia';end if;
 elsif tg_table_name='document_changes' then
  new.revision:=case when tg_op='INSERT' then 1 else old.revision+1 end;
  if tg_op='UPDATE' and old.status<>'PENDIENTE' and new.impact_assessment is distinct from old.impact_assessment then raise exception 'El impacto aprobado conserva su versión';end if;
 elsif tg_table_name='capa' then
  if tg_op='INSERT' then new.original_due_date:=new.due_date;new.original_due_known:=true;new.revision:=1;new.executed_by:=null;new.verified_by:=null;
   if new.effectiveness_status<>'PENDIENTE' or new.effectiveness_verified_at is not null or new.closed_at is not null or new.status<>'ABIERTA' then raise exception 'Una CAPA nueva comienza abierta y pendiente de eficacia';end if;
  else
   if new.original_due_date is distinct from old.original_due_date or new.original_due_known is distinct from old.original_due_known then raise exception 'El plazo original no puede modificarse';end if;
   if old.status in ('CERRADA','CANCELADA') then raise exception 'La CAPA cerrada conserva su expediente';end if;
   if new.nonconformity_id is distinct from old.nonconformity_id then raise exception 'El origen de la CAPA es inmutable';end if;
   new.revision:=old.revision+1;
   if new.status='CERRADA' then
    if new.approval_request_id is null or not exists(select 1 from public.approval_requests ar where ar.id=new.approval_request_id and ar.status='APROBADA' and ar.action_type='CAPA_CLOSE' and ar.entity_id=new.id and ar.requested_at>=new.effectiveness_verified_at and ar.requested_by<>auth.uid()) or new.effectiveness_status not in ('EFECTIVA','VERIFICADA') or new.effectiveness_verified_at is null then raise exception 'El cierre CAPA requiere eficacia y aprobación independiente vigente';end if;
    new.closed_at:=now();new.closed_by:=auth.uid();
   elsif new.closed_at is distinct from old.closed_at or new.closed_by is distinct from old.closed_by then raise exception 'No puede alterar los datos de cierre';end if;
   if new.evidence_url is distinct from old.evidence_url or new.action_plan is distinct from old.action_plan or new.root_cause is distinct from old.root_cause or new.owner_user_id is distinct from old.owner_user_id then
    new.executed_by:=auth.uid();new.verified_by:=null;new.effectiveness_status:='PENDIENTE';new.effectiveness_verified_at:=null;new.effectiveness_notes:=null;new.approval_request_id:=null;
   elsif new.effectiveness_status is distinct from old.effectiveness_status or new.effectiveness_verified_at is distinct from old.effectiveness_verified_at or new.verified_by is distinct from old.verified_by or new.effectiveness_notes is distinct from old.effectiveness_notes then
    if auth.uid()=old.owner_user_id or auth.uid()=old.executed_by or nullif(trim(new.evidence_url),'') is null or nullif(trim(new.effectiveness_notes),'') is null or nullif(trim(new.root_cause),'') is null then raise exception 'La eficacia exige evidencia, causa, observación y revisor independiente';end if;
    if new.effectiveness_status not in ('EFECTIVA','NO_EFECTIVA','VERIFICADA') then raise exception 'Resultado de eficacia inválido';end if;
    new.verified_by:=auth.uid();new.effectiveness_verified_at:=now();new.approval_request_id:=null;
   elsif new.executed_by is distinct from old.executed_by then raise exception 'No puede alterar la identidad de ejecución';end if;
   if new.status='CERRADA' and (new.effectiveness_verified_at is null or new.effectiveness_status not in ('EFECTIVA','VERIFICADA') or new.approval_request_id is null) then raise exception 'El contenido cambió: vuelva a verificar y solicitar aprobación';end if;
  end if;
 elsif tg_table_name='management_reviews' then
  if tg_op='INSERT' then new.chair_user_id:=auth.uid();new.revision:=1;if new.status<>'BORRADOR' then raise exception 'La revisión inicia como borrador';end if;
  else
   if old.status='CERRADA' then raise exception 'La revisión cerrada es inmutable';end if;
   if new.chair_user_id is distinct from old.chair_user_id or new.branch_id is distinct from old.branch_id then raise exception 'Origen y autor de revisión inmutables';end if;
   if new.status='APROBADA' and old.status='BORRADOR' and (auth.uid()=old.chair_user_id or nullif(trim(new.decisions),'') is null) then raise exception 'La revisión requiere decisión y aprobación independiente';end if;
   if old.status='APROBADA' and (new.summary is distinct from old.summary or new.decisions is distinct from old.decisions or new.period_start is distinct from old.period_start or new.period_end is distinct from old.period_end or new.review_code is distinct from old.review_code or new.review_date is distinct from old.review_date or new.participants is distinct from old.participants) then raise exception 'La revisión aprobada conserva su contenido';end if;
   if new.status='CERRADA' and (old.status<>'APROBADA' or exists(select 1 from public.management_review_actions where review_id=new.id and status not in ('CERRADA','CANCELADA'))) then raise exception 'Para cerrar, apruebe y complete los compromisos';end if;
   if new.status not in (old.status,'APROBADA','CERRADA') then raise exception 'Transición de revisión inválida';end if;
   new.revision:=old.revision+1;
  end if;
  if new.period_start>new.period_end then raise exception 'Período inválido';end if;
 elsif tg_table_name='management_review_actions' then
  select status into parent_state from public.management_reviews where id=new.review_id for update;
  if parent_state='CERRADA' then raise exception 'La revisión cerrada no admite cambios';end if;
  if tg_op='INSERT' then if parent_state<>'BORRADOR' then raise exception 'Agregue compromisos antes de aprobar la revisión';end if;update public.management_reviews set revision=revision+1 where id=new.review_id;new.original_due_date:=new.due_date;new.original_due_known:=true;new.revision:=1;new.closed_at:=null;if new.status<>'ABIERTA' then raise exception 'El compromiso inicia abierto';end if;
  else
   if old.status in ('CERRADA','CANCELADA') then raise exception 'El compromiso cerrado es inmutable';end if;
   if parent_state='APROBADA' and (new.description is distinct from old.description or new.owner_user_id is distinct from old.owner_user_id or new.action_code is distinct from old.action_code) then raise exception 'El compromiso aprobado conserva descripción y responsable';end if;
   if new.review_id<>old.review_id or new.original_due_date is distinct from old.original_due_date or new.original_due_known is distinct from old.original_due_known then raise exception 'El origen y plazo original son inmutables';end if;
   if new.due_date is distinct from old.due_date and (nullif(trim(new.replan_reason),'') is null or new.replan_reason is not distinct from old.replan_reason) then raise exception 'Explique la reprogramación';end if;
   if new.status in ('CERRADA','CANCELADA') and nullif(trim(new.evidence_reference),'') is null then raise exception 'El cierre o cancelación requiere evidencia o justificación';end if;
   new.closed_at:=case when new.status='CERRADA' then now() end;new.revision:=old.revision+1;
  end if;
 end if;
 return new;
end$$;
revoke all on function private.qms_guard() from public,anon,authenticated;
create trigger qms_guard before insert or update on public.nonconformities for each row execute function private.qms_guard();
create trigger qms_guard before insert or update on public.risk_register for each row execute function private.qms_guard();
create trigger qms_guard before insert or update on public.document_changes for each row execute function private.qms_guard();
create trigger qms_guard before insert or update on public.capa for each row execute function private.qms_guard();
create trigger qms_guard before insert or update on public.management_reviews for each row execute function private.qms_guard();
create trigger qms_guard before insert or update on public.management_review_actions for each row execute function private.qms_guard();
do $$declare t text;begin foreach t in array array['nonconformities','capa','risk_register','management_reviews','management_review_actions','document_changes'] loop execute format('create trigger qms_audit after insert or update on public.%I for each row execute function private.qms_audit()',t);end loop;end$$;
create function public.qms_management_action(p_action text,p_data jsonb) returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare r public.management_reviews%rowtype;a public.management_review_actions%rowtype;i jsonb;v uuid;b uuid;begin
 if auth.uid() is null or not public.wf_active_actor() or not public.has_permission('MANAGEMENT_REVIEW_WRITE') then raise exception 'Gestión de revisiones no autorizada' using errcode='42501';end if;
 if p_action='CREATE_REVIEW' then
  b:=(p_data->>'branch_id')::uuid;
  if b is null or not public.can_access_branch(b) then raise exception 'Sucursal requerida y autorizada';end if;
  if nullif(trim(p_data->>'decisions'),'') is null or nullif(trim(p_data->>'summary'),'') is null then raise exception 'Resumen y decisiones requeridos';end if;
  if jsonb_typeof(p_data->'actions') is distinct from 'array' or jsonb_array_length(p_data->'actions') not between 1 and 20 then raise exception 'Registre entre 1 y 20 compromisos';end if;
  insert into public.management_reviews(review_code,review_date,period_start,period_end,branch_id,participants,summary,decisions) values(trim(p_data->>'review_code'),(p_data->>'review_date')::date,(p_data->>'period_start')::date,(p_data->>'period_end')::date,b,p_data->>'participants',trim(p_data->>'summary'),trim(p_data->>'decisions')) returning * into r;
  for i in select * from jsonb_array_elements(p_data->'actions') loop
   if nullif(trim(i->>'description'),'') is null or nullif(i->>'due_date','') is null or not exists(select 1 from public.work_agenda_people(b,'CALIDAD') p where p.id=(i->>'owner_user_id')::uuid) then raise exception 'Compromiso: responsable elegible, descripción y fecha requeridos';end if;
   insert into public.management_review_actions(review_id,action_code,description,owner_user_id,due_date) values(r.id,trim(i->>'action_code'),trim(i->>'description'),(i->>'owner_user_id')::uuid,(i->>'due_date')::date);
  end loop;return jsonb_build_object('id',r.id);
 elsif p_action='ADD_COMMITMENT' then
  select * into r from public.management_reviews where id=(p_data->>'review_id')::uuid for update;
  if r.id is null or r.status<>'BORRADOR' or r.branch_id is null then raise exception 'Seleccione una revisión de sucursal en borrador';end if;
  if nullif(trim(p_data->>'description'),'') is null or nullif(p_data->>'due_date','') is null or not exists(select 1 from public.work_agenda_people(r.branch_id,'CALIDAD') p where p.id=(p_data->>'owner_user_id')::uuid) then raise exception 'Responsable, descripción y fecha requeridos';end if;
  insert into public.management_review_actions(review_id,action_code,description,owner_user_id,due_date) values(r.id,trim(p_data->>'action_code'),trim(p_data->>'description'),(p_data->>'owner_user_id')::uuid,(p_data->>'due_date')::date) returning id into v;return jsonb_build_object('id',v);
 elsif p_action in ('APPROVE_REVIEW','CLOSE_REVIEW') then
  select * into r from public.management_reviews where id=(p_data->>'id')::uuid for update;
  if r.id is null or r.revision<>(p_data->>'revision')::int or p_data->>'revision' is null then raise exception 'Revisión cambió; actualice antes de guardar';end if;
  if p_action='APPROVE_REVIEW' and r.status<>'BORRADOR' then raise exception 'Solo se aprueban borradores';end if;
  update public.management_reviews set status=case when p_action='APPROVE_REVIEW' then 'APROBADA' else 'CERRADA' end where id=r.id;
  return jsonb_build_object('id',r.id);
 elsif p_action='SAVE_COMMITMENT' then
  select * into a from public.management_review_actions where id=(p_data->>'id')::uuid for update;
  if a.id is null or a.revision<>(p_data->>'revision')::int or p_data->>'revision' is null then raise exception 'Compromiso cambió; actualice antes de guardar';end if;
  update public.management_review_actions set status=p_data->>'status',due_date=(p_data->>'due_date')::date,evidence_reference=nullif(trim(p_data->>'evidence_reference'),''),replan_reason=nullif(trim(p_data->>'replan_reason'),'') where id=a.id;
  return jsonb_build_object('id',a.id);
 else raise exception 'Acción gerencial inválida';end if;
end$$;
revoke all on function public.qms_management_action(text,jsonb) from public,anon;
grant execute on function public.qms_management_action(text,jsonb) to authenticated;
create function public.qms_capa_action(p_action text,p_data jsonb) returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare c public.capa%rowtype;begin
 if auth.uid() is null or not public.wf_active_actor() or not public.has_permission('QUALITY_WRITE') then raise exception 'Calidad no autorizada' using errcode='42501';end if;
 select * into c from public.capa where id=(p_data->>'id')::uuid for update;
 if c.id is null or c.revision<>(p_data->>'revision')::int or p_data->>'revision' is null then raise exception 'La CAPA cambió; actualice antes de guardar';end if;
 if p_action='SAVE_EVIDENCE' then
  if nullif(trim(p_data->>'evidence_url'),'') is null or nullif(trim(p_data->>'root_cause'),'') is null then raise exception 'Causa y evidencia requeridas';end if;
  update public.capa set evidence_url=trim(p_data->>'evidence_url'),root_cause=trim(p_data->>'root_cause') where id=c.id;
 elsif p_action='VERIFY' then
  update public.capa set effectiveness_status=p_data->>'effectiveness_status',effectiveness_notes=trim(p_data->>'effectiveness_notes'),effectiveness_verified_at=now() where id=c.id;
 else raise exception 'Acción CAPA inválida';end if;
 return jsonb_build_object('id',c.id);
end$$;
revoke all on function public.qms_capa_action(text,jsonb) from public,anon;
grant execute on function public.qms_capa_action(text,jsonb) to authenticated;
create function public.qms_record_action(p_action text,p_data jsonb) returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare r public.risk_register%rowtype;d public.document_changes%rowtype;n public.nonconformities%rowtype;begin
 if auth.uid() is null or not public.wf_active_actor() then raise exception 'Perfil activo requerido' using errcode='42501';end if;
 if p_action='CLOSE_NC' then
  if not public.has_permission('QUALITY_WRITE') then raise exception 'Permiso de Calidad requerido';end if;
  select * into n from public.nonconformities where id=(p_data->>'id')::uuid for update;
  if n.id is null or n.revision<>(p_data->>'revision')::int or p_data->>'revision' is null then raise exception 'La NC cambió; actualice antes de guardar';end if;
  update public.nonconformities set status='CERRADA',root_cause=trim(p_data->>'root_cause'),closure_evidence=trim(p_data->>'closure_evidence') where id=n.id;return jsonb_build_object('id',n.id);
 elsif p_action='RISK_UPDATE' then
  if not public.has_permission('QUALITY_WRITE') then raise exception 'Permiso de Calidad requerido';end if;
  select * into r from public.risk_register where id=(p_data->>'id')::uuid for update;
  if r.id is null or r.revision<>(p_data->>'revision')::int or p_data->>'revision' is null then raise exception 'El riesgo cambió; actualice antes de guardar';end if;
  update public.risk_register set existing_controls=trim(p_data->>'existing_controls'),treatment_action=trim(p_data->>'treatment_action'),residual_probability=nullif(p_data->>'residual_probability','')::int,residual_impact=nullif(p_data->>'residual_impact','')::int,review_date=(p_data->>'review_date')::date,status=p_data->>'status',evidence_url=nullif(trim(p_data->>'evidence_url'),'') where id=r.id;return jsonb_build_object('id',r.id);
 elsif p_action='CHANGE_IMPACT' then
  if not public.has_permission('DOCUMENTS_WRITE') then raise exception 'Permiso documental requerido';end if;
  select * into d from public.document_changes where id=(p_data->>'id')::uuid for update;
  if d.id is null or d.status<>'PENDIENTE' or d.revision<>(p_data->>'revision')::int or p_data->>'revision' is null then raise exception 'El cambio documental ya cambió o fue aprobado';end if;
  if nullif(trim(p_data->>'impact_assessment'),'') is null then raise exception 'Describa documentos, capacitación, equipos y procesos afectados';end if;
  update public.document_changes set impact_assessment=trim(p_data->>'impact_assessment') where id=d.id;return jsonb_build_object('id',d.id);
 else raise exception 'Acción de registro inválida';end if;
end$$;
revoke all on function public.qms_record_action(text,jsonb) from public,anon;
grant execute on function public.qms_record_action(text,jsonb) to authenticated;
-- Prevent DELETE from erasing the operational/audit chain, even through legacy grants.
revoke delete on public.nonconformities,public.capa,public.risk_register,public.management_reviews,public.management_review_actions from authenticated,anon;
notify pgrst,'reload schema';
commit;
