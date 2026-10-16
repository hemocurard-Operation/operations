-- Disposable fixture only, with the real existing procurement schema loaded next.
create function auth.role() returns text language sql stable as $$select current_user::text$$;
create table nonconformities(id uuid primary key);create table capa(id uuid primary key);
create table app_migrations(migration_code text primary key,version text,description text,applied_by uuid,applied_at timestamptz default now());
create table app_permissions(permission_code text primary key,module text,description text,risk_level text,active boolean default true);
create table roles(id uuid primary key default gen_random_uuid(),code text,name text);
create table role_permissions(role_id uuid,permission_code text,primary key(role_id,permission_code));
insert into roles(code) values('SUPER_USUARIO'),('ADMIN'),('GERENCIA_OPERATIVA'),('ASISTENTE_OPERACIONES'),('INVENTARIO'),('CALIDAD');
insert into test_permissions select 'e2000000-0000-0000-0000-000000000001',unnest(array['PURCHASE_VIEW','PURCHASE_WRITE','PURCHASE_APPROVE','PURCHASE_RECEIVE']);
insert into test_permissions select 'e2000000-0000-0000-0000-000000000002',unnest(array['PURCHASE_VIEW']);
insert into test_permissions select 'e2000000-0000-0000-0000-000000000003',unnest(array['PURCHASE_VIEW','PURCHASE_WRITE','PURCHASE_RECEIVE']);
grant select on workflow_audit to authenticated;
