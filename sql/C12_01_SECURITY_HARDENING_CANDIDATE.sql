-- =====================================================================
-- HemoCura · C12 · SECURITY HARDENING CANDIDATE v2
-- Basado en el esquema REAL verificado en Supabase el 2026-10-06.
-- Ejecutar SOLO después de C12_00_PREFLIGHT_SECURITY_HARDENING.sql.
--
-- Objetivos:
--   1) formalizar roles ENCARGADA_LABORATORIO y TI;
--   2) cerrar escrituras directas en release_signoffs y UAT;
--   3) habilitar sign-off controlado mediante RPC con segregación;
--   4) mantener lectura autenticada para la UI actual;
--   5) auditar sign-offs y operaciones UAT;
--   6) impedir PASS UAT con casos activos sin ejecutar.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Roles faltantes
-- ---------------------------------------------------------------------
insert into public.roles(code,name)
values
  ('ENCARGADA_LABORATORIO','Encargada de Laboratorio'),
  ('TI','Tecnología / TI')
on conflict(code) do update set name=excluded.name;

-- ENCARGADA_LABORATORIO hereda permisos del rol LABORATORIO.
insert into public.role_permissions(role_id,permission_code)
select target.id,rp.permission_code
from public.roles target
join public.roles base on base.code='LABORATORIO'
join public.role_permissions rp on rp.role_id=base.id
where target.code='ENCARGADA_LABORATORIO'
on conflict do nothing;

-- ---------------------------------------------------------------------
-- 2. Permisos explícitos de UAT y Release
-- ---------------------------------------------------------------------
insert into public.app_permissions(permission_code,module,description,risk_level,active)
values
  ('UAT_MANAGE','UAT','Crear y gestionar ejecuciones UAT','CRITICO',true),
  ('RELEASE_SIGNOFF_OPERACIONES','RELEASE','Firmar release por Operaciones','CRITICO',true),
  ('RELEASE_SIGNOFF_CALIDAD','RELEASE','Firmar release por Calidad','CRITICO',true),
  ('RELEASE_SIGNOFF_TI','RELEASE','Firmar release por TI','CRITICO',true),
  ('RELEASE_SIGNOFF_GERENCIA','RELEASE','Firmar release por Gerencia','CRITICO',true)
on conflict(permission_code) do update
set module=excluded.module,
    description=excluded.description,
    risk_level=excluded.risk_level,
    active=true;

insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code
from public.roles r
join (values
  ('GERENCIA_OPERATIVA','UAT_MANAGE'),
  ('CALIDAD','UAT_MANAGE'),
  ('ADMIN','UAT_MANAGE'),
  ('GERENCIA_OPERATIVA','RELEASE_SIGNOFF_OPERACIONES'),
  ('CALIDAD','RELEASE_SIGNOFF_CALIDAD'),
  ('TI','RELEASE_SIGNOFF_TI'),
  ('GERENCIA_GENERAL','RELEASE_SIGNOFF_GERENCIA')
) p(role_code,permission_code) on p.role_code=r.code
on conflict do nothing;

-- ---------------------------------------------------------------------
-- 3. release_signoffs: lectura autenticada; escritura solo por RPC
-- ---------------------------------------------------------------------
drop policy if exists release_signoffs_auth on public.release_signoffs;
drop policy if exists release_signoffs_select on public.release_signoffs;

create policy release_signoffs_select
on public.release_signoffs
for select
to authenticated
using (true);

revoke all on public.release_signoffs from anon;
revoke all on public.release_signoffs from authenticated;
grant select on public.release_signoffs to authenticated;

