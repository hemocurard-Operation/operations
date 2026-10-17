begin;
-- Existing private functions remain non-callable; schema usage is needed only for the explicitly granted APIs below.
do $$begin if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and (has_function_privilege('authenticated',p.oid,'EXECUTE') or has_function_privilege('anon',p.oid,'EXECUTE'))) then raise exception 'Review existing private EXECUTE grants before schema usage';end if;end$$;
grant usage on schema private to authenticated;
-- Functional authorization is independent from navigation. Existing people and branch assignments are preserved.
insert into public.app_permissions(permission_code,module,description,risk_level) values
 ('PRODUCTION_VIEW','BLOOD_OPERATIONS','Consultar producción sin editar inventario','SENSIBLE'),
 ('PRODUCTION_WRITE','BLOOD_OPERATIONS','Registrar producción técnica','CRITICO'),
 ('REQUISITION_VIEW','SUPPLY','Consultar requisiciones de insumos','SENSIBLE'),
 ('COMPETENCY_ASSESS','COMPETENCY','Evaluar personal de laboratorio de la sucursal asignada','CRITICO')
on conflict(permission_code) do nothing;

insert into public.role_permissions(role_id,permission_code) select r.id,p.permission_code from public.roles r cross join public.app_permissions p where r.code='TI' and p.permission_code in ('RELEASE_GATE_VIEW','AUDIT_VIEW','CONTINUITY_VIEW') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code) select r.id,p.permission_code from public.roles r cross join public.app_permissions p where r.code='GERENCIA_GENERAL' and p.permission_code in ('APPROVAL_VIEW') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code) select r.id,p.permission_code from public.roles r cross join public.app_permissions p where r.code='LABORATORIO' and p.permission_code in ('PRODUCTION_VIEW','PRODUCTION_WRITE','REQUISITION_VIEW') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code) select r.id,p.permission_code from public.roles r cross join public.app_permissions p where r.code='ENCARGADA_LABORATORIO' and p.permission_code in ('PRODUCTION_VIEW','PRODUCTION_WRITE','REQUISITION_VIEW','REQUISITION_WRITE','COMPETENCY_ASSESS','APPROVAL_DECIDE','APPROVAL_EXECUTE') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code) select r.id,p.permission_code from public.roles r cross join public.app_permissions p where r.code='MEDICO_GERENTE_TECNICO' and p.permission_code in ('PRODUCTION_VIEW','APPROVAL_VIEW','APPROVAL_DECIDE','APPROVAL_EXECUTE') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code) select r.id,p.permission_code from public.roles r cross join public.app_permissions p where r.code='GERENCIA_OPERATIVA' and p.permission_code in ('PRODUCTION_VIEW','REQUISITION_VIEW') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code) select r.id,p.permission_code from public.roles r cross join public.app_permissions p where r.code='ADMIN' and p.permission_code in ('PRODUCTION_VIEW','REQUISITION_VIEW') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code) select r.id,p.permission_code from public.roles r cross join public.app_permissions p where r.code='CALIDAD' and p.permission_code in ('PRODUCTION_VIEW','APPROVAL_EXECUTE') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code) select r.id,p.permission_code from public.roles r cross join public.app_permissions p where r.code='INVENTARIO' and p.permission_code in ('REQUISITION_VIEW') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code) select r.id,p.permission_code from public.roles r cross join public.app_permissions p where r.code='SUCURSAL' and p.permission_code in ('REQUISITION_VIEW','CUSTOMER_VIEW') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code) select r.id,p.permission_code from public.roles r cross join public.app_permissions p where r.code='ASISTENTE_OPERACIONES' and p.permission_code in ('REQUISITION_VIEW','COMMERCIAL_WRITE') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code) select r.id,p.permission_code from public.roles r cross join public.app_permissions p where r.code='SOCIO' and p.permission_code in ('SERVICE_PERFORMANCE_VIEW','DOCUMENTS_VIEW') on conflict do nothing;
delete from public.role_permissions rp using public.roles r where rp.role_id=r.id and r.code='ADMIN' and rp.permission_code in ('UNIT_RELEASE','SCREENING_WRITE','BLOOD_INVENTORY_WRITE','ANALYTICAL_QC_WRITE','COLD_CHAIN_WRITE','HEMOVIGILANCE_WRITE','RESOURCES_WRITE','HYPERBARIC_WRITE','COMPETENCY_WRITE','TRAINING_ADMIN');
delete from public.role_permissions rp using public.roles r where rp.role_id=r.id and r.code='GERENCIA_OPERATIVA' and rp.permission_code in ('UNIT_RELEASE','ANALYTICAL_QC_WRITE','COLD_CHAIN_WRITE','HEMOVIGILANCE_WRITE','RESOURCES_WRITE');
delete from public.role_permissions rp using public.roles r where rp.role_id=r.id and r.code='CALIDAD' and rp.permission_code in ('UNIT_RELEASE');
delete from public.role_permissions rp using public.roles r where rp.role_id=r.id and r.code='LABORATORIO' and rp.permission_code in ('UNIT_RELEASE');

