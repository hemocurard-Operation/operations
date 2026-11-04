-- Synthetic identities for the existing procurement suite against REAL RBAC helpers.
-- This is prefixed to the suite inside a transaction; never deployed.
begin;
insert into branches(id,code,name) values
 ('e1000000-0000-0000-0000-000000000001','PUR-TEST-A','Compras prueba A'),
 ('e1000000-0000-0000-0000-000000000002','PUR-TEST-B','Compras prueba B');
insert into auth.users(id,email) values
 ('e2000000-0000-0000-0000-000000000001','purchase-write@example.invalid'),
 ('e2000000-0000-0000-0000-000000000002','purchase-read@example.invalid'),
 ('e2000000-0000-0000-0000-000000000003','purchase-inactive@example.invalid');
insert into profiles(id,full_name,active,branch_id) select id,'Compras prueba',id<>'e2000000-0000-0000-0000-000000000003'::uuid,'e1000000-0000-0000-0000-000000000001'::uuid from auth.users where email like 'purchase-%@example.invalid';
insert into roles(code,name) values('PUR_TEST_WRITE','Compras escritura prueba'),('PUR_TEST_READ','Compras lectura prueba');
insert into role_permissions(role_id,permission_code) select r.id,p.permission_code from roles r cross join app_permissions p where r.code='PUR_TEST_WRITE' and p.permission_code in ('PURCHASE_VIEW','PURCHASE_WRITE','PURCHASE_APPROVE','PURCHASE_RECEIVE');
insert into role_permissions(role_id,permission_code) select id,'PURCHASE_VIEW' from roles where code='PUR_TEST_READ';
insert into user_roles(user_id,role_id,branch_id) select v.id,r.id,'e1000000-0000-0000-0000-000000000001'::uuid from (values
 ('e2000000-0000-0000-0000-000000000001'::uuid,'PUR_TEST_WRITE'),
 ('e2000000-0000-0000-0000-000000000002'::uuid,'PUR_TEST_READ'),
 ('e2000000-0000-0000-0000-000000000003'::uuid,'PUR_TEST_WRITE')) v(id,code) join roles r on r.code=v.code;
