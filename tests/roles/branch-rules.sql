insert into user_roles values('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002');
set role authenticated;
select set_config('test.role','authenticated',false);
select set_config('test.actor','10000000-0000-0000-0000-000000000002',false);
select test_assert('explicit second branch is accessible',can_access_branch('30000000-0000-0000-0000-000000000002'));
select test_assert('unassigned third branch remains blocked',not can_access_branch('30000000-0000-0000-0000-000000000003'));
select test_assert('additional branch does not grant account administration',not has_permission('ACCESS_ADMIN'));
reset role;
select set_config('test.role','service_role',false);
