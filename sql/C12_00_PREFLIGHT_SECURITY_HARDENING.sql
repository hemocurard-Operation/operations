-- =====================================================================
-- HemoCura · C12 · PREFLIGHT SECURITY HARDENING · READ ONLY
-- Basado en el esquema real verificado en Supabase.
-- No modifica datos ni permisos.
-- =====================================================================

select jsonb_build_object(
  'roles_missing',(
    select coalesce(jsonb_agg(code order by code),'[]'::jsonb)
    from (values ('ENCARGADA_LABORATORIO'),('TI')) v(code)
    where not exists(select 1 from public.roles r where r.code=v.code)
  ),
  'release_signoffs_rows',(select count(*) from public.release_signoffs),
  'release_duplicate_signers',(
    select coalesce(jsonb_agg(x),'[]'::jsonb)
    from (
      select release_version,signed_by,count(*) signoff_count,
             array_agg(signoff_type order by signoff_type) types
      from public.release_signoffs
      where signed_by is not null
      group by release_version,signed_by
      having count(*)>1
    ) x
  ),
  'uat_counts',jsonb_build_object(
    'runs',(select count(*) from public.uat_test_runs),
    'cases',(select count(*) from public.uat_test_cases),
    'results',(select count(*) from public.uat_test_results)
  ),
  'broad_policies',(
    select coalesce(jsonb_agg(x),'[]'::jsonb)
    from (
      select tablename,policyname,cmd,qual,with_check
      from pg_policies
      where schemaname='public'
        and tablename in ('release_signoffs','uat_test_runs','uat_test_cases','uat_test_results')
        and cmd='ALL'
        and (
          coalesce(qual,'') ilike '%auth.role()%authenticated%'
          or coalesce(with_check,'') ilike '%auth.role()%authenticated%'
        )
      order by tablename,policyname
    ) x
  ),
  'release_direct_insert_authenticated',
    has_table_privilege('authenticated','public.release_signoffs','INSERT'),
  'release_direct_insert_anon',
    has_table_privilege('anon','public.release_signoffs','INSERT'),
  'release_rpc_exists',
    to_regprocedure('public.hc_v044_release_signoff(text,text,text,text)') is not null
) as c12_preflight;
