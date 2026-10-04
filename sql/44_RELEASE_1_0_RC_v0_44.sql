begin;
create table if not exists public.release_signoffs(
 id uuid primary key default gen_random_uuid(), release_version text not null,
 signoff_type text not null check(signoff_type in ('OPERACIONES','CALIDAD','TI','GERENCIA')),
 signed_by uuid references public.profiles(id), signed_at timestamptz default now(),
 decision text not null check(decision in ('APROBADO','RECHAZADO','CONDICIONAL')),
 comment text not null, unique(release_version,signoff_type)
);
alter table public.release_signoffs enable row level security;
drop policy if exists release_signoffs_auth on public.release_signoffs;
create policy release_signoffs_auth on public.release_signoffs for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
grant select,insert,update on public.release_signoffs to authenticated;

create or replace view public.vw_release_1_0_readiness as
select
 (select count(*) from public.uat_test_results r join public.uat_test_cases c on c.id=r.test_case_id where c.critical and r.result in ('FAIL','BLOCKED')) critical_uat_failures,
 (select count(*) from public.vw_app_migration_readiness where not applied) missing_migrations,
 (select count(*) from public.vw_app_schema_readiness where not object_exists) missing_objects,
 (select count(*) from public.release_signoffs where release_version='1.0.0' and decision='APROBADO') approved_signoffs,
 (select count(*) from public.release_signoffs where release_version='1.0.0' and decision='RECHAZADO') rejected_signoffs;
grant select on public.vw_release_1_0_readiness to authenticated;

insert into public.app_migrations(migration_code,version,description,applied_by)
values('44_RELEASE_1_0_RC_v0_44','0.44.0','Release candidate final para HemoCura 1.0',auth.uid())
on conflict(migration_code) do update set applied_at=now(),version=excluded.version,description=excluded.description,applied_by=auth.uid();
commit;