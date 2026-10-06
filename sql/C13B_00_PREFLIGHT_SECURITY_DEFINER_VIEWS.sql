-- =====================================================================
-- HemoCura · C13-B · PREFLIGHT SECURITY DEFINER VIEWS · READ ONLY
-- Identifica views que ejecutan con privilegios del propietario.
-- No modifica vistas ni grants.
-- =====================================================================

select
  n.nspname as schema_name,
  c.relname as view_name,
  pg_get_userbyid(c.relowner) as owner,
  coalesce(array_to_string(c.reloptions,','),'') as reloptions,
  has_table_privilege('anon',format('%I.%I',n.nspname,c.relname),'SELECT') as anon_select,
  has_table_privilege('authenticated',format('%I.%I',n.nspname,c.relname),'SELECT') as authenticated_select,
  pg_get_viewdef(c.oid,true) as definition
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public'
  and c.relkind='v'
  and coalesce(array_to_string(c.reloptions,','),'') ilike '%security_barrier%'
   or (
     n.nspname='public'
     and c.relkind='v'
     and coalesce(array_to_string(c.reloptions,','),'') ilike '%security_invoker=false%'
   )
order by c.relname;

-- Complemento: metadata general de todas las views públicas para reconciliar
-- con Supabase Security Advisor antes de cualquier ALTER VIEW.
select
  c.relname as view_name,
  pg_get_userbyid(c.relowner) as owner,
  c.reloptions
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='v'
order by c.relname;
