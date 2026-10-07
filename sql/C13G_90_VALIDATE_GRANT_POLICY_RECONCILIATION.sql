-- =====================================================================
-- HemoCura · C13-G · VALIDATE GRANT ↔ RLS POLICY RECONCILIATION
-- READ ONLY
-- =====================================================================

with tables as (
  select c.oid,c.relname
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relkind in ('r','p')
    and c.relrowsecurity
), ops(op) as (
  values ('INSERT'),('UPDATE'),('DELETE')
), redundant as (
  select t.relname,o.op
  from tables t
  cross join ops o
  where has_table_privilege('authenticated',t.oid,o.op)
    and not exists (
      select 1
      from pg_policies p
      where p.schemaname='public'
        and p.tablename=t.relname
        and p.cmd in ('ALL',o.op)
    )
), checks(name,ok,detail) as (
  values
    ('C13G_REGISTERED',
      exists(select 1 from public.app_migrations where migration_code='C13G_GRANT_POLICY_RECONCILIATION_v0_44_14'),
      'app_migrations contiene C13G_GRANT_POLICY_RECONCILIATION_v0_44_14'),
    ('NO_REDUNDANT_AUTH_WRITE_GRANTS',
      not exists(select 1 from redundant),
      'authenticated no conserva INSERT/UPDATE/DELETE sin policy equivalente'),
    ('CRITICAL_SELECT_PRESERVED',
      has_table_privilege('authenticated','public.branches','SELECT')
      and has_table_privilege('authenticated','public.profiles','SELECT')
      and has_table_privilege('authenticated','public.roles','SELECT')
      and has_table_privilege('authenticated','public.app_permissions','SELECT'),
      'SELECT crítico de la aplicación sigue disponible'),
    ('SERVICE_ROLE_UNCHANGED_CRITICAL',
      has_table_privilege('service_role','public.branches','SELECT')
      and has_table_privilege('service_role','public.app_migrations','INSERT'),
      'service_role conserva acceso crítico')
)
select name,ok,detail,case when ok then 'PASS' else 'FAIL' end as status
from checks
union all
select 'RESULTADO_GENERAL',bool_and(ok),'C13-G grant/policy reconciliation',
       case when bool_and(ok) then 'PASS' else 'STOP' end
from checks;

-- Debe devolver 0 filas tras PASS.
select * from redundant order by relname,op;
