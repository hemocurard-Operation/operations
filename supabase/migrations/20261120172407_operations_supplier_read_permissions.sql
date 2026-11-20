begin;
alter policy supplier_evaluations_scoped on public.supplier_evaluations using(
 (public.has_permission('PURCHASE_VIEW') or public.has_permission('SUPPLIERS_VIEW'))
 and (public.operations_branch_allowed(branch_id) or branch_id is null and public.wf_active_actor() and public.has_role('SUPER_USUARIO')));
alter policy supplier_incidents_scoped on public.supplier_incidents using(
 (public.has_permission('PURCHASE_VIEW') or public.has_permission('SUPPLIERS_VIEW'))
 and (public.operations_branch_allowed(branch_id) or branch_id is null and public.wf_active_actor() and public.has_role('SUPER_USUARIO')));
notify pgrst,'reload schema';
commit;