-- Branch scope is assigned explicitly; legacy global roles no longer imply every branch.
create or replace function public.can_access_branch(target_branch uuid) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.profiles p where p.id=auth.uid() and p.active)
 and (public.has_role('SUPER_USUARIO') or exists(select 1 from public.user_roles ur where ur.user_id=auth.uid() and ur.branch_id=target_branch)
 or exists(select 1 from public.profiles p where p.id=auth.uid() and p.active and p.branch_id=target_branch));
$$;
revoke all on function public.can_access_branch(uuid) from public,anon;
grant execute on function public.can_access_branch(uuid) to authenticated;
update public.app_module_catalog set permission_code='PRODUCTION_VIEW' where route_key='production';
update public.app_module_catalog set permission_code='REQUISITION_VIEW' where route_key='requisitions';

alter table public.role_module_access disable trigger role_module_change;
update public.role_module_access rm set enabled=false,revision=revision+1,updated_at=now() from public.roles r where r.id=rm.role_id and r.code='ADMIN' and rm.route_key in ('screening','production','bloodflow','analyticalqc','coldchain','hemovigilance','resources','hyperbaric','competencies','laboratory') and rm.enabled is distinct from false;
update public.role_module_access rm set enabled=false,revision=revision+1,updated_at=now() from public.roles r where r.id=rm.role_id and r.code='FINANZAS' and rm.route_key in ('commercial') and rm.enabled is distinct from false;
update public.role_module_access rm set enabled=false,revision=revision+1,updated_at=now() from public.roles r where r.id=rm.role_id and r.code='GERENCIA_GENERAL' and rm.route_key in ('laboratory') and rm.enabled is distinct from false;
update public.role_module_access rm set enabled=false,revision=revision+1,updated_at=now() from public.roles r where r.id=rm.role_id and r.code='SUCURSAL' and rm.route_key in ('sgcimplementation') and rm.enabled is distinct from false;
update public.role_module_access rm set enabled=false,revision=revision+1,updated_at=now() from public.roles r where r.id=rm.role_id and r.code='CONSULTA' and rm.route_key in ('sgcimplementation') and rm.enabled is distinct from false;
update public.role_module_access rm set enabled=false,revision=revision+1,updated_at=now() from public.roles r where r.id=rm.role_id and r.code='LABORATORIO' and rm.route_key in ('dispatches') and rm.enabled is distinct from false;
update public.role_module_access rm set enabled=false,revision=revision+1,updated_at=now() from public.roles r where r.id=rm.role_id and r.code='MEDICO_GERENTE_TECNICO' and rm.route_key in ('dispatches','requisitions') and rm.enabled is distinct from false;
update public.role_module_access rm set enabled=false,revision=revision+1,updated_at=now() from public.roles r where r.id=rm.role_id and r.code='SOCIO' and rm.route_key in ('collections','economics') and rm.enabled is distinct from false;
update public.role_module_access rm set enabled=true,revision=revision+1,updated_at=now() from public.roles r where r.id=rm.role_id and r.code='MEDICO_GERENTE_TECNICO' and rm.route_key in ('approvals') and rm.enabled is distinct from true;
alter table public.role_module_access enable trigger role_module_change;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='production_batches' loop execute format('drop policy %I on public.production_batches',p.policyname);end loop;end$$;
create policy task_production_batches_select on public.production_batches for select to authenticated using(public.can_access_branch(branch_id) and public.has_permission('PRODUCTION_VIEW'));
create policy task_production_batches_insert on public.production_batches for insert to authenticated with check(public.can_access_branch(branch_id) and public.has_permission('PRODUCTION_WRITE'));
create policy task_production_batches_update on public.production_batches for update to authenticated using(public.can_access_branch(branch_id) and public.has_permission('PRODUCTION_WRITE')) with check(public.can_access_branch(branch_id) and public.has_permission('PRODUCTION_WRITE'));
create policy task_production_batches_delete on public.production_batches for delete to authenticated using(public.can_access_branch(branch_id) and public.has_role('SUPER_USUARIO') and public.wf_active_actor());
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='blood_inventory_units' loop execute format('drop policy %I on public.blood_inventory_units',p.policyname);end loop;end$$;
create policy task_blood_inventory_units_select on public.blood_inventory_units for select to authenticated using(public.can_access_branch(branch_id) and public.has_permission('BLOOD_INVENTORY_VIEW'));
create policy task_blood_inventory_units_insert on public.blood_inventory_units for insert to authenticated with check(public.can_access_branch(branch_id) and public.has_permission('BLOOD_INVENTORY_WRITE'));
create policy task_blood_inventory_units_update on public.blood_inventory_units for update to authenticated using(public.can_access_branch(branch_id) and (public.has_permission('BLOOD_INVENTORY_WRITE') or public.has_permission('UNIT_RELEASE'))) with check(public.can_access_branch(branch_id) and (public.has_permission('BLOOD_INVENTORY_WRITE') or public.has_permission('UNIT_RELEASE')));
create policy task_blood_inventory_units_delete on public.blood_inventory_units for delete to authenticated using(public.can_access_branch(branch_id) and public.has_role('SUPER_USUARIO') and public.wf_active_actor());
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='requisitions' loop execute format('drop policy %I on public.requisitions',p.policyname);end loop;end$$;
create policy task_requisitions_select on public.requisitions for select to authenticated using(public.can_access_branch(requesting_branch_id) and public.has_permission('REQUISITION_VIEW'));
create policy task_requisitions_insert on public.requisitions for insert to authenticated with check(public.can_access_branch(requesting_branch_id) and public.has_permission('REQUISITION_WRITE'));
create policy task_requisitions_update on public.requisitions for update to authenticated using(public.can_access_branch(requesting_branch_id) and public.has_permission('REQUISITION_WRITE')) with check(public.can_access_branch(requesting_branch_id) and public.has_permission('REQUISITION_WRITE'));
create policy task_requisitions_delete on public.requisitions for delete to authenticated using(public.can_access_branch(requesting_branch_id) and public.has_role('SUPER_USUARIO') and public.wf_active_actor());
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='suppliers' loop execute format('drop policy %I on public.suppliers',p.policyname);end loop;end$$;
create policy task_suppliers_select on public.suppliers for select to authenticated using(public.wf_active_actor() and public.has_permission('SUPPLIERS_VIEW'));
create policy task_suppliers_insert on public.suppliers for insert to authenticated with check(public.wf_active_actor() and public.has_permission('SUPPLIERS_WRITE'));
create policy task_suppliers_update on public.suppliers for update to authenticated using(public.wf_active_actor() and public.has_permission('SUPPLIERS_WRITE')) with check(public.wf_active_actor() and public.has_permission('SUPPLIERS_WRITE'));
create policy task_suppliers_delete on public.suppliers for delete to authenticated using(public.wf_active_actor() and public.has_role('SUPER_USUARIO') and public.wf_active_actor());

