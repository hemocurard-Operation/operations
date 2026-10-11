-- HemoCura Training Release 1.0 foundation
-- Applied to production via Supabase migration history as training_release_1_0_foundation.

create table if not exists public.training_quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  training_id uuid not null references public.training_events(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  competency_id uuid references public.competency_catalog(id),
  branch_id uuid references public.branches(id),
  role_code text not null,
  attempt_no integer not null check (attempt_no >= 1),
  score numeric not null check (score >= 0 and score <= 100),
  scenario_score numeric check (scenario_score is null or (scenario_score >= 0 and scenario_score <= 100)),
  passed boolean not null,
  answers jsonb not null default '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz not null default now(),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(training_id,user_id,attempt_no)
);

create table if not exists public.training_practical_evidence (
  id uuid primary key default gen_random_uuid(),
  training_id uuid not null references public.training_events(id) on delete cascade,
  participation_id uuid references public.training_participation(id) on delete set null,
  user_id uuid not null references public.profiles(id),
  competency_id uuid references public.competency_catalog(id),
  branch_id uuid references public.branches(id),
  role_code text not null,
  task_code text not null,
  task_label text not null,
  result text not null check (result in ('COMPETENTE','REQUIERE_SUPERVISION','NO_COMPETENTE')),
  observed_by uuid not null references public.profiles(id),
  observed_at timestamptz not null default now(),
  evidence_reference text,
  notes text,
  created_at timestamptz not null default now(),
  check (observed_by <> user_id)
);

create table if not exists public.training_content_versions (
  id uuid primary key default gen_random_uuid(),
  version_code text not null unique,
  title text not null,
  status text not null default 'DRAFT' check (status in ('DRAFT','APPROVED','RETIRED')),
  change_summary text not null,
  content_hash text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  effective_from date,
  retired_at timestamptz,
  check ((status <> 'APPROVED') or (approved_by is not null and approved_at is not null))
);

create table if not exists public.training_certificates (
  id uuid primary key default gen_random_uuid(),
  cert_code text not null unique,
  participation_id uuid not null unique references public.training_participation(id) on delete restrict,
  assessment_id uuid not null references public.competency_assessments(id) on delete restrict,
  user_id uuid not null references public.profiles(id),
  training_id uuid not null references public.training_events(id),
  competency_id uuid not null references public.competency_catalog(id),
  branch_id uuid references public.branches(id),
  role_code text not null,
  content_version text not null default 'TRN-1.0-RC',
  issued_by uuid not null references public.profiles(id),
  issued_at timestamptz not null default now(),
  valid_until date not null,
  status text not null default 'VIGENTE' check (status in ('VIGENTE','SUSPENDIDO','REVOCADO')),
  certificate_url text,
  verification_token uuid not null default gen_random_uuid() unique,
  revoked_at timestamptz,
  revoked_by uuid references public.profiles(id),
  revocation_reason text,
  created_at timestamptz not null default now(),
  check (issued_by <> user_id),
  check ((status <> 'REVOCADO') or (revoked_at is not null and revoked_by is not null and coalesce(length(trim(revocation_reason)),0) > 0))
);

create table if not exists public.training_authorizations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  competency_id uuid not null references public.competency_catalog(id),
  branch_id uuid references public.branches(id),
  scope_code text not null,
  scope_description text not null,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','SUSPENDED','REVOKED')),
  authorized_by uuid not null references public.profiles(id),
  authorized_at timestamptz not null default now(),
  valid_until date,
  evidence_reference text not null,
  revoked_by uuid references public.profiles(id),
  revoked_at timestamptz,
  revocation_reason text,
  created_at timestamptz not null default now(),
  check (authorized_by <> user_id),
  check ((status <> 'REVOKED') or (revoked_at is not null and revoked_by is not null and coalesce(length(trim(revocation_reason)),0) > 0))
);

alter table public.training_quiz_attempts enable row level security;
alter table public.training_practical_evidence enable row level security;
alter table public.training_content_versions enable row level security;
alter table public.training_certificates enable row level security;
alter table public.training_authorizations enable row level security;