create or replace function public.hc_v044_release_signoff(
  p_release_version text,
  p_type text,
  p_decision text,
  p_comment text
) returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_type text := upper(trim(coalesce(p_type,'')));
  v_decision text := upper(trim(coalesce(p_decision,'')));
  v_permission text;
  v_id uuid;
  v_existing_signer uuid;
  v_before jsonb;
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida.' using errcode='42501';
  end if;

  if length(trim(coalesce(p_release_version,'')))=0 then
    raise exception 'Versión de release requerida.' using errcode='22023';
  end if;

  v_permission := case v_type
    when 'OPERACIONES' then 'RELEASE_SIGNOFF_OPERACIONES'
    when 'CALIDAD'     then 'RELEASE_SIGNOFF_CALIDAD'
    when 'TI'          then 'RELEASE_SIGNOFF_TI'
    when 'GERENCIA'    then 'RELEASE_SIGNOFF_GERENCIA'
    else null
  end;

  if v_permission is null then
    raise exception 'Tipo de sign-off inválido.' using errcode='22023';
  end if;

  if not public.has_permission(v_permission) then
    raise exception 'No autorizado para sign-off %.',v_type using errcode='42501';
  end if;

  if v_decision not in ('APROBADO','RECHAZADO','CONDICIONAL') then
    raise exception 'Decisión inválida.' using errcode='22023';
  end if;

  -- SoD: un usuario no puede firmar más de un área del mismo release.
  if exists(
    select 1
    from public.release_signoffs
    where release_version=trim(p_release_version)
      and signed_by=auth.uid()
      and signoff_type<>v_type
  ) then
    raise exception 'Segregación de funciones: un usuario no puede firmar dos áreas del mismo release.'
      using errcode='42501';
  end if;

  -- Una firma existente no puede ser reemplazada silenciosamente por otra persona.
  select signed_by,to_jsonb(s)
    into v_existing_signer,v_before
  from public.release_signoffs s
  where s.release_version=trim(p_release_version)
    and s.signoff_type=v_type;

  if v_existing_signer is not null and v_existing_signer<>auth.uid() then
    raise exception 'El área % ya fue firmada por otro usuario.',v_type using errcode='42501';
  end if;

  insert into public.release_signoffs(
    release_version,signoff_type,signed_by,signed_at,decision,comment
  )
  values(
    trim(p_release_version),v_type,auth.uid(),now(),v_decision,
    coalesce(nullif(trim(coalesce(p_comment,'')),''),'Sin comentario')
  )
  on conflict(release_version,signoff_type) do update
    set signed_by=excluded.signed_by,
        signed_at=excluded.signed_at,
        decision=excluded.decision,
        comment=excluded.comment
  returning id into v_id;

  perform public.log_audit_event(
    'RELEASE','SIGNOFF',null,'release_signoffs',v_id,
    trim(p_release_version)||':'||v_type,
    v_before,
    (select to_jsonb(s) from public.release_signoffs s where s.id=v_id),
    jsonb_build_object('permission',v_permission)
  );

  return v_id;
end
$$;

revoke all on function public.hc_v044_release_signoff(text,text,text,text) from public,anon;
grant execute on function public.hc_v044_release_signoff(text,text,text,text) to authenticated;

-- ---------------------------------------------------------------------
-- 4. UAT: lectura directa; escritura pasa a RPC controlado
-- ---------------------------------------------------------------------
drop policy if exists uat_runs_auth on public.uat_test_runs;
drop policy if exists uat_cases_auth on public.uat_test_cases;
drop policy if exists uat_results_auth on public.uat_test_results;
drop policy if exists uat_runs_select on public.uat_test_runs;
drop policy if exists uat_cases_select on public.uat_test_cases;
drop policy if exists uat_results_select on public.uat_test_results;

create policy uat_runs_select on public.uat_test_runs
for select to authenticated using (true);
create policy uat_cases_select on public.uat_test_cases
for select to authenticated using (true);
create policy uat_results_select on public.uat_test_results
for select to authenticated using (true);

revoke all on public.uat_test_runs from anon;
revoke all on public.uat_test_cases from anon;
revoke all on public.uat_test_results from anon;

revoke all on public.uat_test_runs from authenticated;
revoke all on public.uat_test_cases from authenticated;
revoke all on public.uat_test_results from authenticated;

grant select on public.uat_test_runs to authenticated;
grant select on public.uat_test_cases to authenticated;
grant select on public.uat_test_results to authenticated;

create or replace function public.hc_uat_start_run(
  p_run_code text,
  p_release_version text
) returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null or not public.has_permission('UAT_MANAGE') then
    raise exception 'No autorizado para iniciar UAT.' using errcode='42501';
  end if;

  if length(trim(coalesce(p_run_code,'')))=0
     or length(trim(coalesce(p_release_version,'')))=0 then
    raise exception 'run_code y release_version son obligatorios.' using errcode='22023';
  end if;

  insert into public.uat_test_runs(run_code,release_version,tester_user_id,status)
  values(trim(p_run_code),trim(p_release_version),auth.uid(),'EN_CURSO')
  returning id into v_id;

  perform public.log_audit_event(
    'UAT','RUN_STARTED',null,'uat_test_runs',v_id,trim(p_run_code),
    null,
    (select to_jsonb(r) from public.uat_test_runs r where r.id=v_id),
    jsonb_build_object('release_version',trim(p_release_version))
  );

  return v_id;
end
$$;

create or replace function public.hc_uat_record_result(
  p_run_id uuid,
  p_test_case_id uuid,
  p_result text,
  p_actual_result text default null,
  p_evidence_reference text default null
) returns void
language plpgsql
security definer
set search_path=''
as $$
declare
  v_result text := upper(trim(coalesce(p_result,'')));
  v_before jsonb;
