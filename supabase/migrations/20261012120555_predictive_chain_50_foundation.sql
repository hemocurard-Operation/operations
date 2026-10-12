-- HemoCura Predictive Chain 50 foundation (live migration 20261012120555)
insert into public.app_permissions(permission_code,module,description,risk_level,active)
values ('PREDICTIVE_VIEW','PREDICTIVE','Ver cockpit predictivo y señales priorizadas','NORMAL',true),('PREDICTIVE_WRITE','PREDICTIVE','Registrar decisiones sobre recomendaciones predictivas','SENSIBLE',true)
on conflict (permission_code) do update set module=excluded.module,description=excluded.description,risk_level=excluded.risk_level,active=true;
insert into public.role_permissions(role_id,permission_code) select r.id,p.code from public.roles r cross join (values ('PREDICTIVE_VIEW'),('PREDICTIVE_WRITE')) p(code) where r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_GENERAL','GERENCIA_OPERATIVA') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code) select r.id,'PREDICTIVE_VIEW' from public.roles r where r.code in ('SOCIO','CALIDAD','FINANZAS','MEDICO_GERENTE_TECNICO') on conflict do nothing;
create table if not exists public.predictive_decision_reviews(id uuid primary key default gen_random_uuid(),candidate_key text not null,branch_id uuid references public.branches(id),domain text not null,source_table text,source_id uuid,decision text not null check(decision in ('ACEPTAR','DIFERIR','DESCARTAR','OBSERVAR')),rationale text,review_due_date date,linked_action_id uuid references public.integrated_actions(id),reviewed_by uuid default auth.uid(),reviewed_at timestamptz not null default now(),created_at timestamptz not null default now());
create index if not exists idx_predictive_review_key on public.predictive_decision_reviews(candidate_key,reviewed_at desc); create index if not exists idx_predictive_review_branch on public.predictive_decision_reviews(branch_id,reviewed_at desc);
alter table public.predictive_decision_reviews enable row level security;
create policy predictive_review_select on public.predictive_decision_reviews for select to authenticated using(has_permission('PREDICTIVE_VIEW') and (branch_id is null or can_access_branch(branch_id)));
create policy predictive_review_insert on public.predictive_decision_reviews for insert to authenticated with check(has_permission('PREDICTIVE_WRITE') and (branch_id is null or can_access_branch(branch_id)) and reviewed_by=(select auth.uid()));
create policy predictive_review_update on public.predictive_decision_reviews for update to authenticated using(has_permission('PREDICTIVE_WRITE') and (branch_id is null or can_access_branch(branch_id))) with check(has_permission('PREDICTIVE_WRITE') and (branch_id is null or can_access_branch(branch_id)));
create policy predictive_review_delete on public.predictive_decision_reviews for delete to authenticated using(has_permission('PREDICTIVE_WRITE') and (branch_id is null or can_access_branch(branch_id)));
grant select,insert,update,delete on public.predictive_decision_reviews to authenticated; revoke all on public.predictive_decision_reviews from anon;
-- Analytical views are defined in the live migration with security_invoker=true:
-- vw_predictive_demand_30d, vw_stock_risk_projection, vw_cash_collection_forecast,
-- vw_customer_health_score, vw_branch_productivity_30d, vw_avoidable_loss_signals,
-- vw_predictive_action_candidates.
-- See docs/PREDICTIVE_CHAIN_50_EXECUTION_REPORT.md for formula definitions and validation evidence.
