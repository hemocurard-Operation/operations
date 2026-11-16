begin;
-- Register existing, mounted operational screens. No financial drafts are enabled.
insert into public.app_module_catalog(route_key,title,group_name,permission_code) values
('maintenance','Mantenimiento','LABORATORIO Y SANGRE','RESOURCES_VIEW'),
('congresses','Congresos y Noticias','CADENA DE VALOR','COMMERCIAL_VIEW'),
('supplytransfers','Traslado de Insumos','TRABAJO DIARIO','SUPPLY_TRANSFER_VIEW')
on conflict(route_key) do nothing;
insert into public.role_module_access(role_id,route_key,enabled)
select r.id,m.route_key,r.code='SUPER_USUARIO'
from public.roles r cross join public.app_module_catalog m
where m.route_key in ('maintenance','congresses','supplytransfers') on conflict do nothing;
-- Restore the global administrator at old explicit role gates. Functions remain
-- invoker; branch/RLS, evidence, result, idempotency and audit checks stay intact.
create or replace function public.inspection_finding_to_nonconformity(
 p_finding_id uuid,
 p_owner_user_id uuid,
 p_due_date date
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
 v_f public.inspection_findings%rowtype;
 v_i public.branch_inspections%rowtype;
 v_nc uuid;
 v_code text;
begin
 if not ((public.wf_active_actor() and public.has_role('SUPER_USUARIO')) or public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) then
  raise exception 'Rol no autorizado';
 end if;

 select * into v_f from public.inspection_findings where id=p_finding_id for update;
 if v_f.id is null then raise exception 'Hallazgo no encontrado'; end if;
 if v_f.result<>'NC' then
  raise exception 'Solo hallazgos con resultado No Cumple pueden generar NC';
 end if;
 if v_f.nonconformity_id is not null then return v_f.nonconformity_id; end if;

 select * into v_i from public.branch_inspections where id=v_f.inspection_id;
 if not public.can_access_branch(v_i.branch_id) then raise exception 'Sucursal no autorizada'; end if;

 v_code:='NC-INS-'||to_char(current_date,'YYYYMMDD')||'-'||upper(substr(md5(random()::text),1,5));

 insert into public.nonconformities(
  code,branch_id,description,status,owner_user_id,due_date
 ) values(
  v_code,v_i.branch_id,
  concat(v_f.section_name,' · ',v_f.criterion,coalesce(': '||v_f.observation,'')),
  'ABIERTA',p_owner_user_id,p_due_date
 )
 returning id into v_nc;

 update public.inspection_findings set nonconformity_id=v_nc where id=v_f.id;

 perform public.log_audit_event(
  'INSPECCION','CREATE_NC',v_i.branch_id,'inspection_findings',v_f.id,v_i.inspection_code,
  null,jsonb_build_object('nonconformity_id',v_nc,'nc_code',v_code),null
 );

 return v_nc;
end;
$$;
create or replace function public.inspection_finding_create_capa(
 p_finding_id uuid,
 p_action_plan text,
 p_owner_user_id uuid,
 p_due_date date
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
 v_f public.inspection_findings%rowtype;
 v_i public.branch_inspections%rowtype;
 v_capa uuid;
 v_code text;
begin
 if not ((public.wf_active_actor() and public.has_role('SUPER_USUARIO')) or public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) then
  raise exception 'Rol no autorizado';
 end if;

 select * into v_f from public.inspection_findings where id=p_finding_id for update;
 if v_f.id is null then raise exception 'Hallazgo no encontrado'; end if;
 if v_f.nonconformity_id is null then
  raise exception 'El hallazgo debe tener una NC vinculada antes de crear CAPA';
 end if;
 if v_f.capa_id is not null then return v_f.capa_id; end if;
 if trim(coalesce(p_action_plan,''))='' then raise exception 'Plan de acción obligatorio'; end if;

 select * into v_i from public.branch_inspections where id=v_f.inspection_id;
 if not public.can_access_branch(v_i.branch_id) then raise exception 'Sucursal no autorizada'; end if;

 v_code:='CAPA-INS-'||to_char(current_date,'YYYYMMDD')||'-'||upper(substr(md5(random()::text),1,5));

 insert into public.capa(
  code,nonconformity_id,problem,action_plan,owner_user_id,due_date,status
 ) values(
  v_code,v_f.nonconformity_id,
  concat(v_f.section_name,' · ',v_f.criterion,coalesce(': '||v_f.observation,'')),
  p_action_plan,p_owner_user_id,p_due_date,'ABIERTA'
 )
 returning id into v_capa;

 update public.inspection_findings set capa_id=v_capa where id=v_f.id;

 perform public.log_audit_event(
  'INSPECCION','CREATE_CAPA',v_i.branch_id,'inspection_findings',v_f.id,v_i.inspection_code,
  null,jsonb_build_object('capa_id',v_capa,'capa_code',v_code),null
 );

 return v_capa;
end;
$$;
create or replace function public.iso_clause_assessment_upsert(
  p_criterion_id uuid,
  p_branch_id uuid,
  p_status text,
  p_responsible_user_id uuid,
  p_notes text,
  p_next_review_date date
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_id uuid;
  v_before jsonb;
begin
  if not ((public.wf_active_actor() and public.has_role('SUPER_USUARIO')) or public.has_role('ADMIN') or public.has_role('CALIDAD')) then
    raise exception 'Rol no autorizado';
  end if;
  if p_branch_id is not null and not public.can_access_branch(p_branch_id) then
    raise exception 'Sucursal no autorizada';
  end if;
  if p_status not in ('CUMPLE','PARCIAL','NO_CUMPLE','NO_APLICA','PENDIENTE') then
    raise exception 'Estado no válido';
  end if;

  select id,to_jsonb(a.*) into v_id,v_before
  from public.iso_clause_assessments a
  where criterion_id=p_criterion_id and branch_id is not distinct from p_branch_id
  for update;

  if v_id is null then
    insert into public.iso_clause_assessments(
      criterion_id,branch_id,status,responsible_user_id,notes,next_review_date,
      last_reviewed_at,updated_by
    ) values(
      p_criterion_id,p_branch_id,p_status,p_responsible_user_id,p_notes,p_next_review_date,
      now(),auth.uid()
    )
    returning id into v_id;
  else
    update public.iso_clause_assessments set
      status=p_status,
      responsible_user_id=p_responsible_user_id,
      notes=p_notes,
      next_review_date=p_next_review_date,
      last_reviewed_at=now(),
      updated_by=auth.uid(),
      updated_at=now()
    where id=v_id;
  end if;

  perform public.log_audit_event(
    'SGC','ISO_CLAUSE_ASSESSMENT',p_branch_id,'iso_clause_assessments',v_id,
    p_criterion_id::text,v_before,jsonb_build_object('status',p_status),null
  );

  return v_id;
end;
$$;
create or replace function public.iso_clause_assessment_create_nc(
  p_assessment_id uuid,
  p_owner_user_id uuid,
  p_due_date date,
  p_description text
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_a public.iso_clause_assessments%rowtype;
  v_c public.audit_criteria_catalog%rowtype;
  v_nc uuid;
  v_code text;
begin
  if not ((public.wf_active_actor() and public.has_role('SUPER_USUARIO')) or public.has_role('ADMIN') or public.has_role('CALIDAD')) then
    raise exception 'Rol no autorizado';
  end if;

  select * into v_a from public.iso_clause_assessments where id=p_assessment_id for update;
  if v_a.id is null then raise exception 'Autoevaluación no encontrada'; end if;
  if v_a.branch_id is not null and not public.can_access_branch(v_a.branch_id) then
    raise exception 'Sucursal no autorizada';
  end if;
  if v_a.status<>'NO_CUMPLE' then
    raise exception 'Solo cláusulas en estado NO_CUMPLE pueden generar NC';
  end if;
  if v_a.nonconformity_id is not null then return v_a.nonconformity_id; end if;

  select * into v_c from public.audit_criteria_catalog where id=v_a.criterion_id;

  v_code:='NC-ISO-'||to_char(current_date,'YYYYMMDD')||'-'||upper(substr(md5(random()::text),1,5));

  insert into public.nonconformities(
    code,branch_id,description,status,owner_user_id,due_date
  ) values(
    v_code,v_a.branch_id,
    concat(v_c.framework,' ',v_c.clause_reference,' · ',v_c.criterion_summary,coalesce(': '||p_description,'')),
    'ABIERTA',p_owner_user_id,p_due_date
  )
  returning id into v_nc;

  update public.iso_clause_assessments set nonconformity_id=v_nc,updated_at=now() where id=v_a.id;

  perform public.log_audit_event(
    'SGC','CREATE_NC',v_a.branch_id,'iso_clause_assessments',v_a.id,v_c.criterion_code,
    null,jsonb_build_object('nonconformity_id',v_nc,'nc_code',v_code),null
  );

  return v_nc;
end;
$$;

-- Add only active global-owner access to the existing ISO policies.
alter policy iso_clause_assessments_write on public.iso_clause_assessments
using ((branch_id is null or public.can_access_branch(branch_id)) and
 ((public.wf_active_actor() and public.has_role('SUPER_USUARIO')) or public.has_role('ADMIN') or public.has_role('CALIDAD')))
with check ((branch_id is null or public.can_access_branch(branch_id)) and
 ((public.wf_active_actor() and public.has_role('SUPER_USUARIO')) or public.has_role('ADMIN') or public.has_role('CALIDAD')));
alter policy iso_clause_evidence_access on public.iso_clause_evidence
with check (((public.wf_active_actor() and public.has_role('SUPER_USUARIO')) or public.has_role('ADMIN') or public.has_role('CALIDAD'))
 and exists(select 1 from public.iso_clause_assessments a where a.id=assessment_id and (a.branch_id is null or public.can_access_branch(a.branch_id))));
create or replace function public.audit_finding_to_nonconformity(
  p_finding_id uuid,
  p_owner_user_id uuid,
  p_due_date date
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_f public.audit_findings%rowtype;
  v_a public.internal_audits%rowtype;
  v_nc uuid;
  v_code text;
begin
  if not ((public.wf_active_actor() and public.has_role('SUPER_USUARIO')) or public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) then
    raise exception 'Rol no autorizado';
  end if;

  select * into v_f from public.audit_findings where id=p_finding_id for update;
  if v_f.id is null then raise exception 'Hallazgo no encontrado'; end if;
  if v_f.finding_type<>'NO_CONFORMIDAD' then
    raise exception 'Solo hallazgos NO_CONFORMIDAD pueden generar NC';
  end if;
  if v_f.nonconformity_id is not null then return v_f.nonconformity_id; end if;

  select * into v_a from public.internal_audits where id=v_f.audit_id;

  v_code:='NC-AUD-'||to_char(current_date,'YYYYMMDD')||'-'||upper(substr(md5(random()::text),1,5));

  insert into public.nonconformities(
    code,branch_id,process_id,description,status,owner_user_id,due_date
  ) values(
    v_code,v_a.branch_id,v_a.process_id,
    concat(v_f.title,': ',v_f.description),
    'ABIERTA',p_owner_user_id,p_due_date
  )
  returning id into v_nc;

  update public.audit_findings
  set nonconformity_id=v_nc,status='EN_TRATAMIENTO'
  where id=v_f.id;

  perform public.log_audit_event(
    'AUDITORIA','CREATE_NC',v_a.branch_id,'audit_findings',v_f.id,v_f.finding_code,
    null,jsonb_build_object('nonconformity_id',v_nc,'nc_code',v_code),null
  );

  return v_nc;
end;
$$;
create or replace function public.audit_finding_create_capa(
  p_finding_id uuid,
  p_action_plan text,
  p_owner_user_id uuid,
  p_due_date date
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_f public.audit_findings%rowtype;
  v_capa uuid;
  v_code text;
begin
  if not ((public.wf_active_actor() and public.has_role('SUPER_USUARIO')) or public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) then
    raise exception 'Rol no autorizado';
  end if;

  select * into v_f from public.audit_findings where id=p_finding_id for update;
  if v_f.id is null then raise exception 'Hallazgo no encontrado'; end if;
  if v_f.nonconformity_id is null then
    raise exception 'El hallazgo debe tener una NC vinculada antes de crear CAPA';
  end if;
  if v_f.capa_id is not null then return v_f.capa_id; end if;
  if trim(coalesce(p_action_plan,''))='' then raise exception 'Plan de acción obligatorio'; end if;

  v_code:='CAPA-AUD-'||to_char(current_date,'YYYYMMDD')||'-'||upper(substr(md5(random()::text),1,5));

  insert into public.capa(
    code,nonconformity_id,problem,action_plan,owner_user_id,due_date,status
  ) values(
    v_code,v_f.nonconformity_id,
    concat(v_f.title,': ',v_f.description),
    p_action_plan,p_owner_user_id,p_due_date,'ABIERTA'
  )
  returning id into v_capa;

  update public.audit_findings
  set capa_id=v_capa,status='EN_TRATAMIENTO'
  where id=v_f.id;

  return v_capa;
end;
$$;

-- Fixed allowlist of legacy ADMIN gates observed in production. Only substitute
-- the ADMIN alternative; retain the full USING/WITH CHECK expressions, roles,
-- command, grants, branch/ownership predicates and all table triggers.
-- No clinical result/signature function or financial policy is changed.
do $legacy_admin$
declare item record; current_policy record; using_sql text; check_sql text; ddl text;
 old_gate text := 'has_role(''ADMIN''::text)';
 new_gate text := '(has_role(''ADMIN''::text) OR (public.wf_active_actor() AND public.has_role(''SUPER_USUARIO'')))';
begin
 for item in select * from (values
 ('access_events','access_events_read'),
 ('app_migrations','app_migrations_write'),
 ('app_releases','app_releases_write'),
 ('approval_policies','approval_policies_write'),
 ('audit_criteria_catalog','audit_criteria_catalog_write'),
 ('audit_evidence','audit_evidence_write'),
 ('audit_findings','audit_findings_write'),
 ('audit_log','audit_log_management_select'),
 ('audit_programs','audit_programs_write'),
 ('blood_stock_targets','blood_stock_targets_write'),
 ('competency_assessments','competency_assessments_write'),
 ('competency_catalog','competency_catalog_write'),
 ('diagnostic_events','diagnostic_events_read'),
 ('document_register','document_register_write'),
 ('eqa_programs','eqa_programs_write'),
 ('exception_generation_rules','exception_generation_rules_write'),
 ('internal_audits','internal_audits_write'),
 ('inventory_policies','invpol_write'),
 ('job_roles','job_roles_write'),
 ('management_actions','management_actions_write'),
 ('production_yield_rules','production_yield_rules_write'),
 ('profiles','profiles_self_or_management_select'),
 ('project_tasks','project_tasks_write'),
 ('projects','projects_write'),
 ('staff_job_assignments','staff_job_assignments_write'),
 ('training_authorizations','training_authorizations_read'),
 ('training_certificates','training_certificates_read'),
 ('training_content_versions','training_content_versions_insert'),
 ('training_content_versions','training_content_versions_update'),
 ('training_events','training_events_write'),
 ('training_participation','training_participation_write'),
 ('training_practical_evidence','training_practical_evidence_read'),
 ('training_quiz_attempts','training_quiz_attempts_read'),
 ('user_roles','user_roles_self_or_admin_select')
 ) as targets(table_name,policy_name)
 loop
  select * into current_policy from pg_policies where schemaname='public' and tablename=item.table_name and policyname=item.policy_name;
  if not found then raise exception 'Required legacy policy %.% is missing',item.table_name,item.policy_name;end if;
  if position('SUPER_USUARIO' in coalesce(current_policy.qual,'')||coalesce(current_policy.with_check,''))>0 then continue;end if;
  if position(old_gate in coalesce(current_policy.qual,'')||coalesce(current_policy.with_check,''))=0 then
   raise exception 'Legacy ADMIN guard changed for %.%; review required',item.table_name,item.policy_name;
  end if;
  using_sql:=replace(current_policy.qual,old_gate,new_gate);
  check_sql:=replace(current_policy.with_check,old_gate,new_gate);
  ddl:=format('alter policy %I on public.%I',item.policy_name,item.table_name);
  if using_sql is not null then ddl:=ddl||format(' using (%s)',using_sql);end if;
  if check_sql is not null then ddl:=ddl||format(' with check (%s)',check_sql);end if;
  execute ddl;
 end loop;
end;
$legacy_admin$;
-- Preserve the existing guarded service and its ACL; no scheduler or caller is added.
create or replace function public.hc_generate_management_alerts(p_date date default current_date)
returns integer
language plpgsql
security definer
set search_path=''
as $$
begin
  if auth.uid() is null then raise exception 'Sesión requerida.' using errcode='42501'; end if;
  if not ((public.wf_active_actor() and public.has_role('SUPER_USUARIO')) or public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('CALIDAD')) then
    raise exception 'Rol no autorizado para generar alertas de gestión.' using errcode='42501';
  end if;
  return public.generate_management_alerts(p_date);
end
$$;
revoke all on function public.hc_generate_management_alerts(date) from public,anon;
grant execute on function public.hc_generate_management_alerts(date) to authenticated;
notify pgrst,'reload schema';
commit;
