-- ============================================================
-- HemoCura v0.35.0
-- Equipos + calibración + mantenimiento + reactivos + ambiente
-- Requiere v0.34.0
-- ============================================================
begin;
create extension if not exists pgcrypto;

-- 1) MAESTRO DE EQUIPOS
create table if not exists public.lab_equipment (
  id uuid primary key default gen_random_uuid(),
  equipment_code text not null unique,
  branch_id uuid references public.branches(id),
  area text,
  equipment_type text not null,
  manufacturer text,
  model text,
  serial_number text,
  location text,
  criticality text not null default 'MEDIA'
    check(criticality in ('BAJA','MEDIA','ALTA','CRITICA')),
  status text not null default 'ACTIVO'
    check(status in ('ACTIVO','FUERA_SERVICIO','MANTENIMIENTO','CUARENTENA','RETIRADO')),
  acquisition_date date,
  installation_date date,
  qualification_status text default 'PENDIENTE'
    check(qualification_status in ('PENDIENTE','CALIFICADO','REQUIERE_RECALIFICACION')),
  calibration_required boolean not null default false,
  maintenance_required boolean not null default true,
  next_calibration_date date,
  next_maintenance_date date,
  responsible_user_id uuid references public.profiles(id),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.lab_equipment enable row level security;
drop policy if exists lab_equipment_read on public.lab_equipment;
create policy lab_equipment_read on public.lab_equipment for select
using(branch_id is null or public.can_access_branch(branch_id));
drop policy if exists lab_equipment_write on public.lab_equipment;
create policy lab_equipment_write on public.lab_equipment for all
using(
  branch_id is null or public.can_access_branch(branch_id)
)
with check(
  branch_id is null or public.can_access_branch(branch_id)
);
grant select,insert,update on public.lab_equipment to authenticated;

-- 2) MANTENIMIENTO / CALIBRACIÓN / CALIFICACIÓN
create table if not exists public.equipment_service_events (
  id uuid primary key default gen_random_uuid(),
  service_code text not null unique,
  equipment_id uuid not null references public.lab_equipment(id) on delete cascade,
  event_type text not null
    check(event_type in ('MANTENIMIENTO_PREVENTIVO','MANTENIMIENTO_CORRECTIVO','CALIBRACION','CALIFICACION','VERIFICACION')),
  scheduled_date date,
  performed_date date,
  provider text,
  responsible text,
  result text
    check(result in ('CONFORME','NO_CONFORME','PENDIENTE','NO_APLICA') or result is null),
  certificate_reference text,
  evidence_url text,
  findings text,
  next_due_date date,
  status text not null default 'PROGRAMADO'
    check(status in ('PROGRAMADO','EN_CURSO','COMPLETADO','VENCIDO','CANCELADO')),
  nonconformity_id uuid references public.nonconformities(id),
  capa_id uuid references public.capa(id),
  created_at timestamptz not null default now()
);

alter table public.equipment_service_events enable row level security;
drop policy if exists equipment_service_events_read on public.equipment_service_events;
create policy equipment_service_events_read on public.equipment_service_events for select
using(auth.role()='authenticated');
drop policy if exists equipment_service_events_write on public.equipment_service_events;
create policy equipment_service_events_write on public.equipment_service_events for all
using(
  public.has_role('ADMIN') or public.has_role('CALIDAD') or
  public.has_role('LABORATORIO') or public.has_role('GERENCIA_OPERATIVA')
)
with check(
  public.has_role('ADMIN') or public.has_role('CALIDAD') or
  public.has_role('LABORATORIO') or public.has_role('GERENCIA_OPERATIVA')
);
grant select,insert,update on public.equipment_service_events to authenticated;

-- 3) REACTIVOS / LOTES
create table if not exists public.reagent_lots (
  id uuid primary key default gen_random_uuid(),
  reagent_code text not null,
  reagent_name text not null,
  branch_id uuid references public.branches(id),
  manufacturer text,
  lot_number text not null,
  received_date date,
  opened_date date,
  expiry_date date not null,
  quantity_received numeric default 0 check(quantity_received>=0),
  quantity_available numeric default 0 check(quantity_available>=0),
  unit text,
  storage_requirement text,
  verification_status text not null default 'PENDIENTE'
    check(verification_status in ('PENDIENTE','APROBADO','RECHAZADO','CUARENTENA')),
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  certificate_reference text,
  notes text,
  created_at timestamptz not null default now(),
  unique(branch_id,reagent_code,lot_number)
);

