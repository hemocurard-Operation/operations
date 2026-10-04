begin;
create or replace view public.vw_feature_complete_scorecard as
select
 (select count(*) from public.branches where active) branches,
 (select count(*) from public.vw_audit_findings_open) audit_findings_open,
 (select count(*) from public.capa where status not in ('CERRADA','CANCELADA')) capa_open,
 (select count(*) from public.vw_competency_alerts) competency_alerts,
 (select count(*) from public.vw_equipment_alerts) equipment_alerts,
 (select count(*) from public.vw_reagent_alerts) reagent_alerts,
 (select count(*) from public.vw_iqc_alerts) iqc_alerts,
 (select count(*) from public.hemovigilance_events where status not in ('CERRADO','CANCELADO')) hemovigilance_open,
 (select count(*) from public.vw_cold_chain_excursions where reading_time>=now()-interval '30 days') cold_chain_excursions_30d,
 (select count(*) from public.vw_supplier_performance where review_overdue) supplier_reviews_overdue,
 (select count(*) from public.quality_objectives where status in ('ABIERTO','EN_CURSO')) quality_objectives_open,
 (select count(*) from public.continuity_plans where status='ACTIVO') continuity_plans_active;
grant select on public.vw_feature_complete_scorecard to authenticated;
insert into public.app_migrations(migration_code,version,description,applied_by)
values('42_FEATURE_COMPLETE_v0_42','0.42.0','Integración funcional end-to-end',auth.uid())
on conflict(migration_code) do update set applied_at=now(),version=excluded.version,description=excluded.description,applied_by=auth.uid();
commit;