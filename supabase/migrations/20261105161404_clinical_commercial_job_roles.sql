begin;
-- Job catalog only. No people, credentials, assignments or clinical approvals created.
insert into public.roles(code,name) values('CAMARISTA_HIPERBARICA','Camarista de cámara hiperbárica'),('ASISTENTE_COMERCIAL','Asistente comercial') on conflict(code) do nothing;
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r cross join public.app_permissions p where p.active and (
 r.code='CAMARISTA_HIPERBARICA' and p.permission_code in ('DASHBOARD_VIEW','HYPERBARIC_VIEW','HYPERBARIC_WRITE','HYPERBARIC_SESSION_WRITE','HYPERBARIC_PATIENT_PII','TRAINING_SELF','WORK_AGENDA_VIEW','WORK_AGENDA_WRITE') or
 r.code='ASISTENTE_COMERCIAL' and p.permission_code in ('DASHBOARD_VIEW','COMMERCIAL_VIEW','COMMERCIAL_WRITE','CUSTOMER_VIEW','MEDICAL_NETWORK_VIEW','TRAINING_SELF','WORK_AGENDA_VIEW','WORK_AGENDA_WRITE')) on conflict do nothing;
insert into public.role_module_access(role_id,route_key,enabled)
select r.id,m.route_key,case when r.code='CAMARISTA_HIPERBARICA' then m.route_key in ('mywork','hyperbaric','areaagenda','training') else m.route_key in ('mywork','commercial','commercialcalendar','customers','medicalnetwork','areaagenda','training') end
from public.roles r cross join public.app_module_catalog m where r.code in ('CAMARISTA_HIPERBARICA','ASISTENTE_COMERCIAL') on conflict do nothing;
insert into public.work_areas(code,name) values('CAMARA_HIPERBARICA','Cámara hiperbárica') on conflict(code) do nothing;
insert into public.work_area_roles(area_code,role_id,can_manage,can_review)
select case when r.code='ASISTENTE_COMERCIAL' then 'COMERCIAL' else 'CAMARA_HIPERBARICA' end,r.id,r.code='SUPER_USUARIO',r.code='SUPER_USUARIO' from public.roles r where r.code in ('CAMARISTA_HIPERBARICA','ASISTENTE_COMERCIAL','SUPER_USUARIO') on conflict do nothing;
notify pgrst,'reload schema';
commit;
