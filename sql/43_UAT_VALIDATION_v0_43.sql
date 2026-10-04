begin;
create table if not exists public.uat_test_runs(
 id uuid primary key default gen_random_uuid(), run_code text not null unique,
 release_version text not null, tester_user_id uuid references public.profiles(id),
 started_at timestamptz not null default now(), completed_at timestamptz,
 status text not null default 'EN_CURSO' check(status in ('EN_CURSO','PASS','FAIL','BLOQUEADO')),
 summary text
);
create table if not exists public.uat_test_cases(
 id uuid primary key default gen_random_uuid(), test_code text not null unique,
 module text not null, title text not null, preconditions text, steps text not null,
 expected_result text not null, critical boolean not null default false, active boolean not null default true
);
create table if not exists public.uat_test_results(
 id uuid primary key default gen_random_uuid(), run_id uuid not null references public.uat_test_runs(id) on delete cascade,
 test_case_id uuid not null references public.uat_test_cases(id), result text not null check(result in ('PASS','FAIL','BLOCKED','NOT_RUN')),
 actual_result text, evidence_reference text, tested_at timestamptz default now(),
 unique(run_id,test_case_id)
);
alter table public.uat_test_runs enable row level security;
alter table public.uat_test_cases enable row level security;
alter table public.uat_test_results enable row level security;
drop policy if exists uat_runs_auth on public.uat_test_runs; create policy uat_runs_auth on public.uat_test_runs for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
drop policy if exists uat_cases_auth on public.uat_test_cases; create policy uat_cases_auth on public.uat_test_cases for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
drop policy if exists uat_results_auth on public.uat_test_results; create policy uat_results_auth on public.uat_test_results for all using(auth.role()='authenticated') with check(auth.role()='authenticated');
grant select,insert,update on public.uat_test_runs,public.uat_test_cases,public.uat_test_results to authenticated;
insert into public.uat_test_cases(test_code,module,title,steps,expected_result,critical) values
('UAT-AUTH-001','AUTH','Login y sesión','Iniciar sesión con usuario válido','Acceso correcto y sesión persistente',true),
('UAT-RLS-001','SECURITY','RLS por sucursal','Intentar consultar datos de otra sucursal con rol restringido','Acceso denegado',true),
('UAT-BLOOD-001','BLOOD_FLOW','Liberación controlada','Revisar unidad y ejecutar flujo humano autorizado','No hay liberación automática; queda trazabilidad',true),
('UAT-QMS-001','QMS','NC → CAPA','Crear NC y CAPA y verificar cierre','Trazabilidad completa',true),
('UAT-AUD-001','AUDIT','Auditoría interna','Crear auditoría y hallazgo','Hallazgo vinculado y auditable',false),
('UAT-DOC-001','DOCUMENTS','Aprobación documental','Solicitar y aprobar documento con segregación','Solicitante no autoaprueba',true),
('UAT-COLD-001','COLD_CHAIN','Excursión térmica','Registrar lectura fuera de rango','Se genera alerta visible',true),
('UAT-IQC-001','IQC','Control fuera de rango','Registrar IQC fuera de límites','Estado FUERA_CONTROL y alerta',true)
on conflict(test_code) do nothing;
create or replace view public.vw_uat_summary as
select r.id,r.run_code,r.release_version,r.status,
 count(x.id) results_total,
 count(x.id) filter(where x.result='PASS') pass_count,
 count(x.id) filter(where x.result='FAIL') fail_count,
 count(x.id) filter(where x.result='BLOCKED') blocked_count
from public.uat_test_runs r left join public.uat_test_results x on x.run_id=r.id group by r.id;
grant select on public.vw_uat_summary to authenticated;
insert into public.app_migrations(migration_code,version,description,applied_by)
values('43_UAT_VALIDATION_v0_43','0.43.0','UAT y validación operativa',auth.uid())
on conflict(migration_code) do update set applied_at=now(),version=excluded.version,description=excluded.description,applied_by=auth.uid();
commit;