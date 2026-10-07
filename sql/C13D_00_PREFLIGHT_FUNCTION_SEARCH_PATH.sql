-- =====================================================================
-- HemoCura · C13-D · PREFLIGHT FUNCTION SEARCH_PATH · READ ONLY
-- =====================================================================

select jsonb_build_object(
  'anon_create_public',has_schema_privilege('anon','public','CREATE'),
  'authenticated_create_public',has_schema_privilege('authenticated','public','CREATE'),
  'mutable_functions',(
    select coalesce(jsonb_agg(jsonb_build_object(
      'name',p.proname,
      'args',pg_get_function_identity_arguments(p.oid),
      'security_definer',p.prosecdef,
      'anon_execute',has_function_privilege('anon',p.oid,'EXECUTE'),
      'authenticated_execute',has_function_privilege('authenticated',p.oid,'EXECUTE')
    ) order by p.proname,pg_get_function_identity_arguments(p.oid)),'[]'::jsonb)
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and coalesce(array_to_string(p.proconfig,','),'') not ilike '%search_path%'
  )
) as c13d_preflight;
