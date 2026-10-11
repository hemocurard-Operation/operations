-- HemoCura Training Native 1.1 RC
-- Consolidates the production changes applied as training_native_1_1_* migrations.
-- Depends on the Training Release 1.0 foundation migrations immediately above.

insert into public.app_permissions(permission_code,module,description,risk_level,active) values
('TRAINING_SELF','TRAINING','Acceder a la capacitación propia, progreso, evaluaciones y certificados.','NORMAL',true),
('TRAINING_ASSESS','TRAINING','Observar prácticas, evaluar y certificar competencias de otras personas.','SENSIBLE',true),
('TRAINING_ADMIN','TRAINING','Administrar programas, contenido, analítica y vigencias de capacitación.','SENSIBLE',true)
on conflict (permission_code) do update set module=excluded.module,description=excluded.description,risk_level=excluded.risk_level,active=true;

insert into public.role_permissions(role_id,permission_code)
select r.id,'TRAINING_SELF' from public.roles r
where not exists (select 1 from public.role_permissions rp where rp.role_id=r.id and rp.permission_code='TRAINING_SELF');
insert into public.role_permissions(role_id,permission_code)
select r.id,'TRAINING_ASSESS' from public.roles r where r.code in ('CALIDAD','GERENCIA_OPERATIVA')
and not exists (select 1 from public.role_permissions rp where rp.role_id=r.id and rp.permission_code='TRAINING_ASSESS');
insert into public.role_permissions(role_id,permission_code)
select r.id,'TRAINING_ADMIN' from public.roles r where r.code in ('CALIDAD','GERENCIA_OPERATIVA','ADMIN')
and not exists (select 1 from public.role_permissions rp where rp.role_id=r.id and rp.permission_code='TRAINING_ADMIN');

alter table public.training_content_versions add column if not exists controlled_document_id uuid references public.document_register(id);

