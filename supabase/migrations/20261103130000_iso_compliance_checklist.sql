begin;
-- Checklist de cumplimiento ISO 9001 / ISO 15189: autoevaluación continua por
-- cláusula, independiente del programa de auditoría interna (internal_audits),
-- con evidencia y vínculo opcional a una no conformidad cuando hay brecha.
-- Reutiliza audit_criteria_catalog (ya sembrado con ISO 15189) como catálogo
-- único de cláusulas; aquí se agregan las de ISO 9001 y se crea el registro
-- de estado + evidencia que el catálogo por sí solo no tenía.

-- 1) CLÁUSULAS ISO 9001 EN EL CATÁLOGO EXISTENTE
insert into public.audit_criteria_catalog(
  framework,clause_reference,criterion_code,criterion_summary,process_area
) values
('ISO 9001','4','ISO9001-4-CTX','Contexto de la organización: partes interesadas, alcance y procesos del SGC.','CONTEXTO'),
('ISO 9001','5','ISO9001-5-LID','Liderazgo: compromiso, política de calidad, roles y responsabilidades.','LIDERAZGO'),
('ISO 9001','6','ISO9001-6-PLA','Planificación: riesgos, oportunidades, objetivos de calidad y cambios.','PLANIFICACION'),
('ISO 9001','7','ISO9001-7-APO','Apoyo: recursos, competencia, comunicación e información documentada.','APOYO'),
('ISO 9001','8','ISO9001-8-OPE','Operación: planificación y control operacional, diseño y provisión externa.','OPERACION'),
('ISO 9001','9','ISO9001-9-EVA','Evaluación del desempeño: seguimiento, medición, auditoría interna y revisión por la dirección.','EVALUACION'),
('ISO 9001','10','ISO9001-10-MEJ','Mejora: no conformidad, acción correctiva y mejora continua.','MEJORA')
on conflict(criterion_code) do nothing;

-- 2) ESTADO DE CUMPLIMIENTO POR CLÁUSULA Y SUCURSAL (NULL = corporativo)
create table if not exists public.iso_clause_assessments (
  id uuid primary key default gen_random_uuid(),
  criterion_id uuid not null references public.audit_criteria_catalog(id),
  branch_id uuid references public.branches(id),
  status text not null default 'PENDIENTE'
    check(status in ('CUMPLE','PARCIAL','NO_CUMPLE','NO_APLICA','PENDIENTE')),
  responsible_user_id uuid references public.profiles(id),
  nonconformity_id uuid references public.nonconformities(id),
  notes text,
  last_reviewed_at timestamptz,
  next_review_date date,
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(criterion_id,branch_id)
);

alter table public.iso_clause_assessments enable row level security;
drop policy if exists iso_clause_assessments_read on public.iso_clause_assessments;
create policy iso_clause_assessments_read on public.iso_clause_assessments for select
using(branch_id is null or public.can_access_branch(branch_id));
drop policy if exists iso_clause_assessments_write on public.iso_clause_assessments;
create policy iso_clause_assessments_write on public.iso_clause_assessments for all
using(
  (branch_id is null or public.can_access_branch(branch_id))
  and (public.has_role('ADMIN') or public.has_role('CALIDAD'))
)
with check(
  (branch_id is null or public.can_access_branch(branch_id))
  and (public.has_role('ADMIN') or public.has_role('CALIDAD'))
);
grant select,insert,update on public.iso_clause_assessments to authenticated;

-- 3) EVIDENCIA DE CUMPLIMIENTO (varias entradas por cláusula a través del tiempo)
create table if not exists public.iso_clause_evidence (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.iso_clause_assessments(id) on delete cascade,
  evidence_type text not null default 'DOCUMENTO'
    check(evidence_type in ('DOCUMENTO','REGISTRO','ENTREVISTA','OBSERVACION','MUESTRA','FOTO','OTRO')),
  title text not null,
  description text,
  source_reference text,
  source_url text,
  captured_by uuid references public.profiles(id),
  captured_at timestamptz not null default now()
);

