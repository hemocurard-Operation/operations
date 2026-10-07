-- =====================================================================
-- HemoCura · C13-D · FUNCTION SEARCH_PATH HARDENING CANDIDATE
-- Preflight real confirmó que anon/authenticated NO tienen CREATE sobre
-- schema public. Fijamos search_path=public,pg_temp para compatibilidad
-- con funciones legacy que usan referencias no calificadas.
-- =====================================================================

begin;

alter function public.hc_assert_can_migrate(text) set search_path to public,pg_temp;
alter function public.hc_gate_continue_to(text) set search_path to public,pg_temp;
alter function public.hc_gate_dependencies_ready(text) set search_path to public,pg_temp;
alter function public.hc_gate_migration_registered(text) set search_path to public,pg_temp;
alter function public.hc_gate_next_step() set search_path to public,pg_temp;
alter function public.hc_gate_object_exists(text,text) set search_path to public,pg_temp;
alter function public.hc_gate_result(text) set search_path to public,pg_temp;
alter function public.hc_migration_applied(text) set search_path to public,pg_temp;
alter function public.hc_object_exists(text,text) set search_path to public,pg_temp;
alter function public.hc_postcheck(text) set search_path to public,pg_temp;
alter function public.hc_precheck(text) set search_path to public,pg_temp;
alter function public.hc_qa_r1_v022() set search_path to public,pg_temp;
alter function public.hc_run_validation(text) set search_path to public,pg_temp;
alter function public.hc_version_dependencies_ready(text) set search_path to public,pg_temp;
alter function public.hc_version_objects_ready(text) set search_path to public,pg_temp;
alter function public.reconcile_inventory(uuid,date) set search_path to public,pg_temp;
alter function public.refresh_forecasts(date) set search_path to public,pg_temp;
alter function public.set_updated_at() set search_path to public,pg_temp;
alter function public.trg_recalc_daily_sale() set search_path to public,pg_temp;

-- El sistema requiere autenticación; ninguna de estas funciones necesita
-- ser llamada de forma anónima.
revoke execute on function public.hc_assert_can_migrate(text) from anon;
revoke execute on function public.hc_gate_continue_to(text) from anon;
revoke execute on function public.hc_gate_dependencies_ready(text) from anon;
revoke execute on function public.hc_gate_migration_registered(text) from anon;
revoke execute on function public.hc_gate_next_step() from anon;
revoke execute on function public.hc_gate_object_exists(text,text) from anon;
revoke execute on function public.hc_gate_result(text) from anon;
revoke execute on function public.hc_migration_applied(text) from anon;
revoke execute on function public.hc_object_exists(text,text) from anon;
revoke execute on function public.hc_postcheck(text) from anon;
revoke execute on function public.hc_precheck(text) from anon;
revoke execute on function public.hc_run_validation(text) from anon;
revoke execute on function public.hc_version_dependencies_ready(text) from anon;
revoke execute on function public.hc_version_objects_ready(text) from anon;
revoke execute on function public.reconcile_inventory(uuid,date) from anon;
revoke execute on function public.refresh_forecasts(date) from anon;
revoke execute on function public.set_updated_at() from anon;
revoke execute on function public.trg_recalc_daily_sale() from anon;

-- Trigger functions no deben ser RPC directos para navegador.
revoke execute on function public.set_updated_at() from authenticated;
revoke execute on function public.trg_recalc_daily_sale() from authenticated;

insert into public.app_migrations(migration_code,version,description,applied_by,notes)
values(
  'C13D_FUNCTION_SEARCH_PATH_v0_44_11',
  '0.44.11',
  'Fija search_path de 19 funciones legacy y elimina ejecución anónima',
  auth.uid(),
  'search_path=public,pg_temp; public no es CREATE-able por anon/authenticated según preflight.'
)
on conflict(migration_code) do nothing;

commit;
