-- Honor explicit role assignments at each branch, preserving existing legacy scopes.
begin;
create or replace function public.can_access_branch(target_branch uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.profiles where id=auth.uid() and active)
 and (public.has_role('SUPER_USUARIO')
 or exists(select 1 from public.user_roles where user_id=auth.uid() and branch_id=target_branch)
 or private.legacy_can_access_branch(target_branch));
$$;
revoke all on function public.can_access_branch(uuid) from public,anon;
grant execute on function public.can_access_branch(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
