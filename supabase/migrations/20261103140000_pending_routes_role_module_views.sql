begin;
-- Fixes a real access bug: the transport (#47) and isocompliance (#48) routes were
-- mounted in the frontend and permission-mapped, but never registered in
-- app_module_catalog / role_module_access. vw_my_module_access only lists routes
-- that exist in app_module_catalog, and canRoute() in access-control.js denies any
-- route missing from that set for EVERY role, including SUPER_USUARIO. Both routes
-- have therefore been completely unreachable since merge, despite working code.
--
-- This file intentionally ends in _role_module_views.sql so that
-- tools/workflow_postgres_runner.py (the CI job that applies every migration
-- against a disposable Postgres) defers it to the same bucket as the original
-- 20261016223120_role_module_views.sql, applied after app_module_catalog exists.
-- This also registers the new "environmental" route added alongside it.

insert into public.app_module_catalog(route_key,title,group_name,permission_code) values
('transport','Transporte','TRABAJO DIARIO','COLD_CHAIN_VIEW'),
('isocompliance','Cumplimiento ISO 9001/15189','CALIDAD Y SEGURIDAD','ISO_COMPLIANCE_VIEW'),
('environmental','Control Ambiental y Temperaturas','LABORATORIO Y SANGRE','RESOURCES_VIEW')
on conflict(route_key) do update set
  title=excluded.title,group_name=excluded.group_name,permission_code=excluded.permission_code;

-- Mirror the role access of the closest existing route, same pattern used by
-- 20261017023416_sgc_implementation_project.sql for sgcimplementation/quality.
insert into public.role_module_access(role_id,route_key,enabled)
select r.id,'transport',coalesce((select enabled from public.role_module_access m where m.role_id=r.id and route_key='coldchain'),false)
from public.roles r
on conflict(role_id,route_key) do update set enabled=excluded.enabled;

insert into public.role_module_access(role_id,route_key,enabled)
select r.id,'isocompliance',coalesce((select enabled from public.role_module_access m where m.role_id=r.id and route_key='quality'),false)
from public.roles r
on conflict(role_id,route_key) do update set enabled=excluded.enabled;

insert into public.role_module_access(role_id,route_key,enabled)
select r.id,'environmental',coalesce((select enabled from public.role_module_access m where m.role_id=r.id and route_key='resources'),false)
from public.roles r
on conflict(role_id,route_key) do update set enabled=excluded.enabled;

notify pgrst,'reload schema';
commit;
