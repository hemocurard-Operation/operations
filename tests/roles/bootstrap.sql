create role anon;create role authenticated;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
create function auth.role() returns text language sql stable as $$select coalesce(nullif(current_setting('test.role',true),''),'service_role')$$;
create table profiles(id uuid primary key,branch_id uuid,active boolean);
create table roles(id uuid primary key,code text unique,name text);
create table user_roles(user_id uuid,role_id uuid,branch_id uuid,primary key(user_id,role_id,branch_id));
create table app_permissions(permission_code text primary key,module text,risk_level text,active boolean);
create table role_permissions(role_id uuid,permission_code text,primary key(role_id,permission_code));
create function public.has_role(role_code text) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from user_roles u join roles r on r.id=u.role_id where u.user_id=auth.uid() and r.code=role_code)$$;
create function public.can_access_branch(target_branch uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from user_roles where user_id=auth.uid() and branch_id=target_branch)$$;
create function public.has_permission(p_permission_code text) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from user_roles u join role_permissions r on r.role_id=u.role_id where u.user_id=auth.uid() and r.permission_code=p_permission_code)$$;
-- Existing protected role-change trigger is a deployment prerequisite; Edge tests cover its RPC boundary separately.
create function public.guard_user_role_changes() returns trigger language plpgsql as $$begin return new;end$$;
insert into profiles values('10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',true),('10000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001',true);
insert into roles values('20000000-0000-0000-0000-000000000001','SUPER_USUARIO','Super Usuario'),('20000000-0000-0000-0000-000000000002','ADMIN','Administrador');
insert into user_roles select p.id,r.id,p.branch_id from profiles p join roles r on right(p.id::text,1)=right(r.id::text,1);
insert into app_permissions values('ACCESS_ADMIN','USERS','CRITICO',true),('DONORS_VIEW','DONORS','NORMAL',true),('TRAINING_ADMIN','TRAINING','NORMAL',true),('DISABLED','X','NORMAL',false);
insert into role_permissions values('20000000-0000-0000-0000-000000000002','ACCESS_ADMIN'),('20000000-0000-0000-0000-000000000002','DONORS_VIEW');
grant usage on schema auth,public to authenticated,anon;
grant select on profiles,roles,user_roles,app_permissions,role_permissions to authenticated;
grant insert,update,delete on app_permissions,role_permissions to authenticated;
alter table app_permissions enable row level security;alter table role_permissions enable row level security;
create policy app_permissions_read on app_permissions for select to authenticated using(true);
create policy role_permissions_read on role_permissions for select to authenticated using(true);
create function public.test_assert(label text,ok boolean) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;

create table audit_events(id uuid default gen_random_uuid(),user_id uuid,action text,entity_id uuid);
create function public.log_audit_event(text,text,uuid,text,uuid,text,jsonb,jsonb,jsonb) returns uuid language plpgsql security definer as $$declare result uuid:=gen_random_uuid();begin insert into public.audit_events values(result,auth.uid(),$2,$5);return result;end$$;
