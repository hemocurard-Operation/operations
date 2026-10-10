-- HemoCura v0.44.0
-- Hardening de acceso anónimo del Reporte Operativo Diario.
-- No altera datos, lógica clínica ni estados del reporte.
-- Estado: aplicada y verificada en Supabase el 2026-10-10.

begin;

revoke all privileges on table public.daily_operational_closes from anon;
revoke all privileges on table public.daily_operational_report_versions from anon;

-- Mantener acceso únicamente para sesiones autenticadas; RLS y permisos
-- DAILY_REPORT_* continúan determinando el alcance efectivo por sucursal.
grant select, insert, update on table public.daily_operational_closes to authenticated;
grant select on table public.daily_operational_report_versions to authenticated;

commit;
