-- ============================================================
-- HemoCura v0.27.0
-- Auditoría + trazabilidad + automatización de excepciones
-- Requiere v0.26.0
-- ============================================================
begin;
create extension if not exists pgcrypto;

-- 1) BITÁCORA DE AUDITORÍA
create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  event_time timestamptz not null default now(),
  user_id uuid references public.profiles(id),
  branch_id uuid references public.branches(id),
  module text not null,
  action text not null,
  entity_table text,
  entity_id uuid,
  entity_reference text,
  before_data jsonb,
  after_data jsonb,
  metadata jsonb,
  created_at timestamptz not null default now()
);

alter table public.audit_events enable row level security;

drop policy if exists audit_events_read on public.audit_events;
create policy audit_events_read on public.audit_events for select
using(
  auth.role()='authenticated' and (
    branch_id is null or public.can_access_branch(branch_id)
  )
);

drop policy if exists audit_events_insert on public.audit_events;
create policy audit_events_insert on public.audit_events for insert
with check(auth.role()='authenticated');

grant select,insert on public.audit_events to authenticated;

-- 2) FUNCIÓN GENÉRICA PARA AUDITAR CAMBIOS
create or replace function public.log_audit_event(
  p_module text,
  p_action text,
  p_branch_id uuid,
  p_entity_table text,
  p_entity_id uuid,
  p_entity_reference text,
  p_before jsonb default null,
  p_after jsonb default null,
  p_metadata jsonb default null
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare v_id uuid;
begin
  insert into public.audit_events(
    user_id,branch_id,module,action,entity_table,entity_id,entity_reference,
    before_data,after_data,metadata
  ) values(
    auth.uid(),p_branch_id,p_module,p_action,p_entity_table,p_entity_id,p_entity_reference,
    p_before,p_after,p_metadata
  )
  returning id into v_id;
  return v_id;
end;
$$;

grant execute on function public.log_audit_event(text,text,uuid,text,uuid,text,jsonb,jsonb,jsonb) to authenticated;

-- 3) AUTOMATIZACIÓN DE EXCEPCIONES DESDE ALERTAS
create table if not exists public.exception_generation_rules (
  id uuid primary key default gen_random_uuid(),
  rule_code text not null unique,
  source_view text not null,
  source_alert_code text,
  target_domain text not null,
  target_severity text not null check(target_severity in ('BAJA','MEDIA','ALTA','CRITICA')),
  auto_create boolean not null default false,
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.exception_generation_rules enable row level security;
drop policy if exists exception_generation_rules_read on public.exception_generation_rules;
create policy exception_generation_rules_read on public.exception_generation_rules for select
using(auth.role()='authenticated');
drop policy if exists exception_generation_rules_write on public.exception_generation_rules;
create policy exception_generation_rules_write on public.exception_generation_rules for all
using(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('CALIDAD'))
with check(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA') or public.has_role('CALIDAD'));
grant select,insert,update on public.exception_generation_rules to authenticated;

-- 4) CANDIDATOS A EXCEPCIÓN
create or replace view public.vw_exception_candidates as
select
  'BLOOD_FLOW' source_type,
  a.branch_id,
  a.reference_code source_reference,
  a.alert_code source_alert_code,
  case
    when a.severity='ALTA' then 'ALTA'
    when a.severity='MEDIA' then 'MEDIA'
    else 'BAJA'
  end severity,
  case
    when a.alert_type='TAMIZAJE' then 'TAMIZAJE'
    when a.alert_type='VENCIMIENTO' then 'INVENTARIO'
    else 'INVENTARIO'
  end domain,
  a.message title,
  a.message description
from public.vw_blood_flow_alerts a
union all
select
  'SUPPLY',
  a.branch_id,
  a.reference,
  'SUPPLY_'||a.severity,
  case when a.severity='ROJO' then 'ALTA' else 'MEDIA' end,
  'INVENTARIO',
  a.message,
  concat(a.message,' · cobertura=',coalesce(a.coverage_days::text,'N/D'),' · requeridas=',coalesce(a.required_units::text,'0'))
from public.vw_supply_alerts a
union all
select
  'QMS',
  q.branch_id,
  q.code,
  q.source_type,
  case when q.due_date is not null and q.due_date<current_date then 'ALTA' else 'MEDIA' end,
  'SGC',
  concat(q.source_type,' ',coalesce(q.code,'')),
  q.description
from public.vw_qms_open_actions q;

grant select on public.vw_exception_candidates to authenticated;

-- 5) FUNCIÓN PARA CREAR EXCEPCIÓN DESDE CANDIDATO
create or replace function public.create_exception_from_candidate(
  p_source_type text,
  p_branch_id uuid,
  p_source_reference text,
  p_source_alert_code text,
  p_domain text,
  p_severity text,
  p_title text,
  p_description text
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_existing uuid;
  v_id uuid;
  v_code text;
begin
  if p_branch_id is not null and not public.can_access_branch(p_branch_id) then
    raise exception 'Sin acceso a sucursal';
  end if;

  select id into v_existing
  from public.operational_exceptions
  where source_type=p_source_type
    and coalesce(source_reference,'')=coalesce(p_source_reference,'')
    and status in ('ABIERTA','EN_TRATAMIENTO')
  limit 1;

  if v_existing is not null then
    return v_existing;
  end if;

  v_code := 'EX-'||to_char(current_date,'YYYYMMDD')||'-'||upper(substr(md5(random()::text),1,6));

  insert into public.operational_exceptions(
    exception_code,exception_date,branch_id,domain,severity,
    source_type,source_reference,title,description,status
  ) values(
    v_code,current_date,p_branch_id,p_domain,p_severity,
    p_source_type,p_source_reference,p_title,p_description,'ABIERTA'
  )
  returning id into v_id;

  perform public.log_audit_event(
    'EXCEPCIONES','AUTO_CREATE',p_branch_id,'operational_exceptions',v_id,v_code,
    null,
    jsonb_build_object('source_type',p_source_type,'source_reference',p_source_reference,'severity',p_severity),
    jsonb_build_object('source_alert_code',p_source_alert_code)
  );

  return v_id;
end;
$$;

grant execute on function public.create_exception_from_candidate(text,uuid,text,text,text,text,text,text) to authenticated;

-- 6) REVISIÓN SEMANAL
create table if not exists public.weekly_management_reviews (
  id uuid primary key default gen_random_uuid(),
  week_start date not null,
  branch_id uuid not null references public.branches(id),
  management_score numeric,
  donors integer default 0,
  effective_donations integer default 0,
  screened_units integer default 0,
  released_units integer default 0,
  available_units integer default 0,
  dispatched_units numeric default 0,
  invoiced_amount numeric default 0,
  red_stock integer default 0,
  open_quality_actions integer default 0,
  open_exceptions integer default 0,
  overdue_actions integer default 0,
  key_findings text,
  decisions text,
  commitments text,
  reviewed_by uuid references public.profiles(id),
  status text not null default 'BORRADOR'
    check(status in ('BORRADOR','APROBADA','CERRADA')),
  created_at timestamptz not null default now(),
  unique(week_start,branch_id)
);

