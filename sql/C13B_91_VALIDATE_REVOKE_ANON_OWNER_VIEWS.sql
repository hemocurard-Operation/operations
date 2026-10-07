-- =====================================================================
-- HemoCura · C13-B1 · VALIDATE ANON VIEW HARDENING · READ ONLY
-- =====================================================================

with owner_views as (
  select n.nspname schema_name,c.relname view_name,c.oid
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relkind='v'
    and coalesce(array_to_string(c.reloptions,','),'') not ilike '%security_invoker=true%'
), checks(name,ok,detail) as (
 values
 ('NO_ANON_OWNER_VIEW_SELECT',
   not exists(
     select 1 from owner_views v
     where has_table_privilege('anon',format('%I.%I',v.schema_name,v.view_name),'SELECT')
   ),
   '0 owner-privilege views con SELECT para anon'),
 ('AUTH_FRONTEND_VIEWS_REMAIN_SELECTABLE',
   has_table_privilege('authenticated','public.vw_my_access','SELECT')
   and has_table_privilege('authenticated','public.vw_my_security_context','SELECT')
   and has_table_privilege('authenticated','public.vw_blood_flow_status','SELECT')
   and has_table_privilege('authenticated','public.vw_uat_summary','SELECT')
   and has_table_privilege('authenticated','public.vw_release_1_0_readiness','SELECT'),
   'views críticas continúan accesibles para authenticated'),
 ('C13B1_REGISTERED',
   exists(select 1 from public.app_migrations where migration_code='C13B1_REVOKE_ANON_OWNER_VIEWS_v0_44_9'),
   'app_migrations C13B1_REVOKE_ANON_OWNER_VIEWS_v0_44_9')
)
select name,ok,detail,case when ok then 'PASS' else 'FAIL' end status
from checks
union all
select 'RESULTADO_GENERAL',bool_and(ok),'C13-B1 revoke anon owner views',
       case when bool_and(ok) then 'PASS' else 'STOP' end
from checks;

-- Debe devolver 0 filas.
select view_name
from owner_views
where has_table_privilege('anon',format('%I.%I',schema_name,view_name),'SELECT')
order by view_name;
