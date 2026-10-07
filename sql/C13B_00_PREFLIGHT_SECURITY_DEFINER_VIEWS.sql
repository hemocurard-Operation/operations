-- =====================================================================
-- HemoCura · C13-B · PREFLIGHT SECURITY DEFINER VIEWS · READ ONLY
-- PostgreSQL views use owner privileges by default unless
-- security_invoker=true is set. No modifica vistas ni grants.
-- =====================================================================

with views as (
  select
    c.oid,
    n.nspname as schema_name,
    c.relname as view_name,
    pg_get_userbyid(c.relowner) as owner,
    coalesce(array_to_string(c.reloptions,','),'') as reloptions,
    coalesce(array_to_string(c.reloptions,','),'') ilike '%security_invoker=true%' as security_invoker,
    has_table_privilege('anon',format('%I.%I',n.nspname,c.relname),'SELECT') as anon_select,
    has_table_privilege('authenticated',format('%I.%I',n.nspname,c.relname),'SELECT') as authenticated_select,
    pg_get_viewdef(c.oid,true) as definition
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='v'
)
select
  schema_name,view_name,owner,reloptions,security_invoker,
  anon_select,authenticated_select,definition
from views
where not security_invoker
order by view_name;

select jsonb_build_object(
  'public_views_total',count(*),
  'security_invoker_true',count(*) filter(
    where coalesce(array_to_string(c.reloptions,','),'') ilike '%security_invoker=true%'
  ),
  'owner_privilege_views',count(*) filter(
    where coalesce(array_to_string(c.reloptions,','),'') not ilike '%security_invoker=true%'
  ),
  'anon_selectable_owner_views',count(*) filter(
    where coalesce(array_to_string(c.reloptions,','),'') not ilike '%security_invoker=true%'
      and has_table_privilege('anon',format('%I.%I',n.nspname,c.relname),'SELECT')
  )
) as c13b_summary
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='v';
