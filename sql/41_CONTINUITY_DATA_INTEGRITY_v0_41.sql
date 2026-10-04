begin;
create table if not exists public.continuity_plans(
 id uuid primary key default gen_random_uuid(), plan_code text not null unique,
 title text not null, scenario text not null, owner_user_id uuid references public.profiles(id),
 recovery_objective text, workaround text, recovery_steps text, review_date date,
 status text not null default 'ACTIVO' check(status in ('BORRADOR','ACTIVO','EN_REVISION','RETIRADO'))
);
create table if not exists public.continuity_tests(
 id uuid primary key default gen_random_uuid(), plan_id uuid not null references public.continuity_plans(id),
 test_date date not null default current_date, test_type text not null,
 result text not null check(result in ('SATISFACTORIO','PARCIAL','NO_SATISFACTORIO')),
 findings text, actions text, evidence_reference text, tested_by uuid references public.profiles(id)
);
create table if not exists public.data_integrity_checks(
 id uuid primary key default gen_random_uuid(), check_code text not null unique,
 check_date timestamptz not null default now(), subsystem text not null, check_type text not null,
 result text not null check(result in ('PASS','WARN','FAIL')), detail text,
 evidence_reference text, executed_by uuid references public.profiles(id)
);
alter table public.continuity_plans enable row level security;
alter table public.continuity_tests enable row level security;
alter table public.data_integrity_checks enable row level security;
drop policy if exists continuity_plans_auth on public.continuity_plans; create policy continuity_plans_auth on public.continuity_plans for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
drop policy if exists continuity_tests_auth on public.continuity_tests; create policy continuity_tests_auth on public.continuity_tests for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
drop policy if exists data_integrity_checks_auth on public.data_integrity_checks; create policy data_integrity_checks_auth on public.data_integrity_checks for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
grant select,insert,update on public.continuity_plans,public.continuity_tests,public.data_integrity_checks to authenticated;
create or replace view public.vw_continuity_readiness as
select
 (select count(*) from public.continuity_plans where status='ACTIVO') active_plans,
 (select count(*) from public.continuity_plans where review_date<current_date and status='ACTIVO') overdue_reviews,
 (select count(*) from public.continuity_tests where result='NO_SATISFACTORIO' and test_date>=current_date-365) failed_tests_12m,
 (select count(*) from public.data_integrity_checks where result='FAIL' and check_date>=now()-interval '30 days') integrity_failures_30d;
grant select on public.vw_continuity_readiness to authenticated;
insert into public.app_permissions(permission_code,module,description,risk_level) values
('CONTINUITY_VIEW','CONTINUITY','Ver continuidad y controles TI','SENSIBLE'),
('CONTINUITY_WRITE','CONTINUITY','Gestionar continuidad y controles TI','CRITICO')
on conflict(permission_code) do update set active=true;
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r join public.app_permissions p on p.permission_code in ('CONTINUITY_VIEW','CONTINUITY_WRITE')
where r.code in ('ADMIN','GERENCIA_OPERATIVA','CALIDAD') on conflict do nothing;
insert into public.app_migrations(migration_code,version,description,applied_by)
values('41_CONTINUITY_DATA_INTEGRITY_v0_41','0.41.0','Continuidad e integridad de datos',auth.uid())
on conflict(migration_code) do update set applied_at=now(),version=excluded.version,description=excluded.description,applied_by=auth.uid();
commit;