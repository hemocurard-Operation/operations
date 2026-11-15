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
 reading_time timestamptz not null default clock_timestamp(),
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
 select distinct on (u.equipment_id) u.equipment_id,
        (select x.hours_counter from public.equipment_usage x where x.equipment_id=u.equipment_id and x.hours_counter is not null order by x.reading_time desc,x.id desc limit 1) as hours_now,
        (select x.services_counter from public.equipment_usage x where x.equipment_id=u.equipment_id and x.services_counter is not null order by x.reading_time desc,x.id desc limit 1) as services_now,
        u.reading_time as last_reading_at
   from public.equipment_usage u order by u.equipment_id,u.reading_time desc,u.id desc
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

-- Serialize readings for each equipment, even when two sessions submit simultaneously.
create or replace function private.equipment_usage_monotonic() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare previous_time timestamptz;previous_hours numeric;previous_services integer;
begin
 if not public.lab_scope(new.branch_id,'RESOURCES_WRITE',true) then raise exception 'Sin permiso de escritura' using errcode='42501';end if;
 perform 1 from public.lab_equipment where id=new.equipment_id and branch_id=new.branch_id for update;
 if not found then raise exception 'El equipo no pertenece a la sucursal' using errcode='23514';end if;
 new.recorded_by:=auth.uid();new.created_at:=now();
 select max(reading_time) into previous_time from public.equipment_usage where equipment_id=new.equipment_id;
 if new.reading_time>now()+interval '5 minutes' or new.reading_time<=previous_time then
  raise exception 'La lectura debe ser posterior a la anterior y no futura' using errcode='23514';end if;
 select hours_counter into previous_hours from public.equipment_usage where equipment_id=new.equipment_id and hours_counter is not null order by reading_time desc,id desc limit 1;
 select services_counter into previous_services from public.equipment_usage where equipment_id=new.equipment_id and services_counter is not null order by reading_time desc,id desc limit 1;
 if (new.hours_counter<previous_hours or new.services_counter<previous_services) and coalesce(trim(new.observations),'')='' then
  raise exception 'Documente el reset o reemplazo del contador' using errcode='23514';end if;
 return new;
end;$$;
revoke all on function private.equipment_usage_monotonic() from public,anon,authenticated;


notify pgrst,'reload schema';
commit;
