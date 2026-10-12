-- HemoCura Training Native 1.1: governed job assignment used by Training Admin.
create or replace function public.training_assign_job_role(p_user_id uuid,p_job_role_id uuid,p_branch_id uuid,p_primary_role boolean default true,p_start_date date default current_date)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_id uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.has_permission('TRAINING_ADMIN') then raise exception 'TRAINING_ADMIN_REQUIRED'; end if;
  if p_user_id is null or p_job_role_id is null or p_branch_id is null then raise exception 'TRAINING_JOB_ASSIGNMENT_FIELDS_REQUIRED'; end if;
  if p_primary_role then
    update public.staff_job_assignments set primary_role=false,updated_at=now() where user_id=p_user_id and active and primary_role;
  end if;
  insert into public.staff_job_assignments(user_id,job_role_id,branch_id,start_date,active,primary_role)
  values(p_user_id,p_job_role_id,p_branch_id,coalesce(p_start_date,current_date),true,p_primary_role)
  on conflict(user_id,job_role_id,branch_id,start_date) do update set active=true,primary_role=excluded.primary_role,end_date=null,updated_at=now()
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.training_assign_job_role(uuid,uuid,uuid,boolean,date) from public,anon;
grant execute on function public.training_assign_job_role(uuid,uuid,uuid,boolean,date) to authenticated;
