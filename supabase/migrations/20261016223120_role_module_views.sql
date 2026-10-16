begin;
create table public.app_module_catalog(
 route_key text primary key,title text not null,group_name text not null,
 permission_code text not null references public.app_permissions(permission_code),active boolean not null default true
);
create table public.role_module_access(
 role_id uuid not null references public.roles(id),route_key text not null references public.app_module_catalog(route_key),
 enabled boolean not null default false,revision integer not null default 1,
 updated_by uuid references public.profiles(id),updated_at timestamptz not null default now(),primary key(role_id,route_key)
);
create table public.role_module_changes(
 id uuid primary key default gen_random_uuid(),role_id uuid not null references public.roles(id),route_key text not null,
 was_enabled boolean not null,is_enabled boolean not null,actor_id uuid not null references public.profiles(id),changed_at timestamptz not null default now()
);
create index role_module_access_route_idx on public.role_module_access(route_key,role_id);
create index role_module_changes_role_idx on public.role_module_changes(role_id,changed_at desc);
alter table public.app_module_catalog enable row level security;
alter table public.role_module_access enable row level security;
alter table public.role_module_changes enable row level security;
revoke all on public.app_module_catalog,public.role_module_access,public.role_module_changes from public,anon,authenticated;
grant select on public.app_module_catalog,public.role_module_access,public.role_module_changes to authenticated;
grant update(enabled) on public.role_module_access to authenticated;
create policy module_catalog_read on public.app_module_catalog for select to authenticated using((select public.wf_active_actor()));
create policy role_module_read on public.role_module_access for select to authenticated using((select public.wf_active_actor()) and ((select public.has_permission('ACCESS_ADMIN')) or role_id in (select ur.role_id from public.user_roles ur where ur.user_id=(select auth.uid()))));
create policy role_module_update on public.role_module_access for update to authenticated using((select public.wf_active_actor()) and (select public.has_permission('ACCESS_ADMIN')) and (select public.has_role('SUPER_USUARIO'))) with check((select public.wf_active_actor()) and (select public.has_permission('ACCESS_ADMIN')) and (select public.has_role('SUPER_USUARIO')));
create policy module_changes_read on public.role_module_changes for select to authenticated using((select public.wf_active_actor()) and (select public.has_permission('ACCESS_ADMIN')));
insert into public.app_module_catalog(route_key,title,group_name,permission_code) values
('mywork','Mi trabajo','INICIO','DASHBOARD_VIEW'),
('workflow','Ruta operativa','INICIO','WORKFLOW_VIEW'),
('dashboard','Inicio','INICIO','DASHBOARD_VIEW'),
('command','Centro de Mando','INICIO','COMMAND_VIEW'),
('decisioncenter','Centro de Decisión','INICIO','DECISION_CENTER_VIEW'),
('predictive','Cockpit Predictivo','INICIO','PREDICTIVE_VIEW'),
('orchestration','Orquestación y Resiliencia','INICIO','ORCHESTRATION_VIEW'),
('quickcapture','Captura rápida','TRABAJO DIARIO','DASHBOARD_VIEW'),
('dailyinventory','Reporte Operativo Diario','TRABAJO DIARIO','DAILY_REPORT_VIEW'),
('dispatches','Despachos','TRABAJO DIARIO','DISPATCH_VIEW'),
('requisitions','Requisiciones','TRABAJO DIARIO','DISPATCH_VIEW'),
('sales','Ventas / Salidas','TRABAJO DIARIO','SALES_VIEW'),
('hyperbaric','Cámara hiperbárica','TRABAJO DIARIO','HYPERBARIC_VIEW'),
('shiftreport','Ventas por turno','TRABAJO DIARIO','SALES_VIEW'),
('transfers','Entre sucursales','TRABAJO DIARIO','BLOOD_INVENTORY_VIEW'),
('supplycatalog','Catálogo de suministros','TRABAJO DIARIO','SUPPLY_VIEW'),
('inventory','Insumos','TRABAJO DIARIO','BLOOD_INVENTORY_VIEW'),
('supply','Abastecimiento','TRABAJO DIARIO','SUPPLY_VIEW'),
('planning','Planificación','TRABAJO DIARIO','SUPPLY_VIEW'),
('valuechain','Cadena de Valor','CADENA DE VALOR','VALUE_CHAIN_VIEW'),
('serviceperformance','Desempeño y SLA','CADENA DE VALOR','SERVICE_PERFORMANCE_VIEW'),
('donoroutreach','Captación de Donantes','CADENA DE VALOR','DONOR_OUTREACH_VIEW'),
('medicalnetwork','Red Médica','CADENA DE VALOR','MEDICAL_NETWORK_VIEW'),
('customers','Clientes y SLA','CADENA DE VALOR','CUSTOMER_VIEW'),
('commercial','Gestión comercial','CADENA DE VALOR','COMMERCIAL_VIEW'),
('collections','Cobranza y Aging','CADENA DE VALOR','COLLECTIONS_VIEW'),
('economics','Economía y Merma','CADENA DE VALOR','ECONOMICS_VIEW'),
('donors','Donantes','LABORATORIO Y SANGRE','DONORS_VIEW'),
('screening','Tamizaje','LABORATORIO Y SANGRE','SCREENING_VIEW'),
('production','Producción','LABORATORIO Y SANGRE','BLOOD_INVENTORY_WRITE'),
('bloodinventory','Inventario de Sangre','LABORATORIO Y SANGRE','BLOOD_INVENTORY_VIEW'),
('bloodflow','Flujo Sanguíneo','LABORATORIO Y SANGRE','BLOOD_INVENTORY_VIEW'),
('analyticalqc','Calidad Analítica','LABORATORIO Y SANGRE','ANALYTICAL_QC_VIEW'),
('coldchain','Cadena de Frío','LABORATORIO Y SANGRE','COLD_CHAIN_VIEW'),
('hemovigilance','Hemovigilancia','LABORATORIO Y SANGRE','HEMOVIGILANCE_VIEW'),
('resources','Recursos Críticos','LABORATORIO Y SANGRE','RESOURCES_VIEW'),
('actions','Acciones Integradas','CALIDAD Y SEGURIDAD','ACTIONS_VIEW'),
('bloodquality','Calidad del banco de sangre','CALIDAD Y SEGURIDAD','QUALITY_VIEW'),
('quality','SGC','CALIDAD Y SEGURIDAD','QUALITY_VIEW'),
('approvals','Aprobaciones','CALIDAD Y SEGURIDAD','APPROVAL_VIEW'),
('qmsgov','Gobierno QMS','CALIDAD Y SEGURIDAD','QUALITY_VIEW'),
('internalaudits','Auditorías Internas','CALIDAD Y SEGURIDAD','INTERNAL_AUDIT_VIEW'),
('inspections','Inspecciones','CALIDAD Y SEGURIDAD','QUALITY_VIEW'),
('training','Mi Capacitación','CALIDAD Y SEGURIDAD','TRAINING_SELF'),
('competencies','Competencias','CALIDAD Y SEGURIDAD','COMPETENCY_VIEW'),
('documents','Control Documental','CALIDAD Y SEGURIDAD','DOCUMENTS_VIEW'),
('compliance','Compliance Penal','CALIDAD Y SEGURIDAD','COMPLIANCE_VIEW'),
('bi','Inteligencia de Negocios','GESTIÓN','BI_VIEW'),
('management','Revisión Dirección','GESTIÓN','MANAGEMENT_REVIEW_VIEW'),
('projects','Proyectos','GESTIÓN','PROJECTS_VIEW'),
('continuity','Continuidad','GESTIÓN','CONTINUITY_VIEW'),
('suppliers','Pedidos y proveedores','GESTIÓN','SUPPLIERS_VIEW'),
('settings','Configuración','ADMINISTRACIÓN','ADMIN_VIEW'),
('users','Usuarios y Roles','ADMINISTRACIÓN','ACCESS_ADMIN'),
('security','Seguridad y Acceso','ADMINISTRACIÓN','ACCESS_ADMIN'),
('diagnostics','Diagnóstico','ADMINISTRACIÓN','RELEASE_GATE_VIEW'),
('audit','Auditoría del Sistema','ADMINISTRACIÓN','AUDIT_VIEW'),
('uat','Validación UAT','ADMINISTRACIÓN','RELEASE_GATE_VIEW'),
('integration','Integración','ADMINISTRACIÓN','RELEASE_GATE_VIEW'),
('releasegate','Release Gate','ADMINISTRACIÓN','RELEASE_GATE_VIEW'),
('release1','Release 1.0','ADMINISTRACIÓN','RELEASE_GATE_VIEW'),
('qa','QA Técnico','ADMINISTRACIÓN','RELEASE_GATE_VIEW');
insert into public.role_module_access(role_id,route_key,enabled) select r.id,m.route_key,
 case r.code
 when 'SUPER_USUARIO' then m.route_key=any(array['mywork','workflow','dashboard','command','decisioncenter','predictive','orchestration','quickcapture','dailyinventory','dispatches','requisitions','sales','hyperbaric','shiftreport','transfers','supplycatalog','inventory','supply','planning','valuechain','serviceperformance','donoroutreach','medicalnetwork','customers','commercial','collections','economics','donors','screening','production','bloodinventory','bloodflow','analyticalqc','coldchain','hemovigilance','resources','actions','bloodquality','quality','approvals','qmsgov','internalaudits','inspections','training','competencies','documents','compliance','bi','management','projects','continuity','suppliers','settings','users','security','diagnostics','audit','uat','integration','releasegate','release1','qa']::text[])
 when 'ADMIN' then m.route_key=any(array['mywork','workflow','dashboard','command','decisioncenter','quickcapture','dailyinventory','dispatches','requisitions','sales','hyperbaric','shiftreport','transfers','supplycatalog','inventory','supply','planning','valuechain','serviceperformance','donoroutreach','medicalnetwork','customers','commercial','collections','economics','donors','screening','production','bloodinventory','bloodflow','analyticalqc','coldchain','hemovigilance','resources','actions','bloodquality','quality','approvals','qmsgov','internalaudits','inspections','training','competencies','documents','compliance','bi','management','projects','continuity','suppliers','settings']::text[])
 when 'ASISTENTE_OPERACIONES' then m.route_key=any(array['mywork','dashboard','training','documents','workflow','donors','donoroutreach','dailyinventory','bloodinventory','dispatches','requisitions','supplycatalog','supply','suppliers','customers','commercial','medicalnetwork','sales','shiftreport']::text[])
 when 'LABORATORIO' then m.route_key=any(array['mywork','dashboard','training','documents','workflow','donors','screening','production','bloodinventory','bloodflow','dailyinventory','transfers','dispatches','requisitions','supplycatalog','supply','resources','coldchain','analyticalqc','bloodquality','hemovigilance']::text[])
 when 'ENCARGADA_LABORATORIO' then m.route_key=any(array['mywork','dashboard','training','documents','workflow','donors','screening','production','bloodinventory','bloodflow','dailyinventory','transfers','dispatches','requisitions','supplycatalog','supply','resources','coldchain','analyticalqc','bloodquality','hemovigilance','suppliers','quality','inspections','approvals','actions','competencies']::text[])
 when 'INVENTARIO' then m.route_key=any(array['mywork','dashboard','training','documents','workflow','inventory','supplycatalog','supply','bloodinventory','dailyinventory','transfers','dispatches','requisitions','suppliers','resources','coldchain']::text[])
 when 'FINANZAS' then m.route_key=any(array['mywork','dashboard','training','documents','sales','shiftreport','collections','economics','customers','suppliers','bi','commercial']::text[])
 when 'CALIDAD' then m.route_key=any(array['mywork','dashboard','training','documents','workflow','quality','bloodquality','qmsgov','inspections','internalaudits','actions','approvals','analyticalqc','coldchain','hemovigilance','resources','competencies','compliance','management','suppliers','dailyinventory','bloodinventory']::text[])
 when 'GERENCIA_OPERATIVA' then m.route_key=any(array['mywork','dashboard','training','documents','workflow','command','decisioncenter','dailyinventory','donors','donoroutreach','bloodinventory','transfers','dispatches','requisitions','supplycatalog','supply','suppliers','sales','shiftreport','commercial','customers','medicalnetwork','serviceperformance','valuechain','quality','bloodquality','actions','approvals','management','bi','projects']::text[])
 when 'GERENCIA_GENERAL' then m.route_key=any(array['mywork','dashboard','training','documents','command','decisioncenter','sales','shiftreport','collections','economics','suppliers','customers','commercial','medicalnetwork','serviceperformance','valuechain','quality','approvals','management','bi','projects','compliance']::text[])
 when 'SOCIO' then m.route_key=any(array['mywork','dashboard','training','documents','sales','shiftreport','collections','economics','customers','serviceperformance','valuechain','management','bi']::text[])
 when 'MEDICO_GERENTE_TECNICO' then m.route_key=any(array['mywork','dashboard','training','documents','workflow','donors','screening','production','bloodinventory','bloodflow','dailyinventory','transfers','dispatches','requisitions','supplycatalog','supply','resources','coldchain','analyticalqc','bloodquality','hemovigilance','hyperbaric','quality','actions']::text[])
 when 'SUCURSAL' then m.route_key=any(array['mywork','dashboard','training','documents','workflow','donors','screening','bloodinventory','dailyinventory','transfers','dispatches','requisitions','supplycatalog','supply','sales','shiftreport','customers','quality']::text[])
 when 'CONSULTA' then m.route_key=any(array['mywork','dashboard','training','documents','bloodinventory','supply','dailyinventory','quality','bi']::text[])
 when 'TI' then m.route_key=any(array['training','diagnostics','audit','integration','releasegate','release1','qa','uat','continuity']::text[])
 else false end from public.roles r cross join public.app_module_catalog m;
