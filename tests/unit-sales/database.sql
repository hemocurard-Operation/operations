begin;
create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
select pg_temp.ok((select bool_and('security_invoker=true'=any(reloptions)) from pg_class where oid in ('public.vw_sales_unit_report'::regclass,'public.vw_performed_session_report'::regclass)),'unit report views retain invoker RLS');
select pg_temp.ok(not has_table_privilege('anon','public.vw_sales_unit_report','select') and not has_table_privilege('anon','public.vw_performed_session_report','select'),'anonymous reports denied');
select pg_temp.ok(has_table_privilege('authenticated','public.vw_sales_unit_report','select'),'authenticated report accessible within table policies');
select pg_temp.ok(not exists(select 1 from information_schema.columns where table_schema='public' and table_name in ('vw_sales_unit_report','vw_performed_session_report') and column_name ~ '(amount|price|cost|paid|patient|invoice|balance)'),'report exposes neither money nor patient columns');
select pg_temp.ok((select relrowsecurity from pg_class where oid='public.operational_sales'::regclass) and (select relrowsecurity from pg_class where oid='public.operational_sale_lines'::regclass),'source sales RLS remains enabled');
select pg_temp.ok(position('quantity' in pg_get_viewdef('public.vw_sales_unit_report'::regclass))>0 and position('CANCELADA' in pg_get_viewdef('public.vw_sales_unit_report'::regclass))>0,'view uses physical quantities and excludes cancelled sales');
rollback;
