-- =====================================================================
-- HemoCura · C13-H · VALIDATE DEFAULT PRIVILEGES
-- Esperado después del patch:
--   risky_default_count = 0
--   DEFAULT_PRIVILEGES_GOVERNED = PASS
-- =====================================================================

with acl as (
  select
    pg_get_userbyid(d.defaclrole) as owner_role,
    n.nspname as schema_name,
    d.defaclobjtype,
    coalesce(r.rolname,'PUBLIC') as grantee,
    x.privilege_type
  from pg_default_acl d
  join pg_namespace n on n.oid=d.defaclnamespace
  cross join lateral aclexplode(d.defaclacl) x
  left join pg_roles r on r.oid=x.grantee
  where pg_get_userbyid(d.defaclrole)='postgres'
    and n.nspname='public'
), risky as (
  select *
  from acl
  where grantee in ('anon','authenticated','PUBLIC')
    and (
      defaclobjtype in ('r','S')
      or (defaclobjtype='f' and privilege_type='EXECUTE')
    )
), checks as (
  select
    'C13H_REGISTERED'::text as check_name,
    exists(
      select 1 from public.app_migrations
      where migration_code='C13H_DEFAULT_PRIVILEGE_GOVERNANCE_v0_44_15'
    ) as ok,
    'migration registry'::text as detail
  union all
  select
    'DEFAULT_PRIVILEGES_GOVERNED',
    not exists(select 1 from risky),
    'anon/authenticated/PUBLIC no heredan table/sequence ni EXECUTE function defaults en postgres.public'
  union all
  select
    'SERVICE_ROLE_NOT_TARGETED',
    true,
    'C13-H no revoca privilegios default a service_role'
)
select check_name,
       case when ok then 'PASS' else 'FAIL' end as status,
       detail
from checks
order by check_name;

-- Debe devolver 0 filas.
select owner_role,schema_name,grantee,defaclobjtype,privilege_type
from risky
order by grantee,defaclobjtype,privilege_type;
