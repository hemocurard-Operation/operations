-- ============================================================
-- HemoCura v0.29.0
-- Gobierno de Acceso / Roles / Permisos / Diagnóstico RLS
-- Requiere v0.28.0
-- ============================================================
begin;
create extension if not exists pgcrypto;

-- 1) CATÁLOGO DE PERMISOS
create table if not exists public.app_permissions (
  permission_code text primary key,
  module text not null,
  description text not null,
  risk_level text not null default 'NORMAL'
    check(risk_level in ('NORMAL','SENSIBLE','CRITICO')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_code text not null references public.app_permissions(permission_code) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(role_id,permission_code)
);

alter table public.app_permissions enable row level security;
alter table public.role_permissions enable row level security;

drop policy if exists app_permissions_read on public.app_permissions;
create policy app_permissions_read on public.app_permissions
for select using(auth.role()='authenticated');

drop policy if exists role_permissions_read on public.role_permissions;
create policy role_permissions_read on public.role_permissions
for select using(auth.role()='authenticated');

drop policy if exists app_permissions_write on public.app_permissions;
create policy app_permissions_write on public.app_permissions
for all
using(public.has_role('ADMIN'))
with check(public.has_role('ADMIN'));

drop policy if exists role_permissions_write on public.role_permissions;
create policy role_permissions_write on public.role_permissions
for all
using(public.has_role('ADMIN'))
with check(public.has_role('ADMIN'));

grant select on public.app_permissions,public.role_permissions to authenticated;
grant insert,update,delete on public.app_permissions,public.role_permissions to authenticated;

-- 2) PERMISOS BASE DEL SISTEMA
insert into public.app_permissions(permission_code,module,description,risk_level) values
('DASHBOARD_VIEW','DASHBOARD','Ver centro de operaciones','NORMAL'),
('COMMAND_VIEW','COMMAND','Ver centro de mando','SENSIBLE'),
('DAILY_CLOSE_EXECUTE','COMMAND','Ejecutar cierre diario','SENSIBLE'),
('SALES_VIEW','SALES','Ver ventas/salidas','SENSIBLE'),
('SALES_WRITE','SALES','Registrar ventas/salidas','SENSIBLE'),
('DONORS_VIEW','DONORS','Ver donantes','SENSIBLE'),
('DONORS_WRITE','DONORS','Registrar donantes','SENSIBLE'),
('SCREENING_VIEW','SCREENING','Ver tamizaje','SENSIBLE'),
('SCREENING_WRITE','SCREENING','Registrar tamizaje','SENSIBLE'),
('UNIT_RELEASE','BLOOD_FLOW','Liberar o retener unidades','CRITICO'),
('BLOOD_INVENTORY_VIEW','BLOOD_INVENTORY','Ver inventario de sangre','SENSIBLE'),
('BLOOD_INVENTORY_WRITE','BLOOD_INVENTORY','Registrar componentes/unidades','CRITICO'),
('DISPATCH_VIEW','DISPATCH','Ver despachos','SENSIBLE'),
('DISPATCH_WRITE','DISPATCH','Registrar despachos','CRITICO'),
('SUPPLY_VIEW','SUPPLY','Ver planificación de abastecimiento','NORMAL'),
('SUPPLY_WRITE','SUPPLY','Configurar objetivos de stock','SENSIBLE'),
('QUALITY_VIEW','QUALITY','Ver SGC','SENSIBLE'),
('QUALITY_WRITE','QUALITY','Registrar/gestionar NC y CAPA','SENSIBLE'),
('DOCUMENTS_VIEW','DOCUMENTS','Ver documentos controlados','NORMAL'),
('DOCUMENTS_WRITE','DOCUMENTS','Modificar registro documental','SENSIBLE'),
('COMPLIANCE_VIEW','COMPLIANCE','Ver compliance','SENSIBLE'),
('COMPLIANCE_WRITE','COMPLIANCE','Gestionar riesgos de compliance','CRITICO'),
('BI_VIEW','BI','Ver inteligencia de negocios','NORMAL'),
('PROJECTS_VIEW','PROJECTS','Ver proyectos','NORMAL'),
('PROJECTS_WRITE','PROJECTS','Gestionar proyectos','SENSIBLE'),
('AUDIT_VIEW','AUDIT','Ver auditoría y trazabilidad','CRITICO'),
('RELEASE_GATE_VIEW','RELEASE','Ver diagnóstico de release','SENSIBLE'),
('ADMIN_VIEW','ADMIN','Ver administración','CRITICO'),
('ACCESS_ADMIN','ADMIN','Gestionar roles y permisos','CRITICO')
on conflict(permission_code) do update set
  module=excluded.module,
  description=excluded.description,
  risk_level=excluded.risk_level,
  active=true;

