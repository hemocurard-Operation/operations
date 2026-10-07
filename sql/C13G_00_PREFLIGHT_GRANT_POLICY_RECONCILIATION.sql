-- =====================================================================
-- HemoCura · C13-G · PREFLIGHT GRANT ↔ RLS POLICY RECONCILIATION
-- READ ONLY
-- Version objetivo: 0.44.14
--
-- Objetivo:
--   detectar privilegios INSERT/UPDATE/DELETE concedidos a authenticated
--   sobre tablas RLS para las que NO existe una policy que permita esa
--   operación (cmd específico o ALL).
--
-- IMPORTANTE: ejecutar C13-G solo DESPUÉS de C12, C13-A y C13-F.
-- =====================================================================

with prereq(code,installed) as (
  values
    ('C12_SECURITY_HARDENING_v0_44_3',exists(select 1 from public.app_migrations where migration_code='C12_SECURITY_HARDENING_v0_44_3')),
    ('C13A_RLS_NO_POLICY_v0_44_4',exists(select 1 from public.app_migrations where migration_code='C13A_RLS_NO_POLICY_v0_44_4')),
    ('C13F_BROAD_POLICY_HARDENING_v0_44_13',exists(select 1 from public.app_migrations where migration_code='C13F_BROAD_POLICY_HARDENING_v0_44_13'))
), tables as (
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
)
select jsonb_build_object(
  'prerequisites',(
    select jsonb_object_agg(code,installed order by code) from prereq
  ),
  'prerequisites_ready',(select bool_and(installed) from prereq),
  'redundant_write_grants',(select count(*) from redundant),
  'tables_affected',(select count(distinct relname) from redundant),
  'by_operation',coalesce((
    select jsonb_object_agg(op,cnt order by op)
    from (select op,count(*) cnt from redundant group by op) x
  ),'{}'::jsonb),
  'details',coalesce((
    select jsonb_agg(jsonb_build_object('table',relname,'operation',op) order by relname,op)
    from redundant
  ),'[]'::jsonb)
) as c13g_preflight;
