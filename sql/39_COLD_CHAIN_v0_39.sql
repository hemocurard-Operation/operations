begin;
create table if not exists public.cold_chain_devices(
 id uuid primary key default gen_random_uuid(), device_code text not null unique,
 branch_id uuid references public.branches(id), device_type text not null,
 equipment_id uuid references public.lab_equipment(id), location text,
 min_temp numeric not null, max_temp numeric not null, active boolean not null default true
);
create table if not exists public.cold_chain_readings(
 id uuid primary key default gen_random_uuid(), device_id uuid not null references public.cold_chain_devices(id) on delete cascade,
 reading_time timestamptz not null default now(), temperature numeric not null,
 source text default 'MANUAL', recorded_by uuid references public.profiles(id), observation text
);
create table if not exists public.transport_events(
 id uuid primary key default gen_random_uuid(), transport_code text not null unique,
 branch_id uuid references public.branches(id), origin text not null, destination text not null,
 departure_at timestamptz, arrival_at timestamptz, container_reference text, responsible text,
 min_temp numeric, max_temp numeric, status text not null default 'PLANIFICADO'
 check(status in ('PLANIFICADO','EN_TRANSITO','RECIBIDO','CUARENTENA','CANCELADO')),
 notes text
);
create table if not exists public.transport_temperature_readings(
 id uuid primary key default gen_random_uuid(), transport_id uuid not null references public.transport_events(id) on delete cascade,
 reading_time timestamptz not null default now(), temperature numeric not null, source text default 'MANUAL'
);
alter table public.cold_chain_devices enable row level security;
alter table public.cold_chain_readings enable row level security;
alter table public.transport_events enable row level security;
alter table public.transport_temperature_readings enable row level security;
drop policy if exists cc_devices_auth on public.cold_chain_devices; create policy cc_devices_auth on public.cold_chain_devices for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
drop policy if exists cc_readings_auth on public.cold_chain_readings; create policy cc_readings_auth on public.cold_chain_readings for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
drop policy if exists transport_events_auth on public.transport_events; create policy transport_events_auth on public.transport_events for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
drop policy if exists transport_temps_auth on public.transport_temperature_readings; create policy transport_temps_auth on public.transport_temperature_readings for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
grant select,insert,update on public.cold_chain_devices,public.cold_chain_readings,public.transport_events,public.transport_temperature_readings to authenticated;
create or replace view public.vw_cold_chain_excursions as
select r.id reading_id,d.device_code,d.branch_id,d.device_type,d.location,r.reading_time,r.temperature,d.min_temp,d.max_temp,
case when r.temperature<d.min_temp or r.temperature>d.max_temp then 'FUERA_RANGO' else 'CONFORME' end status
from public.cold_chain_readings r join public.cold_chain_devices d on d.id=r.device_id
where r.temperature<d.min_temp or r.temperature>d.max_temp;
grant select on public.vw_cold_chain_excursions to authenticated;
insert into public.app_permissions(permission_code,module,description,risk_level) values
('COLD_CHAIN_VIEW','COLD_CHAIN','Ver cadena de frío','SENSIBLE'),('COLD_CHAIN_WRITE','COLD_CHAIN','Gestionar cadena de frío','CRITICO')
on conflict(permission_code) do update set active=true;
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r join public.app_permissions p on p.permission_code in ('COLD_CHAIN_VIEW','COLD_CHAIN_WRITE')
where r.code in ('ADMIN','GERENCIA_OPERATIVA','CALIDAD','LABORATORIO','INVENTARIO') on conflict do nothing;
insert into public.app_migrations(migration_code,version,description,applied_by)
values('39_COLD_CHAIN_v0_39','0.39.0','Cadena de frío y transporte',auth.uid())
on conflict(migration_code) do update set applied_at=now(),version=excluded.version,description=excluded.description,applied_by=auth.uid();
commit;