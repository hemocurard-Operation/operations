-- Local-only policy parity for legacy hardening already present in production.
CREATE OR REPLACE FUNCTION public.hc_has_any_role(p_roles text[])
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path=''
AS $function$
  select exists(
    select 1
    from unnest(p_roles) r
    where public.has_role(r)
  )
$function$

;
revoke all on function public.hc_has_any_role(text[]) from public,anon;
grant execute on function public.hc_has_any_role(text[]) to authenticated;
do $p$ declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='suppliers' loop execute format('drop policy %I on public.%I',p.policyname,'suppliers');end loop;end $p$;
alter table public."suppliers" enable row level security;
create policy "suppliers_select" on public."suppliers" as PERMISSIVE for SELECT to public using ((auth.role() = 'authenticated'::text));
create policy "suppliers_write" on public."suppliers" as PERMISSIVE for ALL to public using (hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'INVENTARIO'::text])) with check (hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'INVENTARIO'::text]));
do $p$ declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='supplier_evaluations' loop execute format('drop policy %I on public.%I',p.policyname,'supplier_evaluations');end loop;end $p$;
alter table public."supplier_evaluations" enable row level security;
create policy "supplier_evaluations_select" on public."supplier_evaluations" as PERMISSIVE for SELECT to public using ((auth.role() = 'authenticated'::text));
create policy "supplier_evaluations_write" on public."supplier_evaluations" as PERMISSIVE for ALL to public using (hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'INVENTARIO'::text])) with check (hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'INVENTARIO'::text]));
do $p$ declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='supplier_incidents' loop execute format('drop policy %I on public.%I',p.policyname,'supplier_incidents');end loop;end $p$;
alter table public."supplier_incidents" enable row level security;
create policy "supplier_incidents_select" on public."supplier_incidents" as PERMISSIVE for SELECT to public using (((branch_id IS NULL) OR can_access_branch(branch_id)));
create policy "supplier_incidents_write" on public."supplier_incidents" as PERMISSIVE for ALL to public using ((((branch_id IS NULL) OR can_access_branch(branch_id)) AND hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'INVENTARIO'::text]))) with check ((((branch_id IS NULL) OR can_access_branch(branch_id)) AND hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'INVENTARIO'::text])));
do $p$ declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='hemovigilance_events' loop execute format('drop policy %I on public.%I',p.policyname,'hemovigilance_events');end loop;end $p$;
alter table public."hemovigilance_events" enable row level security;
create policy "hemovig_actor_delete_guard" on public."hemovigilance_events" as RESTRICTIVE for DELETE to "authenticated" using (false);
create policy "hemovig_actor_insert_guard" on public."hemovigilance_events" as RESTRICTIVE for INSERT to "authenticated" with check ((wf_active_actor() AND has_permission('HEMOVIGILANCE_WRITE'::text) AND (((branch_id IS NULL) AND (event_type <> 'NC_ENTREGA'::text)) OR can_access_branch(branch_id)) AND ((event_type <> 'NC_ENTREGA'::text) OR (branch_id IS NOT NULL))));
create policy "hemovig_actor_read_guard" on public."hemovigilance_events" as RESTRICTIVE for SELECT to "authenticated" using ((wf_active_actor() AND has_permission('HEMOVIGILANCE_VIEW'::text) AND ((branch_id IS NULL) OR can_access_branch(branch_id))));
create policy "hemovig_actor_update_guard" on public."hemovigilance_events" as RESTRICTIVE for UPDATE to "authenticated" using ((wf_active_actor() AND has_permission('HEMOVIGILANCE_WRITE'::text) AND ((branch_id IS NULL) OR can_access_branch(branch_id)))) with check ((wf_active_actor() AND has_permission('HEMOVIGILANCE_WRITE'::text) AND (((branch_id IS NULL) AND (event_type <> 'NC_ENTREGA'::text)) OR can_access_branch(branch_id)) AND ((event_type <> 'NC_ENTREGA'::text) OR (branch_id IS NOT NULL))));
create policy "hemovig_select" on public."hemovigilance_events" as PERMISSIVE for SELECT to public using (((branch_id IS NULL) OR can_access_branch(branch_id)));
create policy "hemovig_write" on public."hemovigilance_events" as PERMISSIVE for ALL to public using ((((branch_id IS NULL) OR can_access_branch(branch_id)) AND hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'LABORATORIO'::text, 'ENCARGADA_LABORATORIO'::text]))) with check ((((branch_id IS NULL) OR can_access_branch(branch_id)) AND hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'LABORATORIO'::text, 'ENCARGADA_LABORATORIO'::text])));
do $p$ declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='product_recalls' loop execute format('drop policy %I on public.%I',p.policyname,'product_recalls');end loop;end $p$;
alter table public."product_recalls" enable row level security;
create policy "recalls_select" on public."product_recalls" as PERMISSIVE for SELECT to public using (((branch_id IS NULL) OR can_access_branch(branch_id)));
create policy "recalls_write" on public."product_recalls" as PERMISSIVE for ALL to public using ((((branch_id IS NULL) OR can_access_branch(branch_id)) AND hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'LABORATORIO'::text, 'ENCARGADA_LABORATORIO'::text]))) with check ((((branch_id IS NULL) OR can_access_branch(branch_id)) AND hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'LABORATORIO'::text, 'ENCARGADA_LABORATORIO'::text])));
do $p$ declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='recall_units' loop execute format('drop policy %I on public.%I',p.policyname,'recall_units');end loop;end $p$;
alter table public."recall_units" enable row level security;
create policy "recall_units_select" on public."recall_units" as PERMISSIVE for SELECT to public using ((EXISTS ( SELECT 1
   FROM product_recalls r
  WHERE ((r.id = recall_units.recall_id) AND ((r.branch_id IS NULL) OR can_access_branch(r.branch_id))))));