alter table public.iso_clause_evidence enable row level security;
drop policy if exists iso_clause_evidence_access on public.iso_clause_evidence;
create policy iso_clause_evidence_access on public.iso_clause_evidence for all
using(
  exists(
    select 1 from public.iso_clause_assessments a
    where a.id=assessment_id and (a.branch_id is null or public.can_access_branch(a.branch_id))
  )
)
with check(
  (public.has_role('ADMIN') or public.has_role('CALIDAD'))
  and exists(
    select 1 from public.iso_clause_assessments a
    where a.id=assessment_id and (a.branch_id is null or public.can_access_branch(a.branch_id))
  )
);
grant select,insert on public.iso_clause_evidence to authenticated;

-- 4) REGISTRO DE AUTOEVALUACIÓN CON TRAZABILIDAD (UPSERT + LOG)
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
  if not (public.has_role('ADMIN') or public.has_role('CALIDAD')) then
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
revoke all on function public.iso_clause_assessment_upsert(uuid,uuid,text,uuid,text,date) from public,anon;
grant execute on function public.iso_clause_assessment_upsert(uuid,uuid,text,uuid,text,date) to authenticated;

-- 5) CREAR NC DESDE UNA CLÁUSULA NO CUMPLIDA
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
  if not (public.has_role('ADMIN') or public.has_role('CALIDAD')) then
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
revoke all on function public.iso_clause_assessment_create_nc(uuid,uuid,date,text) from public,anon;
grant execute on function public.iso_clause_assessment_create_nc(uuid,uuid,date,text) to authenticated;

-- 6) VISTA GERENCIAL
create or replace view public.vw_iso_compliance_summary
with (security_invoker=true) as
select
  c.framework,
  count(*) clauses_total,
  count(a.id) filter(where a.status='CUMPLE') compliant,
  count(a.id) filter(where a.status='PARCIAL') partial,
  count(a.id) filter(where a.status='NO_CUMPLE') non_compliant,
  count(a.id) filter(where a.status='NO_APLICA') not_applicable,
  count(*) filter(where a.id is null or a.status='PENDIENTE') pending,
  count(a.id) filter(where a.next_review_date<current_date and a.status not in ('NO_APLICA')) overdue_review
from public.audit_criteria_catalog c
left join public.iso_clause_assessments a on a.criterion_id=c.id and a.branch_id is null
where c.framework in ('ISO 9001','ISO 15189') and c.active
group by c.framework;
grant select on public.vw_iso_compliance_summary to authenticated;

-- 7) PERMISOS
insert into public.app_permissions(permission_code,module,description,risk_level) values
('ISO_COMPLIANCE_VIEW','SGC','Ver checklist de cumplimiento ISO 9001/15189','SENSIBLE'),
('ISO_COMPLIANCE_WRITE','SGC','Registrar autoevaluación y evidencia ISO 9001/15189','CRITICO')
on conflict(permission_code) do update set
 module=excluded.module,description=excluded.description,risk_level=excluded.risk_level,active=true;

insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r join public.app_permissions p
on p.permission_code in ('ISO_COMPLIANCE_VIEW','ISO_COMPLIANCE_WRITE')
where r.code in ('ADMIN','CALIDAD') on conflict do nothing;

insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r join public.app_permissions p
on p.permission_code='ISO_COMPLIANCE_VIEW'
where r.code in ('GERENCIA_OPERATIVA','GERENCIA_GENERAL','SOCIO','SUPER_USUARIO') on conflict do nothing;

-- 8) MIGRACIÓN
insert into public.app_migrations(migration_code,version,description,applied_by)
values(
  '20261103130000_iso_compliance_checklist','0.49.2',
  'Checklist de cumplimiento ISO 9001/15189 con autoevaluación, evidencia y NC',
  auth.uid()
)
on conflict(migration_code) do update set
  version=excluded.version,description=excluded.description,applied_at=now(),applied_by=auth.uid();

notify pgrst,'reload schema';
commit;
