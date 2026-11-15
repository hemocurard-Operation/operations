begin;
insert into public.app_permissions(permission_code,module,description)
values('WORKSPACE_PREVIEW_VIEW','ADMINISTRACION','Consultar áreas y permisos de otros usuarios, sin asumir su identidad')
on conflict(permission_code) do nothing;
insert into public.role_permissions(role_id,permission_code)
select id,'WORKSPACE_PREVIEW_VIEW' from public.roles where code in ('ADMIN','SUPER_USUARIO') on conflict do nothing;
insert into public.app_module_catalog(route_key,title,group_name,permission_code)
values('userworkspaces','Pantallas por usuario','ADMINISTRACIÓN','WORKSPACE_PREVIEW_VIEW') on conflict(route_key) do nothing;
insert into public.role_module_access(role_id,route_key,enabled)
select id,'userworkspaces',code in ('ADMIN','SUPER_USUARIO') from public.roles on conflict do nothing;

create table public.workspace_preview_access_log(
 id bigint generated always as identity primary key,
 actor_id uuid not null references public.profiles(id),
 target_id uuid references public.profiles(id),
 accessed_at timestamptz not null default now()
);
alter table public.workspace_preview_access_log enable row level security;
revoke all on public.workspace_preview_access_log from public,anon,authenticated;
grant select on public.workspace_preview_access_log to authenticated;
create policy workspace_preview_log_read on public.workspace_preview_access_log for select to authenticated
using(public.has_permission('ACCESS_ADMIN'));

-- Only permission metadata; no auth.users, credentials, session substitution or target records.
create function public.admin_workspace_preview(p_target uuid default null,p_search text default '',p_offset integer default 0)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
 if not public.has_permission('WORKSPACE_PREVIEW_VIEW') or
    not (public.has_role('ADMIN') or public.has_role('SUPER_USUARIO')) then
  raise exception 'Administrador activo y permiso de consulta requeridos' using errcode='42501';
 end if;
 if p_offset<0 or p_offset>100000 or length(coalesce(p_search,''))>100 then
  raise exception 'Consulta fuera de límites' using errcode='22023';
 end if;
 if p_target is not null and not exists(select 1 from public.profiles where id=p_target) then
  raise exception 'Usuario no disponible' using errcode='P0002';
 end if;
 with page as (
  select p.id,p.full_name,p.active from public.profiles p
  where coalesce(p.full_name,'') ilike '%'||coalesce(p_search,'')||'%'
  order by p.full_name nulls last,p.id limit 50 offset p_offset
 ), selected as (
  select * from page union
  select p.id,p.full_name,p.active from public.profiles p where p.id=p_target
 ), users as (
  select p.*,coalesce((select jsonb_agg(jsonb_build_object(
   'role_id',r.id,'role_code',r.code,'role_name',r.name,
   'branch_id',ur.branch_id,'branch_name',b.name) order by r.code,ur.branch_id)
   from public.user_roles ur join public.roles r on r.id=ur.role_id
   left join public.branches b on b.id=ur.branch_id where ur.user_id=p.id),'[]'::jsonb) as roles
  from selected p
 )
 select jsonb_build_object('caller_user_id',auth.uid(),
  'users',coalesce((select jsonb_agg(to_jsonb(u) order by u.full_name nulls last,u.id) from users u),'[]'::jsonb),
  'has_more',(select count(*)>p_offset+50 from public.profiles where coalesce(full_name,'') ilike '%'||coalesce(p_search,'')||'%'),
  'catalog',coalesce((select jsonb_agg(jsonb_build_object('route_key',route_key,'title',title,'group_name',group_name,'permission_code',permission_code,'active',active)) from public.app_module_catalog),'[]'::jsonb),
  'settings',coalesce((select jsonb_agg(jsonb_build_object('role_id',role_id,'route_key',route_key,'enabled',enabled)) from public.role_module_access),'[]'::jsonb),
  'permissions',coalesce((select jsonb_agg(jsonb_build_object('permission_code',permission_code,'active',active)) from public.app_permissions),'[]'::jsonb),
  'rolePermissions',coalesce((select jsonb_agg(jsonb_build_object('role_id',role_id,'permission_code',permission_code)) from public.role_permissions),'[]'::jsonb)
 ) into result;
 insert into public.workspace_preview_access_log(actor_id,target_id) values(auth.uid(),p_target);
 return result;
end;$$;
revoke all on function public.admin_workspace_preview(uuid,text,integer) from public,anon;
grant execute on function public.admin_workspace_preview(uuid,text,integer) to authenticated;
notify pgrst,'reload schema';
commit;
