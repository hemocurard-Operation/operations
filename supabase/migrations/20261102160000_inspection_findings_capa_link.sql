begin;
-- Nivela inspection_findings con audit_findings: hoy un hallazgo de inspección
-- solo guarda nonconformity_id (sin forma de generar la NC ni una CAPA desde la
-- UI), mientras que audit_findings ya tiene ambos pasos vía
-- audit_finding_to_nonconformity/audit_finding_create_capa. Se replica el mismo
-- patrón (misma firma, mismos roles autorizados, misma convención de código)
-- en vez de generalizar esas funciones para no acoplar auditorías internas con
-- inspecciones de sucursal, que son procesos y tablas distintos.

alter table public.inspection_findings
 add column if not exists capa_id uuid references public.capa(id);

create or replace function public.inspection_finding_to_nonconformity(
 p_finding_id uuid,
 p_owner_user_id uuid,
 p_due_date date
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
 v_f public.inspection_findings%rowtype;
 v_i public.branch_inspections%rowtype;
 v_nc uuid;
 v_code text;
begin
 if not (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) then
  raise exception 'Rol no autorizado';
 end if;

 select * into v_f from public.inspection_findings where id=p_finding_id for update;
 if v_f.id is null then raise exception 'Hallazgo no encontrado'; end if;
 if v_f.result<>'NC' then
  raise exception 'Solo hallazgos con resultado No Cumple pueden generar NC';
 end if;
 if v_f.nonconformity_id is not null then return v_f.nonconformity_id; end if;

 select * into v_i from public.branch_inspections where id=v_f.inspection_id;
 if not public.can_access_branch(v_i.branch_id) then raise exception 'Sucursal no autorizada'; end if;

 v_code:='NC-INS-'||to_char(current_date,'YYYYMMDD')||'-'||upper(substr(md5(random()::text),1,5));

 insert into public.nonconformities(
  code,branch_id,description,status,owner_user_id,due_date
 ) values(
  v_code,v_i.branch_id,
  concat(v_f.section_name,' · ',v_f.criterion,coalesce(': '||v_f.observation,'')),
  'ABIERTA',p_owner_user_id,p_due_date
 )
 returning id into v_nc;

 update public.inspection_findings set nonconformity_id=v_nc where id=v_f.id;

 perform public.log_audit_event(
  'INSPECCION','CREATE_NC',v_i.branch_id,'inspection_findings',v_f.id,v_i.inspection_code,
  null,jsonb_build_object('nonconformity_id',v_nc,'nc_code',v_code),null
 );

 return v_nc;
end;
$$;
revoke all on function public.inspection_finding_to_nonconformity(uuid,uuid,date) from public,anon;
grant execute on function public.inspection_finding_to_nonconformity(uuid,uuid,date) to authenticated;

create or replace function public.inspection_finding_create_capa(
 p_finding_id uuid,
 p_action_plan text,
 p_owner_user_id uuid,
 p_due_date date
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
 v_f public.inspection_findings%rowtype;
 v_i public.branch_inspections%rowtype;
 v_capa uuid;
 v_code text;
begin
 if not (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA')) then
  raise exception 'Rol no autorizado';
 end if;

 select * into v_f from public.inspection_findings where id=p_finding_id for update;
 if v_f.id is null then raise exception 'Hallazgo no encontrado'; end if;
 if v_f.nonconformity_id is null then
  raise exception 'El hallazgo debe tener una NC vinculada antes de crear CAPA';
 end if;
 if v_f.capa_id is not null then return v_f.capa_id; end if;
 if trim(coalesce(p_action_plan,''))='' then raise exception 'Plan de acción obligatorio'; end if;

 select * into v_i from public.branch_inspections where id=v_f.inspection_id;
 if not public.can_access_branch(v_i.branch_id) then raise exception 'Sucursal no autorizada'; end if;

 v_code:='CAPA-INS-'||to_char(current_date,'YYYYMMDD')||'-'||upper(substr(md5(random()::text),1,5));

 insert into public.capa(
  code,nonconformity_id,problem,action_plan,owner_user_id,due_date,status
 ) values(
  v_code,v_f.nonconformity_id,
  concat(v_f.section_name,' · ',v_f.criterion,coalesce(': '||v_f.observation,'')),
  p_action_plan,p_owner_user_id,p_due_date,'ABIERTA'
 )
 returning id into v_capa;

 update public.inspection_findings set capa_id=v_capa where id=v_f.id;

 perform public.log_audit_event(
  'INSPECCION','CREATE_CAPA',v_i.branch_id,'inspection_findings',v_f.id,v_i.inspection_code,
  null,jsonb_build_object('capa_id',v_capa,'capa_code',v_code),null
 );

 return v_capa;
end;
$$;
revoke all on function public.inspection_finding_create_capa(uuid,text,uuid,date) from public,anon;
grant execute on function public.inspection_finding_create_capa(uuid,text,uuid,date) to authenticated;

notify pgrst,'reload schema';
commit;