create or replace view public.vw_my_module_access with(security_invoker=true) as
select m.route_key,m.permission_code,
 public.wf_active_actor() and m.active and public.has_permission(m.permission_code)
 and (public.has_role('SUPER_USUARIO') or exists(select 1 from public.role_module_access rm join public.user_roles ur on ur.role_id=rm.role_id where ur.user_id=auth.uid() and rm.route_key=m.route_key and rm.enabled)) as enabled
from public.app_module_catalog m;
revoke all on public.vw_my_module_access from public,anon;
grant select on public.vw_my_module_access to authenticated;
create or replace function private.guard_role_module_change() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null or not public.wf_active_actor() or not public.has_role('SUPER_USUARIO') or not public.has_permission('ACCESS_ADMIN') then raise exception 'Solo el Super Usuario puede modificar los módulos por rol.' using errcode='42501';end if;
 if new.role_id<>old.role_id or new.route_key<>old.route_key then raise exception 'La identidad de la configuración no puede cambiar.';end if;
 if exists(select 1 from public.roles where id=old.role_id and code='SUPER_USUARIO') then raise exception 'El Super Usuario conserva acceso total.';end if;
 if new.enabled and new.route_key in ('users','security') then raise exception 'La administración de usuarios es exclusiva del Super Usuario.';end if;
 new.revision:=old.revision+1;new.updated_by:=auth.uid();new.updated_at:=now();
 if new.enabled is distinct from old.enabled then
  insert into public.role_module_changes(role_id,route_key,was_enabled,is_enabled,actor_id) values(new.role_id,new.route_key,old.enabled,new.enabled,auth.uid());
 end if;
 return new;
