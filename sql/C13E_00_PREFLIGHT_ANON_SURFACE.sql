-- =====================================================================
-- HemoCura · C13-E · PREFLIGHT ANONYMOUS DATA SURFACE · READ ONLY
-- Verifica exposición directa de anon sobre relaciones/secuencias public.
-- No modifica datos, grants ni policies.
-- =====================================================================

with rels as (
  select c.oid,c.relname,c.relkind
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relkind in ('r','v','m','f','p')
),
checks(name,ok,detail) as (
  values
  ('ALL_TABLES_RLS_ENABLED',
    not exists(
      select 1
      from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relkind='r' and not c.relrowsecurity
    ),
    'Todas las tablas public tienen RLS habilitado'),
  ('AUTH_BRANCHES_SELECT',
    has_table_privilege('authenticated','public.branches','SELECT'),
    'authenticated conserva SELECT en branches'),
  ('AUTH_MY_ACCESS_SELECT',
    has_table_privilege('authenticated','public.vw_my_access','SELECT'),
    'authenticated conserva SELECT en vw_my_access'),
  ('AUTH_MIGRATION_READINESS_SELECT',
    has_table_privilege('authenticated','public.vw_app_migration_readiness','SELECT'),
    'authenticated conserva SELECT en vw_app_migration_readiness'),
  ('ANON_SCHEMA_CREATE_DISABLED',
    not has_schema_privilege('anon','public','CREATE'),
    'anon no puede crear objetos en public')
)
select name,ok,detail,case when ok then 'PASS' else 'FAIL' end status
from checks
union all
select
  'ANON_RELATIONS_WITH_PRIVILEGES',
  count(*)=0,
  format('%s relaciones public con SELECT/INSERT/UPDATE/DELETE para anon',count(*)),
  case when count(*)=0 then 'PASS' else 'ATTENTION' end
from rels
where has_table_privilege('anon',oid,'SELECT')
   or has_table_privilege('anon',oid,'INSERT')
   or has_table_privilege('anon',oid,'UPDATE')
   or has_table_privilege('anon',oid,'DELETE')
union all
select
  'ANON_SEQUENCE_GRANTS',
  count(*)=0,
  format('%s grants de secuencia public para anon',count(*)),
  case when count(*)=0 then 'PASS' else 'ATTENTION' end
from information_schema.role_usage_grants
where grantee='anon' and object_schema='public' and object_type='SEQUENCE';

-- Evidencia detallada: relaciones expuestas a anon.
select c.relname,
       case c.relkind when 'r' then 'TABLE' when 'v' then 'VIEW' when 'm' then 'MATVIEW' else c.relkind::text end object_type,
       has_table_privilege('anon',c.oid,'SELECT') as anon_select,
       has_table_privilege('anon',c.oid,'INSERT') as anon_insert,
       has_table_privilege('anon',c.oid,'UPDATE') as anon_update,
       has_table_privilege('anon',c.oid,'DELETE') as anon_delete
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
order by object_type,c.relname;
