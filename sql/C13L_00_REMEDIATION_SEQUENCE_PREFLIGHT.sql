-- =====================================================================
-- HemoCura · C13-L · REMEDIATION SEQUENCE PREFLIGHT · READ ONLY
-- Version 0.44.19
--
-- Verifica qué hardenings 0.44.3–0.44.15 ya están registrados en Supabase.
-- El orden completo y los gates frontend/manuales viven en
-- contracts/remediation-plan-v0.44.19.json.
-- =====================================================================

with target(version,stage) as (
  values
    ('0.44.3','S02_C12_SECURITY_HARDENING'),
    ('0.44.4','S03_C13A_RLS_POLICIES'),
    ('0.44.5','S04_C13C1_FUNCTION_EXECUTE_HARDENING'),
    ('0.44.6','S05_C13C2A_CONTROLLED_RPC_WRAPPERS'),
    ('0.44.7','S07_C13C2B_LEGACY_RPC_CUTOVER'),
    ('0.44.8','S08_C14_CLINICAL_GUARDRAILS'),
    ('0.44.9','S09_C13B1_ANON_VIEW_EXPOSURE'),
    ('0.44.10','S10_C13B2_SECURITY_INVOKER_VIEWS'),
    ('0.44.11','S11_C13D_FUNCTION_SEARCH_PATH'),
    ('0.44.13','S12_C13F_BROAD_POLICY_HARDENING'),
    ('0.44.14','S13_C13G_GRANT_POLICY_RECONCILIATION'),
    ('0.44.12','S14_C13E_ANON_SURFACE_HARDENING'),
    ('0.44.15','S15_C13H_DEFAULT_PRIVILEGE_GOVERNANCE')
),
applied as (
  select t.version,t.stage,
         exists(select 1 from public.app_migrations m where m.version=t.version) applied
  from target t
)
select jsonb_build_object(
  'gate','C13-L',
  'version','0.44.19',
  'mode','READ_ONLY',
  'target_versions',coalesce((select jsonb_agg(to_jsonb(a) order by stage) from applied a),'[]'::jsonb),
  'applied_target_count',(select count(*) from applied where applied),
  'pending_target_count',(select count(*) from applied where not applied),
  'uat_runs_1_0_0',(select count(*) from public.uat_test_runs where release_version='1.0.0'),
  'release_signoffs_1_0_0',(select count(*) from public.release_signoffs where release_version='1.0.0'),
  'note','Frontend/manual dependencies are enforced by the repository remediation sequencer.'
) as c13l_preflight;
