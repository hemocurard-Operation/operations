-- ============================================================
-- HemoCura v0.24.0
-- Automatización CONTROLADA de cadena sanguínea
-- Requiere v0.23.0
-- ============================================================

begin;
create extension if not exists pgcrypto;

-- 1) CONTROL DE LIBERACIÓN DE UNIDADES
create table if not exists public.unit_release_reviews (
  id uuid primary key default gen_random_uuid(),
  source_unit_code text not null,
  branch_id uuid not null references public.branches(id),
  review_date timestamptz not null default now(),
  reviewed_by uuid not null references public.profiles(id),
  decision text not null check(decision in ('APTO','NO_APTO','RETENER')),
  rationale text not null,
  evidence_reference text,
  created_at timestamptz not null default now()
);

create index if not exists idx_unit_release_reviews_unit
  on public.unit_release_reviews(source_unit_code, review_date desc);

alter table public.unit_release_reviews enable row level security;

drop policy if exists unit_release_reviews_read on public.unit_release_reviews;
create policy unit_release_reviews_read on public.unit_release_reviews for select
using(public.can_access_branch(branch_id));

drop policy if exists unit_release_reviews_write on public.unit_release_reviews;
create policy unit_release_reviews_write on public.unit_release_reviews for insert
with check(
  public.can_access_branch(branch_id)
  and (
    public.has_role('ADMIN') or
    public.has_role('LABORATORIO') or
    public.has_role('CALIDAD') or
    public.has_role('GERENCIA_OPERATIVA')
  )
);

grant select,insert on public.unit_release_reviews to authenticated;

-- 2) ÚLTIMA DECISIÓN DE LIBERACIÓN
create or replace view public.vw_unit_release_latest as
select distinct on (r.source_unit_code)
  r.id,
  r.source_unit_code,
  r.branch_id,
  r.review_date,
  r.reviewed_by,
  r.decision,
  r.rationale,
  r.evidence_reference
from public.unit_release_reviews r
order by r.source_unit_code, r.review_date desc;

grant select on public.vw_unit_release_latest to authenticated;

-- 3) COLA DE REVISIÓN DE TAMIZAJE
create or replace view public.vw_screening_release_queue as
with test_summary as (
  select
    source_unit_code,
    branch_id,
    count(*) total_tests,
    count(*) filter(where status='VALIDADO') validated_tests,
    count(*) filter(where result='REACTIVO') reactive_tests,
    count(*) filter(where result='INDETERMINADO') indeterminate_tests,
    max(screening_date) last_screening_date
  from public.screening_tests
  group by source_unit_code, branch_id
)
select
  d.id donation_id,
  d.donation_code,
  d.source_unit_code,
  d.branch_id,
  d.donation_date,
  d.status donation_status,
  coalesce(t.total_tests,0) total_tests,
  coalesce(t.validated_tests,0) validated_tests,
  coalesce(t.reactive_tests,0) reactive_tests,
  coalesce(t.indeterminate_tests,0) indeterminate_tests,
  t.last_screening_date,
  r.decision latest_release_decision,
  r.review_date latest_review_date,
  case
    when r.decision='APTO' then 'LIBERADA'
    when r.decision='NO_APTO' then 'NO_LIBERADA'
    when r.decision='RETENER' then 'RETENIDA'
    when coalesce(t.total_tests,0)=0 then 'SIN_TAMIZAJE'
    when coalesce(t.validated_tests,0)<coalesce(t.total_tests,0) then 'TAMIZAJE_PENDIENTE'
    when coalesce(t.reactive_tests,0)>0 then 'REQUIERE_REVISION_REACTIVO'
    when coalesce(t.indeterminate_tests,0)>0 then 'REQUIERE_REVISION_INDETERMINADO'
    else 'LISTA_PARA_REVISION'
  end queue_status
from public.donations d
left join test_summary t on t.source_unit_code=d.source_unit_code and t.branch_id=d.branch_id
left join public.vw_unit_release_latest r on r.source_unit_code=d.source_unit_code
where d.status not in ('DESCARTADA');

grant select on public.vw_screening_release_queue to authenticated;

