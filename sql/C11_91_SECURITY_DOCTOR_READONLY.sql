-- HemoCura C11.2 · Security Doctor · READ ONLY
-- No modifica datos ni policies.
select 'missing_roles' as control, jsonb_agg(x) as detail
from (
  select r.code, exists(select 1 from public.roles p where p.code=r.code) present
  from (values ('ENCARGADA_LABORATORIO'),('TI')) r(code)
) x
union all
select 'broad_all_policies', jsonb_agg(x)
from (
  select tablename,policyname,cmd
  from pg_policies
  where schemaname='public' and cmd='ALL'
    and (
      coalesce(qual,'') ilike '%auth.role()%authenticated%'
      or coalesce(with_check,'') ilike '%auth.role()%authenticated%'
    )
  order by tablename,policyname
) x
union all
select 'critical_release_objects', jsonb_build_object(
  'release_signoffs',to_regclass('public.release_signoffs') is not null,
  'release_operational_signoffs',to_regclass('public.release_operational_signoffs') is not null,
  'v044_rpc',to_regprocedure('public.hc_v044_release_signoff(text,text,text,text)') is not null,
  'v100_rpc',to_regprocedure('public.hc_v100_signoff(text,text,text,text)') is not null
);
