begin;
-- Registers the new commercialcalendar route so it's actually reachable
-- (see 20261103140000_pending_routes_role_module_views.sql for why this
-- step is not optional). Filename ends in _role_module_views.sql so
-- tools/workflow_postgres_runner.py defers it to the bucket that applies
-- after app_module_catalog exists.

insert into public.app_module_catalog(route_key,title,group_name,permission_code) values
('commercialcalendar','Agenda Comercial','CADENA DE VALOR','COMMERCIAL_VIEW')
on conflict(route_key) do update set
  title=excluded.title,group_name=excluded.group_name,permission_code=excluded.permission_code;

-- Mirror the role access of the closest existing route (commercial).
insert into public.role_module_access(role_id,route_key,enabled)
select r.id,'commercialcalendar',coalesce((select enabled from public.role_module_access m where m.role_id=r.id and route_key='commercial'),false)
from public.roles r
on conflict(role_id,route_key) do nothing;

notify pgrst,'reload schema';
commit;
