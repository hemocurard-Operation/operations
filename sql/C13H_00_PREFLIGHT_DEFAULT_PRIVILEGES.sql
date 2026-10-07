-- =====================================================================
-- HemoCura · C13-H · DEFAULT PRIVILEGE GOVERNANCE · PREFLIGHT READ ONLY
-- Version objetivo: 0.44.15
--
-- Objetivo: detectar privilegios DEFAULT que volverían a abrir superficies
-- futuras aunque las tablas/funciones actuales ya hayan sido endurecidas.
-- Scope deliberado: owner postgres + schema public.
-- No toca auth/storage/graphql/realtime ni objetos existentes.
-- =====================================================================

with acl as (
  select
    pg_get_userbyid(d.defaclrole) as owner_role,
    n.nspname as schema_name,
    d.defaclobjtype,
    coalesce(r.rolname,'PUBLIC') as grantee,
    x.privilege_type,
    x.is_grantable
  from pg_default_acl d
  join pg_namespace n on n.oid=d.defaclnamespace
  cross join lateral aclexplode(d.defaclacl) x
  left join pg_roles r on r.oid=x.grantee
  where pg_get_userbyid(d.defaclrole)='postgres'
    and n.nspname='public'
), risky as (
  select *
  from acl
  where grantee in ('anon','authenticated','PUBLIC')
    and (
      defaclobjtype in ('r','S')
      or (defaclobjtype='f' and privilege_type='EXECUTE')
    )
)
select jsonb_build_object(
  'current_user',current_user,
  'public_schema_owner',(select pg_get_userbyid(nspowner) from pg_namespace where nspname='public'),
  'risky_default_count',(select count(*) from risky),
  'by_grantee',coalesce((
    select jsonb_object_agg(grantee,cnt)
    from (select grantee,count(*) cnt from risky group by grantee) x
  ),'{}'::jsonb),
  'by_object_type',coalesce((
    select jsonb_object_agg(defaclobjtype,cnt)
    from (select defaclobjtype,count(*) cnt from risky group by defaclobjtype) x
  ),'{}'::jsonb),
  'details',coalesce((
    select jsonb_agg(to_jsonb(r) order by grantee,defaclobjtype,privilege_type)
    from risky r
  ),'[]'::jsonb)
) as c13h_preflight;
