-- =====================================================================
-- HemoCura · C13-F · VALIDATE BROAD POLICY HARDENING · READ ONLY
-- =====================================================================

with checks(name,ok,detail) as (
 values
 ('NO_BROAD_ALL_POLICIES',
   not exists(
     select 1 from pg_policies
     where schemaname='public'
       and tablename in ('audit_plan_criteria','job_role_competencies')
       and cmd='ALL'
   ),
   '0 policies ALL en las dos tablas objetivo'),

 ('AUDIT_POLICIES_EXPLICIT',
   exists(select 1 from pg_policies where schemaname='public' and tablename='audit_plan_criteria' and policyname='audit_plan_criteria_read' and cmd='SELECT')
   and exists(select 1 from pg_policies where schemaname='public' and tablename='audit_plan_criteria' and policyname='audit_plan_criteria_insert' and cmd='INSERT')
   and exists(select 1 from pg_policies where schemaname='public' and tablename='audit_plan_criteria' and policyname='audit_plan_criteria_update' and cmd='UPDATE'),
   'audit_plan_criteria: SELECT/INSERT/UPDATE separados'),

 ('AUDIT_POLICY_BRANCH_SCOPED',
   coalesce((select qual ilike '%can_access_branch%' and qual ilike '%INTERNAL_AUDIT_%'
             from pg_policies where schemaname='public' and tablename='audit_plan_criteria' and policyname='audit_plan_criteria_read'),false)
   and coalesce((select with_check ilike '%can_access_branch%' and with_check ilike '%INTERNAL_AUDIT_WRITE%'
             from pg_policies where schemaname='public' and tablename='audit_plan_criteria' and policyname='audit_plan_criteria_insert'),false),
   'auditoría hereda alcance de sucursal del audit padre'),

 ('COMPETENCY_POLICIES_EXPLICIT',
   exists(select 1 from pg_policies where schemaname='public' and tablename='job_role_competencies' and policyname='job_role_competencies_read' and cmd='SELECT')
   and exists(select 1 from pg_policies where schemaname='public' and tablename='job_role_competencies' and policyname='job_role_competencies_insert' and cmd='INSERT')
   and exists(select 1 from pg_policies where schemaname='public' and tablename='job_role_competencies' and policyname='job_role_competencies_update' and cmd='UPDATE'),
   'job_role_competencies: SELECT/INSERT/UPDATE separados'),

 ('NO_BROWSER_DELETE',
   not has_table_privilege('authenticated','public.audit_plan_criteria','DELETE')
   and not has_table_privilege('authenticated','public.job_role_competencies','DELETE'),
   'sin DELETE directo desde authenticated'),

 ('AUTH_UPSERT_COMPATIBLE',
   has_table_privilege('authenticated','public.audit_plan_criteria','SELECT,INSERT,UPDATE')
   and has_table_privilege('authenticated','public.job_role_competencies','SELECT,INSERT,UPDATE'),
   'frontend actual conserva SELECT+INSERT+UPDATE'),

 ('ANON_NO_DIRECT_ACCESS',
   not has_table_privilege('anon','public.audit_plan_criteria','SELECT')
   and not has_table_privilege('anon','public.audit_plan_criteria','INSERT')
   and not has_table_privilege('anon','public.job_role_competencies','SELECT')
   and not has_table_privilege('anon','public.job_role_competencies','INSERT'),
   'anon sin acceso directo a tablas objetivo'),

 ('C13F_REGISTERED',
   exists(select 1 from public.app_migrations where migration_code='C13F_BROAD_POLICY_HARDENING_v0_44_13'),
   'app_migrations C13F_BROAD_POLICY_HARDENING_v0_44_13')
)
select name,ok,detail,case when ok then 'PASS' else 'FAIL' end status
from checks
union all
select 'RESULTADO_GENERAL',bool_and(ok),'C13-F broad policy hardening',
       case when bool_and(ok) then 'PASS' else 'STOP' end
from checks;

-- Evidencia complementaria
select tablename,policyname,cmd,roles,qual,with_check
from pg_policies
where schemaname='public'
  and tablename in ('audit_plan_criteria','job_role_competencies')
order by tablename,policyname;
