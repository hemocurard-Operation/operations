-- =====================================================================
-- HemoCura · C13-B · PREFLIGHT SECURITY DEFINER VIEWS · READ ONLY
-- I-012 reconciliation: exposure + critical-target dependency checks.
-- No modifica vistas, grants, RLS, datos ni app_migrations.
-- =====================================================================

-- 1) Superficie actual de views public.
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

-- 2) Resumen de exposición. En el baseline I-012 esperado:
--    82 views public / 15 invoker / 67 owner-privilege.
select jsonb_build_object(
  'public_views_total',count(*),
  'security_invoker_true',count(*) filter(
    where coalesce(array_to_string(c.reloptions,','),'') ilike '%security_invoker=true%'
  ),
  'owner_privilege_views',count(*) filter(
    where coalesce(array_to_string(c.reloptions,','),'') not ilike '%security_invoker=true%'
  ),
  'anon_selectable_views',count(*) filter(
    where has_table_privilege('anon',format('%I.%I',n.nspname,c.relname),'SELECT')
  ),
  'anon_selectable_owner_views',count(*) filter(
    where coalesce(array_to_string(c.reloptions,','),'') not ilike '%security_invoker=true%'
      and has_table_privilege('anon',format('%I.%I',n.nspname,c.relname),'SELECT')
  ),
  'authenticated_selectable_views',count(*) filter(
    where has_table_privilege('authenticated',format('%I.%I',n.nspname,c.relname),'SELECT')
  ),
  'authenticated_selectable_owner_views',count(*) filter(
    where coalesce(array_to_string(c.reloptions,','),'') not ilike '%security_invoker=true%'
      and has_table_privilege('authenticated',format('%I.%I',n.nspname,c.relname),'SELECT')
  )
) as c13b_summary
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='v';

-- 3) Compatibilidad directa de los 10 targets del candidato C13-B2.
--    Para security_invoker, authenticated debe conservar SELECT sobre las
--    dependencias directas y las tablas base deben mantener RLS habilitado.
with targets(view_name) as (
 values
 ('vw_app_migration_readiness'),
 ('vw_blood_flow_status'),
 ('vw_blood_inventory_available'),
 ('vw_cold_chain_excursions'),
 ('vw_hemovigilance_summary'),
 ('vw_my_access'),
 ('vw_my_security_context'),
 ('vw_release_1_0_readiness'),
 ('vw_screening_release_queue'),
 ('vw_uat_summary')
), target_oids as (
 select t.view_name,c.oid,
        coalesce(array_to_string(c.reloptions,','),'') ilike '%security_invoker=true%' as security_invoker,
        has_table_privilege('anon',format('public.%I',t.view_name),'SELECT') as anon_select,
        has_table_privilege('authenticated',format('public.%I',t.view_name),'SELECT') as authenticated_select
 from targets t
 join pg_class c on c.relname=t.view_name
 join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
 where c.relkind='v'
), deps as (
 select distinct t.view_name,
        rn.nspname as dep_schema,
        rc.relname as dep_name,
        rc.relkind,
        rc.relrowsecurity,
        has_table_privilege('authenticated',format('%I.%I',rn.nspname,rc.relname),'SELECT') as auth_select
 from target_oids t
 join pg_rewrite rw on rw.ev_class=t.oid
 join pg_depend d
   on d.classid='pg_rewrite'::regclass
  and d.objid=rw.oid
  and d.refclassid='pg_class'::regclass
 join pg_class rc on rc.oid=d.refobjid
 join pg_namespace rn on rn.oid=rc.relnamespace
 where rc.oid<>t.oid
   and rn.nspname not in ('pg_catalog','information_schema')
   and rc.relkind in ('r','p','v','m')
), roll as (
 select view_name,
        count(*) as direct_dependencies,
        count(*) filter(where not auth_select) as dependencies_missing_auth_select,
        count(*) filter(where relkind in ('r','p') and not relrowsecurity) as base_tables_without_rls
 from deps
 group by view_name
), state as (
 select t.view_name,
        o.security_invoker,
        o.anon_select,
        o.authenticated_select,
        coalesce(r.direct_dependencies,0) as direct_dependencies,
        coalesce(r.dependencies_missing_auth_select,0) as dependencies_missing_auth_select,
        coalesce(r.base_tables_without_rls,0) as base_tables_without_rls,
        coalesce(r.dependencies_missing_auth_select,0)=0
          and coalesce(r.base_tables_without_rls,0)=0 as direct_compatibility_pass
 from targets t
 left join target_oids o using(view_name)
 left join roll r using(view_name)
)
select * from state order by view_name;

-- 4) Gate de PREPARACIÓN solamente. PASS no autoriza aplicar C13-B2 fuera
--    de la secuencia de remediación aprobada.
with targets(view_name) as (
 values
 ('vw_app_migration_readiness'),
 ('vw_blood_flow_status'),
 ('vw_blood_inventory_available'),
 ('vw_cold_chain_excursions'),
 ('vw_hemovigilance_summary'),
 ('vw_my_access'),
 ('vw_my_security_context'),
 ('vw_release_1_0_readiness'),
 ('vw_screening_release_queue'),
 ('vw_uat_summary')
), target_oids as (
 select t.view_name,c.oid
 from targets t
 join pg_class c on c.relname=t.view_name
 join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
 where c.relkind='v'
), deps as (
 select distinct t.view_name,
        rc.relkind,
        rc.relrowsecurity,
        has_table_privilege('authenticated',format('%I.%I',rn.nspname,rc.relname),'SELECT') as auth_select
 from target_oids t
 join pg_rewrite rw on rw.ev_class=t.oid
 join pg_depend d
   on d.classid='pg_rewrite'::regclass
  and d.objid=rw.oid
  and d.refclassid='pg_class'::regclass
 join pg_class rc on rc.oid=d.refobjid
 join pg_namespace rn on rn.oid=rc.relnamespace
 where rc.oid<>t.oid
   and rn.nspname not in ('pg_catalog','information_schema')
   and rc.relkind in ('r','p','v','m')
), compat as (
 select t.view_name,
        count(d.*) filter(where d.auth_select=false) as missing_auth_select,
        count(d.*) filter(where d.relkind in ('r','p') and d.relrowsecurity=false) as rls_off
 from targets t
 left join deps d using(view_name)
 group by t.view_name
)
select jsonb_build_object(
  'targets_expected',10,
  'targets_present',(select count(*) from target_oids),
  'targets_direct_compatible',count(*) filter(where missing_auth_select=0 and rls_off=0),
  'missing_auth_dependency_grants',sum(missing_auth_select),
  'base_table_rls_off',sum(rls_off),
  'candidate_preflight',case
    when (select count(*) from target_oids)=10
     and bool_and(missing_auth_select=0 and rls_off=0)
    then 'PASS_PREPARED_NOT_APPLIED'
    else 'STOP_REVIEW_REQUIRED'
  end
) as c13b2_candidate_preflight
from compat;