grant select,insert,update,delete on public.production_batches,public.blood_inventory_units,public.requisitions,public.suppliers to authenticated;
create or replace function private.guard_release_only_inventory() returns trigger
language plpgsql security invoker set search_path=public,pg_temp as $$
begin
 if public.has_permission('BLOOD_INVENTORY_WRITE') then return new;end if;
 -- Only the nested screening safety trigger may quarantine after a changed result.
 if pg_trigger_depth()>1 and public.has_permission('SCREENING_WRITE') and public.can_access_branch(new.branch_id)
 and new.inventory_status='CUARENTENA' and new.screening_status='INDETERMINADO'
 and (to_jsonb(new)-array['screening_status','inventory_status']) is not distinct from (to_jsonb(old)-array['screening_status','inventory_status']) then return new;end if;
 if not public.has_permission('UNIT_RELEASE') or not public.can_access_branch(old.branch_id)
 or (to_jsonb(new)-array['screening_status','inventory_status']) is distinct from (to_jsonb(old)-array['screening_status','inventory_status']) then
  raise exception 'La liberación técnica no permite editar datos del inventario' using errcode='42501';end if;
 if not exists(select 1 from public.unit_release_reviews r where r.source_unit_code=new.source_unit_code and r.branch_id=new.branch_id and r.reviewed_by=auth.uid()
 and r.review_date>=transaction_timestamp() and
 ((r.decision='APTO' and new.screening_status='APTO' and new.inventory_status=case when old.inventory_status='CUARENTENA' then 'DISPONIBLE' else old.inventory_status end)
 or (r.decision='NO_APTO' and new.screening_status='NO_APTO' and new.inventory_status='DESCARTADA')
 or (r.decision='RETENER' and new.screening_status=old.screening_status and new.inventory_status=case when old.inventory_status='DISPONIBLE' then 'CUARENTENA' else old.inventory_status end))) then
 raise exception 'Use la revisión técnica para cambiar el estado' using errcode='42501';end if;
 return new;
