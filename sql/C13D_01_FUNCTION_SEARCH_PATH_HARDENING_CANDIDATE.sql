-- =====================================================================
-- HemoCura · C13-D · FUNCTION SEARCH_PATH HARDENING CANDIDATE
-- Preflight real confirmó que anon/authenticated NO tienen CREATE sobre
-- schema public. Fijamos search_path=public,pg_temp para compatibilidad
-- con funciones legacy que usan referencias no calificadas.
--
-- PostgreSQL concede EXECUTE a PUBLIC por defecto. Por eso esta revisión
-- retira PUBLIC + anon y reotorga authenticated solo donde corresponde.
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

-- Ninguna de estas funciones necesita ejecución anónima. Retirar PUBLIC es
-- necesario para que anon no conserve EXECUTE por herencia.
revoke execute on function public.hc_assert_can_migrate(text) from PUBLIC, anon;
revoke execute on function public.hc_gate_continue_to(text) from PUBLIC, anon;
revoke execute on function public.hc_gate_dependencies_ready(text) from PUBLIC, anon;
revoke execute on function public.hc_gate_migration_registered(text) from PUBLIC, anon;
revoke execute on function public.hc_gate_next_step() from PUBLIC, anon;
revoke execute on function public.hc_gate_object_exists(text,text) from PUBLIC, anon;
revoke execute on function public.hc_gate_result(text) from PUBLIC, anon;
revoke execute on function public.hc_migration_applied(text) from PUBLIC, anon;
revoke execute on function public.hc_object_exists(text,text) from PUBLIC, anon;
revoke execute on function public.hc_postcheck(text) from PUBLIC, anon;
revoke execute on function public.hc_precheck(text) from PUBLIC, anon;
revoke execute on function public.hc_run_validation(text) from PUBLIC, anon;
revoke execute on function public.hc_version_dependencies_ready(text) from PUBLIC, anon;
revoke execute on function public.hc_version_objects_ready(text) from PUBLIC, anon;
revoke execute on function public.reconcile_inventory(uuid,date) from PUBLIC, anon;
revoke execute on function public.refresh_forecasts(date) from PUBLIC, anon;
revoke execute on function public.set_updated_at() from PUBLIC, anon;
revoke execute on function public.trg_recalc_daily_sale() from PUBLIC, anon;

-- Las funciones de diagnóstico/gate y cálculo que la app autenticada pueda
-- necesitar se reotorgan de forma explícita.
grant execute on function public.hc_gate_continue_to(text) to authenticated;
grant execute on function public.hc_gate_dependencies_ready(text) to authenticated;
grant execute on function public.hc_gate_migration_registered(text) to authenticated;
grant execute on function public.hc_gate_next_step() to authenticated;
grant execute on function public.hc_gate_object_exists(text,text) to authenticated;
grant execute on function public.hc_gate_result(text) to authenticated;
grant execute on function public.hc_migration_applied(text) to authenticated;
grant execute on function public.hc_object_exists(text,text) to authenticated;
grant execute on function public.hc_postcheck(text) to authenticated;
grant execute on function public.hc_precheck(text) to authenticated;
grant execute on function public.hc_version_dependencies_ready(text) to authenticated;
grant execute on function public.hc_version_objects_ready(text) to authenticated;
grant execute on function public.reconcile_inventory(uuid,date) to authenticated;
grant execute on function public.refresh_forecasts(date) to authenticated;

-- Mutating/admin validation helpers y trigger functions no quedan RPC directos.
revoke execute on function public.hc_assert_can_migrate(text) from authenticated;
revoke execute on function public.hc_run_validation(text) from authenticated;
revoke execute on function public.hc_qa_r1_v022() from authenticated;
revoke execute on function public.set_updated_at() from authenticated;
revoke execute on function public.trg_recalc_daily_sale() from authenticated;

insert into public.app_migrations(migration_code,version,description,applied_by,notes)
values(
  'C13D_FUNCTION_SEARCH_PATH_v0_44_11',
  '0.44.11',
  'Fija search_path de 19 funciones legacy y elimina herencia EXECUTE de PUBLIC/anon',
  auth.uid(),
  'search_path=public,pg_temp; authenticated se reotorga explícitamente solo donde corresponde.'
)
on conflict(migration_code) do nothing;

commit;