revoke all on public.training_quiz_attempts from public, anon, authenticated;
revoke all on public.training_practical_evidence from public, anon, authenticated;
revoke all on public.training_content_versions from public, anon, authenticated;
revoke all on public.training_certificates from public, anon, authenticated;
revoke all on public.training_authorizations from public, anon, authenticated;

grant select, insert on public.training_quiz_attempts to authenticated;
grant select, insert, update on public.training_practical_evidence to authenticated;
grant select, insert, update on public.training_content_versions to authenticated;
grant select, insert, update on public.training_certificates to authenticated;
grant select, insert, update on public.training_authorizations to authenticated;

create policy training_quiz_attempts_read on public.training_quiz_attempts for select to authenticated using (user_id = (select auth.uid()) or public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
create policy training_quiz_attempts_insert on public.training_quiz_attempts for insert to authenticated with check ((user_id = (select auth.uid()) and created_by = (select auth.uid())) or public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
create policy training_practical_evidence_read on public.training_practical_evidence for select to authenticated using (user_id = (select auth.uid()) or public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
create policy training_practical_evidence_insert on public.training_practical_evidence for insert to authenticated with check ((public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) and observed_by = (select auth.uid()));
create policy training_practical_evidence_update on public.training_practical_evidence for update to authenticated using (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) with check ((public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) and observed_by <> user_id);
create policy training_content_versions_read on public.training_content_versions for select to authenticated using (true);
create policy training_content_versions_insert on public.training_content_versions for insert to authenticated with check (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
create policy training_content_versions_update on public.training_content_versions for update to authenticated using (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) with check (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
create policy training_certificates_read on public.training_certificates for select to authenticated using (user_id = (select auth.uid()) or public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
create policy training_certificates_insert on public.training_certificates for insert to authenticated with check ((public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) and issued_by = (select auth.uid()) and issued_by <> user_id);
create policy training_certificates_update on public.training_certificates for update to authenticated using (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) with check (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
create policy training_authorizations_read on public.training_authorizations for select to authenticated using (user_id = (select auth.uid()) or public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));
create policy training_authorizations_insert on public.training_authorizations for insert to authenticated with check ((public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) and authorized_by = (select auth.uid()) and authorized_by <> user_id);
create policy training_authorizations_update on public.training_authorizations for update to authenticated using (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) with check (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));

create or replace view public.vw_training_certificate_status with (security_invoker = true) as
select c.id,c.cert_code,c.participation_id,c.assessment_id,c.user_id,p.full_name,c.training_id,t.training_code,t.title as training_title,c.competency_id,cc.competency_code,cc.title as competency_title,c.branch_id,b.name as branch_name,c.role_code,c.content_version,c.issued_by,c.issued_at,c.valid_until,c.status,case when c.status='REVOCADO' then 'REVOCADO' when c.status='SUSPENDIDO' then 'SUSPENDIDO' when c.valid_until < current_date then 'VENCIDO' else 'VIGENTE' end as effective_status,(c.valid_until-current_date) as days_remaining,c.certificate_url,c.verification_token,c.revoked_at,c.revoked_by,c.revocation_reason
from public.training_certificates c join public.profiles p on p.id=c.user_id join public.training_events t on t.id=c.training_id join public.competency_catalog cc on cc.id=c.competency_id left join public.branches b on b.id=c.branch_id;

create or replace view public.vw_training_recertification_alerts with (security_invoker = true) as
select *,case when effective_status in ('REVOCADO','SUSPENDIDO','VENCIDO') then 'ALTA' when days_remaining <= 30 then 'ALTA' when days_remaining <= 60 then 'MEDIA' when days_remaining <= 90 then 'BAJA' else 'INFO' end as severity from public.vw_training_certificate_status where effective_status <> 'VIGENTE' or days_remaining <= 90;

create or replace view public.vw_training_analytics with (security_invoker = true) as
select q.training_id,t.training_code,t.title as training_title,q.branch_id,b.name as branch_name,q.role_code,count(*) as attempts,count(distinct q.user_id) as participants,round(avg(q.score),2) as avg_score,round(avg(q.scenario_score),2) as avg_scenario_score,round(100.0 * count(*) filter (where q.passed) / nullif(count(*),0),2) as pass_rate_pct,round(avg(extract(epoch from (q.completed_at-q.started_at))/60.0) filter (where q.started_at is not null),2) as avg_duration_minutes from public.training_quiz_attempts q join public.training_events t on t.id=q.training_id left join public.branches b on b.id=q.branch_id group by q.training_id,t.training_code,t.title,q.branch_id,b.name,q.role_code;

create or replace view public.vw_training_authorization_status with (security_invoker = true) as
select a.*,p.full_name,cc.competency_code,cc.title as competency_title,b.name as branch_name,case when a.status='REVOKED' then 'REVOKED' when a.status='SUSPENDED' then 'SUSPENDED' when a.valid_until is not null and a.valid_until < current_date then 'EXPIRED' else 'ACTIVE' end as effective_status from public.training_authorizations a join public.profiles p on p.id=a.user_id join public.competency_catalog cc on cc.id=a.competency_id left join public.branches b on b.id=a.branch_id;

revoke all on public.vw_training_certificate_status from public, anon, authenticated;
revoke all on public.vw_training_recertification_alerts from public, anon, authenticated;
revoke all on public.vw_training_analytics from public, anon, authenticated;
revoke all on public.vw_training_authorization_status from public, anon, authenticated;
grant select on public.vw_training_certificate_status to authenticated;
grant select on public.vw_training_recertification_alerts to authenticated;
grant select on public.vw_training_analytics to authenticated;
grant select on public.vw_training_authorization_status to authenticated;

create or replace function public.verify_training_certificate(p_code text)
returns table(cert_code text,full_name text,training_title text,competency_title text,branch_name text,role_code text,issued_at timestamptz,valid_until date,effective_status text,days_remaining integer)
language sql stable set search_path = '' as $$
select v.cert_code,v.full_name,v.training_title,v.competency_title,v.branch_name,v.role_code,v.issued_at,v.valid_until,v.effective_status,v.days_remaining from public.vw_training_certificate_status v where v.cert_code=p_code limit 1
$$;
revoke all on function public.verify_training_certificate(text) from public, anon;
grant execute on function public.verify_training_certificate(text) to authenticated;

insert into public.training_content_versions(version_code,title,status,change_summary,effective_from)
values ('TRN-1.0-RC','Entrenamiento HemoCura por Rol','DRAFT','Release candidate con certificación, recertificación, analítica, escenarios, evidencias, autorización y UAT.',current_date)
on conflict (version_code) do update set title=excluded.title,change_summary=excluded.change_summary,effective_from=excluded.effective_from;

insert into public.uat_test_cases(test_code,module,title,preconditions,steps,expected_result,critical,active) values
('UAT-TRN-AO-001','TRAINING','Capacitación Asistente de Operaciones','Usuario real ASISTENTE_OPERACIONES y un evaluador autorizado distinto.','Abrir Capacitación; completar ruta; ejecutar prácticas; aprobar evaluación; registrar competencia.','Participación, evidencia práctica, evaluación y certificado quedan trazables sin autocertificación.',true,true),
('UAT-TRN-LAB-001','TRAINING','Capacitación Laboratorio / Calidad / Gerencia Técnica','Usuarios reales de ENCARGADA_LABORATORIO, CALIDAD y MEDICO_GERENTE_TECNICO; evaluador autorizado distinto.','Completar rutas por rol; validar escenarios críticos de tamizaje, cadena de frío, SGC y decisiones técnicas; certificar.','Cada rol ve contenido pertinente y las guardias clínicas impiden interpretar el entrenamiento como autorización clínica automática.',true,true),
('UAT-TRN-ADM-001','TRAINING','Capacitación Super Usuario / Gerencia / TI','Usuarios reales SUPER_USUARIO/ADMIN, GERENCIA y TI; evaluador autorizado distinto.','Completar rutas; validar seguridad, dashboards, diagnóstico y despliegue; certificar.','Se respeta mínimo privilegio, segregación de funciones y trazabilidad de la certificación.',true,true)
on conflict (test_code) do update set module=excluded.module,title=excluded.title,preconditions=excluded.preconditions,steps=excluded.steps,expected_result=excluded.expected_result,critical=excluded.critical,active=excluded.active;