end$$;
revoke all on function private.guard_release_only_inventory() from public,anon,authenticated;
create trigger task_release_only_inventory before update on public.blood_inventory_units for each row execute function private.guard_release_only_inventory();
-- The safety hold must run even for a screening writer without inventory administration.
create or replace function private.lab_screening_hold() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null or not public.wf_active_actor() or not public.has_permission('SCREENING_WRITE') or not public.can_access_branch(new.branch_id) then raise exception 'Sin permiso de tamizaje en la sucursal' using errcode='42501';end if;
 if new.status<>'VALIDADO' or new.result<>'NO_REACTIVO' then
  update public.blood_inventory_units set inventory_status='CUARENTENA',screening_status='INDETERMINADO'
  where branch_id=new.branch_id and source_unit_code=new.source_unit_code and inventory_status in ('DISPONIBLE','RESERVADA');
 end if;return new;
end$$;
revoke all on function private.lab_screening_hold() from public,anon,authenticated;
-- A production capture cannot itself declare clinically available components.
create or replace function private.guard_production_availability() returns trigger
language plpgsql security invoker set search_path=public,pg_temp as $$
begin
 if new.status in ('DISPONIBLE','RESERVADA') and (tg_op='INSERT' or new.status is distinct from old.status or new.source_unit_code is distinct from old.source_unit_code or new.branch_id is distinct from old.branch_id) then
  if not public.has_permission('UNIT_RELEASE') or not exists(select 1 from public.unit_release_reviews r where r.source_unit_code=new.source_unit_code and r.branch_id=new.branch_id and r.decision='APTO' and r.id=(select id from public.unit_release_reviews where source_unit_code=new.source_unit_code and branch_id=new.branch_id order by review_date desc,id desc limit 1)) then raise exception 'La disponibilidad requiere liberación técnica vigente' using errcode='42501';end if;
 end if;
 return new;
end$$;
revoke all on function private.guard_production_availability() from public,anon,authenticated;
create trigger task_production_availability before insert or update on public.production_batches for each row execute function private.guard_production_availability();

revoke insert,update,delete on public.approval_requests from public,anon,authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='approval_requests' loop execute format('drop policy %I on public.approval_requests',p.policyname);end loop;end$$;
revoke insert,update,delete on public.approval_decisions from public,anon,authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='approval_decisions' loop execute format('drop policy %I on public.approval_decisions',p.policyname);end loop;end$$;
revoke insert,update,delete on public.approval_policies from public,anon,authenticated;
do $$declare p record;begin for p in select policyname from pg_policies where schemaname='public' and tablename='approval_policies' loop execute format('drop policy %I on public.approval_policies',p.policyname);end loop;end$$;

create policy task_approval_requests_read on public.approval_requests for select to authenticated
 using(public.wf_active_actor() and (branch_id is null or public.can_access_branch(branch_id)) and (requested_by=auth.uid() or public.has_permission('APPROVAL_VIEW')));
