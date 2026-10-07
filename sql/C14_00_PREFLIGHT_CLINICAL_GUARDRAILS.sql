-- =====================================================================
-- HemoCura · C14 · PREFLIGHT CLINICAL GUARDRAILS · READ ONLY
-- Verifica que FEFO, bloqueo térmico y trazabilidad clínica permanezcan
-- controlados por feature flags + system_operating_mode.
-- =====================================================================

select jsonb_build_object(
  'system_mode',(select to_jsonb(s) from public.system_operating_mode s where id=1),
  'feature_flags',(
    select jsonb_object_agg(key,jsonb_build_object('enabled',enabled,'mode',mode,'description',description))
    from public.app_feature_flags
    where key in ('clinical_fefo','cold_chain_auto_block','donor_recipient_traceability')
  ),
  'reserve_fefo_exists',to_regprocedure('public.reserve_blood_units_fefo(uuid)') is not null,
  'temperature_trigger_exists',exists(
    select 1 from pg_trigger
    where tgrelid='public.temperature_readings'::regclass
      and tgname='trg_temperature_evaluation'
      and not tgisinternal
  ),
  'reserve_fefo_checks_feature_flag',
    coalesce(pg_get_functiondef(to_regprocedure('public.reserve_blood_units_fefo(uuid)')),'') ilike '%clinical_fefo%',
  'reserve_fefo_checks_system_mode',
    coalesce(pg_get_functiondef(to_regprocedure('public.reserve_blood_units_fefo(uuid)')),'') ilike '%clinical_unit_dispatch_enabled%',
  'temperature_checks_feature_flag',
    coalesce(pg_get_functiondef(to_regprocedure('public.evaluate_temperature_reading()')),'') ilike '%cold_chain_auto_block%',
  'temperature_checks_system_mode',
    coalesce(pg_get_functiondef(to_regprocedure('public.evaluate_temperature_reading()')),'') ilike '%temperature_blocking_enabled%'
) as c14_preflight;
