-- HemoCura v11 Brecha L2 — captura de horas de uso / servicios realizados.
--
-- El prompt maestro §5.4 exige programar el mantenimiento preventivo por
-- "tiempo transcurrido, horas de uso, número de servicios realizados o
-- criterios del fabricante". El código actual solo soportaba tiempo
-- transcurrido via next_maintenance_date. Esta tabla permite registrar
-- lecturas periódicas de contadores y una vista calcula si el equipo
-- ya alcanzó el umbral del fabricante.
--
-- Columnas opcionales añadidas en lab_equipment:
--   usage_threshold_hours, usage_threshold_services — umbrales del
--   fabricante por encima de los cuales se sugiere mantenimiento.
-- Los umbrales son nullables: si no están definidos, la vista no emite
-- señal por consumo y se sigue usando solo tiempo transcurrido.

begin;

alter table public.lab_equipment add column if not exists usage_threshold_hours integer
 check(usage_threshold_hours is null or usage_threshold_hours between 1 and 100000);
alter table public.lab_equipment add column if not exists usage_threshold_services integer
 check(usage_threshold_services is null or usage_threshold_services between 1 and 1000000);

create table public.equipment_usage(
 id uuid primary key default gen_random_uuid(),
 equipment_id uuid not null references public.lab_equipment(id) on delete restrict,
 branch_id uuid not null references public.branches(id),
 reading_time timestamptz not null default now(),
 hours_counter numeric check(hours_counter is null or hours_counter>=0),
 services_counter integer check(services_counter is null or services_counter>=0),
 observations text check(length(coalesce(observations,''))<=2000),
 recorded_by uuid references public.profiles(id),
 created_at timestamptz not null default now(),
 check(hours_counter is not null or services_counter is not null)
);

create index equipment_usage_by_equipment on public.equipment_usage(equipment_id,reading_time desc,id);
create index equipment_usage_by_branch on public.equipment_usage(branch_id,reading_time desc,id);

-- Las lecturas de contadores deben ser monótonas crecientes dentro del
-- mismo equipo. Un valor menor significa reemplazo de módulo o reset:
-- se registra pero marcándolo como reset explícito con una observación.
create function private.equipment_usage_monotonic() returns trigger language plpgsql as $$
declare prev record;
begin
 select hours_counter,services_counter into prev
  from public.equipment_usage
  where equipment_id=new.equipment_id and reading_time<new.reading_time
  order by reading_time desc,id desc limit 1;
 if prev is null then return new;end if;
 if new.hours_counter is not null and prev.hours_counter is not null
    and new.hours_counter<prev.hours_counter
    and coalesce(trim(new.observations),'')='' then
  raise exception 'Lectura de horas no monotónica (previa % > nueva %). Documente el reset o reemplazo en observations.',prev.hours_counter,new.hours_counter;
 end if;
 if new.services_counter is not null and prev.services_counter is not null
    and new.services_counter<prev.services_counter
    and coalesce(trim(new.observations),'')='' then
  raise exception 'Lectura de servicios no monotónica (previa % > nueva %). Documente el reset o reemplazo en observations.',prev.services_counter,new.services_counter;
 end if;
 return new;
end;$$;

create trigger equipment_usage_monotonic
 before insert on public.equipment_usage
 for each row execute function private.equipment_usage_monotonic();

alter table public.equipment_usage enable row level security;
revoke all on public.equipment_usage from public,anon,authenticated;
grant select,insert on public.equipment_usage to authenticated;
create policy equipment_usage_read on public.equipment_usage for select to authenticated
 using(public.lab_scope(branch_id,'RESOURCES_VIEW'));
create policy equipment_usage_insert on public.equipment_usage for insert to authenticated
 with check(public.lab_scope(branch_id,'RESOURCES_WRITE',true));

create or replace view public.vw_equipment_usage_alerts with(security_invoker=true) as
with latest as (
 select u.equipment_id,
        max(u.hours_counter) as hours_now,
        max(u.services_counter) as services_now,
        max(u.reading_time) as last_reading_at
   from public.equipment_usage u
   group by u.equipment_id
)
select
 e.id as equipment_id,e.equipment_code,e.branch_id,e.equipment_type,
 e.usage_threshold_hours,e.usage_threshold_services,
 l.hours_now,l.services_now,l.last_reading_at,
 case
  when l.last_reading_at is null then 'SIN_LECTURA'
  when e.usage_threshold_hours is not null and l.hours_now>=e.usage_threshold_hours then 'UMBRAL_HORAS'
  when e.usage_threshold_services is not null and l.services_now>=e.usage_threshold_services then 'UMBRAL_SERVICIOS'
  else 'DENTRO_UMBRAL'
 end as usage_status,
 case
  when l.last_reading_at is null then 'MEDIA'
  when (e.usage_threshold_hours is not null and l.hours_now>=e.usage_threshold_hours)
    or (e.usage_threshold_services is not null and l.services_now>=e.usage_threshold_services) then 'CRITICA'
  else 'BAJA'
 end as severity
from public.lab_equipment e
left join latest l on l.equipment_id=e.id
where e.status='ACTIVO'
 and (e.usage_threshold_hours is not null or e.usage_threshold_services is not null);

grant select on public.vw_equipment_usage_alerts to authenticated;

notify pgrst,'reload schema';
commit;
