-- Test-only catalog and authorizations. Never apply this fixture to a hosted database.
create table public.app_permissions(permission_code text primary key,module text,description text,risk_level text,active boolean default true);
create table public.roles(id uuid primary key default gen_random_uuid(),code text unique,name text);
create table public.role_permissions(role_id uuid,permission_code text,primary key(role_id,permission_code));
insert into roles(code,name) values('SUPER_USUARIO','Super Usuario'),('ASISTENTE_OPERACIONES','Asistente'),('ENCARGADA_LABORATORIO','Laboratorio');
insert into test_permissions(actor,permission) select 'e2000000-0000-0000-0000-000000000001',unnest(array['ORDER_PLAN_VIEW','ORDER_PLAN_WRITE','DONOR_AGENDA_CONFIG']);
insert into test_permissions(actor,permission) values('e2000000-0000-0000-0000-000000000002','ORDER_PLAN_VIEW');
insert into test_permissions(actor,permission) select 'e2000000-0000-0000-0000-000000000003',unnest(array['ORDER_PLAN_VIEW','ORDER_PLAN_WRITE','DONOR_AGENDA_CONFIG','DONORS_WRITE']);
update donors set full_name='Donante sintético',phone='8095550101';
insert into donors(id,donor_code,branch_id,full_name) values('e3000000-0000-0000-0000-000000000003','D-THIRD','e1000000-0000-0000-0000-000000000001','Tercer donante sintético'),('e3000000-0000-0000-0000-000000000004','D-FOURTH','e1000000-0000-0000-0000-000000000002','Donante de otra sucursal');
insert into donations(donor_id,donation_date,branch_id) values('e3000000-0000-0000-0000-000000000001',current_date-10,'e1000000-0000-0000-0000-000000000001');
grant select on public.app_permissions,public.roles,public.role_permissions to authenticated;

grant select on public.workflow_audit to authenticated;
