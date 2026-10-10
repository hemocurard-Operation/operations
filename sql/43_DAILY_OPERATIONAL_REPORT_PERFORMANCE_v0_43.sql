-- HemoCura v0.43.0
-- Rendimiento acotado al Reporte Operativo Diario.
-- Esta migración NO altera lógica clínica, estados, RLS ni permisos.
-- Estado: aplicada y verificada en Supabase el 2026-10-10.

begin;

create index if not exists idx_daily_operational_closes_branch_id
  on public.daily_operational_closes(branch_id);

create index if not exists idx_daily_operational_closes_closed_by
  on public.daily_operational_closes(closed_by)
  where closed_by is not null;

create index if not exists idx_daily_operational_closes_last_modified_by
  on public.daily_operational_closes(last_modified_by)
  where last_modified_by is not null;

create index if not exists idx_daily_operational_closes_reopened_by
  on public.daily_operational_closes(reopened_by)
  where reopened_by is not null;

create index if not exists idx_daily_operational_closes_submitted_by
  on public.daily_operational_closes(submitted_by)
  where submitted_by is not null;

create index if not exists idx_daily_report_versions_changed_by
  on public.daily_operational_report_versions(changed_by)
  where changed_by is not null;

commit;
