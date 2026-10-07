-- =====================================================================
-- HemoCura · C13-B1 · REVOKE ANON FROM OWNER-PRIVILEGE VIEWS
-- Cierra exposición anónima primero, sin cambiar todavía la semántica
-- de las views para usuarios authenticated.
-- =====================================================================

begin;

do $$
declare
  r record;
begin
  for r in
    select n.nspname,c.relname
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relkind='v'
      and coalesce(array_to_string(c.reloptions,','),'') not ilike '%security_invoker=true%'
  loop
    execute format('revoke all on table %I.%I from anon',r.nspname,r.relname);
  end loop;
end
$$;

insert into public.app_migrations(migration_code,version,description,applied_by,notes)
values(
  'C13B1_REVOKE_ANON_OWNER_VIEWS_v0_44_9',
  '0.44.9',
  'Revoca acceso anon a views públicas que aún ejecutan con privilegios del owner',
  auth.uid(),
  'No cambia todavía security_invoker para authenticated; fase 1 de remediación de views.'
)
on conflict(migration_code) do nothing;

commit;
