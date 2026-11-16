begin;
alter table public.commercial_opportunities
 add column target_units numeric(14,3) check(target_units>0 and target_units::text not in ('NaN','Infinity','-Infinity')),
 add column target_date date,
 add column hyperbaric_session_id uuid references public.hyperbaric_sessions(id);
alter table public.commercial_opportunities drop constraint wf_opportunity_evidence;
alter table public.commercial_opportunities add constraint wf_opportunity_evidence
 check(service_type in ('SANGRE','CAMARA_HIPERBARICA') and (stage<>'GANADA' or sale_id is not null or hyperbaric_charge_id is not null or hyperbaric_session_id is not null));
create or replace view public.vw_performed_session_report with(security_invoker=true) as
select s.id,s.branch_id,s.operational_date,s.shift,s.status,a.customer_id
from public.hyperbaric_sessions s left join public.hyperbaric_appointments a on a.id=s.appointment_id and a.branch_id=s.branch_id
where s.status='REALIZADA';
revoke all on public.vw_performed_session_report from public,anon;
grant select on public.vw_performed_session_report to authenticated;
create or replace function public.wf_save_opportunity(p_branch uuid,p_id uuid,p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare result uuid; customer uuid; new_stage text; sale uuid; service text; charge uuid; session uuid; prior public.commercial_opportunities%rowtype; units numeric; due date;
begin
 if auth.uid() is null or not public.wf_active_actor() then raise exception 'Usuario activo requerido' using errcode='42501';end if;
 perform public.wf_require('COMMERCIAL_WRITE',p_branch);
 customer:=(p_data->>'customer_id')::uuid;new_stage:=p_data->>'stage';sale:=nullif(p_data->>'sale_id','')::uuid;service:=coalesce(p_data->>'service_type','SANGRE');charge:=nullif(p_data->>'hyperbaric_charge_id','')::uuid;session:=nullif(p_data->>'hyperbaric_session_id','')::uuid;
 if service not in ('SANGRE','CAMARA_HIPERBARICA') or (service='CAMARA_HIPERBARICA' and sale is not null) or (service='SANGRE' and (charge is not null or session is not null)) then raise exception 'Una oportunidad tiene un único tipo de evidencia operativa';end if;
 if not exists(select 1 from public.customers where id=customer and active) or nullif(btrim(p_data->>'title'),'') is null then raise exception 'Centro y título requeridos';end if;
 if p_id is not null then
  select * into prior from public.commercial_opportunities where id=p_id and branch_id=p_branch and customer_id=customer and (owner_id=auth.uid() or public.has_permission('ACCESS_ADMIN')) for update;
  if not found then raise exception 'Oportunidad no accesible' using errcode='42501';end if;
 end if;
 units:=case when p_data?'target_units' then nullif(p_data->>'target_units','')::numeric else prior.target_units end;
 due:=case when p_data?'target_date' then nullif(p_data->>'target_date','')::date else prior.target_date end;
 if units is not null and (units<=0 or units::text in ('NaN','Infinity','-Infinity')) then raise exception 'Cantidad prevista debe ser positiva';end if;
 if (new_stage='GANADA' and service='SANGRE' or sale is not null) and not exists(
  select 1 from public.operational_sales s where s.id=sale and s.branch_id=p_branch and s.customer_id=customer and s.status in ('DESPACHADA','FACTURADA','COBRADA')
  and exists(select 1 from public.operational_sale_lines l where l.sale_id=s.id and l.quantity>0)) then raise exception 'Entrega con unidades del mismo centro y sucursal requerida';end if;
 -- Legacy charge references stay valid only when backed by a performed session.
 if charge is not null and not exists(select 1 from public.hyperbaric_charges c join public.hyperbaric_sessions s on s.id=c.session_id
  where c.id=charge and c.branch_id=p_branch and c.customer_id=customer and c.status<>'ANULADA' and s.branch_id=p_branch and s.status='REALIZADA' and (session is null or session=s.id)) then raise exception 'Evidencia histórica de sesión no válida';end if;
 if ((new_stage='GANADA' and service='CAMARA_HIPERBARICA' and charge is null) or session is not null) and not exists(
  select 1 from public.hyperbaric_sessions s join public.hyperbaric_appointments a on a.id=s.appointment_id
  where s.id=session and s.branch_id=p_branch and a.branch_id=p_branch and a.customer_id=customer and s.status='REALIZADA') then raise exception 'Sesión realizada del mismo centro y sucursal requerida';end if;
 if p_id is null then
  insert into public.commercial_opportunities(branch_id,customer_id,owner_id,title,stage,currency,estimated_amount,sale_id,loss_reason,service_type,hyperbaric_charge_id,hyperbaric_session_id,target_units,target_date)
  values(p_branch,customer,auth.uid(),btrim(p_data->>'title'),new_stage,'DOP',0,sale,p_data->>'loss_reason',service,charge,session,units,due) returning id into result;
 else
  update public.commercial_opportunities set title=btrim(p_data->>'title'),stage=new_stage,sale_id=sale,loss_reason=p_data->>'loss_reason',service_type=service,hyperbaric_charge_id=charge,hyperbaric_session_id=session,target_units=units,target_date=due where id=p_id returning id into result;
 end if;
 return result;
end $$;
revoke execute on function public.wf_save_opportunity(uuid,uuid,jsonb) from public,anon;
grant execute on function public.wf_save_opportunity(uuid,uuid,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