create policy task_approval_decisions_read on public.approval_decisions for select to authenticated
 using(exists(select 1 from public.approval_requests r where r.id=request_id));
create policy task_approval_policies_read on public.approval_policies for select to authenticated
 using(public.wf_active_actor() and (public.has_permission('APPROVAL_VIEW') or public.has_permission(required_permission)));
update public.approval_policies set allowed_approver_roles=array['ENCARGADA_LABORATORIO','MEDICO_GERENTE_TECNICO'],updated_at=now() where action_type='UNIT_RELEASE';

create or replace function private.task_create_approval_request(p_action_type text,p_branch_id uuid,p_entity_type text,p_entity_id uuid,p_entity_reference text,p_title text,p_reason text,p_payload jsonb default '{}'::jsonb) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $function$
declare
  v_policy public.approval_policies%rowtype;
  v_id uuid;
  v_code text;
begin

  if auth.uid() is null or not public.wf_active_actor() then raise exception 'Usuario inactivo o no autenticado' using errcode='42501';end if;
  if not public.has_permission('APPROVAL_VIEW') then raise exception 'Sin permiso de solicitudes' using errcode='42501';end if;
  select * into v_policy
  from public.approval_policies
  where action_type=p_action_type and active
  limit 1;

  if v_policy.policy_code is null then
    raise exception 'No existe política activa para %',p_action_type;
  end if;

  if p_branch_id is not null and not public.can_access_branch(p_branch_id) then
    raise exception 'Sin acceso a la sucursal';
  end if;

  if v_policy.required_permission is not null and
     not public.has_permission(v_policy.required_permission) then
    raise exception 'Permiso requerido: %',v_policy.required_permission;
  end if;

  if trim(coalesce(p_reason,''))='' then
    raise exception 'La justificación es obligatoria';
  end if;

  v_code:='APR-'||to_char(now(),'YYYYMMDDHH24MISS')||'-'||upper(substr(md5(random()::text),1,5));

  insert into public.approval_requests(
    request_code,action_type,policy_code,branch_id,entity_type,entity_id,entity_reference,
    title,reason,payload,requested_by,status,required_approvals
  )
  values(
    v_code,p_action_type,v_policy.policy_code,p_branch_id,p_entity_type,p_entity_id,p_entity_reference,
    p_title,p_reason,coalesce(p_payload,'{}'::jsonb),auth.uid(),'PENDIENTE',v_policy.required_approvals
  )
  returning id into v_id;

  perform public.log_audit_event(
    'APROBACIONES','REQUEST',p_branch_id,'approval_requests',v_id,v_code,
    null,
    jsonb_build_object('action_type',p_action_type,'reason',p_reason,'payload',p_payload),
    null
  );

  return v_id;
end;
$function$;
revoke all on function private.task_create_approval_request(text,uuid,text,uuid,text,text,text,jsonb) from public,anon;
grant execute on function private.task_create_approval_request(text,uuid,text,uuid,text,text,text,jsonb) to authenticated;
create or replace function public.create_approval_request(p_action_type text,p_branch_id uuid,p_entity_type text,p_entity_id uuid,p_entity_reference text,p_title text,p_reason text,p_payload jsonb default '{}'::jsonb) returns uuid language sql security invoker set search_path=public,pg_temp as $$select private.task_create_approval_request(p_action_type,p_branch_id,p_entity_type,p_entity_id,p_entity_reference,p_title,p_reason,p_payload);$$;
revoke all on function public.create_approval_request(text,uuid,text,uuid,text,text,text,jsonb) from public,anon;
grant execute on function public.create_approval_request(text,uuid,text,uuid,text,text,text,jsonb) to authenticated;
create or replace function private.task_decide_approval_request(p_request_id uuid,p_decision text,p_comment text,p_acknowledgement text) returns text
language plpgsql security definer set search_path=public,pg_temp as $function$
declare
  v_req public.approval_requests%rowtype;
  v_policy public.approval_policies%rowtype;
  v_role text;
  v_count integer;
