-- HemoCura Training: assignment, document-control and BI gates.
alter table public.training_content_versions add column if not exists controlled_document_id uuid references public.document_register(id);
insert into public.document_register(document_code,title,area,document_type,version,status,source_path,controlled_copy,notes)
values ('HC-TRN-SUITE-001','Programa de Capacitación y Competencias — Suite HemoCura','CALIDAD','PROGRAMA_CAPACITACION','1.0-RC','BORRADOR','training.html',true,'Documento controlado asociado al contenido TRN-1.0-RC. Requiere revisión y aprobación formal antes de declarar la versión formativa APPROVED.')
on conflict (document_code) do update set title=excluded.title,area=excluded.area,document_type=excluded.document_type,version=excluded.version,source_path=excluded.source_path,controlled_copy=true,notes=excluded.notes;
update public.training_content_versions t set controlled_document_id=d.id from public.document_register d where t.version_code='TRN-1.0-RC' and d.document_code='HC-TRN-SUITE-001';

create or replace function public.enforce_training_content_approval() returns trigger language plpgsql set search_path = '' as $$
declare v_status text;
begin
  if new.status='APPROVED' and old.status is distinct from 'APPROVED' then
    if new.controlled_document_id is null then raise exception 'Training content approval requires a controlled document.'; end if;
    select d.status into v_status from public.document_register d where d.id=new.controlled_document_id;
    if v_status not in ('APROBADO','VIGENTE') then raise exception 'Controlled document must be APROBADO or VIGENTE before training content approval. Current: %',coalesce(v_status,'MISSING'); end if;
  end if;
  return new;
end $$;
revoke all on function public.enforce_training_content_approval() from public,anon,authenticated;
drop trigger if exists trg_training_content_approval_gate on public.training_content_versions;
create trigger trg_training_content_approval_gate before update of status on public.training_content_versions for each row execute function public.enforce_training_content_approval();

create or replace function public.enforce_training_certificate_assignment() returns trigger language plpgsql set search_path = '' as $$
begin
  if not exists (
    select 1 from public.staff_job_assignments s join public.job_role_competencies jrc on jrc.job_role_id=s.job_role_id
    where s.user_id=new.user_id and s.active=true and s.start_date<=current_date and (s.end_date is null or s.end_date>=current_date)
      and jrc.competency_id=new.competency_id and jrc.mandatory=true
  ) then raise exception 'Certificate blocked: competency is not mandatory for an active assigned job role of this participant.'; end if;
  return new;
end $$;
revoke all on function public.enforce_training_certificate_assignment() from public,anon,authenticated;
drop trigger if exists trg_training_certificate_assignment_gate on public.training_certificates;
create trigger trg_training_certificate_assignment_gate before insert on public.training_certificates for each row execute function public.enforce_training_certificate_assignment();

create or replace view public.vw_training_assignment_eligibility with (security_invoker = true) as
select s.user_id,p.full_name,s.branch_id,b.name as branch_name,jr.id as job_role_id,jr.role_code,jr.title as job_title,cc.id as competency_id,cc.competency_code,cc.title as competency_title,jrc.required_level,jrc.mandatory,jrc.evaluation_method,s.start_date,s.end_date
from public.staff_job_assignments s join public.profiles p on p.id=s.user_id join public.job_roles jr on jr.id=s.job_role_id join public.job_role_competencies jrc on jrc.job_role_id=jr.id join public.competency_catalog cc on cc.id=jrc.competency_id left join public.branches b on b.id=s.branch_id
where s.active=true and s.start_date<=current_date and (s.end_date is null or s.end_date>=current_date);

create or replace view public.vw_training_compliance_by_job_role with (security_invoker = true) as
select jr.role_code,jr.title as job_title,count(distinct s.user_id) as assigned_people,count(*) filter(where g.competency_status='COMPETENTE') as competent_requirements,count(*) filter(where g.competency_status<>'COMPETENTE') as gap_requirements,round(100.0*count(*) filter(where g.competency_status='COMPETENTE')/nullif(count(*),0),2) as compliance_pct
from public.staff_job_assignments s join public.job_roles jr on jr.id=s.job_role_id join public.vw_staff_competency_gaps g on g.user_id=s.user_id and g.job_role_id=s.job_role_id
where s.active=true and s.start_date<=current_date and (s.end_date is null or s.end_date>=current_date) group by jr.role_code,jr.title;

create or replace view public.vw_training_compliance_by_competency with (security_invoker = true) as
select g.competency_code,g.competency_title,count(*) as required_assignments,count(*) filter(where g.competency_status='COMPETENTE') as competent,count(*) filter(where g.competency_status<>'COMPETENTE') as gaps,round(100.0*count(*) filter(where g.competency_status='COMPETENTE')/nullif(count(*),0),2) as compliance_pct
from public.vw_staff_competency_gaps g group by g.competency_code,g.competency_title;

create or replace view public.vw_training_gaps_by_branch with (security_invoker = true) as
select g.branch_id,b.name as branch_name,count(*) as requirements,count(*) filter(where g.competency_status='COMPETENTE') as competent,count(*) filter(where g.competency_status<>'COMPETENTE') as gaps,count(*) filter(where g.competency_status in ('VENCIDA','POR_VENCER')) as recertification_attention
from public.vw_staff_competency_gaps g left join public.branches b on b.id=g.branch_id group by g.branch_id,b.name;

create or replace view public.vw_training_critical_process_risk with (security_invoker = true) as
select g.competency_code,g.competency_title,count(*) filter(where g.competency_status<>'COMPETENTE') as people_with_gap,case when count(*) filter(where g.competency_status<>'COMPETENTE')=0 then 'BAJO' when count(*) filter(where g.competency_status<>'COMPETENTE')<=2 then 'MEDIO' else 'ALTO' end as risk_level
from public.vw_staff_competency_gaps g where g.competency_code like 'HC-DIG-SUITE-%' group by g.competency_code,g.competency_title;

create or replace view public.vw_training_monthly_executive with (security_invoker = true) as
select date_trunc('month',q.completed_at)::date as month,q.role_code,q.branch_id,b.name as branch_name,count(*) as attempts,count(distinct q.user_id) as participants,round(avg(q.score),2) as avg_score,round(100.0*count(*) filter(where q.passed)/nullif(count(*),0),2) as pass_rate_pct,round(avg(extract(epoch from(q.completed_at-q.started_at))/60.0) filter(where q.started_at is not null),2) as avg_duration_minutes
from public.training_quiz_attempts q left join public.branches b on b.id=q.branch_id group by date_trunc('month',q.completed_at)::date,q.role_code,q.branch_id,b.name;

revoke all on public.vw_training_assignment_eligibility from public,anon,authenticated;
revoke all on public.vw_training_compliance_by_job_role from public,anon,authenticated;
revoke all on public.vw_training_compliance_by_competency from public,anon,authenticated;
revoke all on public.vw_training_gaps_by_branch from public,anon,authenticated;
revoke all on public.vw_training_critical_process_risk from public,anon,authenticated;
revoke all on public.vw_training_monthly_executive from public,anon,authenticated;
grant select on public.vw_training_assignment_eligibility to authenticated;
grant select on public.vw_training_compliance_by_job_role to authenticated;
grant select on public.vw_training_compliance_by_competency to authenticated;
grant select on public.vw_training_gaps_by_branch to authenticated;
grant select on public.vw_training_critical_process_risk to authenticated;
grant select on public.vw_training_monthly_executive to authenticated;
