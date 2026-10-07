-- =====================================================================
-- HemoCura · C13-E · VALIDATE ANONYMOUS DATA SURFACE · READ ONLY
-- Ejecutar DESPUÉS de C13E_01_ANON_SURFACE_HARDENING_CANDIDATE.sql
-- =====================================================================

with checks(name,ok,detail) as (
  values
  ('ANON_NO_RELATION_PRIVILEGES',
    not exists(
      select 1
      from pg_class c
      join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public'
        and c.relkind in ('r','v','m','f','p')
        and (
          has_table_privilege('anon',c.oid,'SELECT')
          or has_table_privilege('anon',c.oid,'INSERT')
          or has_table_privilege('anon',c.oid,'UPDATE')
          or has_table_privilege('anon',c.oid,'DELETE')
        )
    ),
    '0 relaciones public con acceso directo anon'),

  ('ANON_NO_SEQUENCE_GRANTS',
    not exists(
      select 1 from information_schema.role_usage_grants
      where grantee='anon' and object_schema='public' and object_type='SEQUENCE'
    ),
    '0 grants de secuencia public para anon'),

  ('ANON_SCHEMA_CREATE_DISABLED',
    not has_schema_privilege('anon','public','CREATE'),
    'anon sin CREATE en schema public'),

  ('AUTH_CRITICAL_READS_PRESERVED',
    has_table_privilege('authenticated','public.branches','SELECT')
    and has_table_privilege('authenticated','public.vw_my_access','SELECT')
    and has_table_privilege('authenticated','public.vw_app_migration_readiness','SELECT'),
    'authenticated conserva lecturas críticas'),

  ('RLS_REMAINS_ENABLED',
    not exists(
      select 1
      from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relkind='r' and not c.relrowsecurity
    ),
    'RLS continúa habilitado en todas las tablas public'),

  ('CLINICAL_GATES_UNCHANGED',
    exists(select 1 from public.app_feature_flags where key='clinical_fefo' and (not enabled or mode='SHADOW'))
    and exists(select 1 from public.app_feature_flags where key='cold_chain_auto_block' and (not enabled or mode='SHADOW'))
    and exists(select 1 from public.system_operating_mode where id=1 and not clinical_unit_dispatch_enabled and not temperature_blocking_enabled),
    'FEFO y auto-bloqueo térmico permanecen deshabilitados/SHADOW'),

  ('C13E_REGISTERED',
    exists(select 1 from public.app_migrations where migration_code='C13E_ANON_SURFACE_HARDENING_v0_44_12'),
    'app_migrations C13E_ANON_SURFACE_HARDENING_v0_44_12')
)
select name,ok,detail,case when ok then 'PASS' else 'FAIL' end status
from checks
union all
select 'RESULTADO_GENERAL',bool_and(ok),'C13-E anonymous data surface hardening',
       case when bool_and(ok) then 'PASS' else 'STOP' end
from checks;