end$$;
revoke all on function private.guard_role_module_change() from public,anon,authenticated;
create trigger role_module_change before update on public.role_module_access for each row execute function private.guard_role_module_change();
create function public.set_role_modules(p_role uuid,p_changes jsonb) returns jsonb
language plpgsql security invoker set search_path=public,pg_temp as $$
declare x record;n integer:=0;updated integer;
begin
 if auth.uid() is null or not public.wf_active_actor() or not public.has_role('SUPER_USUARIO') or not public.has_permission('ACCESS_ADMIN') then raise exception 'Solo el Super Usuario puede modificar los módulos por rol.' using errcode='42501';end if;
 if jsonb_typeof(p_changes) is distinct from 'array' then raise exception 'Formato de cambios no válido.';end if;
 if jsonb_array_length(p_changes)>200 then raise exception 'Demasiados cambios.';end if;
 if exists(select 1 from jsonb_array_elements(p_changes) j group by j->>'route_key' having count(*)>1) then raise exception 'Hay módulos duplicados.';end if;
 for x in select * from jsonb_to_recordset(p_changes) as t(route_key text,enabled boolean,revision integer) order by route_key loop
  if x.route_key is null or x.enabled is null or x.revision is null then raise exception 'Faltan datos del cambio.';end if;
  update public.role_module_access set enabled=x.enabled where role_id=p_role and route_key=x.route_key and revision=x.revision;
  get diagnostics updated=row_count;
  if updated<>1 then raise exception 'La configuración cambió. Actualice y vuelva a intentar.' using errcode='40001';end if;
  n:=n+1;
 end loop;
 return jsonb_build_object('updated',n);
end$$;
revoke all on function public.set_role_modules(uuid,jsonb) from public,anon;
grant execute on function public.set_role_modules(uuid,jsonb) to authenticated;
comment on table public.role_module_access is 'Activación de ventanas por rol, adicional a los permisos de datos existentes. Múltiples roles combinan sus ventanas; Super Usuario conserva todas.';
notify pgrst,'reload schema';
commit;
