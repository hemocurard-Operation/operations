begin;
-- Additive team roles only. No existing person, assignment or general access configuration is changed.
insert into public.roles(code,name) values
 ('LOGISTICA_CONDUCTOR','Conductor de Logística'),
 ('LOGISTICA_SUPERVISOR','Supervisor de Logística'),
 ('LOGISTICA_CONSULTA','Consulta de Logística') on conflict(code) do nothing;
insert into public.app_permissions(permission_code,module,description,risk_level) values
 ('TRIPS_READ_ALL','LOGISTICS','Consultar viajes del equipo en sucursales autorizadas, sin modificar','SENSIBLE') on conflict(permission_code) do nothing;
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r cross join public.app_permissions p where
 r.code='LOGISTICA_CONDUCTOR' and p.permission_code in ('DASHBOARD_VIEW','TRIPS_VIEW','TRIPS_WRITE')
 or r.code='LOGISTICA_SUPERVISOR' and p.permission_code in ('DASHBOARD_VIEW','TRIPS_VIEW','TRIPS_WRITE','TRIPS_REVIEW')
 or r.code='LOGISTICA_CONSULTA' and p.permission_code in ('DASHBOARD_VIEW','TRIPS_VIEW','TRIPS_READ_ALL')
on conflict do nothing;
insert into public.role_module_access(role_id,route_key,enabled)
select r.id,m.route_key,m.route_key in ('mywork','extratrips') from public.roles r cross join public.app_module_catalog m
where r.code in ('LOGISTICA_CONDUCTOR','LOGISTICA_SUPERVISOR','LOGISTICA_CONSULTA') on conflict do nothing;
-- Existing worker, reviewer and Finance rules are preserved. This policy grants SELECT only.
create policy logistics_team_consultation on public.logistics_trips for select to authenticated
using(public.logistics_access(branch_id,'TRIPS_READ_ALL'));
comment on policy logistics_team_consultation on public.logistics_trips is 'Team read-only access. Does not confer approval, write, settlement or account administration.';
notify pgrst,'reload schema';
commit;