begin

  if auth.uid() is null or not public.wf_active_actor() then raise exception 'Usuario inactivo o no autenticado' using errcode='42501';end if;
  if not public.has_permission('APPROVAL_DECIDE') then raise exception 'Sin permiso: APPROVAL_DECIDE' using errcode='42501';end if;
  if p_decision not in ('APROBAR','RECHAZAR') then
    raise exception 'Decisión inválida';
  end if;

  if trim(coalesce(p_comment,''))='' then
    raise exception 'El comentario es obligatorio';
  end if;

  if trim(coalesce(p_acknowledgement,''))='' then
    raise exception 'La declaración de conformidad es obligatoria';
  end if;

  select * into v_req from public.approval_requests where id=p_request_id for update;
  if v_req.id is null then raise exception 'Solicitud no encontrada'; end if;
  if v_req.branch_id is not null and not public.can_access_branch(v_req.branch_id) then raise exception 'Sin acceso a la sucursal' using errcode='42501';end if;
  if not exists(select 1 from public.approval_policies p where p.policy_code=v_req.policy_code and p.active and p.action_type=v_req.action_type and public.has_permission(p.required_permission)) then raise exception 'Sin permiso funcional para esta acción' using errcode='42501';end if;


  if v_req.status not in ('PENDIENTE','EN_REVISION') then
    raise exception 'La solicitud no está pendiente de revisión';
  end if;

  select * into v_policy from public.approval_policies where policy_code=v_req.policy_code;

  if v_policy.require_distinct_approver and v_req.requested_by=auth.uid() then
    raise exception 'Segregación de funciones: el solicitante no puede aprobar su propia solicitud' using errcode='42501';
  end if;

  select r.code into v_role
  from public.user_roles ur
  join public.roles r on r.id=ur.role_id
  where ur.user_id=auth.uid()
    and (r.code='SUPER_USUARIO' or v_req.branch_id is null or ur.branch_id is null or ur.branch_id=v_req.branch_id)
    and (
      cardinality(v_policy.allowed_approver_roles)=0
      or r.code='SUPER_USUARIO' or r.code=any(v_policy.allowed_approver_roles)
    )
  order by case r.code when 'ADMIN' then 1 when 'GERENCIA_OPERATIVA' then 2 when 'CALIDAD' then 3 else 4 end
  limit 1;

  if v_role is null then
    raise exception 'El usuario no tiene un rol autorizado para aprobar esta acción';
  end if;

  insert into public.approval_decisions(
    request_id,decision,approver_id,comment,acknowledgement,approver_role,approver_branch_id
  ) values(
    p_request_id,p_decision,auth.uid(),p_comment,p_acknowledgement,v_role,v_req.branch_id
  );

  if p_decision='RECHAZAR' then
    update public.approval_requests
    set status='RECHAZADA',rejection_reason=p_comment
    where id=p_request_id;
  else
    select count(*) into v_count
    from public.approval_decisions
    where request_id=p_request_id and decision='APROBAR';

    update public.approval_requests
    set approvals_count=v_count,
        status=case when v_count>=required_approvals then 'APROBADA' else 'EN_REVISION' end
    where id=p_request_id;
  end if;

  perform public.log_audit_event(
    'APROBACIONES',p_decision,v_req.branch_id,'approval_requests',p_request_id,v_req.request_code,
    null,
    jsonb_build_object('decision',p_decision,'comment',p_comment,'approver_role',v_role),
    null
  );

  return case
    when p_decision='RECHAZAR' then 'RECHAZADA'
    when v_count>=v_req.required_approvals then 'APROBADA'
    else 'EN_REVISION'
  end;
end;
$function$;
revoke all on function private.task_decide_approval_request(uuid,text,text,text) from public,anon;
grant execute on function private.task_decide_approval_request(uuid,text,text,text) to authenticated;
create or replace function public.decide_approval_request(p_request_id uuid,p_decision text,p_comment text,p_acknowledgement text) returns text language sql security invoker set search_path=public,pg_temp as $$select private.task_decide_approval_request(p_request_id,p_decision,p_comment,p_acknowledgement);$$;
revoke all on function public.decide_approval_request(uuid,text,text,text) from public,anon;
grant execute on function public.decide_approval_request(uuid,text,text,text) to authenticated;
create or replace function private.task_execute_approved_action(p_request_id uuid) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $function$
declare
  v_req public.approval_requests%rowtype;
  v_result jsonb;
  v_review uuid;
  v_close uuid;
  v_doc_id uuid;
  v_capa_id uuid;
