begin;
-- Physical quantities only. Invoker views retain the existing table RLS.
-- A header without detail remains visible as missing quantity, not a fabricated zero.
create view public.vw_sales_unit_report with(security_invoker=true) as
select s.id as sale_id,s.sale_code,s.sale_date,s.branch_id,s.customer_id,
 coalesce(nullif(btrim(s.customer_name),''),nullif(btrim(s.destination_center),''),'Centro no registrado') as center_name,
 coalesce(nullif(s.shift,''),'SIN_TURNO') as shift,s.status,
 l.id as line_id,l.component_name,l.abo,l.rh,l.quantity
from public.operational_sales s
left join public.operational_sale_lines l on l.sale_id=s.id
where s.status not in ('CANCELADA','ANULADA');
revoke all on public.vw_sales_unit_report from public,anon;
grant select on public.vw_sales_unit_report to authenticated;
create view public.vw_performed_session_report with(security_invoker=true) as
select id,branch_id,operational_date,shift,status from public.hyperbaric_sessions where status='REALIZADA';
revoke all on public.vw_performed_session_report from public,anon;
grant select on public.vw_performed_session_report to authenticated;
update public.app_module_catalog set title='Ventas en unidades' where route_key='economics';
update public.app_module_catalog set title='Unidades por centro' where route_key='collections';
update public.app_module_catalog set title='Unidades por turno' where route_key='shiftreport';
notify pgrst,'reload schema';
commit;
