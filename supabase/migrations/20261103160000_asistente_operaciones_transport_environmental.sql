begin;
-- ASISTENTE_OPERACIONES got quick-access dashboard links to transport and
-- environmental (ops-dashboard.js) without ever being granted the underlying
-- COLD_CHAIN_VIEW / RESOURCES_VIEW permission or module access — a dead link
-- to "Acceso denegado" in production. This grants the permission.
--
-- It does NOT flip role_module_access.enabled for these two routes: that
-- table's UPDATE path is guarded by private.guard_role_module_change(),
-- which requires an authenticated Super Usuario session
-- (has_role('SUPER_USUARIO') + has_permission('ACCESS_ADMIN')) and logs the
-- change to role_module_changes. A migration running as the service role has
-- no such session, so that update is rejected by design — confirmed by
-- applying this against production (42501: "Solo el Super Usuario puede
-- modificar los módulos por rol."). The row for both routes already exists
-- (enabled=false, from 20261103140000) for every role, including this one,
-- so a plain INSERT can't bypass the guard either.
--
-- A Super Usuario must enable 'transport' and 'environmental' for
-- ASISTENTE_OPERACIONES from Configuración → Módulos por rol (calls
-- set_role_modules(), which is how this is meant to be done — audited,
-- under a real user).

insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r join public.app_permissions p
on p.permission_code in ('COLD_CHAIN_VIEW','RESOURCES_VIEW')
where r.code='ASISTENTE_OPERACIONES'
on conflict do nothing;

notify pgrst,'reload schema';
commit;
