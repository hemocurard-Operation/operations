-- =====================================================================
-- HemoCura · C13-C · PREFLIGHT FUNCTION SECURITY · READ ONLY
-- Revisa SECURITY DEFINER, search_path y EXECUTE para anon/authenticated.
-- No modifica funciones ni privilegios.
-- =====================================================================

select
  n.nspname as schema_name,
  p.proname,
  pg_get_function_identity_arguments(p.oid) as arguments,
  p.prosecdef as security_definer,
  coalesce(array_to_string(p.proconfig,','),'') as proconfig,
  has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
  has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and (
    p.prosecdef
    or coalesce(array_to_string(p.proconfig,','),'') not ilike '%search_path%'
  )
order by p.proname,pg_get_function_identity_arguments(p.oid);

select
  count(*) filter(where p.prosecdef and has_function_privilege('anon',p.oid,'EXECUTE')) as secdef_anon_executable,
  count(*) filter(where p.prosecdef and has_function_privilege('authenticated',p.oid,'EXECUTE')) as secdef_authenticated_executable,
  count(*) filter(where coalesce(array_to_string(p.proconfig,','),'') not ilike '%search_path%') as mutable_search_path_candidates
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public';
