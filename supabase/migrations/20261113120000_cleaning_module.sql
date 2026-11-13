-- HemoCura v11 §5.8 — Limpieza de equipos.
-- Brecha L1 del PLAN_EJECUTIVO_v11.md. Schema aditivo: no toca tablas
-- existentes salvo para añadir filas al catálogo de permisos y módulos.
--
-- Entidades nuevas:
--   cleaning_plans       — plan recurrente por equipo (frecuencia, procedimiento,
--                           producto, responsable, checklist).
--   cleaning_records     — ejecución del plan con responsable, evidencia,
--                           verificación independiente.
--   vw_cleaning_alerts   — vista derivada que calcula la próxima limpieza
--                           por frecuencia y marca severidad (análoga a
--                           vw_equipment_alerts).
--
-- RLS: por sucursal vía public.lab_scope (patrón del lab_management_workspace).
-- Audit: trigger escribe a public.lab_event_log para trazabilidad.

begin;

insert into public.app_permissions(permission_code,active,description) values
 ('CLEANING_VIEW',true,'Consulta de planes y registros de limpieza de equipos'),
 ('CLEANING_WRITE',true,'Crear o editar planes y registros de limpieza'),
 ('CLEANING_VERIFY',true,'Verificar de forma independiente un registro de limpieza')
 on conflict (permission_code) do update set active=excluded.active,description=excluded.description;

insert into public.role_permissions(role_id,permission_code)
 select r.id,p.permission_code from public.roles r cross join public.app_permissions p
 where r.code='ENCARGADA_LABORATORIO'
   and p.permission_code in ('CLEANING_VIEW','CLEANING_WRITE','CLEANING_VERIFY')
 on conflict do nothing;

insert into public.role_permissions(role_id,permission_code)
 select r.id,'CLEANING_VIEW' from public.roles r
 where r.code in ('LABORATORIO','CALIDAD','GERENCIA_OPERATIVA','GERENCIA_GENERAL','MEDICO_GERENTE_TECNICO')
 on conflict do nothing;