begin
  if auth.uid() is null or not public.has_permission('UAT_MANAGE') then
    raise exception 'No autorizado para registrar UAT.' using errcode='42501';
  end if;

  if v_result not in ('PASS','FAIL','BLOCKED','NOT_RUN') then
    raise exception 'Resultado UAT inválido.' using errcode='22023';
  end if;

  if not exists(
    select 1 from public.uat_test_runs
    where id=p_run_id and status='EN_CURSO'
  ) then
    raise exception 'Run UAT inexistente o cerrado.' using errcode='P0002';
  end if;

  if not exists(
    select 1 from public.uat_test_cases
    where id=p_test_case_id and active=true
  ) then
    raise exception 'Caso UAT inexistente o inactivo.' using errcode='P0002';
  end if;

  select to_jsonb(r) into v_before
  from public.uat_test_results r
  where r.run_id=p_run_id and r.test_case_id=p_test_case_id;

  insert into public.uat_test_results(
    run_id,test_case_id,result,actual_result,evidence_reference,tested_at
  )
  values(
    p_run_id,p_test_case_id,v_result,
    nullif(trim(coalesce(p_actual_result,'')),''),
    nullif(trim(coalesce(p_evidence_reference,'')),''),now()
  )
  on conflict(run_id,test_case_id) do update
    set result=excluded.result,
        actual_result=excluded.actual_result,
        evidence_reference=excluded.evidence_reference,
        tested_at=excluded.tested_at;

  perform public.log_audit_event(
    'UAT','RESULT_RECORDED',null,'uat_test_results',null,
    p_run_id::text||':'||p_test_case_id::text,
    v_before,
    (select to_jsonb(r) from public.uat_test_results r
      where r.run_id=p_run_id and r.test_case_id=p_test_case_id),
    jsonb_build_object('result',v_result)
  );
end
$$;

create or replace function public.hc_uat_complete_run(
  p_run_id uuid,
  p_summary text default null
) returns text
language plpgsql
security definer
set search_path=''
as $$
declare
  v_fail integer;
  v_blocked integer;
  v_not_pass integer;
  v_status text;
  v_before jsonb;
begin
  if auth.uid() is null or not public.has_permission('UAT_MANAGE') then
    raise exception 'No autorizado para cerrar UAT.' using errcode='42501';
  end if;

  select to_jsonb(r) into v_before
  from public.uat_test_runs r
  where r.id=p_run_id;

  if v_before is null then
    raise exception 'Run UAT no encontrado.' using errcode='P0002';
  end if;

  if (v_before->>'status')<>'EN_CURSO' then
    raise exception 'El run UAT ya está cerrado.' using errcode='22023';
  end if;

  select
    count(*) filter(where r.result='FAIL'),
    count(*) filter(where r.result='BLOCKED'),
    count(*) filter(where coalesce(r.result,'NOT_RUN')<>'PASS')
  into v_fail,v_blocked,v_not_pass
  from public.uat_test_cases c
  left join public.uat_test_results r
    on r.test_case_id=c.id and r.run_id=p_run_id
  where c.active=true;

  v_status := case
    when v_fail>0 then 'FAIL'
    when v_blocked>0 or v_not_pass>0 then 'BLOQUEADO'
    else 'PASS'
  end;

  update public.uat_test_runs
  set status=v_status,
      completed_at=now(),
      summary=nullif(trim(coalesce(p_summary,'')),'')
  where id=p_run_id;

  perform public.log_audit_event(
    'UAT','RUN_COMPLETED',null,'uat_test_runs',p_run_id,p_run_id::text,
    v_before,
    (select to_jsonb(r) from public.uat_test_runs r where r.id=p_run_id),
    jsonb_build_object('status',v_status,'not_pass_count',v_not_pass)
  );

  return v_status;
end
$$;

revoke all on function public.hc_uat_start_run(text,text) from public,anon;
revoke all on function public.hc_uat_record_result(uuid,uuid,text,text,text) from public,anon;
revoke all on function public.hc_uat_complete_run(uuid,text) from public,anon;

grant execute on function public.hc_uat_start_run(text,text) to authenticated;
grant execute on function public.hc_uat_record_result(uuid,uuid,text,text,text) to authenticated;
grant execute on function public.hc_uat_complete_run(uuid,text) to authenticated;

-- ---------------------------------------------------------------------
-- 5. Registro de la corrección en el registry de la aplicación
-- ---------------------------------------------------------------------
insert into public.app_migrations(
  migration_code,version,description,applied_by,notes
)
values(
  'C12_SECURITY_HARDENING_v0_44_3',
  '0.44.3',
  'Hardening de roles, UAT y sign-offs con segregación y auditoría',
  auth.uid(),
  'Aplicar solo tras C12 preflight favorable.'
)
on conflict(migration_code) do nothing;

commit;
