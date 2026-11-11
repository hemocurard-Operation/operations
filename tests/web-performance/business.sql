-- Synthetic rows in disposable PostgreSQL only.
insert into public.donors(donor_code,branch_id,full_name,cedula,abo,rh,registration_date)
 select 'PERF-'||i,'e1000000-0000-0000-0000-000000000001','Rendimiento '||lpad(i::text,3,'0'),lpad(i::text,11,'0'),case when i%2=0 then 'O' else 'A' end,case when i%2=0 then 'POSITIVO' else 'NEGATIVO' end,'2026-11-01' from generate_series(1,62) i;
insert into public.donors(donor_code,branch_id,full_name,cedula,abo,rh,registration_date)
 values('PERF-OTHER','e1000000-0000-0000-0000-000000000002','Rendimiento reservado','99999999999','O','POSITIVO','2026-11-01');
set role authenticated;
select set_config('test.actor','e2000000-0000-0000-0000-000000000001',false);
do $$declare page jsonb;focus uuid;begin
 page:=public.donor_search_page(p_search=>'Rendimiento');
 if (page->>'total')::int<>62 or jsonb_array_length(page->'rows')<>25 then raise exception 'Pagination total or size incorrect';end if;
 if (page->'rows'->0) ? 'observations' or (page->'rows'->0) ? 'birth_date' then raise exception 'Summary leaked detail columns';end if;
 raise notice 'PASS initial page is bounded with exact authorized total and explicit columns';
 if (public.donor_search_page(p_search=>'Rendimiento',p_offset=>25)->>'offset')::int<>25 then raise exception 'Next page wrong';end if;
 if jsonb_array_length(public.donor_search_page(p_search=>'Rendimiento',p_offset=>50)->'rows')<>12 then raise exception 'Last page wrong';end if;
 raise notice 'PASS successive pages cover final records';
 select id into focus from public.donors where donor_code='PERF-62';
 page:=public.donor_search_page(p_search=>'Rendimiento',p_focus=>focus);
 if not exists(select 1 from jsonb_array_elements(page->'rows') r where r->>'id'=focus::text) then raise exception 'Focus not returned';end if;
 raise notice 'PASS focus opens the correct page for agenda or saved profile';
 if (public.donor_search_page(p_search=>'000-0000030')->>'total')::int<>1 then raise exception 'Formatted identity lookup failed';end if;
 if (public.donor_search_page(p_search=>'Rendimiento',p_group=>'O+')->>'total')::int<>31 then raise exception 'Blood group filter wrong';end if;
 if (public.donor_search_page(p_search=>'Rendimiento',p_group=>'Pendiente')->>'total')::int<>0 then raise exception 'Pending filter wrong';end if;
 raise notice 'PASS identity and blood group filters run on the complete authorized dataset';
 if (public.donor_search_page(p_search=>$q$%') OR true --$q$)->>'total')::int<>0 then raise exception 'Search interpolation vulnerability';end if;
 raise notice 'PASS search is literal without SQL or filter interpolation';
 begin perform public.donor_search_page(p_limit=>101);raise exception 'Limit accepted';exception when invalid_parameter_value then null;end;
 begin perform public.donor_search_page(p_offset=>-1);raise exception 'Offset accepted';exception when invalid_parameter_value then null;end;
 begin perform public.donor_search_page(p_group=>'INVALID');raise exception 'Group accepted';exception when invalid_parameter_value then null;end;
 raise notice 'PASS input bounds and filters rejected';
 begin perform public.donor_search_page(p_branch=>'e1000000-0000-0000-0000-000000000002');raise exception 'Other branch accepted';exception when insufficient_privilege then null;end;
 if (public.donor_search_page(p_search=>'reservado')->>'total')::int<>0 then raise exception 'RLS bypass';end if;
 raise notice 'PASS explicit branch and cross-branch RLS isolation';
 if has_function_privilege('anon','public.donor_search_page(uuid,text,text,integer,integer,uuid)','EXECUTE') then raise exception 'Anonymous callable';end if;
 raise notice 'PASS anonymous execute revoked';
end$$;
select set_config('test.actor','e2000000-0000-0000-0000-000000000003',false);
do $$begin
 begin perform public.donor_search_page();raise exception 'Inactive accepted';exception when insufficient_privilege then null;end;
 raise notice 'PASS inactive actors rejected';
end$$;
reset role;
delete from public.test_permissions where actor='e2000000-0000-0000-0000-000000000002' and permission='DONORS_VIEW';
set role authenticated;
select set_config('test.actor','e2000000-0000-0000-0000-000000000002',false);
do $$begin
 begin perform public.donor_search_page();raise exception 'Missing permission accepted';exception when insufficient_privilege then null;end;
 raise notice 'PASS missing donor permission rejected';
end$$;
