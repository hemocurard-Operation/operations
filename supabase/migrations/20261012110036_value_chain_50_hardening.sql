-- HemoCura Value Chain 50 hardening
-- Split write RLS policies to avoid SELECT overlap, add focused indexes, and harden scorecard vocabulary.

drop policy if exists donor_campaigns_write on public.donor_campaigns;
drop policy if exists donor_campaigns_insert on public.donor_campaigns;
drop policy if exists donor_campaigns_update on public.donor_campaigns;
drop policy if exists donor_campaigns_delete on public.donor_campaigns;
create policy donor_campaigns_insert on public.donor_campaigns for insert to authenticated
with check (public.has_permission('DONOR_OUTREACH_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));
create policy donor_campaigns_update on public.donor_campaigns for update to authenticated
using (public.has_permission('DONOR_OUTREACH_WRITE') and (branch_id is null or public.can_access_branch(branch_id)))
with check (public.has_permission('DONOR_OUTREACH_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));
create policy donor_campaigns_delete on public.donor_campaigns for delete to authenticated
using (public.has_permission('DONOR_OUTREACH_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));

drop policy if exists customer_agreements_write on public.customer_service_agreements;
drop policy if exists customer_agreements_insert on public.customer_service_agreements;
drop policy if exists customer_agreements_update on public.customer_service_agreements;
drop policy if exists customer_agreements_delete on public.customer_service_agreements;
create policy customer_agreements_insert on public.customer_service_agreements for insert to authenticated
with check (public.has_permission('CUSTOMER_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));
create policy customer_agreements_update on public.customer_service_agreements for update to authenticated
using (public.has_permission('CUSTOMER_WRITE') and (branch_id is null or public.can_access_branch(branch_id)))
with check (public.has_permission('CUSTOMER_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));
create policy customer_agreements_delete on public.customer_service_agreements for delete to authenticated
using (public.has_permission('CUSTOMER_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));

drop policy if exists customer_feedback_write on public.customer_feedback;
drop policy if exists customer_feedback_insert on public.customer_feedback;
drop policy if exists customer_feedback_update on public.customer_feedback;
drop policy if exists customer_feedback_delete on public.customer_feedback;
create policy customer_feedback_insert on public.customer_feedback for insert to authenticated
with check (public.has_permission('CUSTOMER_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));
create policy customer_feedback_update on public.customer_feedback for update to authenticated
using (public.has_permission('CUSTOMER_WRITE') and (branch_id is null or public.can_access_branch(branch_id)))
with check (public.has_permission('CUSTOMER_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));
create policy customer_feedback_delete on public.customer_feedback for delete to authenticated
using (public.has_permission('CUSTOMER_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));

drop policy if exists integrated_actions_write on public.integrated_actions;
drop policy if exists integrated_actions_insert on public.integrated_actions;
drop policy if exists integrated_actions_update on public.integrated_actions;
drop policy if exists integrated_actions_delete on public.integrated_actions;
create policy integrated_actions_insert on public.integrated_actions for insert to authenticated
with check (public.has_permission('ACTIONS_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));
create policy integrated_actions_update on public.integrated_actions for update to authenticated
using (public.has_permission('ACTIONS_WRITE') and (branch_id is null or public.can_access_branch(branch_id)))
with check (public.has_permission('ACTIONS_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));
create policy integrated_actions_delete on public.integrated_actions for delete to authenticated
using (public.has_permission('ACTIONS_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));

drop policy if exists customers_write on public.customers;
drop policy if exists customers_insert on public.customers;
drop policy if exists customers_update on public.customers;
drop policy if exists customers_delete on public.customers;
create policy customers_insert on public.customers for insert to authenticated with check (public.has_permission('CUSTOMER_WRITE'));
create policy customers_update on public.customers for update to authenticated using (public.has_permission('CUSTOMER_WRITE')) with check (public.has_permission('CUSTOMER_WRITE'));
create policy customers_delete on public.customers for delete to authenticated using (public.has_permission('CUSTOMER_WRITE'));

drop policy if exists demand_branch_write on public.clinical_demand_requests;
drop policy if exists demand_branch_insert on public.clinical_demand_requests;
drop policy if exists demand_branch_update on public.clinical_demand_requests;
drop policy if exists demand_branch_delete on public.clinical_demand_requests;
create policy demand_branch_insert on public.clinical_demand_requests for insert to authenticated
with check (public.can_access_branch(branch_id) and (public.has_permission('VALUE_CHAIN_WRITE') or public.has_permission('SUPPLY_WRITE') or public.has_permission('DISPATCH_WRITE')));
create policy demand_branch_update on public.clinical_demand_requests for update to authenticated
using (public.can_access_branch(branch_id) and (public.has_permission('VALUE_CHAIN_WRITE') or public.has_permission('SUPPLY_WRITE') or public.has_permission('DISPATCH_WRITE')))
with check (public.can_access_branch(branch_id) and (public.has_permission('VALUE_CHAIN_WRITE') or public.has_permission('SUPPLY_WRITE') or public.has_permission('DISPATCH_WRITE')));
create policy demand_branch_delete on public.clinical_demand_requests for delete to authenticated
using (public.can_access_branch(branch_id) and (public.has_permission('VALUE_CHAIN_WRITE') or public.has_permission('SUPPLY_WRITE') or public.has_permission('DISPATCH_WRITE')));

create index if not exists idx_clinical_demand_branch_status_needed on public.clinical_demand_requests(branch_id,status,needed_by);
create index if not exists idx_clinical_demand_customer on public.clinical_demand_requests(customer_id);
create index if not exists idx_clinical_demand_product on public.clinical_demand_requests(product_id);
create index if not exists idx_customer_agreements_branch_active on public.customer_service_agreements(branch_id,active);
create index if not exists idx_customer_feedback_branch_status_date on public.customer_feedback(branch_id,status,feedback_date desc);
create index if not exists idx_customer_feedback_action on public.customer_feedback(linked_action_id);
create index if not exists idx_integrated_actions_owner_status on public.integrated_actions(owner_user_id,status);
create index if not exists idx_integrated_actions_verified_by on public.integrated_actions(verified_by);
create index if not exists idx_donor_campaigns_created_by on public.donor_campaigns(created_by);

create or replace view public.vw_value_chain_scorecard with (security_invoker=true) as
select b.id as branch_id,b.code as branch_code,b.name as branch_name,
  (select count(*) from public.clinical_demand_requests d where d.branch_id=b.id and upper(coalesce(d.status,'')) not in ('CERRADA','CANCELADA','ATENDIDA'))::integer as open_demand,
  (select coalesce(sum(i.quantity),0) from public.blood_inventory_units i where i.branch_id=b.id and upper(coalesce(i.inventory_status,'')) in ('AVAILABLE','DISPONIBLE'))::numeric as available_units,
  (select count(*) from public.dispatches x where x.branch_id=b.id and x.dispatch_date>=current_date-30 and upper(coalesce(x.status,'')) not in ('CANCELADO','CANCELADA'))::integer as dispatches_30d,
  (select coalesce(sum(s.total_amount),0) from public.operational_sales s where s.branch_id=b.id and s.sale_date>=current_date-30)::numeric as billed_30d,
  (select coalesce(sum(s.collected_amount),0) from public.operational_sales s where s.branch_id=b.id and s.sale_date>=current_date-30)::numeric as collected_30d,
  (select count(*) from public.donor_campaigns c where (c.branch_id=b.id or c.branch_id is null) and c.status='ACTIVA')::integer as active_campaigns,
  (select count(*) from public.customer_feedback f where (f.branch_id=b.id or f.branch_id is null) and f.status<>'CERRADO')::integer as open_feedback,
  (select count(*) from public.integrated_actions a where (a.branch_id=b.id or a.branch_id is null) and a.status not in ('CERRADA','CANCELADA'))::integer as open_actions
from public.branches b where b.active=true;

grant select on public.vw_value_chain_scorecard to authenticated;
