begin;
alter table public.commercial_goals add column product_id uuid references public.products(id),add column component_name text;
alter table public.commercial_goals drop constraint commercial_goals_metric_check;
alter table public.commercial_goals add constraint commercial_goals_metric_check check(metric in ('VISITAS_COMPLETADAS','VISITAS_EDUCATIVAS','REFERIDOS_NUEVOS','DONANTES_CAPTADOS','VENTAS_UNIDADES','SESIONES_REALIZADAS','OPORTUNIDADES_ABIERTAS','OPORTUNIDADES_GANADAS','CLIENTES_ACTIVOS','TASA_CONVERSION_PCT'));
alter table public.commercial_goals add constraint commercial_goals_product_scope check((product_id is null or component_name is null) and (component_name is null or length(btrim(component_name)) between 1 and 200) and (metric='VENTAS_UNIDADES' or (product_id is null and component_name is null)));
alter table public.commercial_goals add constraint commercial_goals_finite_target check(target_value::text not in ('NaN','Infinity','-Infinity'));
drop index public.commercial_goals_scope;
create unique index commercial_goals_scope on public.commercial_goals(period_start,period_end,coalesce(branch_id,'00000000-0000-0000-0000-000000000000'::uuid),coalesce(agent_id,'00000000-0000-0000-0000-000000000000'::uuid),coalesce(service_id,'00000000-0000-0000-0000-000000000000'::uuid),metric,coalesce(product_id,'00000000-0000-0000-0000-000000000000'::uuid),coalesce(component_name,''));
create function public.guard_commercial_goal_units() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
begin
 -- Database-owner migrations remain possible; application callers always need an active actor.
 if current_user in ('postgres','supabase_admin') and auth.uid() is null then return new;end if;
 if auth.uid() is null or not public.wf_active_actor() or not public.has_permission('COMMERCIAL_WRITE') then raise exception 'Usuario comercial activo requerido' using errcode='42501';end if;
 if new.service_id is not null and new.metric in ('VENTAS_UNIDADES','SESIONES_REALIZADAS') and not exists(select 1 from public.crm_services where id=new.service_id and active and code=case new.metric when 'VENTAS_UNIDADES' then 'SANGRE' else 'CAMARA_HIPERBARICA' end) then raise exception 'El servicio no corresponde a la unidad de medida de la meta' using errcode='23514';end if;
 if new.product_id is not null and not exists(select 1 from public.products where id=new.product_id and active) then raise exception 'Producto activo requerido' using errcode='23514';end if;
 if tg_op='INSERT' then
  if new.approved_by is not null or new.approved_at is not null then raise exception 'Cree la meta como borrador antes de aprobarla' using errcode='42501';end if;
  new.created_by:=auth.uid();new.currency:=null;new.revision:=1;
 else
  new.created_by:=old.created_by;new.created_at:=old.created_at;new.currency:=old.currency;
  if (new.approved_by,new.approved_at) is distinct from (old.approved_by,old.approved_at) then
   if not public.has_permission('ACCESS_ADMIN') or new.approved_by is distinct from auth.uid() or new.approved_at is null then raise exception 'Aprobación administrativa con actor y evidencia de fecha requerida' using errcode='42501';end if;
   new.approved_at:=now();
  end if;
  if (new.period_start,new.period_end,new.branch_id,new.agent_id,new.service_id,new.metric,new.target_value,new.product_id,new.component_name) is distinct from (old.period_start,old.period_end,old.branch_id,old.agent_id,old.service_id,old.metric,old.target_value,old.product_id,old.component_name) then new.approved_by:=null;new.approved_at:=null;end if;
  new.revision:=old.revision+1;
 end if;
 new.updated_at:=now();return new;