alter table public.reagent_lots enable row level security;
drop policy if exists reagent_lots_read on public.reagent_lots;
create policy reagent_lots_read on public.reagent_lots for select
using(branch_id is null or public.can_access_branch(branch_id));
drop policy if exists reagent_lots_write on public.reagent_lots;
create policy reagent_lots_write on public.reagent_lots for all
using(
  branch_id is null or public.can_access_branch(branch_id)
)
with check(
  branch_id is null or public.can_access_branch(branch_id)
);
grant select,insert,update on public.reagent_lots to authenticated;

-- 4) PUNTOS DE MONITOREO AMBIENTAL
create table if not exists public.environmental_points (
  id uuid primary key default gen_random_uuid(),
  point_code text not null unique,
  branch_id uuid not null references public.branches(id),
  area text not null,
  parameter text not null
    check(parameter in ('TEMPERATURA','HUMEDAD','PRESION','OTRO')),
  unit text not null,
  min_allowed numeric,
  max_allowed numeric,
  frequency text,
  active boolean not null default true,
  equipment_id uuid references public.lab_equipment(id),
  notes text
);

alter table public.environmental_points enable row level security;
drop policy if exists environmental_points_access on public.environmental_points;
create policy environmental_points_access on public.environmental_points for all
using(public.can_access_branch(branch_id))
with check(public.can_access_branch(branch_id));
grant select,insert,update on public.environmental_points to authenticated;

-- 5) REGISTROS AMBIENTALES
create table if not exists public.environmental_readings (
  id uuid primary key default gen_random_uuid(),
  point_id uuid not null references public.environmental_points(id) on delete cascade,
  reading_time timestamptz not null default now(),
  value numeric not null,
  recorded_by uuid references public.profiles(id),
  source text default 'MANUAL'
    check(source in ('MANUAL','IMPORTADO','SENSOR')),
  observation text,
  created_at timestamptz not null default now()
);

alter table public.environmental_readings enable row level security;
drop policy if exists environmental_readings_read on public.environmental_readings;
create policy environmental_readings_read on public.environmental_readings for select
using(auth.role()='authenticated');
drop policy if exists environmental_readings_write on public.environmental_readings;
create policy environmental_readings_write on public.environmental_readings for insert
with check(auth.role()='authenticated');
grant select,insert on public.environmental_readings to authenticated;

-- 6) VISTA DE CONFORMIDAD AMBIENTAL
create or replace view public.vw_environmental_status as
select
  r.id,r.point_id,p.point_code,p.branch_id,p.area,p.parameter,p.unit,
  p.min_allowed,p.max_allowed,r.reading_time,r.value,r.recorded_by,
  case
    when p.min_allowed is not null and r.value<p.min_allowed then 'FUERA_RANGO'
    when p.max_allowed is not null and r.value>p.max_allowed then 'FUERA_RANGO'
    else 'CONFORME'
  end reading_status
from public.environmental_readings r
join public.environmental_points p on p.id=r.point_id;

grant select on public.vw_environmental_status to authenticated;

-- 7) ALERTAS DE EQUIPOS
create or replace view public.vw_equipment_alerts as
select
  e.id equipment_id,e.equipment_code,e.branch_id,e.equipment_type,e.criticality,
  'CALIBRACION' alert_type,
  e.next_calibration_date due_date,
  case
    when e.next_calibration_date<current_date then 'CRITICA'
    when e.next_calibration_date<=current_date+7 then 'ALTA'
    when e.next_calibration_date<=current_date+30 then 'MEDIA'
    else 'BAJA'
  end severity,
  case
    when e.next_calibration_date<current_date then 'Calibración vencida'
    else 'Calibración próxima'
  end message
from public.lab_equipment e
where e.calibration_required
  and e.status='ACTIVO'
  and e.next_calibration_date is not null
  and e.next_calibration_date<=current_date+30
union all
select
  e.id,e.equipment_code,e.branch_id,e.equipment_type,e.criticality,
  'MANTENIMIENTO',
  e.next_maintenance_date,
  case
    when e.next_maintenance_date<current_date then 'CRITICA'
    when e.next_maintenance_date<=current_date+7 then 'ALTA'
    when e.next_maintenance_date<=current_date+30 then 'MEDIA'
    else 'BAJA'
  end,
  case
    when e.next_maintenance_date<current_date then 'Mantenimiento vencido'
    else 'Mantenimiento próximo'
  end