create table if not exists public.training_programs (
  id uuid primary key default gen_random_uuid(),
  program_code text not null unique,
  training_id uuid not null references public.training_events(id) on delete restrict,
  competency_id uuid not null references public.competency_catalog(id) on delete restrict,
  content_version_id uuid not null references public.training_content_versions(id) on delete restrict,
  title text not null,
  audience_label text not null,
  pass_threshold integer not null check (pass_threshold between 1 and 100),
  critical_process text not null,
  estimated_minutes integer not null default 60 check (estimated_minutes > 0),
  modules jsonb not null default '[]'::jsonb,
  practices jsonb not null default '[]'::jsonb,
  microlearning jsonb not null default '[]'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.training_program_job_roles (
  program_id uuid not null references public.training_programs(id) on delete cascade,
  job_role_id uuid not null references public.job_roles(id) on delete cascade,
  primary key(program_id,job_role_id)
);
create table if not exists public.training_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  program_id uuid not null references public.training_programs(id) on delete restrict,
  job_role_id uuid not null references public.job_roles(id) on delete restrict,
  branch_id uuid references public.branches(id),
  status text not null default 'ASIGNADO' check (status in ('ASIGNADO','EN_CURSO','PRACTICA_PENDIENTE','EVALUACION','REENTRENAMIENTO','COMPETENTE','RECERTIFICACION_DUE','VENCIDO')),
  due_date date,
  started_at timestamptz,
  completed_at timestamptz,
  current_module_code text,
  source text not null default 'AUTO_ROLE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id,program_id,job_role_id)
);
create table if not exists public.training_module_progress (
  assignment_id uuid not null references public.training_assignments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  module_code text not null,
  completed_at timestamptz not null default now(),
  primary key(assignment_id,module_code)
);
create table if not exists public.training_question_bank (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.training_programs(id) on delete cascade,
  question_code text not null,
  prompt text not null,
  options jsonb not null,
  correct_index integer not null check (correct_index >= 0),
  explanation text not null,
  difficulty integer not null default 1 check (difficulty between 1 and 5),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(program_id,question_code),
  check (jsonb_typeof(options)='array' and jsonb_array_length(options)>=2 and correct_index < jsonb_array_length(options))
);
create table if not exists public.training_knowledge_snippets (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.document_register(id) on delete cascade,
  role_scope text[] not null default '{}'::text[],
  keywords text[] not null default '{}'::text[],
  answer text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.training_practical_evidence add column if not exists assignment_id uuid references public.training_assignments(id) on delete cascade;
create unique index if not exists ux_training_practical_assignment_task on public.training_practical_evidence(assignment_id,task_code) where assignment_id is not null;

alter table public.training_programs enable row level security;
alter table public.training_program_job_roles enable row level security;
alter table public.training_assignments enable row level security;
alter table public.training_module_progress enable row level security;
alter table public.training_question_bank enable row level security;
alter table public.training_knowledge_snippets enable row level security;

revoke all on public.training_programs from public,anon,authenticated;
revoke all on public.training_program_job_roles from public,anon,authenticated;
revoke all on public.training_assignments from public,anon,authenticated;
revoke all on public.training_module_progress from public,anon,authenticated;
revoke all on public.training_question_bank from public,anon,authenticated;
revoke all on public.training_knowledge_snippets from public,anon,authenticated;
grant select,insert,update on public.training_assignments to authenticated;
grant select,insert,delete on public.training_module_progress to authenticated;
grant select,insert,update,delete on public.training_programs to authenticated;
grant select,insert,update,delete on public.training_program_job_roles to authenticated;
grant select(id,program_id,question_code,prompt,options,difficulty,active) on public.training_question_bank to authenticated;
grant insert,update,delete on public.training_question_bank to authenticated;
grant select,insert,update,delete on public.training_knowledge_snippets to authenticated;

-- Rebuild policies deterministically for clean deployment/reconciliation.
drop policy if exists training_programs_read on public.training_programs;
drop policy if exists training_programs_admin on public.training_programs;
create policy training_programs_read on public.training_programs for select to authenticated using (
  public.has_permission('TRAINING_ADMIN') or
  (public.has_permission('TRAINING_SELF') and exists(select 1 from public.training_content_versions v where v.id=content_version_id and v.status='APPROVED'))
);
create policy training_programs_admin on public.training_programs for all to authenticated using (public.has_permission('TRAINING_ADMIN')) with check (public.has_permission('TRAINING_ADMIN'));

drop policy if exists training_program_job_roles_read on public.training_program_job_roles;
drop policy if exists training_program_job_roles_admin on public.training_program_job_roles;
create policy training_program_job_roles_read on public.training_program_job_roles for select to authenticated using (public.has_permission('TRAINING_SELF'));
create policy training_program_job_roles_admin on public.training_program_job_roles for all to authenticated using (public.has_permission('TRAINING_ADMIN')) with check (public.has_permission('TRAINING_ADMIN'));

drop policy if exists training_assignments_read on public.training_assignments;
drop policy if exists training_assignments_insert_self on public.training_assignments;
drop policy if exists training_assignments_update_self on public.training_assignments;
create policy training_assignments_read on public.training_assignments for select to authenticated using (user_id=auth.uid() or public.has_permission('TRAINING_ASSESS') or public.has_permission('TRAINING_ADMIN'));
create policy training_assignments_insert_self on public.training_assignments for insert to authenticated with check (
  user_id=auth.uid() and public.has_permission('TRAINING_SELF') and exists(
    select 1 from public.training_program_job_roles pjr join public.staff_job_assignments sja on sja.job_role_id=pjr.job_role_id
    where pjr.program_id=training_assignments.program_id and pjr.job_role_id=training_assignments.job_role_id and sja.user_id=auth.uid() and sja.active and (sja.end_date is null or sja.end_date>=current_date)
  )
);
create policy training_assignments_update_self on public.training_assignments for update to authenticated using (user_id=auth.uid() or public.has_permission('TRAINING_ASSESS') or public.has_permission('TRAINING_ADMIN')) with check (
  (user_id=auth.uid() and status in ('ASIGNADO','EN_CURSO','PRACTICA_PENDIENTE','EVALUACION','REENTRENAMIENTO')) or public.has_permission('TRAINING_ASSESS') or public.has_permission('TRAINING_ADMIN')
);

drop policy if exists training_module_progress_read on public.training_module_progress;
drop policy if exists training_module_progress_self on public.training_module_progress;
drop policy if exists training_module_progress_delete_self on public.training_module_progress;
create policy training_module_progress_read on public.training_module_progress for select to authenticated using (user_id=auth.uid() or public.has_permission('TRAINING_ASSESS') or public.has_permission('TRAINING_ADMIN'));
create policy training_module_progress_self on public.training_module_progress for insert to authenticated with check (user_id=auth.uid() and exists(select 1 from public.training_assignments a where a.id=assignment_id and a.user_id=auth.uid()));
create policy training_module_progress_delete_self on public.training_module_progress for delete to authenticated using (user_id=auth.uid());

drop policy if exists training_question_bank_read on public.training_question_bank;
drop policy if exists training_question_bank_admin on public.training_question_bank;
create policy training_question_bank_read on public.training_question_bank for select to authenticated using (
  public.has_permission('TRAINING_ADMIN') or exists(select 1 from public.training_programs p join public.training_content_versions v on v.id=p.content_version_id where p.id=program_id and p.active and v.status='APPROVED')
);
create policy training_question_bank_admin on public.training_question_bank for all to authenticated using (public.has_permission('TRAINING_ADMIN')) with check (public.has_permission('TRAINING_ADMIN'));

drop policy if exists training_knowledge_read on public.training_knowledge_snippets;
drop policy if exists training_knowledge_admin on public.training_knowledge_snippets;
create policy training_knowledge_read on public.training_knowledge_snippets for select to authenticated using (
  public.has_permission('TRAINING_SELF') and exists(select 1 from public.document_register d where d.id=document_id and d.status in ('APROBADO','VIGENTE'))
);
create policy training_knowledge_admin on public.training_knowledge_snippets for all to authenticated using (public.has_permission('TRAINING_ADMIN')) with check (public.has_permission('TRAINING_ADMIN'));

revoke insert,update on public.training_quiz_attempts from authenticated;
drop policy if exists training_quiz_attempts_insert on public.training_quiz_attempts;
drop policy if exists training_quiz_attempts_update_instructor on public.training_quiz_attempts;
revoke insert,update on public.training_certificates from authenticated;
drop policy if exists training_certificates_insert on public.training_certificates;
drop policy if exists training_certificates_update on public.training_certificates;
revoke insert,update on public.training_authorizations from authenticated;
drop policy if exists training_authorizations_insert on public.training_authorizations;
drop policy if exists training_authorizations_update on public.training_authorizations;

drop policy if exists training_practical_evidence_insert on public.training_practical_evidence;
create policy training_practical_evidence_insert on public.training_practical_evidence for insert to authenticated with check (
  public.has_permission('TRAINING_ASSESS') and observed_by=auth.uid() and observed_by<>user_id and assignment_id is not null and
  exists(select 1 from public.training_assignments a where a.id=assignment_id and a.user_id=training_practical_evidence.user_id and a.program_id in (select p.id from public.training_programs p where exists(select 1 from jsonb_array_elements(p.practices) x where x->>'code'=training_practical_evidence.task_code)))
);
drop policy if exists training_practical_evidence_update on public.training_practical_evidence;
create policy training_practical_evidence_update on public.training_practical_evidence for update to authenticated
using (public.has_permission('TRAINING_ASSESS') and observed_by=auth.uid() and observed_by<>user_id)
with check (public.has_permission('TRAINING_ASSESS') and observed_by=auth.uid() and observed_by<>user_id);

create or replace view public.vw_my_training_catalog with (security_invoker=true) as
select p.id as program_id,p.program_code,p.title,p.audience_label,p.pass_threshold,p.critical_process,p.estimated_minutes,p.modules,p.practices,p.microlearning,p.training_id,p.competency_id,pjr.job_role_id,jr.role_code as job_role_code,jr.title as job_role_title,sja.branch_id,sja.primary_role,
       a.id as assignment_id,coalesce(a.status,'ASIGNADO') as assignment_status,a.due_date,a.started_at,a.completed_at
from public.training_programs p
join public.training_program_job_roles pjr on pjr.program_id=p.id
join public.job_roles jr on jr.id=pjr.job_role_id
join public.staff_job_assignments sja on sja.job_role_id=jr.id and sja.user_id=auth.uid() and sja.active and (sja.end_date is null or sja.end_date>=current_date)
left join public.training_assignments a on a.user_id=auth.uid() and a.program_id=p.id and a.job_role_id=jr.id
where p.active;
revoke all on public.vw_my_training_catalog from public,anon,authenticated;
grant select on public.vw_my_training_catalog to authenticated;

create or replace view public.vw_training_questions with (security_invoker=true) as
select q.id,q.program_id,q.question_code,q.prompt,q.options,q.difficulty from public.training_question_bank q where q.active;
revoke all on public.vw_training_questions from public,anon,authenticated;
grant select on public.vw_training_questions to authenticated;

create or replace view public.vw_training_tutor_knowledge with (security_invoker=true) as
select k.id,k.role_scope,k.keywords,k.answer,d.document_code,d.title,d.version
from public.training_knowledge_snippets k join public.document_register d on d.id=k.document_id
where k.active and d.status in ('APROBADO','VIGENTE');
revoke all on public.vw_training_tutor_knowledge from public,anon,authenticated;
grant select on public.vw_training_tutor_knowledge to authenticated;

create or replace view public.vw_training_instructor_queue with (security_invoker=true) as
select a.id as assignment_id,a.user_id,pf.full_name,a.branch_id,b.name as branch_name,a.status,a.due_date,a.started_at,pr.program_code,pr.title as program_title,pr.critical_process,jr.role_code as job_role_code,jr.title as job_role_title,
       (select count(*) from jsonb_array_elements(pr.practices)) as required_practices,
       (select count(*) from public.training_practical_evidence pe where pe.assignment_id=a.id and pe.result='COMPETENTE') as competent_practices,
       (select max(qa.score) from public.training_quiz_attempts qa where qa.user_id=a.user_id and qa.training_id=pr.training_id and qa.passed) as best_passing_score
from public.training_assignments a join public.profiles pf on pf.id=a.user_id join public.training_programs pr on pr.id=a.program_id join public.job_roles jr on jr.id=a.job_role_id left join public.branches b on b.id=a.branch_id
where public.has_permission('TRAINING_ASSESS') or public.has_permission('TRAINING_ADMIN');
revoke all on public.vw_training_instructor_queue from public,anon,authenticated;
grant select on public.vw_training_instructor_queue to authenticated;

create or replace view public.vw_training_assignment_detail with (security_invoker=true) as
select a.id as assignment_id,a.user_id,pf.full_name,a.program_id,pr.program_code,pr.title as program_title,pr.pass_threshold,pr.critical_process,pr.estimated_minutes,pr.modules,pr.practices,pr.microlearning,pr.training_id,pr.competency_id,a.job_role_id,jr.role_code as job_role_code,jr.title as job_role_title,a.branch_id,b.name as branch_name,a.status,a.due_date,a.started_at,a.completed_at,a.current_module_code,
       coalesce((select count(*) from public.training_module_progress mp where mp.assignment_id=a.id),0) as modules_completed,
       jsonb_array_length(pr.modules) as modules_total,
       coalesce((select count(*) from public.training_practical_evidence pe where pe.assignment_id=a.id and pe.result='COMPETENTE'),0) as practices_completed,
       jsonb_array_length(pr.practices) as practices_total,
       (select max(qa.score) from public.training_quiz_attempts qa where qa.training_id=pr.training_id and qa.user_id=a.user_id) as best_score,
       (select bool_or(qa.passed) from public.training_quiz_attempts qa where qa.training_id=pr.training_id and qa.user_id=a.user_id) as quiz_passed
from public.training_assignments a join public.training_programs pr on pr.id=a.program_id join public.profiles pf on pf.id=a.user_id join public.job_roles jr on jr.id=a.job_role_id left join public.branches b on b.id=a.branch_id;
revoke all on public.vw_training_assignment_detail from public,anon,authenticated;
grant select on public.vw_training_assignment_detail to authenticated;

create or replace view public.vw_training_next_action with (security_invoker=true) as
select d.*,
case when d.status='COMPETENTE' then 'VER_COMPETENCIA' when d.modules_completed<d.modules_total then 'CONTINUAR_MODULOS' when d.practices_completed<d.practices_total then 'PRACTICA_SUPERVISADA' when coalesce(d.quiz_passed,false)=false then 'REALIZAR_EVALUACION' else 'PENDIENTE_CERTIFICACION' end as next_action
from public.vw_training_assignment_detail d;
revoke all on public.vw_training_next_action from public,anon,authenticated;
grant select on public.vw_training_next_action to authenticated;

create or replace function public.training_submit_quiz(p_assignment_id uuid,p_answers jsonb,p_started_at timestamptz default null)
returns table(attempt_id uuid,score numeric,passed boolean,threshold integer)
language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_a public.training_assignments%rowtype; v_p public.training_programs%rowtype; v_total int; v_correct int; v_score numeric; v_attempt int; v_id uuid; v_items jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_a from public.training_assignments where id=p_assignment_id and user_id=v_uid;
  if not found then raise exception 'TRAINING_ASSIGNMENT_NOT_FOUND'; end if;
  select * into v_p from public.training_programs where id=v_a.program_id and active;
  if not found then raise exception 'TRAINING_PROGRAM_NOT_FOUND'; end if;
  if not exists(select 1 from public.training_content_versions v where v.id=v_p.content_version_id and v.status='APPROVED') then raise exception 'TRAINING_CONTENT_NOT_APPROVED'; end if;
  if jsonb_typeof(p_answers)<>'array' or jsonb_array_length(p_answers)<3 then raise exception 'TRAINING_ANSWERS_INCOMPLETE'; end if;
  with submitted as (select (x->>'question_id')::uuid question_id,(x->>'selected_index')::int selected_index from jsonb_array_elements(p_answers) x),
  graded as (select q.id,q.prompt,s.selected_index,q.correct_index,(s.selected_index=q.correct_index) correct from submitted s join public.training_question_bank q on q.id=s.question_id and q.program_id=v_p.id and q.active)
  select count(*),count(*) filter(where correct),coalesce(jsonb_agg(jsonb_build_object('question_id',id,'question',prompt,'selected_index',selected_index,'correct_index',correct_index,'correct',correct)),'[]'::jsonb)
  into v_total,v_correct,v_items from graded;
  if v_total<>jsonb_array_length(p_answers) then raise exception 'TRAINING_QUESTION_MISMATCH'; end if;
  v_score:=round((100.0*v_correct/nullif(v_total,0))::numeric,2);
  select coalesce(max(attempt_no),0)+1 into v_attempt from public.training_quiz_attempts where training_id=v_p.training_id and user_id=v_uid;
  insert into public.training_quiz_attempts(training_id,user_id,competency_id,branch_id,role_code,attempt_no,score,passed,answers,started_at,completed_at,created_by)
  values(v_p.training_id,v_uid,v_p.competency_id,v_a.branch_id,(select role_code from public.job_roles where id=v_a.job_role_id),v_attempt,v_score,v_score>=v_p.pass_threshold,jsonb_build_object('items',v_items),p_started_at,now(),v_uid) returning id into v_id;
  update public.training_assignments set status=case when v_score>=v_p.pass_threshold then 'EVALUACION' else 'REENTRENAMIENTO' end,started_at=coalesce(started_at,now()),updated_at=now() where id=v_a.id;
  return query select v_id,v_score,(v_score>=v_p.pass_threshold),v_p.pass_threshold;
end $$;
revoke all on function public.training_submit_quiz(uuid,jsonb,timestamptz) from public,anon;
grant execute on function public.training_submit_quiz(uuid,jsonb,timestamptz) to authenticated;

create or replace function public.training_finalize_competency(p_assignment_id uuid,p_notes text default null)
returns table(certificate_id uuid,cert_code text,valid_until date)
language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_a public.training_assignments%rowtype; v_p public.training_programs%rowtype; v_latest public.training_quiz_attempts%rowtype; v_required int; v_done int; v_part uuid; v_ass uuid; v_cert uuid; v_code text; v_valid date; v_role text; v_doc_status text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.has_permission('TRAINING_ASSESS') then raise exception 'TRAINING_ASSESS_REQUIRED'; end if;
  select * into v_a from public.training_assignments where id=p_assignment_id;
  if not found then raise exception 'TRAINING_ASSIGNMENT_NOT_FOUND'; end if;
  if v_a.user_id=v_uid then raise exception 'TRAINING_SELF_CERTIFICATION_FORBIDDEN'; end if;
  select * into v_p from public.training_programs where id=v_a.program_id and active;
  if not found then raise exception 'TRAINING_PROGRAM_NOT_FOUND'; end if;
  select d.status into v_doc_status from public.training_content_versions v left join public.document_register d on d.id=v.controlled_document_id where v.id=v_p.content_version_id and v.status='APPROVED';
  if v_doc_status is distinct from 'APROBADO' and v_doc_status is distinct from 'VIGENTE' then raise exception 'TRAINING_CONTROLLED_DOCUMENT_NOT_APPROVED'; end if;
  if not exists(select 1 from public.staff_job_assignments s where s.user_id=v_a.user_id and s.job_role_id=v_a.job_role_id and s.active and (s.end_date is null or s.end_date>=current_date)) then raise exception 'TRAINING_ACTIVE_JOB_ASSIGNMENT_REQUIRED'; end if;
  select * into v_latest from public.training_quiz_attempts where training_id=v_p.training_id and user_id=v_a.user_id and passed order by completed_at desc limit 1;
  if not found then raise exception 'TRAINING_PASSING_QUIZ_REQUIRED'; end if;
  select jsonb_array_length(v_p.practices) into v_required;
  select count(*) into v_done from public.training_practical_evidence where assignment_id=v_a.id and result='COMPETENTE';
  if v_done<v_required then raise exception 'TRAINING_PRACTICE_INCOMPLETE %/%',v_done,v_required; end if;
  select role_code into v_role from public.job_roles where id=v_a.job_role_id;
  v_valid:=current_date + make_interval(months=>coalesce((select validity_months from public.competency_catalog where id=v_p.competency_id),12));
  insert into public.training_participation(training_id,user_id,competency_id,attendance_status,score,passed,evidence_reference,completed_at)
  values(v_p.training_id,v_a.user_id,v_p.competency_id,'COMPLETO',v_latest.score,true,'PENDIENTE_CERTIFICADO',now())
  on conflict (training_id,user_id,competency_id) do update set attendance_status='COMPLETO',score=excluded.score,passed=true,completed_at=now() returning id into v_part;
  v_code:='HC-CERT-'||extract(year from current_date)::int||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
  insert into public.competency_assessments(assessment_code,user_id,competency_id,branch_id,assessment_date,assessor_user_id,method,score,level_achieved,result,evidence_reference,valid_until,notes)
  values(v_code,v_a.user_id,v_p.competency_id,v_a.branch_id,current_date,v_uid,'Evaluación teórica + práctica supervisada',v_latest.score,case when v_latest.score>=90 then 4 else 3 end,'COMPETENTE',v_code,v_valid,p_notes) returning id into v_ass;
  insert into public.training_certificates(cert_code,participation_id,assessment_id,user_id,training_id,competency_id,branch_id,role_code,content_version,issued_by,valid_until,status)
  values(v_code,v_part,v_ass,v_a.user_id,v_p.training_id,v_p.competency_id,v_a.branch_id,v_role,(select version_code from public.training_content_versions where id=v_p.content_version_id),v_uid,v_valid,'VIGENTE') returning id into v_cert;
  update public.training_participation set evidence_reference='CERT='||v_code where id=v_part;
  update public.training_assignments set status='COMPETENTE',completed_at=now(),updated_at=now() where id=v_a.id;
  return query select v_cert,v_code,v_valid;
end $$;
revoke all on function public.training_finalize_competency(uuid,text) from public,anon;
grant execute on function public.training_finalize_competency(uuid,text) to authenticated;

create or replace function public.training_revoke_certificate(p_cert_code text,p_reason text)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not (public.has_permission('TRAINING_ASSESS') or public.has_permission('TRAINING_ADMIN')) then raise exception 'TRAINING_ASSESS_REQUIRED'; end if;
  if coalesce(length(trim(p_reason)),0)<5 then raise exception 'TRAINING_REVOCATION_REASON_REQUIRED'; end if;
  update public.training_certificates set status='REVOCADO',revoked_at=now(),revoked_by=v_uid,revocation_reason=trim(p_reason) where cert_code=p_cert_code and status<>'REVOCADO';
  return found;
end $$;
revoke all on function public.training_revoke_certificate(text,text) from public,anon;
grant execute on function public.training_revoke_certificate(text,text) to authenticated;

create or replace function public.training_authorize_system_use(p_assignment_id uuid,p_scope_code text,p_scope_description text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_a public.training_assignments%rowtype; v_p public.training_programs%rowtype; v_c public.training_certificates%rowtype; v_id uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.has_permission('TRAINING_ASSESS') then raise exception 'TRAINING_ASSESS_REQUIRED'; end if;
  select * into v_a from public.training_assignments where id=p_assignment_id and status='COMPETENTE';
  if not found then raise exception 'TRAINING_COMPETENT_ASSIGNMENT_REQUIRED'; end if;
  if v_a.user_id=v_uid then raise exception 'TRAINING_SELF_AUTHORIZATION_FORBIDDEN'; end if;
  select * into v_p from public.training_programs where id=v_a.program_id;
  select * into v_c from public.training_certificates where user_id=v_a.user_id and training_id=v_p.training_id and competency_id=v_p.competency_id and status='VIGENTE' and valid_until>=current_date order by issued_at desc limit 1;
  if not found then raise exception 'TRAINING_VALID_CERTIFICATE_REQUIRED'; end if;
  insert into public.training_authorizations(user_id,competency_id,branch_id,scope_code,scope_description,status,authorized_by,valid_until,evidence_reference)
  values(v_a.user_id,v_p.competency_id,v_a.branch_id,p_scope_code,p_scope_description,'ACTIVE',v_uid,v_c.valid_until,v_c.cert_code) returning id into v_id;
  return v_id;
end $$;
revoke all on function public.training_authorize_system_use(uuid,text,text) from public,anon;
grant execute on function public.training_authorize_system_use(uuid,text,text) to authenticated;

create or replace function public.training_revoke_authorization(p_authorization_id uuid,p_reason text)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not (public.has_permission('TRAINING_ASSESS') or public.has_permission('TRAINING_ADMIN')) then raise exception 'TRAINING_ASSESS_REQUIRED'; end if;
  if coalesce(length(trim(p_reason)),0)<5 then raise exception 'TRAINING_REVOCATION_REASON_REQUIRED'; end if;
  update public.training_authorizations set status='REVOKED',revoked_by=v_uid,revoked_at=now(),revocation_reason=trim(p_reason) where id=p_authorization_id and status<>'REVOKED';
  return found;
end $$;
revoke all on function public.training_revoke_authorization(uuid,text) from public,anon;
grant execute on function public.training_revoke_authorization(uuid,text) to authenticated;
