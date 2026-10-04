-- ============================================================
-- HemoCura v0.28.0
-- Deployment Governance / Migration Registry / Readiness
-- Requiere v0.27.0
-- ============================================================

begin;
create extension if not exists pgcrypto;

-- 1) REGISTRO DE MIGRACIONES
create table if not exists public.app_migrations (
  migration_code text primary key,
  version text not null,
  description text,
  applied_at timestamptz not null default now(),
  applied_by uuid references public.profiles(id),
  checksum text,
  notes text
);

alter table public.app_migrations enable row level security;

drop policy if exists app_migrations_read on public.app_migrations;
create policy app_migrations_read on public.app_migrations for select
using(auth.role()='authenticated');

drop policy if exists app_migrations_write on public.app_migrations;
create policy app_migrations_write on public.app_migrations for all
using(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA'))
with check(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA'));

grant select,insert,update on public.app_migrations to authenticated;

-- 2) REGISTRO DE RELEASES
create table if not exists public.app_releases (
  id uuid primary key default gen_random_uuid(),
  version text not null unique,
  release_channel text not null default 'RC',
  deployed_at timestamptz,
  deployed_by uuid references public.profiles(id),
  frontend_commit text,
  manifest_sha256 text,
  status text not null default 'PREPARADO'
    check(status in ('PREPARADO','VALIDACION','APROBADO','RECHAZADO','ROLLED_BACK')),
  validation_notes text,
  created_at timestamptz not null default now()
);

alter table public.app_releases enable row level security;

drop policy if exists app_releases_read on public.app_releases;
create policy app_releases_read on public.app_releases for select
using(auth.role()='authenticated');

drop policy if exists app_releases_write on public.app_releases;
create policy app_releases_write on public.app_releases for all
using(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA'))
with check(public.has_role('ADMIN') or public.has_role('GERENCIA_OPERATIVA'));

grant select,insert,update on public.app_releases to authenticated;

-- 3) OBJETOS MÍNIMOS REQUERIDOS
create or replace view public.vw_app_required_objects as
select * from (values
 ('TABLE','branches'),
 ('TABLE','profiles'),
 ('TABLE','user_roles'),
 ('TABLE','dispatches'),
 ('TABLE','donors'),
 ('TABLE','donations'),
 ('TABLE','screening_tests'),
 ('TABLE','blood_inventory_units'),
 ('TABLE','operational_sales'),
 ('TABLE','requisitions'),
 ('TABLE','branch_inspections'),
 ('TABLE','document_register'),
 ('TABLE','risk_register'),
 ('TABLE','projects'),
 ('TABLE','daily_operational_closes'),
 ('TABLE','operational_exceptions'),
 ('TABLE','management_actions'),
 ('TABLE','audit_events'),
 ('VIEW','vw_screening_release_queue'),
 ('VIEW','vw_blood_supply_plan'),
 ('VIEW','vw_management_scorecard'),
 ('VIEW','vw_exception_candidates')
) as x(object_type,object_name);

grant select on public.vw_app_required_objects to authenticated;

-- 4) READINESS DE OBJETOS
create or replace view public.vw_app_schema_readiness as
select
  r.object_type,
  r.object_name,
  case
    when r.object_type='TABLE' then exists(
      select 1 from information_schema.tables t
      where t.table_schema='public' and t.table_name=r.object_name
    )
    when r.object_type='VIEW' then exists(
      select 1 from information_schema.views v
      where v.table_schema='public' and v.table_name=r.object_name
    )
    else false
  end as object_exists
from public.vw_app_required_objects r;

grant select on public.vw_app_schema_readiness to authenticated;

-- 5) READINESS DE MIGRACIONES
create or replace view public.vw_app_migration_readiness as
with required(code,version) as (
  values
   ('22_OPERATIONS_QMS_COMPLIANCE_v0_22','0.22.0'),
   ('23_BLOOD_OPERATIONS_BI_PM_v0_23','0.23.0'),
   ('24_CONTROLLED_BLOOD_FLOW_v0_24','0.24.0'),
   ('25_PRODUCTION_DEMAND_SUPPLY_v0_25','0.25.0'),
   ('26_COMMAND_CENTER_DAILY_CLOSE_v0_26','0.26.0'),
   ('27_AUDIT_TRACE_EXCEPTIONS_v0_27','0.27.0'),
   ('28_DEPLOYMENT_GOVERNANCE_v0_28','0.28.0')
)
select
  r.code migration_code,
  r.version,
  m.applied_at,
  (m.migration_code is not null) as applied
from required r
left join public.app_migrations m on m.migration_code=r.code;

grant select on public.vw_app_migration_readiness to authenticated;

-- 6) ESTADO GENERAL
create or replace view public.vw_app_release_readiness as
select
  (select count(*) from public.vw_app_schema_readiness where object_exists) objects_ok,
  (select count(*) from public.vw_app_schema_readiness) objects_total,
  (select count(*) from public.vw_app_migration_readiness where applied) migrations_ok,
  (select count(*) from public.vw_app_migration_readiness) migrations_total,
  (
    not exists(select 1 from public.vw_app_schema_readiness where not object_exists)
    and not exists(select 1 from public.vw_app_migration_readiness where not applied)
  ) as backend_ready;

grant select on public.vw_app_release_readiness to authenticated;

-- 7) REGISTRAR ESTA MIGRACIÓN
insert into public.app_migrations(
  migration_code,version,description,applied_by
)
values(
  '28_DEPLOYMENT_GOVERNANCE_v0_28',
  '0.28.0',
  'Registro de migraciones, releases y readiness',
  auth.uid()
)
on conflict(migration_code) do update set
  version=excluded.version,
  description=excluded.description,
  applied_at=now(),
  applied_by=auth.uid();

commit;
