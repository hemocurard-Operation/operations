-- =====================================================================
-- HemoCura · C13-F · PREFLIGHT BROAD POLICY HARDENING · READ ONLY
-- Version objetivo: 0.44.13
-- =====================================================================

select jsonb_build_object(
  'tables_present', jsonb_build_object(
    'audit_plan_criteria', to_regclass('public.audit_plan_criteria') is not null,
    'job_role_competencies', to_regclass('public.job_role_competencies') is not null
  ),
  'row_counts', jsonb_build_object(
    'audit_plan_criteria', (select count(*) from public.audit_plan_criteria),
    'job_role_competencies', (select count(*) from public.job_role_competencies)
  ),
  'broad_policies', (
    select coalesce(jsonb_agg(x order by tablename,policyname),'[]'::jsonb)
    from (
      select tablename,policyname,cmd,roles,qual,with_check
      from pg_policies
      where schemaname='public'
        and tablename in ('audit_plan_criteria','job_role_competencies')
        and cmd='ALL'
    ) x
  ),
  'required_permissions', (
    select coalesce(jsonb_agg(x order by permission_code),'[]'::jsonb)
    from (
      select permission_code,module,active
      from public.app_permissions
      where permission_code in (
        'INTERNAL_AUDIT_VIEW','INTERNAL_AUDIT_WRITE',
        'COMPETENCY_VIEW','COMPETENCY_WRITE'
      )
    ) x
  ),
  'role_permission_map', (
    select coalesce(jsonb_agg(x order by permission_code),'[]'::jsonb)
    from (
      select p.permission_code,array_agg(r.code order by r.code) roles
      from public.role_permissions rp
      join public.roles r on r.id=rp.role_id
      join public.app_permissions p on p.permission_code=rp.permission_code
      where p.permission_code in (
        'INTERNAL_AUDIT_VIEW','INTERNAL_AUDIT_WRITE',
        'COMPETENCY_VIEW','COMPETENCY_WRITE'
      )
      group by p.permission_code
    ) x
  ),
  'frontend_compatibility', jsonb_build_object(
    'audit_upsert_requires', 'SELECT + INSERT + UPDATE on audit_plan_criteria',
    'competency_upsert_requires', 'SELECT + INSERT + UPDATE on job_role_competencies',
    'direct_delete_required_by_current_frontend', false
  )
) as c13f_preflight;

-- Resultado esperado antes del patch:
--  * 2 policies ALL amplias: audit_plan_criteria_access y job_role_competencies_access
--  * permisos INTERNAL_AUDIT_* y COMPETENCY_* existentes
--  * no dependencia actual del frontend en DELETE directo
