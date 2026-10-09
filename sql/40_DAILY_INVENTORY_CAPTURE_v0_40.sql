-- ============================================================
-- HemoCura v0.40.0
-- Captura diaria de inventario de laboratorio / banco de sangre
-- Formato digital basado en reporte operativo diario
-- ============================================================
begin;

create table if not exists public.daily_inventory_captures(
  id uuid primary key default gen_random_uuid(),
  capture_date date not null default current_date,
  shift text not null default 'DIURNO',
  branch_id uuid not null references public.branches(id),
  responsible_name text,
  service_area text default 'LABORATORIO',
  donor_counts jsonb not null default '{"accepted":0,"deferred":0,"discarded":0}'::jsonb,
  daily_movement jsonb not null default '{}'::jsonb,
  available_inventory jsonb not null default '{}'::jsonb,
  equipment_status jsonb not null default '{}'::jsonb,
  observations text,
  status text not null default 'BORRADOR' check(status in ('BORRADOR','COMPLETADO')),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(capture_date,shift,branch_id)
);

create index if not exists idx_daily_inventory_capture_date_branch
on public.daily_inventory_captures(capture_date,branch_id);

alter table public.daily_inventory_captures enable row level security;

drop policy if exists daily_inventory_capture_select on public.daily_inventory_captures;
create policy daily_inventory_capture_select on public.daily_inventory_captures
for select using(public.can_access_branch(branch_id));

drop policy if exists daily_inventory_capture_insert on public.daily_inventory_captures;
create policy daily_inventory_capture_insert on public.daily_inventory_captures
for insert with check(public.can_access_branch(branch_id));

drop policy if exists daily_inventory_capture_update on public.daily_inventory_captures;
create policy daily_inventory_capture_update on public.daily_inventory_captures
for update using(public.can_access_branch(branch_id))
with check(public.can_access_branch(branch_id));

grant select,insert,update on public.daily_inventory_captures to authenticated;

insert into public.app_migrations(migration_code,version,description,applied_by)
values(
  '40_DAILY_INVENTORY_CAPTURE_v0_40',
  '0.40.0',
  'Captura diaria simplificada de inventario, movimientos, donantes y equipos',
  auth.uid()
)
on conflict(migration_code) do update
set applied_at=now(),version=excluded.version,description=excluded.description,applied_by=auth.uid();

commit;