-- 4) FUNCIÓN DE LIBERACIÓN MANUAL CONTROLADA
create or replace function public.review_and_release_unit(
  p_source_unit_code text,
  p_decision text,
  p_rationale text,
  p_evidence_reference text default null
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_branch uuid;
  v_profile uuid;
  v_review_id uuid;
begin
  if p_decision not in ('APTO','NO_APTO','RETENER') then
    raise exception 'Decisión inválida';
  end if;

  if trim(coalesce(p_rationale,''))='' then
    raise exception 'La justificación es obligatoria';
  end if;

  select branch_id into v_branch
  from public.donations
  where source_unit_code=p_source_unit_code
  limit 1;

  if v_branch is null then
    raise exception 'Unidad origen no encontrada';
  end if;

  if not public.can_access_branch(v_branch) then
    raise exception 'Sin acceso a la sucursal';
  end if;

  if not (
    public.has_role('ADMIN') or
    public.has_role('LABORATORIO') or
    public.has_role('CALIDAD') or
    public.has_role('GERENCIA_OPERATIVA')
  ) then
    raise exception 'Rol no autorizado para liberar unidades';
  end if;

  v_profile := auth.uid();

  insert into public.unit_release_reviews(
    source_unit_code,branch_id,reviewed_by,decision,rationale,evidence_reference
  )
  values(
    p_source_unit_code,v_branch,v_profile,p_decision,p_rationale,p_evidence_reference
  )
  returning id into v_review_id;

  update public.donations
  set status = case
      when p_decision='APTO' then 'APTA'
      when p_decision='NO_APTO' then 'NO_APTA'
      else status
    end
  where source_unit_code=p_source_unit_code;

  update public.blood_inventory_units
  set
    screening_status = case
      when p_decision='APTO' then 'APTO'
      when p_decision='NO_APTO' then 'NO_APTO'
      else screening_status
    end,
    inventory_status = case
      when p_decision='APTO' and inventory_status='CUARENTENA' then 'DISPONIBLE'
      when p_decision='NO_APTO' then 'DESCARTADA'
      when p_decision='RETENER' and inventory_status='DISPONIBLE' then 'CUARENTENA'
      else inventory_status
    end
  where source_unit_code=p_source_unit_code;

  return v_review_id;
end;
$$;

grant execute on function public.review_and_release_unit(text,text,text,text) to authenticated;

-- 5) BLOQUEO DE SALIDA DE UNIDADES NO DISPONIBLES
create or replace function public.validate_blood_unit_outflow()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_status text;
  v_screening text;
begin
  if new.blood_inventory_unit_id is null then
    return new;
  end if;

  select inventory_status,screening_status
    into v_status,v_screening
  from public.blood_inventory_units
  where id=new.blood_inventory_unit_id
  for update;

  if v_status is null then
    raise exception 'Unidad de inventario no encontrada';
  end if;

  if v_screening<>'APTO' or v_status<>'DISPONIBLE' then
    raise exception 'Unidad no liberada o no disponible: screening=%, inventario=%',
      v_screening,v_status;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_blood_unit_outflow on public.operational_sale_lines;
create trigger trg_validate_blood_unit_outflow
before insert or update of blood_inventory_unit_id
on public.operational_sale_lines
for each row
execute function public.validate_blood_unit_outflow();

-- 6) MARCAR UNIDAD DESPACHADA DESPUÉS DE ASOCIARLA A UNA SALIDA
create or replace function public.mark_blood_unit_dispatched()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
begin
  if new.blood_inventory_unit_id is not null then
    update public.blood_inventory_units
    set inventory_status='DESPACHADA'
    where id=new.blood_inventory_unit_id
      and inventory_status='DISPONIBLE'
      and screening_status='APTO';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_mark_blood_unit_dispatched on public.operational_sale_lines;
create trigger trg_mark_blood_unit_dispatched
after insert
on public.operational_sale_lines
for each row
execute function public.mark_blood_unit_dispatched();

-- 7) ESTADO OPERATIVO DE FLUJO
create or replace view public.vw_blood_flow_status as
select
  d.branch_id,
  d.donation_date,
  d.donation_code,
  d.source_unit_code,
  d.status donation_status,
  q.queue_status,
  q.total_tests,
  q.validated_tests,
  q.reactive_tests,
  q.indeterminate_tests,
  q.latest_release_decision,
  count(b.id) component_count,
  count(b.id) filter(where b.inventory_status='DISPONIBLE' and b.screening_status='APTO') available_components,
  count(b.id) filter(where b.inventory_status='DESPACHADA') dispatched_components,
  min(b.expiry_date) filter(where b.inventory_status='DISPONIBLE') nearest_expiry
