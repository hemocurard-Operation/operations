-- ============================================================
-- HemoCura v0.31.0
-- Aprobaciones + firma operativa + segregación de funciones
-- Requiere v0.30.0
-- ============================================================
begin;
create extension if not exists pgcrypto;

-- 1) POLÍTICAS DE APROBACIÓN
create table if not exists public.approval_policies (
  policy_code text primary key,
  action_type text not null unique,
  title text not null,
  description text,
  required_approvals integer not null default 1 check(required_approvals between 1 and 5),
  require_distinct_approver boolean not null default true,
  required_permission text references public.app_permissions(permission_code),
  allowed_approver_roles text[] not null default '{}',
  enforce_before_execution boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.approval_policies enable row level security;

drop policy if exists approval_policies_read on public.approval_policies;
create policy approval_policies_read on public.approval_policies for select
using(auth.role()='authenticated');

drop policy if exists approval_policies_write on public.approval_policies;
create policy approval_policies_write on public.approval_policies for all
using(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA'))
with check(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA'));

grant select,insert,update on public.approval_policies to authenticated;

insert into public.approval_policies(
  policy_code,action_type,title,description,required_approvals,
  require_distinct_approver,required_permission,allowed_approver_roles,enforce_before_execution
) values
('POL-UNIT-RELEASE','UNIT_RELEASE','Liberación de unidad',
 'Aprobación previa para ejecutar una decisión de liberación controlada.',
 1,true,'UNIT_RELEASE',array['ADMIN','GERENCIA_OPERATIVA','CALIDAD','LABORATORIO'],false),
('POL-DAILY-CLOSE','DAILY_CLOSE','Cierre operativo diario',
 'Aprobación previa del cierre operativo de una sucursal.',
 1,true,'DAILY_CLOSE_EXECUTE',array['ADMIN','GERENCIA_OPERATIVA','CALIDAD'],false),
('POL-DOC-APPROVAL','DOCUMENT_APPROVAL','Aprobación documental',
 'Flujo de aprobación para documentos controlados.',
 1,true,'DOCUMENTS_WRITE',array['ADMIN','GERENCIA_OPERATIVA','CALIDAD'],false),
('POL-CAPA-CLOSE','CAPA_CLOSE','Cierre CAPA',
 'Aprobación del cierre y efectividad de una acción CAPA.',
 1,true,'QUALITY_WRITE',array['ADMIN','GERENCIA_OPERATIVA','CALIDAD'],false)
on conflict(policy_code) do update set
  title=excluded.title,
  description=excluded.description,
  required_approvals=excluded.required_approvals,
  require_distinct_approver=excluded.require_distinct_approver,
  required_permission=excluded.required_permission,
  allowed_approver_roles=excluded.allowed_approver_roles,
  updated_at=now();

-- 2) SOLICITUDES DE APROBACIÓN
create table if not exists public.approval_requests (
  id uuid primary key default gen_random_uuid(),
  request_code text not null unique,
  action_type text not null,
  policy_code text references public.approval_policies(policy_code),
  branch_id uuid references public.branches(id),
  entity_type text,
  entity_id uuid,
  entity_reference text,
  title text not null,
  reason text not null,
  payload jsonb not null default '{}'::jsonb,
  requested_by uuid not null references public.profiles(id),
  requested_at timestamptz not null default now(),
  status text not null default 'PENDIENTE'
    check(status in ('PENDIENTE','EN_REVISION','APROBADA','RECHAZADA','EJECUTADA','CANCELADA')),
  required_approvals integer not null default 1 check(required_approvals between 1 and 5),
  approvals_count integer not null default 0,
  rejection_reason text,
  executed_by uuid references public.profiles(id),
  executed_at timestamptz,
  execution_result jsonb,
  created_at timestamptz not null default now()
);

alter table public.approval_requests enable row level security;

drop policy if exists approval_requests_read on public.approval_requests;
create policy approval_requests_read on public.approval_requests for select
using(
  requested_by=auth.uid()
  or branch_id is null
  or public.can_access_branch(branch_id)
);

drop policy if exists approval_requests_insert on public.approval_requests;
create policy approval_requests_insert on public.approval_requests for insert
with check(
  requested_by=auth.uid()
  and (branch_id is null or public.can_access_branch(branch_id))
);

drop policy if exists approval_requests_update on public.approval_requests;
create policy approval_requests_update on public.approval_requests for update
using(
  requested_by=auth.uid()
  or branch_id is null
  or public.can_access_branch(branch_id)
)
with check(
  requested_by=auth.uid()
  or branch_id is null
  or public.can_access_branch(branch_id)
);

grant select,insert,update on public.approval_requests to authenticated;

-- 3) DECISIONES / FIRMA OPERATIVA
create table if not exists public.approval_decisions (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.approval_requests(id) on delete cascade,
  decision text not null check(decision in ('APROBAR','RECHAZAR')),
  approver_id uuid not null references public.profiles(id),
  decision_at timestamptz not null default now(),
  comment text not null,
  acknowledgement text not null,
  approver_role text,
  approver_branch_id uuid references public.branches(id),
  metadata jsonb,
  unique(request_id,approver_id)
);

alter table public.approval_decisions enable row level security;

drop policy if exists approval_decisions_read on public.approval_decisions;
create policy approval_decisions_read on public.approval_decisions for select
using(auth.role()='authenticated');

drop policy if exists approval_decisions_insert on public.approval_decisions;
create policy approval_decisions_insert on public.approval_decisions for insert
with check(approver_id=auth.uid());

grant select,insert on public.approval_decisions to authenticated;

-- 4) CREAR SOLICITUD CONTROLADA
create or replace function public.create_approval_request(
  p_action_type text,
  p_branch_id uuid,
  p_entity_type text,
  p_entity_id uuid,
  p_entity_reference text,
  p_title text,
  p_reason text,
  p_payload jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_policy public.approval_policies%rowtype;
  v_id uuid;
  v_code text;
begin
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
$$;

grant execute on function public.create_approval_request(text,uuid,text,uuid,text,text,text,jsonb)
to authenticated;

-- 5) DECIDIR APROBACIÓN CON SEGREGACIÓN
create or replace function public.decide_approval_request(
  p_request_id uuid,
  p_decision text,
  p_comment text,
  p_acknowledgement text
)
returns text
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_req public.approval_requests%rowtype;
  v_policy public.approval_policies%rowtype;
  v_role text;
  v_count integer;