-- 3) MATRIZ BASE POR ROL
-- ADMIN: todo
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r cross join public.app_permissions p
where r.code='ADMIN'
on conflict do nothing;

-- GERENCIA_OPERATIVA
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p on p.permission_code in (
'DASHBOARD_VIEW','COMMAND_VIEW','DAILY_CLOSE_EXECUTE','SALES_VIEW','SALES_WRITE',
'DONORS_VIEW','SCREENING_VIEW','UNIT_RELEASE','BLOOD_INVENTORY_VIEW',
'DISPATCH_VIEW','DISPATCH_WRITE','SUPPLY_VIEW','SUPPLY_WRITE',
'QUALITY_VIEW','QUALITY_WRITE','DOCUMENTS_VIEW','DOCUMENTS_WRITE',
'COMPLIANCE_VIEW','COMPLIANCE_WRITE','BI_VIEW','PROJECTS_VIEW','PROJECTS_WRITE',
'AUDIT_VIEW','RELEASE_GATE_VIEW'
)
where r.code='GERENCIA_OPERATIVA'
on conflict do nothing;

-- GERENCIA_GENERAL: lectura amplia
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p on p.permission_code in (
'DASHBOARD_VIEW','COMMAND_VIEW','SALES_VIEW','DONORS_VIEW','SCREENING_VIEW',
'BLOOD_INVENTORY_VIEW','DISPATCH_VIEW','SUPPLY_VIEW','QUALITY_VIEW',
'DOCUMENTS_VIEW','COMPLIANCE_VIEW','BI_VIEW','PROJECTS_VIEW','AUDIT_VIEW',
'RELEASE_GATE_VIEW'
)
where r.code='GERENCIA_GENERAL'
on conflict do nothing;

-- CALIDAD
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p on p.permission_code in (
'DASHBOARD_VIEW','COMMAND_VIEW','DONORS_VIEW','SCREENING_VIEW','UNIT_RELEASE',
'BLOOD_INVENTORY_VIEW','DISPATCH_VIEW','QUALITY_VIEW','QUALITY_WRITE',
'DOCUMENTS_VIEW','DOCUMENTS_WRITE','COMPLIANCE_VIEW','COMPLIANCE_WRITE',
'BI_VIEW','PROJECTS_VIEW','PROJECTS_WRITE','AUDIT_VIEW'
)
where r.code='CALIDAD'
on conflict do nothing;

-- LABORATORIO
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p on p.permission_code in (
'DASHBOARD_VIEW','DONORS_VIEW','DONORS_WRITE','SCREENING_VIEW','SCREENING_WRITE',
'UNIT_RELEASE','BLOOD_INVENTORY_VIEW','BLOOD_INVENTORY_WRITE',
'SUPPLY_VIEW','QUALITY_VIEW','DOCUMENTS_VIEW'
)
where r.code='LABORATORIO'
on conflict do nothing;

-- INVENTARIO
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p on p.permission_code in (
'DASHBOARD_VIEW','BLOOD_INVENTORY_VIEW','BLOOD_INVENTORY_WRITE',
'DISPATCH_VIEW','DISPATCH_WRITE','SUPPLY_VIEW','SUPPLY_WRITE',
'DOCUMENTS_VIEW'
)
where r.code='INVENTARIO'
on conflict do nothing;

-- FINANZAS
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p on p.permission_code in (
'DASHBOARD_VIEW','SALES_VIEW','BI_VIEW','DOCUMENTS_VIEW'
)
where r.code='FINANZAS'
on conflict do nothing;

-- SUCURSAL
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p on p.permission_code in (
'DASHBOARD_VIEW','SALES_VIEW','SALES_WRITE','DONORS_VIEW','DONORS_WRITE',
'SCREENING_VIEW','SCREENING_WRITE','BLOOD_INVENTORY_VIEW',
'DISPATCH_VIEW','DISPATCH_WRITE','SUPPLY_VIEW','QUALITY_VIEW','DOCUMENTS_VIEW'
)
where r.code='SUCURSAL'
on conflict do nothing;

-- CONSULTA
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p on p.permission_code in (
'DASHBOARD_VIEW','BLOOD_INVENTORY_VIEW','SUPPLY_VIEW','QUALITY_VIEW',
'DOCUMENTS_VIEW','BI_VIEW'
)
where r.code='CONSULTA'
on conflict do nothing;

