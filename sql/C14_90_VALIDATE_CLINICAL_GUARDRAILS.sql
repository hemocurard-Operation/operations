-- =====================================================================
-- HemoCura · C14 · VALIDATE CLINICAL GUARDRAILS · READ ONLY
-- Ejecutar DESPUÉS de C14_01_CLINICAL_GUARDRAILS_CANDIDATE.sql
-- =====================================================================

with checks(name,ok,detail) as (
 values
 ('FEFO_FUNCTION_EXISTS',
   to_regprocedure('public.reserve_blood_units_fefo(uuid)') is not null,
   'reserve_blood_units_fefo(uuid)'),

 ('FEFO_DOUBLE_GATE',
   pg_get_functiondef(to_regprocedure('public.reserve_blood_units_fefo(uuid)')) ilike '%clinical_fefo%'
   and pg_get_functiondef(to_regprocedure('public.reserve_blood_units_fefo(uuid)')) ilike '%clinical_unit_dispatch_enabled%'
   and pg_get_functiondef(to_regprocedure('public.reserve_blood_units_fefo(uuid)')) ilike '%DISPATCH_WRITE%',
   'feature flag + system mode + permission'),

 ('TEMP_DOUBLE_GATE',
   pg_get_functiondef(to_regprocedure('public.evaluate_temperature_reading()')) ilike '%cold_chain_auto_block%'
   and pg_get_functiondef(to_regprocedure('public.evaluate_temperature_reading()')) ilike '%temperature_blocking_enabled%',
   'feature flag + system mode'),

 ('TEMP_TRIGGER_NOT_BROWSER_RPC',
   not has_function_privilege('anon',to_regprocedure('public.evaluate_temperature_reading()'),'EXECUTE')
   and not has_function_privilege('authenticated',to_regprocedure('public.evaluate_temperature_reading()'),'EXECUTE'),
   'trigger function sin EXECUTE directo'),

 ('CLINICAL_FEFO_REMAINS_DISABLED',
   exists(select 1 from public.app_feature_flags where key='clinical_fefo' and (not enabled or mode='SHADOW'))
   and exists(select 1 from public.system_operating_mode where id=1 and not clinical_unit_dispatch_enabled),
   'FEFO sigue SHADOW/BLOCKED'),

 ('TEMP_BLOCK_REMAINS_DISABLED',
   exists(select 1 from public.app_feature_flags where key='cold_chain_auto_block' and (not enabled or mode='SHADOW'))
   and exists(select 1 from public.system_operating_mode where id=1 and not temperature_blocking_enabled),
   'bloqueo térmico automático sigue SHADOW/BLOCKED'),

 ('TRACEABILITY_REMAINS_DISABLED',
   exists(select 1 from public.app_feature_flags where key='donor_recipient_traceability' and (not enabled or mode='SHADOW'))
   and exists(select 1 from public.system_operating_mode where id=1 and not donor_recipient_traceability_enabled),
   'trazabilidad donante→receptor sigue SHADOW/BLOCKED'),

 ('C14_REGISTERED',
   exists(select 1 from public.app_migrations where migration_code='C14_CLINICAL_GUARDRAILS_v0_44_5'),
   'app_migrations C14_CLINICAL_GUARDRAILS_v0_44_5')
)
select name,ok,detail,case when ok then 'PASS' else 'FAIL' end status
from checks
union all
select 'RESULTADO_GENERAL',bool_and(ok),'C14 clinical guardrails',
       case when bool_and(ok) then 'PASS' else 'STOP' end
from checks;
