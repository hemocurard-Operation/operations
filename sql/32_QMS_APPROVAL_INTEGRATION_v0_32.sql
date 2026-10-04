-- ============================================================
-- HemoCura v0.32.0
-- Control documental + CAPA integrados con aprobaciones
-- Requiere v0.31.0
-- ============================================================
begin;

-- 1) CAMPOS DE GOBIERNO DOCUMENTAL
alter table public.document_register
  add column if not exists review_status text default 'NO_INICIADA',
  add column if not exists approval_request_id uuid references public.approval_requests(id),
  add column if not exists last_reviewed_at timestamptz,
  add column if not exists last_reviewed_by uuid references public.profiles(id);

alter table public.capa
  add column if not exists approval_request_id uuid references public.approval_requests(id),
  add column if not exists closed_by uuid references public.profiles(id);

-- 2) SOLICITUD DE APROBACIÓN DOCUMENTAL
create or replace function public.request_document_approval(
  p_document_id uuid,
  p_reason text
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_doc public.document_register%rowtype;
  v_req uuid;
begin
  select * into v_doc from public.document_register where id=p_document_id for update;
  if v_doc.id is null then raise exception 'Documento no encontrado'; end if;

  if not public.has_permission('DOCUMENTS_WRITE') then
    raise exception 'Permiso requerido: DOCUMENTS_WRITE';
  end if;

  if v_doc.status not in ('BORRADOR','EN_REVISION','APROBADO') then
    raise exception 'Estado documental no permite solicitar aprobación: %',v_doc.status;
  end if;

  v_req:=public.create_approval_request(
    'DOCUMENT_APPROVAL',
    null,
    'document_register',
    v_doc.id,
    v_doc.document_code,
    concat('Aprobar documento ',v_doc.document_code,' v',v_doc.version),
    p_reason,
    jsonb_build_object(
      'document_id',v_doc.id,
      'document_code',v_doc.document_code,
      'version',v_doc.version
    )
  );

  update public.document_register
  set status='EN_REVISION',
      review_status='EN_APROBACION',
      approval_request_id=v_req
  where id=v_doc.id;

  insert into public.document_changes(
    document_id,requested_by,change_reason,previous_version,new_version,status
  ) values(
    v_doc.id,auth.uid(),p_reason,v_doc.version,v_doc.version,'PENDIENTE'
  );

  return v_req;
end;
$$;

grant execute on function public.request_document_approval(uuid,text) to authenticated;

-- 3) SOLICITUD DE CIERRE CAPA
create or replace function public.request_capa_close(
  p_capa_id uuid,
  p_reason text
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_capa public.capa%rowtype;
  v_branch uuid;
  v_req uuid;
begin
  select * into v_capa from public.capa where id=p_capa_id for update;
  if v_capa.id is null then raise exception 'CAPA no encontrada'; end if;

  if not public.has_permission('QUALITY_WRITE') then
    raise exception 'Permiso requerido: QUALITY_WRITE';
  end if;

  select n.branch_id into v_branch
  from public.nonconformities n
  where n.id=v_capa.nonconformity_id;

  if v_capa.status in ('CERRADA','CANCELADA') then
    raise exception 'CAPA ya cerrada/cancelada';
  end if;

  if coalesce(v_capa.effectiveness_status,'PENDIENTE') not in ('EFECTIVA','VERIFICADA') then
    raise exception 'La efectividad debe estar verificada antes de solicitar cierre';
  end if;

  v_req:=public.create_approval_request(
    'CAPA_CLOSE',
    v_branch,
    'capa',
    v_capa.id,
    v_capa.code,
    concat('Cerrar CAPA ',v_capa.code),
    p_reason,
    jsonb_build_object(
      'capa_id',v_capa.id,
      'code',v_capa.code,
      'effectiveness_status',v_capa.effectiveness_status
    )
  );

  update public.capa
  set approval_request_id=v_req
  where id=v_capa.id;

  return v_req;
end;
$$;

grant execute on function public.request_capa_close(uuid,text) to authenticated;

-- 4) AMPLIAR EJECUCIÓN APROBADA
create or replace function public.execute_approved_action(
  p_request_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_req public.approval_requests%rowtype;
  v_result jsonb;
  v_review uuid;
  v_close uuid;
  v_doc_id uuid;
  v_capa_id uuid;
begin
  select * into v_req from public.approval_requests where id=p_request_id for update;
  if v_req.id is null then raise exception 'Solicitud no encontrada'; end if;
  if v_req.status<>'APROBADA' then raise exception 'La solicitud debe estar APROBADA'; end if;

  if v_req.requested_by=auth.uid() then
    raise exception 'Segregación de funciones: el solicitante no puede ejecutar su propia solicitud aprobada';
  end if;

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
$$;

grant execute on function public.execute_approved_action(uuid) to authenticated;

-- 5) VISTA CONTROL DOCUMENTAL
create or replace view public.vw_document_control_status as
select
  d.id,d.document_code,d.title,d.area,d.document_type,d.version,d.status,
  d.review_status,d.owner_user_id,d.approver_user_id,
  d.effective_date,d.review_date,d.approved_at,
  d.approval_request_id,
  a.request_code approval_request_code,
  a.status approval_status,
  case
    when d.review_date is not null and d.review_date<current_date then true
    else false
  end review_overdue
from public.document_register d
left join public.approval_requests a on a.id=d.approval_request_id;

grant select on public.vw_document_control_status to authenticated;

-- 6) VISTA CAPA
create or replace view public.vw_capa_control_status as
select
  c.id,c.code,c.nonconformity_id,c.problem,c.root_cause,c.action_plan,
  c.owner_user_id,c.due_date,c.status,c.effectiveness_status,
  c.effectiveness_notes,c.effectiveness_verified_at,c.closed_at,c.closed_by,
  c.approval_request_id,
  a.request_code approval_request_code,
  a.status approval_status,
  case
    when c.status not in ('CERRADA','CANCELADA') and c.due_date<current_date then true
    else false
  end overdue
from public.capa c
left join public.approval_requests a on a.id=c.approval_request_id;

grant select on public.vw_capa_control_status to authenticated;

-- 7) DASHBOARD QMS
create or replace view public.vw_qms_governance_summary as
select
  (select count(*) from public.document_register where status='EN_REVISION') documents_in_review,
  (select count(*) from public.document_register where review_date<current_date and status not in ('OBSOLETO','DEROGADO')) overdue_document_reviews,
  (select count(*) from public.capa where status not in ('CERRADA','CANCELADA')) open_capa,
  (select count(*) from public.capa where status not in ('CERRADA','CANCELADA') and due_date<current_date) overdue_capa,
  (select count(*) from public.approval_requests where action_type='DOCUMENT_APPROVAL' and status in ('PENDIENTE','EN_REVISION','APROBADA')) pending_document_approvals,
  (select count(*) from public.approval_requests where action_type='CAPA_CLOSE' and status in ('PENDIENTE','EN_REVISION','APROBADA')) pending_capa_approvals;

grant select on public.vw_qms_governance_summary to authenticated;

-- 8) MIGRATION
insert into public.app_migrations(
  migration_code,version,description,applied_by
)
values(
  '32_QMS_APPROVAL_INTEGRATION_v0_32',
  '0.32.0',
  'Control documental y cierre CAPA integrados con aprobaciones',
  auth.uid()
)
on conflict(migration_code) do update set
  version=excluded.version,
  description=excluded.description,
  applied_at=now(),
  applied_by=auth.uid();

commit;
