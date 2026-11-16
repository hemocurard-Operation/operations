begin;
insert into public.app_permissions(permission_code,module,description)
values('OPERATIONAL_OUTLOOK_VIEW','OPERACIONES','Consultar cobertura de insumos, donantes y expediente de equipos') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code)
select id,'OPERATIONAL_OUTLOOK_VIEW' from public.roles
where code in ('SUPER_USUARIO','GERENCIA_GENERAL','GERENCIA_OPERATIVA','ENCARGADA_LABORATORIO','CALIDAD','ADMIN') on conflict do nothing;
insert into public.app_module_catalog(route_key,title,group_name,permission_code) values
('operationsoutlook','Previsión operativa','GESTIÓN','OPERATIONAL_OUTLOOK_VIEW'),
('licenses','Habilitaciones sanitarias','CALIDAD Y SEGURIDAD','LICENSE_VIEW'),
('regulatorymatrix','Matriz regulatoria','CALIDAD Y SEGURIDAD','REGULATORY_VIEW'),
('commercialgoals','Metas operativas','CADENA DE VALOR','COMMERCIAL_VIEW')
on conflict(route_key) do nothing;
insert into public.role_module_access(role_id,route_key,enabled)
select r.id,m.route_key,case when r.code='SUPER_USUARIO' then true else exists(
select 1 from public.role_permissions p where p.role_id=r.id and p.permission_code=m.permission_code) end
from public.roles r cross join public.app_module_catalog m
where m.route_key in ('operationsoutlook','licenses','regulatorymatrix','commercialgoals') on conflict do nothing;
notify pgrst,'reload schema';
commit;