create policy "recall_units_write" on public."recall_units" as PERMISSIVE for ALL to public using ((hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'LABORATORIO'::text, 'ENCARGADA_LABORATORIO'::text]) AND (EXISTS ( SELECT 1
   FROM product_recalls r
  WHERE ((r.id = recall_units.recall_id) AND ((r.branch_id IS NULL) OR can_access_branch(r.branch_id))))))) with check ((hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'LABORATORIO'::text, 'ENCARGADA_LABORATORIO'::text]) AND (EXISTS ( SELECT 1
   FROM product_recalls r
  WHERE ((r.id = recall_units.recall_id) AND ((r.branch_id IS NULL) OR can_access_branch(r.branch_id)))))));
do $p$ declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='continuity_plans' loop execute format('drop policy %I on public.%I',p.policyname,'continuity_plans');end loop;end $p$;
alter table public."continuity_plans" enable row level security;
create policy "continuity_plans_select" on public."continuity_plans" as PERMISSIVE for SELECT to public using ((auth.role() = 'authenticated'::text));
create policy "continuity_plans_write" on public."continuity_plans" as PERMISSIVE for ALL to public using (hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'TI'::text])) with check (hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'TI'::text]));
do $p$ declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='continuity_tests' loop execute format('drop policy %I on public.%I',p.policyname,'continuity_tests');end loop;end $p$;
alter table public."continuity_tests" enable row level security;
create policy "continuity_tests_select" on public."continuity_tests" as PERMISSIVE for SELECT to public using ((auth.role() = 'authenticated'::text));
create policy "continuity_tests_write" on public."continuity_tests" as PERMISSIVE for ALL to public using (hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'TI'::text])) with check (hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'TI'::text]));
do $p$ declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='data_integrity_checks' loop execute format('drop policy %I on public.%I',p.policyname,'data_integrity_checks');end loop;end $p$;
alter table public."data_integrity_checks" enable row level security;
create policy "data_integrity_checks_select" on public."data_integrity_checks" as PERMISSIVE for SELECT to public using ((auth.role() = 'authenticated'::text));
create policy "data_integrity_checks_write" on public."data_integrity_checks" as PERMISSIVE for ALL to public using (hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'TI'::text])) with check (hc_has_any_role(ARRAY['ADMIN'::text, 'GERENCIA_OPERATIVA'::text, 'CALIDAD'::text, 'TI'::text]));
do $p$ declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='stg_resp_despachos' loop execute format('drop policy %I on public.%I',p.policyname,'stg_resp_despachos');end loop;end $p$;
alter table public."stg_resp_despachos" enable row level security;
create policy "c13a_stg_resp_despachos_admin_select" on public."stg_resp_despachos" as PERMISSIVE for SELECT to "authenticated" using (has_permission('ACCESS_ADMIN'::text));
do $p$ declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='stg_requerimientos' loop execute format('drop policy %I on public.%I',p.policyname,'stg_requerimientos');end loop;end $p$;
alter table public."stg_requerimientos" enable row level security;
create policy "c13a_stg_requerimientos_admin_select" on public."stg_requerimientos" as PERMISSIVE for SELECT to "authenticated" using (has_permission('ACCESS_ADMIN'::text));
do $p$ declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='migration_issues' loop execute format('drop policy %I on public.%I',p.policyname,'migration_issues');end loop;end $p$;
alter table public."migration_issues" enable row level security;
create policy "c13a_migration_issues_select" on public."migration_issues" as PERMISSIVE for SELECT to "authenticated" using ((has_permission('RELEASE_GATE_VIEW'::text) OR has_permission('ACCESS_ADMIN'::text)));

