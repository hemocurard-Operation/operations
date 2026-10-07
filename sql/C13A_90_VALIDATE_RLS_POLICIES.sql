-- =====================================================================
-- HemoCura · C13-A · VALIDATE RLS POLICIES · READ ONLY
-- Ejecutar DESPUÉS de C13A_01_RLS_POLICY_CANDIDATE.sql
-- =====================================================================

with targets(name) as (
 values
 ('app_feature_flags'),('blood_unit_tests'),('deployment_events'),('deployment_releases'),('dispatch_unit_allocations'),
 ('hc_gate_requirements'),('hc_gate_versions'),('integration_outbox'),('inventory_lots'),('migration_issues'),
 ('product_control_modes'),('recipient_issues'),('stg_requerimientos'),('stg_resp_despachos'),('storage_devices'),
 ('storage_excursions'),('system_operating_mode'),('temperature_policies'),('temperature_readings')
), checks(name,ok,detail) as (
 values
 ('ALL_19_HAVE_POLICY',
  not exists(
    select 1 from targets t
    where not exists(
      select 1 from pg_policies p
      where p.schemaname='public' and p.tablename=t.name
    )
  ),
  'Las 19 tablas tienen al menos una policy'),

 ('NO_ANON_DIRECT_ACCESS',
  not exists(
    select 1 from targets t
    where has_table_privilege('anon','public.'||t.name,'SELECT')
       or has_table_privilege('anon','public.'||t.name,'INSERT')
       or has_table_privilege('anon','public.'||t.name,'UPDATE')
       or has_table_privilege('anon','public.'||t.name,'DELETE')
       or has_table_privilege('anon','public.'||t.name,'TRUNCATE')
  ),
  'anon sin acceso directo'),

 ('NO_AUTH_TRUNCATE',
  not exists(
    select 1 from targets t
    where has_table_privilege('authenticated','public.'||t.name,'TRUNCATE')
  ),
  'authenticated sin TRUNCATE'),

 ('NO_AUTH_DELETE_CLINICAL',
  not has_table_privilege('authenticated','public.blood_unit_tests','DELETE')
  and not has_table_privilege('authenticated','public.dispatch_unit_allocations','DELETE')
  and not has_table_privilege('authenticated','public.inventory_lots','DELETE')
  and not has_table_privilege('authenticated','public.recipient_issues','DELETE')
  and not has_table_privilege('authenticated','public.temperature_readings','DELETE')
  and not has_table_privilege('authenticated','public.storage_excursions','DELETE'),
  'sin DELETE directo en trazabilidad clínica/cadena de frío'),

 ('TEMPERATURE_APPEND_ONLY',
  has_table_privilege('authenticated','public.temperature_readings','SELECT')
  and has_table_privilege('authenticated','public.temperature_readings','INSERT')
  and not has_table_privilege('authenticated','public.temperature_readings','UPDATE')
  and not has_table_privilege('authenticated','public.temperature_readings','DELETE'),
  'temperature_readings SELECT+INSERT únicamente'),

 ('INTERNAL_TABLES_READ_ONLY',
  not has_table_privilege('authenticated','public.integration_outbox','INSERT')
  and not has_table_privilege('authenticated','public.integration_outbox','UPDATE')
  and not has_table_privilege('authenticated','public.integration_outbox','DELETE')
  and not has_table_privilege('authenticated','public.stg_requerimientos','INSERT')
  and not has_table_privilege('authenticated','public.stg_resp_despachos','INSERT')
  and not has_table_privilege('authenticated','public.hc_gate_versions','INSERT')
  and not has_table_privilege('authenticated','public.hc_gate_requirements','INSERT'),
  'outbox/staging/gate sin escritura directa desde browser'),

 ('BRANCH_SCOPED_POLICIES',
  exists(select 1 from pg_policies where schemaname='public' and tablename='inventory_lots' and coalesce(qual,'') ilike '%can_access_branch%')
  and exists(select 1 from pg_policies where schemaname='public' and tablename='storage_devices' and coalesce(qual,'') ilike '%can_access_branch%')
  and exists(select 1 from pg_policies where schemaname='public' and tablename='blood_unit_tests' and coalesce(qual,'') ilike '%can_access_branch%')
  and exists(select 1 from pg_policies where schemaname='public' and tablename='dispatch_unit_allocations' and coalesce(qual,'') ilike '%can_access_branch%')
  and exists(select 1 from pg_policies where schemaname='public' and tablename='recipient_issues' and coalesce(qual,'') ilike '%can_access_branch%'),
  'operación clínica/inventario con scope de sucursal'),

 ('C13A_REGISTERED',
  exists(select 1 from public.app_migrations where migration_code='C13A_RLS_NO_POLICY_v0_44_4'),
  'app_migrations C13A_RLS_NO_POLICY_v0_44_4')
)
select name,ok,detail,case when ok then 'PASS' else 'FAIL' end as status
from checks
union all
select 'RESULTADO_GENERAL',bool_and(ok),'C13-A RLS remediation',
       case when bool_and(ok) then 'PASS' else 'STOP' end
from checks;

-- Evidencia complementaria: debe devolver 0 filas.
select c.relname as table_without_policy
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public'
  and c.relkind='r'
  and c.relrowsecurity
  and c.relname in (
    'app_feature_flags','blood_unit_tests','deployment_events','deployment_releases','dispatch_unit_allocations',
    'hc_gate_requirements','hc_gate_versions','integration_outbox','inventory_lots','migration_issues',
    'product_control_modes','recipient_issues','stg_requerimientos','stg_resp_despachos','storage_devices',
    'storage_excursions','system_operating_mode','temperature_policies','temperature_readings'
  )
  and not exists(select 1 from pg_policy p where p.polrelid=c.oid)
order by c.relname;
