-- =====================================================================
-- HemoCura · C13-F · BROAD POLICY HARDENING CANDIDATE
-- Version objetivo: 0.44.13
--
-- Corrige las dos policies ALL restantes que permiten escritura a cualquier
-- usuario authenticated:
--   * audit_plan_criteria_access
--   * job_role_competencies_access
--
-- Principios:
--   * lectura por permiso explícito;
--   * escritura por permiso explícito;
--   * audit_plan_criteria hereda alcance de sucursal desde internal_audits;
--   * no DELETE directo desde navegador (el frontend actual no lo requiere);
--   * anon/PUBLIC sin acceso directo a estas tablas.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. AUDIT PLAN CRITERIA
-- ---------------------------------------------------------------------
drop policy if exists audit_plan_criteria_access on public.audit_plan_criteria;
drop policy if exists audit_plan_criteria_read on public.audit_plan_criteria;
drop policy if exists audit_plan_criteria_insert on public.audit_plan_criteria;
drop policy if exists audit_plan_criteria_update on public.audit_plan_criteria;

drop policy if exists audit_plan_criteria_delete on public.audit_plan_criteria;

revoke all privileges on public.audit_plan_criteria from public,anon,authenticated;
grant select,insert,update on public.audit_plan_criteria to authenticated;

create policy audit_plan_criteria_read
on public.audit_plan_criteria
for select
to authenticated
using (
  (
    public.has_permission('INTERNAL_AUDIT_VIEW')
    or public.has_permission('INTERNAL_AUDIT_WRITE')
  )
  and exists (
    select 1
    from public.internal_audits ia
    where ia.id=audit_plan_criteria.audit_id
      and (ia.branch_id is null or public.can_access_branch(ia.branch_id))
  )
);

create policy audit_plan_criteria_insert
on public.audit_plan_criteria
for insert
to authenticated
with check (
  public.has_permission('INTERNAL_AUDIT_WRITE')
  and exists (
    select 1
    from public.internal_audits ia
    where ia.id=audit_plan_criteria.audit_id
      and (ia.branch_id is null or public.can_access_branch(ia.branch_id))
  )
);

create policy audit_plan_criteria_update
on public.audit_plan_criteria
for update
to authenticated
using (
  public.has_permission('INTERNAL_AUDIT_WRITE')
  and exists (
    select 1
    from public.internal_audits ia
    where ia.id=audit_plan_criteria.audit_id
      and (ia.branch_id is null or public.can_access_branch(ia.branch_id))
  )
)
with check (
  public.has_permission('INTERNAL_AUDIT_WRITE')
  and exists (
    select 1
    from public.internal_audits ia
    where ia.id=audit_plan_criteria.audit_id
      and (ia.branch_id is null or public.can_access_branch(ia.branch_id))
  )
);

-- No se crea policy DELETE ni se concede DELETE a authenticated.

-- ---------------------------------------------------------------------
-- 2. JOB ROLE COMPETENCIES
-- ---------------------------------------------------------------------
drop policy if exists job_role_competencies_access on public.job_role_competencies;
drop policy if exists job_role_competencies_read on public.job_role_competencies;
drop policy if exists job_role_competencies_insert on public.job_role_competencies;
drop policy if exists job_role_competencies_update on public.job_role_competencies;
drop policy if exists job_role_competencies_delete on public.job_role_competencies;

revoke all privileges on public.job_role_competencies from public,anon,authenticated;
grant select,insert,update on public.job_role_competencies to authenticated;

create policy job_role_competencies_read
on public.job_role_competencies
for select
to authenticated
using (
  public.has_permission('COMPETENCY_VIEW')
  or public.has_permission('COMPETENCY_WRITE')
);

create policy job_role_competencies_insert
on public.job_role_competencies
for insert
to authenticated
with check (public.has_permission('COMPETENCY_WRITE'));

create policy job_role_competencies_update
on public.job_role_competencies
for update
to authenticated
using (public.has_permission('COMPETENCY_WRITE'))
with check (public.has_permission('COMPETENCY_WRITE'));

-- No se crea policy DELETE ni se concede DELETE a authenticated.

-- ---------------------------------------------------------------------
-- 3. Registro
-- ---------------------------------------------------------------------
insert into public.app_migrations(
  migration_code,version,description,applied_by,notes
)
values(
  'C13F_BROAD_POLICY_HARDENING_v0_44_13',
  '0.44.13',
  'Reemplaza policies ALL de auditorías y matriz de competencias por permisos explícitos y alcance de sucursal',
  auth.uid(),
  'Sin DELETE browser; compatible con upsert actual de audit_plan_criteria y job_role_competencies.'
)
on conflict(migration_code) do nothing;

commit;
