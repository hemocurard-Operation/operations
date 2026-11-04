-- Hemocura: preserve upsert contracts and shared training catalog reads.
-- hc-lint: allow=HC009 reason=Only REVOKE TRUNCATE privileges; no records are truncated.
begin;
set local lock_timeout='5s';

drop policy audit_plan_criteria_access on public.audit_plan_criteria;
create policy audit_plan_criteria_read on public.audit_plan_criteria
 for select to authenticated using (
 public.wf_active_actor() and public.has_permission('INTERNAL_AUDIT_VIEW') and exists(
  select 1 from public.internal_audits a where a.id=audit_id
   and (a.branch_id is null or public.can_access_branch(a.branch_id))));
create policy audit_plan_criteria_insert on public.audit_plan_criteria
 for insert to authenticated with check (
 public.wf_active_actor() and public.has_permission('INTERNAL_AUDIT_WRITE') and exists(
  select 1 from public.internal_audits a where a.id=audit_id
   and (a.branch_id is null or public.can_access_branch(a.branch_id))));
create policy audit_plan_criteria_update on public.audit_plan_criteria
 for update to authenticated using (
 public.wf_active_actor() and public.has_permission('INTERNAL_AUDIT_WRITE') and exists(
  select 1 from public.internal_audits a where a.id=audit_id
   and (a.branch_id is null or public.can_access_branch(a.branch_id))))
 with check (
 public.wf_active_actor() and public.has_permission('INTERNAL_AUDIT_WRITE') and exists(
  select 1 from public.internal_audits a where a.id=audit_id
   and (a.branch_id is null or public.can_access_branch(a.branch_id))));

drop policy job_role_competencies_access on public.job_role_competencies;
-- This is a global job-to-competency catalog, not an employee/branch assignment.
-- Training views need read access even for staff without COMPETENCY_VIEW.
create policy job_role_competencies_read on public.job_role_competencies
 for select to authenticated using ((select public.wf_active_actor()));
create policy job_role_competencies_insert on public.job_role_competencies
 for insert to authenticated with check (
  (select public.wf_active_actor()) and (select public.has_permission('COMPETENCY_WRITE')));
create policy job_role_competencies_update on public.job_role_competencies
 for update to authenticated using (
  (select public.wf_active_actor()) and (select public.has_permission('COMPETENCY_WRITE')))
 with check ((select public.wf_active_actor()) and (select public.has_permission('COMPETENCY_WRITE')));

revoke all privileges on public.audit_plan_criteria,public.job_role_competencies from public,anon;
revoke delete,truncate on public.audit_plan_criteria,public.job_role_competencies from authenticated;

create or replace function private.audit_quality_configuration_change()
returns trigger language plpgsql security definer set search_path='' as $audit$
declare before_row jsonb;after_row jsonb;changed jsonb;branch uuid;module_code text;
begin
 if TG_TABLE_SCHEMA<>'public' or TG_TABLE_NAME not in ('audit_plan_criteria','job_role_competencies') then
  raise exception 'Unsupported quality configuration table';
 end if;
 before_row:=case when TG_OP='INSERT' then '{}'::jsonb else to_jsonb(OLD) end;
 after_row:=case when TG_OP='DELETE' then '{}'::jsonb else to_jsonb(NEW) end;
 if TG_OP='UPDATE' then
  if before_row->'id' is distinct from after_row->'id' then
   raise exception 'No se permite cambiar la identidad del registro' using errcode='23514';
  end if;
  if before_row=after_row then return NEW;end if;
 end if;
 select coalesce(jsonb_agg(key order by key),'[]'::jsonb) into changed
 from jsonb_object_keys(before_row||after_row) keys(key)
 where before_row->key is distinct from after_row->key;
 if TG_TABLE_NAME='audit_plan_criteria' then
  module_code:='INTERNAL_AUDIT';
  select a.branch_id into branch from public.internal_audits a
   where a.id=coalesce(after_row->>'audit_id',before_row->>'audit_id')::uuid;
 else module_code:='COMPETENCY';end if;
 insert into public.audit_events(user_id,branch_id,module,action,entity_table,entity_id,entity_reference,
  before_data,after_data,metadata)
 values(auth.uid(),branch,module_code,TG_OP,TG_TABLE_NAME,
  coalesce(after_row->>'id',before_row->>'id')::uuid,
  coalesce(after_row->>'audit_id',before_row->>'audit_id',after_row->>'job_role_id',before_row->>'job_role_id'),
  (select coalesce(jsonb_object_agg(key,value),'{}'::jsonb) from jsonb_each(before_row)
   where key in ('id','audit_id','criterion_id','responsible_auditor_id','result','tested_at','job_role_id','competency_id','required_level','mandatory')),
  (select coalesce(jsonb_object_agg(key,value),'{}'::jsonb) from jsonb_each(after_row)
   where key in ('id','audit_id','criterion_id','responsible_auditor_id','result','tested_at','job_role_id','competency_id','required_level','mandatory')),
  jsonb_build_object('changed_fields',changed,'redacted',true));
 if TG_OP='DELETE' then return OLD;end if;return NEW;
end $audit$;
revoke all on function private.audit_quality_configuration_change() from public,anon,authenticated;
create trigger audit_plan_criteria_change after insert or update or delete on public.audit_plan_criteria
 for each row execute function private.audit_quality_configuration_change();
create trigger job_role_competencies_change after insert or update or delete on public.job_role_competencies
 for each row execute function private.audit_quality_configuration_change();
notify pgrst,'reload schema';
commit;