from public.donations d
left join public.vw_screening_release_queue q on q.source_unit_code=d.source_unit_code
left join public.blood_inventory_units b on b.source_unit_code=d.source_unit_code
group by
  d.branch_id,d.donation_date,d.donation_code,d.source_unit_code,d.status,
  q.queue_status,q.total_tests,q.validated_tests,q.reactive_tests,q.indeterminate_tests,
  q.latest_release_decision;

grant select on public.vw_blood_flow_status to authenticated;

-- 8) ALERTAS OPERATIVAS
create or replace view public.vw_blood_flow_alerts as
select
  'TAMIZAJE' alert_type,
  q.branch_id,
  q.source_unit_code reference_code,
  q.queue_status alert_code,
  case
    when q.queue_status in ('REQUIERE_REVISION_REACTIVO','REQUIERE_REVISION_INDETERMINADO') then 'ALTA'
    when q.queue_status in ('SIN_TAMIZAJE','TAMIZAJE_PENDIENTE') then 'MEDIA'
    else 'BAJA'
  end severity,
  concat('Unidad ',q.source_unit_code,' · ',q.queue_status) message
from public.vw_screening_release_queue q
where q.queue_status not in ('LIBERADA','NO_LIBERADA')
union all
select
  'VENCIMIENTO',
  b.branch_id,
  b.unit_code,
  'PROXIMO_VENCIMIENTO',
  case when b.expiry_date<=current_date+1 then 'ALTA' else 'MEDIA' end,
  concat('Unidad ',b.unit_code,' vence ',b.expiry_date)
from public.blood_inventory_units b
where b.inventory_status='DISPONIBLE'
  and b.expiry_date is not null
  and b.expiry_date<=current_date+7
union all
select
  'INVENTARIO',
  a.branch_id,
  concat(coalesce(a.component_name,''),' ',coalesce(a.abo,''),' ',coalesce(a.rh,'')),
  'SIN_DISPONIBILIDAD',
  'ALTA',
  concat('Sin disponibilidad: ',coalesce(a.component_name,''),' ',coalesce(a.abo,''),' ',coalesce(a.rh,''))
from public.vw_blood_inventory_available a
where coalesce(a.available_units,0)=0;

grant select on public.vw_blood_flow_alerts to authenticated;

-- 9) BI DEL EMBUDO SANGUÍNEO
create or replace view public.vw_blood_flow_funnel_30d as
select
  b.id branch_id,
  b.name branch_name,
  coalesce(d.donors,0) donors,
  coalesce(d.effective,0) effective_donations,
  coalesce(x.donations,0) collected_units,
  coalesce(s.screened_units,0) screened_units,
  coalesce(r.released_units,0) released_units,
  coalesce(i.available_units,0) available_units,
  coalesce(o.dispatched_units,0) dispatched_units
from public.branches b
left join (
  select branch_id,count(*) donors,count(*) filter(where effective_donation) effective
  from public.donors
  where registration_date>=current_date-29
  group by branch_id
) d on d.branch_id=b.id
left join (
  select branch_id,count(*) donations
  from public.donations
  where donation_date>=current_date-29
  group by branch_id
) x on x.branch_id=b.id
left join (
  select branch_id,count(distinct source_unit_code) screened_units
  from public.screening_tests
  where screening_date>=current_date-29
  group by branch_id
) s on s.branch_id=b.id
left join (
  select branch_id,count(distinct source_unit_code) released_units
  from public.unit_release_reviews
  where review_date::date>=current_date-29 and decision='APTO'
  group by branch_id
) r on r.branch_id=b.id
left join (
  select branch_id,count(*) available_units
  from public.blood_inventory_units
  where inventory_status='DISPONIBLE' and screening_status='APTO'
  group by branch_id
) i on i.branch_id=b.id
left join (
  select branch_id,count(*) dispatched_units
  from public.blood_inventory_units
  where inventory_status='DESPACHADA' and created_at::date>=current_date-29
  group by branch_id
) o on o.branch_id=b.id
where b.active;

grant select on public.vw_blood_flow_funnel_30d to authenticated;

commit;