end$$;
revoke execute on function public.guard_commercial_goal_units() from public,anon,authenticated;
create trigger commercial_goals_units_guard before insert or update on public.commercial_goals for each row execute function public.guard_commercial_goal_units();
create trigger commercial_goals_units_audit after insert or update on public.commercial_goals for each row when (auth.uid() is not null) execute function public.wf_audit_change();
create function public.approve_commercial_goal(p_goal uuid) returns uuid language plpgsql security invoker set search_path=public,pg_temp as $$
declare g public.commercial_goals%rowtype;
begin
 if auth.uid() is null or not public.wf_active_actor() or not public.has_permission('ACCESS_ADMIN') or not public.has_permission('COMMERCIAL_WRITE') then raise exception 'Aprobador administrativo activo requerido' using errcode='42501';end if;
 select * into g from public.commercial_goals where id=p_goal for update;
 if not found or (g.branch_id is null and not public.has_role('SUPER_USUARIO')) or (g.branch_id is not null and not public.can_access_branch(g.branch_id)) then raise exception 'Meta no accesible' using errcode='42501';end if;
 if g.approved_by is not null and g.approved_at is not null then return g.id;end if;
 update public.commercial_goals set approved_by=auth.uid(),approved_at=now() where id=g.id;
 perform public.log_audit_event('COMMERCIAL','APPROVE_GOAL',g.branch_id,'commercial_goals',g.id,g.metric,to_jsonb(g),jsonb_build_object('approved_by',auth.uid(),'approved_at',now(),'target_value',g.target_value),null);
 return g.id;
end$$;
revoke execute on function public.approve_commercial_goal(uuid) from public,anon;
grant execute on function public.approve_commercial_goal(uuid) to authenticated;
create or replace view public.vw_commercial_goal_progress with(security_invoker=true) as
select g.id as goal_id,g.period_start,g.period_end,g.branch_id,g.agent_id,g.service_id,g.metric,g.target_value,
 case when g.metric in ('VENTAS_UNIDADES','SESIONES_REALIZADAS') then null::bigint else progress.actual_quantity::bigint end as actual_value,
 g.approved_by,g.approved_at,g.product_id,g.component_name,progress.actual_quantity
from public.commercial_goals g
cross join lateral (select case g.metric
 when 'VENTAS_UNIDADES' then case when g.agent_id is not null or not (public.has_permission('SALES_VIEW') or public.has_permission('ECONOMICS_VIEW') or public.has_permission('CUSTOMER_VIEW')) then null else (
  select coalesce(sum(l.quantity),0) from public.operational_sales s join public.operational_sale_lines l on l.sale_id=s.id
  where s.status in ('DESPACHADA','FACTURADA','COBRADA') and s.sale_date between g.period_start and g.period_end
  and (g.branch_id is null or s.branch_id=g.branch_id) and (g.product_id is null or l.product_id=g.product_id) and (g.component_name is null or l.component_name=g.component_name)
  and (g.service_id is null or exists(select 1 from public.crm_services cs where cs.id=g.service_id and cs.code='SANGRE'))
 ) end
 when 'SESIONES_REALIZADAS' then case when g.agent_id is not null or not public.has_permission('HYPERBARIC_VIEW') then null else (
  select count(*) from public.hyperbaric_sessions s where s.status='REALIZADA' and s.operational_date between g.period_start and g.period_end
  and (g.branch_id is null or s.branch_id=g.branch_id) and (g.service_id is null or exists(select 1 from public.crm_services cs where cs.id=g.service_id and cs.code='CAMARA_HIPERBARICA'))
 ) end
 when 'VISITAS_COMPLETADAS' then case when g.service_id is not null then null else (
  select count(*) from public.commercial_visits v where v.status='REALIZADA' and (v.scheduled_at at time zone 'America/Santo_Domingo')::date between g.period_start and g.period_end and (g.branch_id is null or v.branch_id=g.branch_id) and (g.agent_id is null or v.agent_id=g.agent_id)
 ) end
 when 'VISITAS_EDUCATIVAS' then case when g.service_id is not null then null else (
  select count(*) from public.commercial_visits v where v.status='REALIZADA' and v.purpose_type='EDUCACION_INSTITUCIONAL' and (v.scheduled_at at time zone 'America/Santo_Domingo')::date between g.period_start and g.period_end and (g.branch_id is null or v.branch_id=g.branch_id) and (g.agent_id is null or v.agent_id=g.agent_id)
 ) end
 when 'OPORTUNIDADES_GANADAS' then (
  select count(*) from public.commercial_opportunities o where o.stage='GANADA' and (o.created_at at time zone 'America/Santo_Domingo')::date between g.period_start and g.period_end and (g.branch_id is null or o.branch_id=g.branch_id) and (g.agent_id is null or o.owner_id=g.agent_id) and (g.service_id is null or exists(select 1 from public.crm_services cs where cs.id=g.service_id and cs.code=o.service_type))
 ) else null end as actual_quantity) progress;
revoke all on public.vw_commercial_goal_progress from public,anon;
grant select on public.vw_commercial_goal_progress to authenticated;
notify pgrst,'reload schema';
commit;
