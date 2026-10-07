-- =====================================================================
-- HemoCura · C13-G · GRANT ↔ RLS POLICY RECONCILIATION CANDIDATE
-- Version objetivo: 0.44.14
--
-- Principio:
--   authenticated no debe conservar INSERT/UPDATE/DELETE sobre una tabla
--   RLS si no existe una policy para esa misma operación (o ALL).
--
-- Este patch NO cambia policies, NO cambia SELECT, NO toca service_role,
-- NO cambia datos y NO modifica funciones/RPC.
--
-- Aplicar SOLO después de:
--   C12_SECURITY_HARDENING_v0_44_3
--   C13A_RLS_NO_POLICY_v0_44_4
--   C13F_BROAD_POLICY_HARDENING_v0_44_13
-- =====================================================================

begin;

do $$
declare
  r record;
begin
  if not exists(
    select 1 from public.app_migrations
    where migration_code='C12_SECURITY_HARDENING_v0_44_3'
  ) then
    raise exception 'C13-G BLOQUEADO: falta C12_SECURITY_HARDENING_v0_44_3';
  end if;

  if not exists(
    select 1 from public.app_migrations
    where migration_code='C13A_RLS_NO_POLICY_v0_44_4'
  ) then
    raise exception 'C13-G BLOQUEADO: falta C13A_RLS_NO_POLICY_v0_44_4';
  end if;

  if not exists(
    select 1 from public.app_migrations
    where migration_code='C13F_BROAD_POLICY_HARDENING_v0_44_13'
  ) then
    raise exception 'C13-G BLOQUEADO: falta C13F_BROAD_POLICY_HARDENING_v0_44_13';
  end if;

  for r in
    with tables as (
      select c.oid,c.relname
      from pg_class c
      join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public'
        and c.relkind in ('r','p')
        and c.relrowsecurity
    ), ops(op) as (
      values ('INSERT'),('UPDATE'),('DELETE')
    )
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
    order by t.relname,o.op
  loop
    execute format(
      'revoke %s on table public.%I from authenticated',
      r.op,r.relname
    );
  end loop;
end
$$;

insert into public.app_migrations(
  migration_code,version,description,applied_by,notes
)
values(
  'C13G_GRANT_POLICY_RECONCILIATION_v0_44_14',
  '0.44.14',
  'Revoca write grants redundantes de authenticated cuando no existe RLS policy equivalente',
  auth.uid(),
  'Ejecutar después de C12, C13-A y C13-F. No modifica SELECT, policies, service_role ni datos.'
)
on conflict(migration_code) do nothing;

commit;