alter table public.weekly_management_reviews enable row level security;
drop policy if exists weekly_management_reviews_access on public.weekly_management_reviews;
create policy weekly_management_reviews_access on public.weekly_management_reviews for all
using(public.can_access_branch(branch_id))
with check(public.can_access_branch(branch_id));
grant select,insert,update on public.weekly_management_reviews to authenticated;

-- 7) PORTAFOLIO DE EXCEPCIONES CON EDAD
create or replace view public.vw_exception_portfolio as
select
  e.*,
  (current_date-e.exception_date) age_days,
  case
    when e.status in ('RESUELTA','CERRADA','CANCELADA') then false
    when e.due_date is not null and e.due_date<current_date then true
    else false
  end overdue,
  count(a.id) actions_count,
  count(a.id) filter(where a.status='COMPLETADA') completed_actions
from public.operational_exceptions e
left join public.management_actions a on a.source_exception_id=e.id
group by e.id;

grant select on public.vw_exception_portfolio to authenticated;

-- 8) AUDITORÍA DE CIERRES, EXCEPCIONES Y ACCIONES
create or replace function public.audit_management_change()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_branch uuid;
  v_ref text;
  v_action text;
begin
  v_branch := coalesce(new.branch_id,old.branch_id);
  v_ref := coalesce(
    case when tg_table_name='daily_operational_closes' then coalesce(new.close_date,old.close_date)::text end,
    case when tg_table_name='operational_exceptions' then coalesce(new.exception_code,old.exception_code) end,
    case when tg_table_name='management_actions' then coalesce(new.action_code,old.action_code) end,
    ''
  );
  v_action := tg_op;

  insert into public.audit_events(
    user_id,branch_id,module,action,entity_table,entity_id,entity_reference,before_data,after_data
  ) values(
    auth.uid(),v_branch,'GESTION',v_action,tg_table_name,coalesce(new.id,old.id),v_ref,
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end
  );

  return coalesce(new,old);
end;
$$;

drop trigger if exists trg_audit_daily_closes on public.daily_operational_closes;
create trigger trg_audit_daily_closes
after insert or update on public.daily_operational_closes
for each row execute function public.audit_management_change();

drop trigger if exists trg_audit_exceptions on public.operational_exceptions;
create trigger trg_audit_exceptions
after insert or update on public.operational_exceptions
for each row execute function public.audit_management_change();

drop trigger if exists trg_audit_actions on public.management_actions;
create trigger trg_audit_actions
after insert or update on public.management_actions
for each row execute function public.audit_management_change();

-- 9) AUDITORÍA DE LIBERACIÓN DE UNIDADES
create or replace function public.audit_release_review()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
begin
  insert into public.audit_events(
    user_id,branch_id,module,action,entity_table,entity_id,entity_reference,after_data
  ) values(
    auth.uid(),new.branch_id,'FLUJO_SANGUINEO','RELEASE_REVIEW',
    'unit_release_reviews',new.id,new.source_unit_code,to_jsonb(new)
  );
  return new;
end;
$$;

drop trigger if exists trg_audit_release_review on public.unit_release_reviews;
create trigger trg_audit_release_review
after insert on public.unit_release_reviews
for each row execute function public.audit_release_review();

-- 10) RESUMEN DE AUDITORÍA
create or replace view public.vw_audit_summary_30d as
select
  branch_id,module,action,
  count(*) events,
  min(event_time) first_event,
  max(event_time) last_event
from public.audit_events
where event_time>=now()-interval '30 days'
group by branch_id,module,action;

grant select on public.vw_audit_summary_30d to authenticated;

commit;