create table public.cleaning_plans(
 id uuid primary key default gen_random_uuid(),
 equipment_id uuid not null references public.lab_equipment(id) on delete restrict,
 branch_id uuid not null references public.branches(id),
 frequency_days integer not null check(frequency_days between 1 and 365),
 procedure_ref text,
 product_name text,
 responsible_role text,
 checklist jsonb not null default '[]'::jsonb
  check(jsonb_typeof(checklist)='array' and jsonb_array_length(checklist)<=50),
 active boolean not null default true,
 revision integer not null default 1,
 created_by uuid references public.profiles(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create unique index cleaning_plan_active_per_equipment
 on public.cleaning_plans(equipment_id) where active;
create index cleaning_plan_branch_idx on public.cleaning_plans(branch_id);

create table public.cleaning_records(
 id uuid primary key default gen_random_uuid(),
 plan_id uuid references public.cleaning_plans(id) on delete restrict,
 equipment_id uuid not null references public.lab_equipment(id) on delete restrict,
 branch_id uuid not null references public.branches(id),
 performed_at timestamptz not null default now(),
 performed_by uuid references public.profiles(id),
 product_used text,
 checklist jsonb not null default '[]'::jsonb
  check(jsonb_typeof(checklist)='array'),
 observations text check(length(coalesce(observations,''))<=4000),
 evidence_reference text,
 verified_by uuid references public.profiles(id)
  check(verified_by is null or verified_by is distinct from performed_by),
 verified_at timestamptz,
 revision integer not null default 1,
 created_at timestamptz not null default now()
);
create index cleaning_record_equipment_date
 on public.cleaning_records(equipment_id,performed_at desc,id);
create index cleaning_record_branch_date
 on public.cleaning_records(branch_id,performed_at desc,id);
create index cleaning_record_plan_idx on public.cleaning_records(plan_id);

alter table public.cleaning_plans enable row level security;
alter table public.cleaning_records enable row level security;
revoke all on public.cleaning_plans,public.cleaning_records from public,anon,authenticated;
grant select,insert,update on public.cleaning_plans to authenticated;
grant select,insert,update on public.cleaning_records to authenticated;

create policy cleaning_plans_read on public.cleaning_plans for select to authenticated
 using(public.lab_scope(branch_id,'CLEANING_VIEW'));
create policy cleaning_plans_insert on public.cleaning_plans for insert to authenticated
 with check(public.lab_scope(branch_id,'CLEANING_WRITE',true));
create policy cleaning_plans_update on public.cleaning_plans for update to authenticated
 using(public.lab_scope(branch_id,'CLEANING_WRITE',true))
 with check(public.lab_scope(branch_id,'CLEANING_WRITE',true));

create policy cleaning_records_read on public.cleaning_records for select to authenticated
 using(public.lab_scope(branch_id,'CLEANING_VIEW'));
create policy cleaning_records_insert on public.cleaning_records for insert to authenticated
 with check(public.lab_scope(branch_id,'CLEANING_WRITE',true));
create policy cleaning_records_update on public.cleaning_records for update to authenticated
 using(public.lab_scope(branch_id,'CLEANING_VERIFY',true))
 with check(public.lab_scope(branch_id,'CLEANING_VERIFY',true));

create function private.cleaning_audit() returns trigger language plpgsql security definer
 set search_path=public,pg_temp as $$
declare b uuid:=case tg_op when 'DELETE' then (to_jsonb(old)->>'branch_id')::uuid
                            else (to_jsonb(new)->>'branch_id')::uuid end;
 id uuid:=case tg_op when 'DELETE' then (to_jsonb(old)->>'id')::uuid
                     else (to_jsonb(new)->>'id')::uuid end;
begin
 insert into public.lab_event_log(branch_id,table_name,record_id,actor_id,before_data,after_data)
 values(b,tg_table_name,id,coalesce(auth.uid(),(to_jsonb(new)->>'created_by')::uuid),
        case tg_op when 'INSERT' then null else to_jsonb(old) end,
        case tg_op when 'DELETE' then '{}'::jsonb else to_jsonb(new) end);
 return case tg_op when 'DELETE' then old else new end;
end;$$;
revoke all on function private.cleaning_audit() from public,anon,authenticated;

create trigger cleaning_plans_audit
 after insert or update on public.cleaning_plans
 for each row execute function private.cleaning_audit();

create trigger cleaning_records_audit
 after insert or update on public.cleaning_records
 for each row execute function private.cleaning_audit();

create or replace view public.vw_cleaning_alerts with(security_invoker=true) as
with latest as (
 select r.equipment_id,max(r.performed_at) as last_performed_at
   from public.cleaning_records r group by r.equipment_id
)
select
 p.equipment_id,e.equipment_code,p.branch_id,p.id as plan_id,
 p.frequency_days,
 l.last_performed_at,
 case when l.last_performed_at is null then current_date
      else (l.last_performed_at at time zone 'America/Santo_Domingo')::date + p.frequency_days
 end as next_due_date,
 case
  when l.last_performed_at is null then 999999
  else greatest(0,
    (current_date - ((l.last_performed_at at time zone 'America/Santo_Domingo')::date + p.frequency_days)))
 end as days_overdue,
 case
  when l.last_performed_at is null then 'CRITICA'
  when ((l.last_performed_at at time zone 'America/Santo_Domingo')::date + p.frequency_days) < current_date then 'CRITICA'
  when ((l.last_performed_at at time zone 'America/Santo_Domingo')::date + p.frequency_days) <= current_date + 3 then 'ALTA'
  when ((l.last_performed_at at time zone 'America/Santo_Domingo')::date + p.frequency_days) <= current_date + 7 then 'MEDIA'
  else 'BAJA'
 end as severity
from public.cleaning_plans p
join public.lab_equipment e on e.id=p.equipment_id
left join latest l on l.equipment_id=p.equipment_id
where p.active and e.status='ACTIVO';

grant select on public.vw_cleaning_alerts to authenticated;

insert into public.app_module_catalog(route_key,title,group_name,permission_code) values
 ('cleaning','Limpieza de equipos','LABORATORIO Y SANGRE','CLEANING_VIEW')
 on conflict (route_key) do update set title=excluded.title,group_name=excluded.group_name,permission_code=excluded.permission_code;

insert into public.role_module_access(role_id,route_key,enabled)
 select id,'cleaning',code in ('SUPER_USUARIO','ENCARGADA_LABORATORIO','LABORATORIO','CALIDAD','GERENCIA_OPERATIVA','GERENCIA_GENERAL','MEDICO_GERENTE_TECNICO')
 from public.roles
 on conflict do nothing;

notify pgrst,'reload schema';

commit;