begin

  if auth.uid() is null or not public.wf_active_actor() then raise exception 'Usuario inactivo o no autenticado' using errcode='42501';end if;
  if not public.has_permission('APPROVAL_EXECUTE') then raise exception 'Sin permiso: APPROVAL_EXECUTE' using errcode='42501';end if;
  select * into v_req from public.approval_requests where id=p_request_id for update;
  if v_req.id is null then raise exception 'Solicitud no encontrada'; end if;
  if v_req.branch_id is not null and not public.can_access_branch(v_req.branch_id) then raise exception 'Sin acceso a la sucursal' using errcode='42501';end if;
  if not exists(select 1 from public.approval_policies p where p.policy_code=v_req.policy_code and p.active and p.action_type=v_req.action_type and public.has_permission(p.required_permission)) then raise exception 'Sin permiso funcional para esta acción' using errcode='42501';end if;

  if v_req.status<>'APROBADA' then raise exception 'La solicitud debe estar APROBADA'; end if;

  if v_req.requested_by=auth.uid() then
    raise exception 'Segregación de funciones: el solicitante no puede ejecutar su propia solicitud aprobada';
  end if;


  if v_req.approvals_count<v_req.required_approvals or (select count(*) from public.approval_decisions d where d.request_id=v_req.id and d.decision='APROBAR')<v_req.required_approvals then raise exception 'Faltan decisiones independientes';end if;
  if v_req.action_type='DOCUMENT_APPROVAL' and not exists(select 1 from public.document_register d where d.id=(v_req.payload->>'document_id')::uuid and d.approval_request_id=v_req.id) then raise exception 'Documento fuera del ámbito autorizado';end if;
  if v_req.action_type='CAPA_CLOSE' and not exists(select 1 from public.capa c left join public.nonconformities n on n.id=c.nonconformity_id where c.id=(v_req.payload->>'capa_id')::uuid and (n.branch_id is null or public.can_access_branch(n.branch_id)) and n.branch_id is not distinct from v_req.branch_id) then raise exception 'CAPA fuera del ámbito autorizado';end if;
  if v_req.action_type='UNIT_RELEASE' and not exists(select 1 from public.donations d where d.source_unit_code=v_req.payload->>'source_unit_code' and d.branch_id=v_req.branch_id and public.can_access_branch(d.branch_id)) then raise exception 'Unidad fuera del ámbito autorizado';end if;
  if v_req.action_type='UNIT_RELEASE' then
    v_review:=public.review_and_release_unit(
      v_req.payload->>'source_unit_code',
      v_req.payload->>'decision',
      v_req.payload->>'rationale',
      nullif(v_req.payload->>'evidence_reference','')
    );
    v_result=jsonb_build_object('release_review_id',v_review);

  elsif v_req.action_type='DAILY_CLOSE' then
    v_close:=public.capture_daily_operational_close(
      v_req.branch_id,
      coalesce(v_req.payload->>'notes',v_req.reason)
    );
    v_result=jsonb_build_object('daily_close_id',v_close);

  elsif v_req.action_type='DOCUMENT_APPROVAL' then
    v_doc_id:=(v_req.payload->>'document_id')::uuid;

    update public.document_register
    set status='APROBADO',
        review_status='APROBADO',
        approver_user_id=auth.uid(),
        approved_at=now(),
        last_reviewed_at=now(),
        last_reviewed_by=auth.uid()
    where id=v_doc_id
      and approval_request_id=p_request_id;

    if not found then
      raise exception 'Documento no encontrado o solicitud no coincide';
    end if;

    update public.document_changes
    set status='APROBADO',
        approved_by=auth.uid(),
        approved_at=now()
    where document_id=v_doc_id
      and status='PENDIENTE';

    v_result=jsonb_build_object('document_id',v_doc_id,'status','APROBADO');

  elsif v_req.action_type='CAPA_CLOSE' then
    v_capa_id:=(v_req.payload->>'capa_id')::uuid;

    update public.capa
    set status='CERRADA',
        closed_at=now(),
        closed_by=auth.uid(),
        effectiveness_verified_at=coalesce(effectiveness_verified_at,now())
    where id=v_capa_id
      and approval_request_id=p_request_id
      and coalesce(effectiveness_status,'PENDIENTE') in ('EFECTIVA','VERIFICADA');

    if not found then
      raise exception 'CAPA no encontrada, solicitud no coincide o efectividad no validada';
    end if;

    v_result=jsonb_build_object('capa_id',v_capa_id,'status','CERRADA');

  else
    raise exception 'Ejecución automática no implementada para action_type=%',v_req.action_type;
  end if;

  update public.approval_requests
  set status='EJECUTADA',
      executed_by=auth.uid(),
      executed_at=now(),
      execution_result=v_result
  where id=p_request_id;

  perform public.log_audit_event(
    'APROBACIONES','EXECUTE',v_req.branch_id,'approval_requests',v_req.id,v_req.request_code,
    null,v_result,jsonb_build_object('action_type',v_req.action_type)
  );

  return v_result;
