-- ============================================================
-- HemoCura v0.40.0
-- Reporte operativo diario consolidado
-- Digitaliza la estructura manual actual SIN captura individual
-- de tamizaje, inventario ni despachos.
-- Requiere v0.26.0
-- ============================================================
begin;

alter table public.daily_operational_closes
  add column if not exists responsible_name text,
  add column if not exists screening_lots jsonb not null default '[]'::jsonb,
  add column if not exists manual_inventory jsonb not null default '{}'::jsonb,
  add column if not exists manual_dispatches jsonb not null default '[]'::jsonb,
  add column if not exists equipment_snapshot jsonb not null default '[]'::jsonb,
  add column if not exists source_mode text not null default 'MANUAL_CONSOLIDADO',
  add column if not exists updated_at timestamptz not null default now();

comment on column public.daily_operational_closes.screening_lots is
  'Lotes/tandas diarios de tamizaje. No almacena resultados individuales por unidad.';
comment on column public.daily_operational_closes.manual_inventory is
  'Fotografía manual consolidada de inventario por grupo y componente.';
comment on column public.daily_operational_closes.manual_dispatches is
  'Despachos consolidados del día. No requiere captura individual por unidad.';

create or replace function public.save_daily_operational_report(
  p_close_date date,
  p_branch_id uuid,
  p_responsible_name text,
  p_screening_lots jsonb default '[]'::jsonb,
  p_manual_inventory jsonb default '{}'::jsonb,
  p_manual_dispatches jsonb default '[]'::jsonb,
  p_equipment_snapshot jsonb default '[]'::jsonb,
  p_notes text default null,
  p_status text default 'BORRADOR'
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare v_id uuid;
begin
  if not public.can_access_branch(p_branch_id) then
    raise exception 'Sin acceso a la sucursal';
  end if;
  if p_status not in ('BORRADOR','EN_REVISION','CERRADO','REABIERTO') then
    raise exception 'Estado no válido';
  end if;

  insert into public.daily_operational_closes(
    close_date,branch_id,status,responsible_name,
    screening_lots,manual_inventory,manual_dispatches,equipment_snapshot,
    source_mode,notes,closed_by,closed_at,updated_at
  ) values(
    p_close_date,p_branch_id,p_status,nullif(trim(p_responsible_name),''),
    coalesce(p_screening_lots,'[]'::jsonb),
    coalesce(p_manual_inventory,'{}'::jsonb),
    coalesce(p_manual_dispatches,'[]'::jsonb),
    coalesce(p_equipment_snapshot,'[]'::jsonb),
    'MANUAL_CONSOLIDADO',p_notes,
    case when p_status='CERRADO' then auth.uid() else null end,
    case when p_status='CERRADO' then now() else null end,
    now()
  )
  on conflict(close_date,branch_id) do update set
    status=excluded.status,
    responsible_name=excluded.responsible_name,
    screening_lots=excluded.screening_lots,
    manual_inventory=excluded.manual_inventory,
    manual_dispatches=excluded.manual_dispatches,
    equipment_snapshot=excluded.equipment_snapshot,
    source_mode='MANUAL_CONSOLIDADO',
    notes=excluded.notes,
    closed_by=case when excluded.status='CERRADO' then auth.uid() else public.daily_operational_closes.closed_by end,
    closed_at=case when excluded.status='CERRADO' then now() else public.daily_operational_closes.closed_at end,
    updated_at=now()
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.save_daily_operational_report(date,uuid,text,jsonb,jsonb,jsonb,jsonb,text,text) to authenticated;

insert into public.app_migrations(migration_code,version,description,applied_by)
values(
  '40_DAILY_OPERATIONAL_REPORT_v0_40',
  '0.40.0',
  'Reporte operativo manual consolidado por lotes, inventario y despachos',
  auth.uid()
)
on conflict(migration_code) do update
set applied_at=now(),version=excluded.version,description=excluded.description,applied_by=auth.uid();

commit;