from public.lab_equipment e
where e.maintenance_required
  and e.status='ACTIVO'
  and e.next_maintenance_date is not null
  and e.next_maintenance_date<=current_date+30;

grant select on public.vw_equipment_alerts to authenticated;

-- 8) ALERTAS DE REACTIVOS
create or replace view public.vw_reagent_alerts as
select
  id reagent_lot_id,reagent_code,reagent_name,branch_id,lot_number,expiry_date,
  quantity_available,verification_status,
  case
    when expiry_date<current_date then 'CRITICA'
    when expiry_date<=current_date+7 then 'ALTA'
    when expiry_date<=current_date+30 then 'MEDIA'
    else 'BAJA'
  end severity,
  case
    when expiry_date<current_date then 'Lote vencido'
    when verification_status<>'APROBADO' then 'Lote no aprobado para uso'
    else 'Lote próximo a vencer'
  end message
from public.reagent_lots
where expiry_date<=current_date+30
   or verification_status<>'APROBADO';

grant select on public.vw_reagent_alerts to authenticated;

-- 9) ALERTAS AMBIENTALES
create or replace view public.vw_environmental_alerts as
select
  s.id reading_id,s.point_id,s.point_code,s.branch_id,s.area,s.parameter,s.unit,
  s.reading_time,s.value,s.min_allowed,s.max_allowed,
  'ALTA' severity,
  concat(
    'Valor fuera de rango: ',s.value,' ',s.unit,
    ' · esperado ',
    coalesce(s.min_allowed::text,'-∞'),' a ',coalesce(s.max_allowed::text,'+∞')
  ) message
from public.vw_environmental_status s
where s.reading_status='FUERA_RANGO'
  and s.reading_time>=now()-interval '30 days';

grant select on public.vw_environmental_alerts to authenticated;

-- 10) RESUMEN DE GESTIÓN
create or replace view public.vw_resource_control_summary as
select
  (select count(*) from public.lab_equipment where status='ACTIVO') active_equipment,
  (select count(*) from public.vw_equipment_alerts where severity in ('CRITICA','ALTA')) equipment_high_alerts,
  (select count(*) from public.reagent_lots where verification_status='APROBADO' and expiry_date>=current_date) reagent_lots_approved,
  (select count(*) from public.vw_reagent_alerts where severity in ('CRITICA','ALTA')) reagent_high_alerts,
  (select count(*) from public.vw_environmental_alerts) environmental_excursions_30d;

grant select on public.vw_resource_control_summary to authenticated;

-- 11) VINCULAR AUDITORÍAS CON RECURSOS
alter table public.audit_findings
  add column if not exists equipment_id uuid references public.lab_equipment(id),
  add column if not exists reagent_lot_id uuid references public.reagent_lots(id),
  add column if not exists environmental_point_id uuid references public.environmental_points(id);

-- 12) PERMISOS
insert into public.app_permissions(permission_code,module,description,risk_level) values
('RESOURCES_VIEW','RESOURCES','Ver equipos, reactivos y ambiente','SENSIBLE'),
('RESOURCES_WRITE','RESOURCES','Gestionar equipos, reactivos y ambiente','CRITICO')
on conflict(permission_code) do update set
 module=excluded.module,description=excluded.description,risk_level=excluded.risk_level,active=true;

insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p
on p.permission_code in ('RESOURCES_VIEW','RESOURCES_WRITE')
where r.code in ('ADMIN','CALIDAD','LABORATORIO','GERENCIA_OPERATIVA')
on conflict do nothing;

insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r join public.app_permissions p
on p.permission_code='RESOURCES_VIEW'
where r.code in ('GERENCIA_GENERAL','INVENTARIO','SUCURSAL')
on conflict do nothing;

-- 13) MIGRACIÓN
insert into public.app_migrations(
  migration_code,version,description,applied_by
)
values(
  '35_RESOURCES_CONTROL_v0_35',
  '0.35.0',
  'Equipos, mantenimiento/calibración, reactivos y monitoreo ambiental',
  auth.uid()
)
on conflict(migration_code) do update set
  version=excluded.version,
  description=excluded.description,
  applied_at=now(),
  applied_by=auth.uid();

commit;