end;
$function$;
revoke all on function private.task_execute_approved_action(uuid) from public,anon;
grant execute on function private.task_execute_approved_action(uuid) to authenticated;
create or replace function public.execute_approved_action(p_request_id uuid) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select private.task_execute_approved_action(p_request_id);$$;
revoke all on function public.execute_approved_action(uuid) from public,anon;
grant execute on function public.execute_approved_action(uuid) to authenticated;

-- Target lookup bypasses only the role lookup RLS, not functional or branch authorization.
create or replace function private.task_lab_assessment_target(target_user uuid,target_branch uuid) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select public.wf_active_actor() and public.has_permission('COMPETENCY_ASSESS') and public.can_access_branch(target_branch)
 and exists(select 1 from public.profiles p join public.user_roles ur on ur.user_id=p.id join public.roles r on r.id=ur.role_id where p.id=target_user and p.active and ur.branch_id=target_branch and r.code in ('LABORATORIO','ENCARGADA_LABORATORIO','MEDICO_GERENTE_TECNICO'));
$$;
revoke all on function private.task_lab_assessment_target(uuid,uuid) from public,anon;
grant execute on function private.task_lab_assessment_target(uuid,uuid) to authenticated;
create policy task_lab_assessment_insert on public.competency_assessments for insert to authenticated
 with check(assessor_user_id=auth.uid() and user_id<>auth.uid() and private.task_lab_assessment_target(user_id,branch_id));
-- ALL legacy policies must also honor the functional permission and real assessor.
create policy task_assessment_function_insert on public.competency_assessments as restrictive for insert to authenticated
 with check(public.wf_active_actor() and assessor_user_id=auth.uid() and user_id<>auth.uid() and
 ((public.has_permission('COMPETENCY_WRITE') and (branch_id is null or public.can_access_branch(branch_id))) or private.task_lab_assessment_target(user_id,branch_id)));
create policy task_assessment_function_update on public.competency_assessments as restrictive for update to authenticated
 using(public.has_permission('COMPETENCY_WRITE') and (branch_id is null or public.can_access_branch(branch_id)))
 with check(public.has_permission('COMPETENCY_WRITE') and assessor_user_id=auth.uid() and user_id<>auth.uid() and (branch_id is null or public.can_access_branch(branch_id)));
-- Views must not bypass the repaired table policies, including nested reports.
do $$declare v record;begin
 for v in with recursive deps(oid) as (
 select c.oid from pg_class c where c.oid in ('production_batches'::regclass,'blood_inventory_units'::regclass,'requisitions'::regclass,'suppliers'::regclass,'approval_requests'::regclass,'approval_decisions'::regclass)
 union select rw.ev_class from deps d join pg_depend pd on pd.refobjid=d.oid join pg_rewrite rw on rw.oid=pd.objid where rw.ev_class<>d.oid)
 select distinct c.oid::regclass as name from deps d join pg_class c on c.oid=d.oid join pg_namespace n on n.oid=c.relnamespace where c.relkind='v' and n.nspname='public'
 loop execute format('alter view %s set (security_invoker=true)',v.name);end loop;
end$$;
notify pgrst,'reload schema';
commit;