-- 4) FUNCIÓN DE PERMISO
create or replace function public.has_permission(p_permission_code text)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select exists(
    select 1
    from public.user_roles ur
    join public.role_permissions rp on rp.role_id=ur.role_id
    join public.app_permissions ap on ap.permission_code=rp.permission_code
    where ur.user_id=auth.uid()
      and rp.permission_code=p_permission_code
      and ap.active
  );
$$;

grant execute on function public.has_permission(text) to authenticated;

-- 5) ACCESO EFECTIVO DEL USUARIO ACTUAL
create or replace view public.vw_my_access as
select distinct
  p.id user_id,
  p.branch_id profile_branch_id,
  r.code role_code,
  r.name role_name,
  ur.branch_id role_branch_id,
  ap.permission_code,
  ap.module,
  ap.risk_level
from public.profiles p
join public.user_roles ur on ur.user_id=p.id
join public.roles r on r.id=ur.role_id
join public.role_permissions rp on rp.role_id=r.id
join public.app_permissions ap on ap.permission_code=rp.permission_code
where p.id=auth.uid() and ap.active;

grant select on public.vw_my_access to authenticated;

-- 6) DIAGNÓSTICO DEL USUARIO ACTUAL
create or replace view public.vw_my_security_context as
select
  auth.uid() user_id,
  auth.email() email,
  p.full_name,
  p.branch_id profile_branch_id,
  b.code branch_code,
  b.name branch_name,
  coalesce(
    (select jsonb_agg(distinct r.code)
     from public.user_roles ur
     join public.roles r on r.id=ur.role_id
     where ur.user_id=auth.uid()),
    '[]'::jsonb
  ) roles,
  coalesce(
    (select jsonb_agg(distinct rp.permission_code)
     from public.user_roles ur
     join public.role_permissions rp on rp.role_id=ur.role_id
     where ur.user_id=auth.uid()),
    '[]'::jsonb
  ) permissions
from public.profiles p
left join public.branches b on b.id=p.branch_id
where p.id=auth.uid();

grant select on public.vw_my_security_context to authenticated;

-- 7) LOG DE DECISIONES DE ACCESO
create table if not exists public.access_events (
  id uuid primary key default gen_random_uuid(),
  event_time timestamptz not null default now(),
  user_id uuid not null references public.profiles(id),
  route text,
  permission_code text,
  allowed boolean not null,
  reason text,
  branch_id uuid references public.branches(id),
  metadata jsonb
);

alter table public.access_events enable row level security;

drop policy if exists access_events_insert on public.access_events;
create policy access_events_insert on public.access_events for insert
with check(user_id=auth.uid());

drop policy if exists access_events_read on public.access_events;
create policy access_events_read on public.access_events for select
using(
  user_id=auth.uid()
  or public.has_role('ADMIN')
  or public.has_role('GERENCIA_OPERATIVA')
);

grant select,insert on public.access_events to authenticated;

create or replace function public.log_access_event(
  p_route text,
  p_permission_code text,
  p_allowed boolean,
  p_reason text default null,
  p_branch_id uuid default null,
  p_metadata jsonb default null
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare v_id uuid;
begin
  insert into public.access_events(
    user_id,route,permission_code,allowed,reason,branch_id,metadata
  )
  values(
    auth.uid(),p_route,p_permission_code,p_allowed,p_reason,p_branch_id,p_metadata
  )
  returning id into v_id;
  return v_id;
end;
$$;

grant execute on function public.log_access_event(text,text,boolean,text,uuid,jsonb) to authenticated;

-- 8) READINESS DE SEGURIDAD
create or replace view public.vw_security_readiness as
select
  (select count(*) from public.app_permissions where active) permissions_count,
  (select count(*) from public.role_permissions) role_permission_links,
  (select count(*) from public.roles) roles_count,
  (select count(*) from public.profiles) profiles_count,
  (select count(*) from public.user_roles) user_role_links,
  not exists(
    select 1
    from public.user_roles ur
    left join public.profiles p on p.id=ur.user_id
    where p.id is null
  ) as user_roles_have_profiles;

grant select on public.vw_security_readiness to authenticated;

insert into public.app_migrations(
  migration_code,version,description,applied_by
)
values(
  '29_ACCESS_GOVERNANCE_v0_29',
  '0.29.0',
  'Gobierno de roles, permisos y diagnóstico RLS',
  auth.uid()
)
on conflict(migration_code) do update set
  version=excluded.version,
  description=excluded.description,
  applied_at=now(),
  applied_by=auth.uid();

commit;
