-- Isolated authorization fixture only. Never run against a hosted project.
create role anon;create role authenticated;create schema auth;create schema private;
revoke all on schema private from public,anon,authenticated;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
create table profiles(id uuid primary key,active boolean not null);
create table roles(id uuid primary key default gen_random_uuid(),code text unique,name text);
create table user_roles(user_id uuid references profiles(id),role_id uuid references roles(id),primary key(user_id,role_id));
create table app_permissions(permission_code text primary key,active boolean default true);
create table role_permissions(role_id uuid references roles(id),permission_code text references app_permissions(permission_code),primary key(role_id,permission_code));
create function public.has_role(c text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$select exists(select 1 from user_roles ur join roles r on r.id=ur.role_id where ur.user_id=auth.uid() and r.code=c)$$;
create function public.wf_active_actor() returns boolean language sql stable security definer set search_path=public,pg_temp as $$select exists(select 1 from profiles where id=auth.uid() and active)$$;
create function public.has_permission(c text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$select wf_active_actor() and exists(select 1 from app_permissions p where p.permission_code=c and p.active and (has_role('SUPER_USUARIO') or (c<>'ACCESS_ADMIN' and exists(select 1 from user_roles ur join role_permissions rp on rp.role_id=ur.role_id where ur.user_id=auth.uid() and rp.permission_code=c))))$$;
alter table user_roles enable row level security;
create policy self_roles on user_roles for select to authenticated using(user_id=(select auth.uid()) or (select has_role('SUPER_USUARIO')));
grant usage on schema auth,public to authenticated,anon;
grant select on user_roles,roles,role_permissions to authenticated;
insert into profiles values('e2000000-0000-0000-0000-000000000001',true),('e2000000-0000-0000-0000-000000000002',true),('e2000000-0000-0000-0000-000000000003',false),('e2000000-0000-0000-0000-000000000004',true),('e2000000-0000-0000-0000-000000000005',true),('e2000000-0000-0000-0000-000000000006',true);
