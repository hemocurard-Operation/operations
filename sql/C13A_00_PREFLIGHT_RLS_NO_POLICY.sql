-- =====================================================================
-- HemoCura · C13-A · PREFLIGHT RLS ENABLED / NO POLICY · READ ONLY
-- No modifica datos, grants ni policies.
-- =====================================================================

with targets as (
  select c.oid,
         n.nspname as schema_name,
         c.relname as table_name,
         c.relrowsecurity as rls_enabled,
         exists(
           select 1 from pg_policy p where p.polrelid=c.oid
         ) as has_policy
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relkind='r'
    and c.relrowsecurity
), flagged as (
  select * from targets where not has_policy
)
select
  f.table_name,
  exists(
    select 1 from information_schema.columns c
    where c.table_schema='public' and c.table_name=f.table_name and c.column_name='branch_id'
  ) as has_branch_id,
  exists(
    select 1 from information_schema.columns c
    where c.table_schema='public' and c.table_name=f.table_name and c.column_name='created_by'
  ) as has_created_by,
  has_table_privilege('anon','public.'||f.table_name,'SELECT') as anon_select,
  has_table_privilege('authenticated','public.'||f.table_name,'SELECT') as authenticated_select,
  has_table_privilege('authenticated','public.'||f.table_name,'INSERT') as authenticated_insert,
  has_table_privilege('authenticated','public.'||f.table_name,'UPDATE') as authenticated_update,
  has_table_privilege('authenticated','public.'||f.table_name,'DELETE') as authenticated_delete
from flagged f
order by f.table_name;

select count(*) as tables_rls_without_policy
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public'
  and c.relkind='r'
  and c.relrowsecurity
  and not exists(select 1 from pg_policy p where p.polrelid=c.oid);
