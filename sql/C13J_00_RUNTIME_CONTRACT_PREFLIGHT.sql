-- =====================================================================
-- HemoCura · C13-J · SCHEMA DRIFT & RUNTIME CONTRACT PREFLIGHT
-- Version del gate: 0.44.17
-- READ ONLY. No modifica schema, datos, grants, RLS ni funciones.
-- Fuente contractual: contracts/runtime-contract-v0.44.json
-- =====================================================================

with expected_rel(name) as (
  select unnest(array[
'access_events','app_feature_flags','app_releases','audit_criteria_catalog','audit_events','audit_evidence','audit_findings','audit_plan_criteria','audit_programs','blood_inventory_units','blood_stock_targets','branch_inspections','branches','capa','cold_chain_devices','cold_chain_readings','competency_assessments','competency_catalog','continuity_plans','continuity_tests','daily_sales','data_integrity_checks','deployment_events','deployment_releases','diagnostic_events','dispatch_lines','dispatches','document_register','donations','donors','environmental_points','environmental_readings','eqa_events','eqa_programs','equipment_service_events','forecast_snapshots','hemovigilance_events','incidents','inspection_findings','internal_audits','inventory_movements','inventory_policies','iqc_plans','iqc_results','job_role_competencies','job_roles','lab_equipment','lab_methods','management_actions','management_reviews','monthly_cost_entries','monthly_cost_periods','nonconformities','operational_exceptions','operational_plan_lines','operational_plans','operational_sale_lines','operational_sales','physical_inventory_counts','price_versions','product_recalls','production_batches','production_yield_rules','products','profiles','projects','purchase_orders','qc_deviations','quality_objectives','quality_processes','reagent_lots','release_signoffs','requisition_lines','requisitions','risk_register','roles','screening_tests','services','staff_job_assignments','supplier_incidents','suppliers','system_operating_mode','training_events','transport_events','uat_test_cases','user_roles','vw_analytical_quality_summary','vw_app_migration_readiness','vw_app_release_readiness','vw_app_schema_readiness','vw_approval_decision_history','vw_approval_inbox','vw_audit_findings_open','vw_audit_program_summary','vw_audit_summary_30d','vw_bi_operations_today','vw_blood_flow_alerts','vw_blood_flow_funnel_30d','vw_blood_flow_status','vw_blood_inventory_available','vw_blood_supply_plan','vw_capa_control_status','vw_cold_chain_excursions','vw_command_center_today','vw_competency_alerts','vw_competency_compliance_summary','vw_continuity_readiness','vw_current_user_health','vw_daily_branch_operations','vw_daily_close_reconciliation','vw_dispatch_sales_reconciliation','vw_document_control_status','vw_donor_summary','vw_donors_required_plan','vw_environmental_alerts','vw_eqa_alerts','vw_equipment_alerts','vw_exception_candidates','vw_exception_portfolio','vw_feature_complete_scorecard','vw_inspection_summary','vw_internal_audit_portfolio','vw_inventory_status','vw_iqc_alerts','vw_management_action_portfolio','vw_management_review_inputs','vw_management_scorecard','vw_monthly_product_costs','vw_my_access','vw_my_security_context','vw_open_management_alerts','vw_plan_vs_actual_status','vw_production_summary_30d','vw_project_portfolio','vw_qms_governance_summary','vw_qms_open_actions','vw_quality_today','vw_reagent_alerts','vw_release_1_0_readiness','vw_resource_control_summary','vw_sale_lines_editable','vw_sales_operational_summary','vw_screening_release_queue','vw_screening_summary','vw_security_readiness','vw_staff_competency_gaps','vw_supplier_performance','vw_supply_alerts','vw_uat_summary','weekly_management_reviews'
  ]::text[])
), expected_rpc(name) as (
  select unnest(array[
'adjust_sale_line','audit_finding_create_capa','audit_finding_to_nonconformity','calculate_monthly_product_costs','capture_daily_operational_close','create_approval_request','create_exception_from_candidate','decide_approval_request','execute_approved_action','log_access_event','log_diagnostic_event','production_healthcheck','refresh_forecasts','request_capa_close','request_document_approval','review_and_release_unit'
  ]::text[])
), existing_rel as (
  select c.relname name
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind in ('r','p','v','m')
), existing_rpc as (
  select distinct p.proname name
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
), critical(table_name,column_name) as (
  values
    ('incidents','id'),('incidents','requires_quality_followup'),
    ('dispatches','id'),('dispatches','dispatch_date'),
    ('nonconformities','id'),('nonconformities','status'),
    ('capa','id'),('capa','status'),
    ('release_signoffs','id'),('uat_test_cases','id')
), missing_rel as (
  select e.name from expected_rel e
  where not exists(select 1 from existing_rel x where x.name=e.name)
), missing_rpc as (
  select e.name from expected_rpc e
  where not exists(select 1 from existing_rpc x where x.name=e.name)
), missing_cols as (
  select c.* from critical c
  where not exists(
    select 1 from information_schema.columns ic
    where ic.table_schema='public'
      and ic.table_name=c.table_name
      and ic.column_name=c.column_name
  )
), forbidden_cols as (
  select 'incidents'::text table_name,'status'::text column_name
  where exists(
    select 1 from information_schema.columns
    where table_schema='public' and table_name='incidents' and column_name='status'
  )
), gate as (
  select
    (select count(*) from expected_rel) expected_relations,
    (select count(*) from expected_rpc) expected_rpcs,
    (select count(*) from missing_rel) missing_relation_count,
    (select count(*) from missing_rpc) missing_rpc_count,
    (select count(*) from missing_cols) missing_column_count,
    (select count(*) from forbidden_cols) forbidden_column_count,
    exists(
      select 1 from public.app_migrations
      where version='0.44.0' and migration_code='44_RELEASE_1_0_RC_v0_44'
    ) baseline_ok
)
select jsonb_build_object(
  'gate','C13-J',
  'version','0.44.17',
  'expected_relations',g.expected_relations,
  'expected_rpcs',g.expected_rpcs,
  'missing_relations',coalesce((select jsonb_agg(name order by name) from missing_rel),'[]'::jsonb),
  'missing_rpcs',coalesce((select jsonb_agg(name order by name) from missing_rpc),'[]'::jsonb),
  'missing_critical_columns',coalesce((select jsonb_agg(table_name||'.'||column_name order by table_name,column_name) from missing_cols),'[]'::jsonb),
  'forbidden_columns_present',coalesce((select jsonb_agg(table_name||'.'||column_name order by table_name,column_name) from forbidden_cols),'[]'::jsonb),
  'baseline_0_44_0',g.baseline_ok,
  'result',case when g.missing_relation_count=0 and g.missing_rpc_count=0 and g.missing_column_count=0 and g.forbidden_column_count=0 and g.baseline_ok then 'PASS' else 'STOP' end
) as c13j_runtime_contract
from gate g;