begin
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

  if v_req.status not in ('PENDIENTE','EN_REVISION') then
    raise exception 'La solicitud no está pendiente de revisión';
  end if;

  select * into v_policy from public.approval_policies where policy_code=v_req.policy_code;

  if v_policy.require_distinct_approver and v_req.requested_by=auth.uid() then
    raise exception 'Segregación de funciones: el solicitante no puede aprobar su propia solicitud';
  end if;

  select r.code into v_role
  from public.user_roles ur
  join public.roles r on r.id=ur.role_id
  where ur.user_id=auth.uid()
    and (v_req.branch_id is null or ur.branch_id is null or ur.branch_id=v_req.branch_id)
    and (
      cardinality(v_policy.allowed_approver_roles)=0
      or r.code=any(v_policy.allowed_approver_roles)
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
$$;

grant execute on function public.decide_approval_request(uuid,text,text,text) to authenticated;

-- 6) EJECUTAR ACCIÓN APROBADA
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
begin
  select * into v_req from public.approval_requests where id=p_request_id for update;
  if v_req.id is null then raise exception 'Solicitud no encontrada'; end if;
  if v_req.status<>'APROBADA' then raise exception 'La solicitud debe estar APROBADA'; end if;
  if v_req.requested_by=auth.uid() then
    -- Separación solicitante/ejecutor para acciones soportadas.
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

  else
    raise exception 'Ejecución automática no implementada para action_type=%',v_req.action_type;
  end if;

  update public.approval_requests
  set status='EJECUTADA',executed_by=auth.uid(),executed_at=now(),execution_result=v_result
  where id=p_request_id;

  perform public.log_audit_event(
    'APROBACIONES','EXECUTE',v_req.branch_id,'approval_requests',v_req.id,v_req.request_code,
    null,v_result,jsonb_build_object('action_type',v_req.action_type)
  );

  return v_result;
end;
$$;

grant execute on function public.execute_approved_action(uuid) to authenticated;

-- 7) VISTAS
create or replace view public.vw_approval_inbox as
select
  r.id,r.request_code,r.action_type,r.policy_code,r.branch_id,r.entity_type,r.entity_reference,
  r.title,r.reason,r.requested_by,r.requested_at,r.status,r.required_approvals,r.approvals_count,
  p.full_name requested_by_name,
  pol.require_distinct_approver,
  pol.allowed_approver_roles,
  pol.required_permission,
  pol.enforce_before_execution,
  (current_date-r.requested_at::date) age_days
from public.approval_requests r
left join public.profiles p on p.id=r.requested_by
left join public.approval_policies pol on pol.policy_code=r.policy_code
order by
  case r.status when 'PENDIENTE' then 1 when 'EN_REVISION' then 2 when 'APROBADA' then 3 else 4 end,
  r.requested_at;

grant select on public.vw_approval_inbox to authenticated;

create or replace view public.vw_approval_decision_history as
select
  d.id,d.request_id,r.request_code,r.action_type,r.branch_id,
  d.decision,d.approver_id,p.full_name approver_name,d.approver_role,
  d.decision_at,d.comment,d.acknowledgement
from public.approval_decisions d
join public.approval_requests r on r.id=d.request_id
left join public.profiles p on p.id=d.approver_id
order by d.decision_at desc;

grant select on public.vw_approval_decision_history to authenticated;

-- 8) NUEVOS PERMISOS
insert into public.app_permissions(permission_code,module,description,risk_level) values
('APPROVAL_VIEW','APPROVALS','Ver bandeja de aprobaciones','SENSIBLE'),
('APPROVAL_DECIDE','APPROVALS','Aprobar o rechazar solicitudes','CRITICO'),
('APPROVAL_EXECUTE','APPROVALS','Ejecutar acciones ya aprobadas','CRITICO')
on conflict(permission_code) do update set
  module=excluded.module,description=excluded.description,risk_level=excluded.risk_level,active=true;

-- ADMIN
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r cross join public.app_permissions p
where r.code='ADMIN' and p.permission_code in ('APPROVAL_VIEW','APPROVAL_DECIDE','APPROVAL_EXECUTE')
on conflict do nothing;

-- GERENCIA OPERATIVA
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r join public.app_permissions p
on p.permission_code in ('APPROVAL_VIEW','APPROVAL_DECIDE','APPROVAL_EXECUTE')
where r.code='GERENCIA_OPERATIVA'
on conflict do nothing;

-- CALIDAD
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r join public.app_permissions p
on p.permission_code in ('APPROVAL_VIEW','APPROVAL_DECIDE')
where r.code='CALIDAD'
on conflict do nothing;

insert into public.app_migrations(
  migration_code,version,description,applied_by
)
values(
  '31_APPROVALS_SOD_v0_31',
  '0.31.0',
  'Aprobaciones, firma operativa y segregación de funciones',
  auth.uid()
)
on conflict(migration_code) do update set
  version=excluded.version,
  description=excluded.description,
  applied_at=now(),
  applied_by=auth.uid();

commit;
