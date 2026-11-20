begin;
create table public.operational_blood_counts(
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),
 component_name text not null check(component_name in ('SANGRE_TOTAL','CONCENTRADO_HEMATIES','PLASMA_FRESCO_CONGELADO','PLAQUETAS','CRIOPRECIPITADO')),
 group_code text not null check(group_code in ('PENDIENTE','A|POSITIVO','A|NEGATIVO','B|POSITIVO','B|NEGATIVO','AB|POSITIVO','AB|NEGATIVO','O|POSITIVO','O|NEGATIVO')),
 available_units integer not null check(available_units between 0 and 1000000),
 quarantine_units integer not null check(quarantine_units between 0 and 1000000),
 reserved_units integer not null check(reserved_units between 0 and 1000000),
 count_date date not null,previous_id uuid references public.operational_blood_counts(id),revision integer not null,
 request_id uuid not null,line_no integer not null check(line_no between 1 and 50),payload_hash text not null,
 created_by uuid not null references public.profiles(id),created_at timestamptz not null default clock_timestamp(),unique(request_id,line_no)
);
create index operational_blood_counts_current on public.operational_blood_counts(branch_id,component_name,group_code,revision desc);
alter table public.operational_blood_counts enable row level security;
revoke all on public.operational_blood_counts from public,anon,authenticated;
grant select,insert on public.operational_blood_counts to authenticated;
create policy operational_counts_read on public.operational_blood_counts for select to authenticated using(public.lab_scope(branch_id,'BLOOD_INVENTORY_VIEW') or public.lab_scope(branch_id,'BLOOD_INVENTORY_WRITE'));
create policy operational_counts_write on public.operational_blood_counts for insert to authenticated with check(public.lab_scope(branch_id,'BLOOD_INVENTORY_WRITE',true) and created_by=auth.uid());
create function private.guard_operational_blood_count() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
declare prior public.operational_blood_counts%rowtype;
begin
 if not public.lab_scope(new.branch_id,'BLOOD_INVENTORY_WRITE',true) or not exists(select 1 from public.branches where id=new.branch_id and active) then raise exception 'Sucursal o permiso no autorizado.' using errcode='42501';end if;
 if new.created_by is distinct from auth.uid() then raise exception 'Responsable no autorizado.' using errcode='42501';end if;
 if new.count_date>(clock_timestamp() at time zone 'America/Santo_Domingo')::date then raise exception 'El conteo no puede tener fecha futura.';end if;
 perform pg_advisory_xact_lock(hashtextextended(new.branch_id::text,781));
 select * into prior from public.operational_blood_counts where branch_id=new.branch_id and component_name=new.component_name and group_code=new.group_code order by revision desc limit 1;
 if new.previous_id is distinct from prior.id then raise exception 'El conteo cambió. Actualiza el inventario antes de guardar.';end if;
 if prior.id is not null and new.count_date<prior.count_date then raise exception 'La fecha no puede ser anterior al último conteo de este grupo.';end if;
 new.revision:=coalesce(prior.revision,0)+1;new.created_at:=clock_timestamp();return new;
end$$;
revoke all on function private.guard_operational_blood_count() from public,anon,authenticated;
create trigger operational_count_guard before insert on public.operational_blood_counts for each row execute function private.guard_operational_blood_count();
create view public.vw_operational_blood_inventory with(security_invoker=true) as
select distinct on(branch_id,component_name,group_code) id,branch_id,component_name,group_code,
 case when group_code='PENDIENTE' then null else split_part(group_code,'|',1) end as abo,
 case when group_code='PENDIENTE' then null else split_part(group_code,'|',2) end as rh,
 available_units,quarantine_units,reserved_units,count_date,revision,created_at,created_by
from public.operational_blood_counts order by branch_id,component_name,group_code,revision desc;
revoke all on public.vw_operational_blood_inventory from public,anon;grant select on public.vw_operational_blood_inventory to authenticated;
create function public.record_operational_blood_counts(p_branch uuid,p_request uuid,p_date date,p_lines jsonb)
returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare item jsonb;hash text;n integer:=0;existing integer;valid boolean;
begin
 if auth.uid() is null or not public.lab_scope(p_branch,'BLOOD_INVENTORY_WRITE',true) then raise exception 'No puedes registrar conteos en esta sucursal.' using errcode='42501';end if;
 if p_request is null or p_date is null or jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) not between 1 and 50 then raise exception 'Conteo no válido.';end if;
 if exists(select 1 from jsonb_array_elements(p_lines)x group by x->>'component_name',x->>'group_code' having count(*)>1) then raise exception 'Hay hemocomponentes y grupos repetidos en el conteo.';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_branch::text,781));
 hash:=md5(jsonb_build_object('branch',p_branch,'date',p_date,'lines',p_lines)::text);
 select count(*),bool_and(payload_hash=hash and created_by=auth.uid()) into existing,valid from public.operational_blood_counts where request_id=p_request;
 if existing>0 then if not valid or existing<>jsonb_array_length(p_lines) then raise exception 'La solicitud ya fue utilizada con otros datos.';end if;return jsonb_build_object('count',existing,'already_saved',true);end if;
 for item in select value from jsonb_array_elements(p_lines) loop
  n:=n+1;
  insert into public.operational_blood_counts(branch_id,component_name,group_code,available_units,quarantine_units,reserved_units,count_date,previous_id,revision,request_id,line_no,payload_hash,created_by)
  values(p_branch,item->>'component_name',item->>'group_code',(item->>'available_units')::integer,(item->>'quarantine_units')::integer,(item->>'reserved_units')::integer,p_date,nullif(item->>'previous_id','')::uuid,1,p_request,n,hash,auth.uid());
 end loop;
 return jsonb_build_object('count',n,'already_saved',false);
end$$;
revoke all on function public.record_operational_blood_counts(uuid,uuid,date,jsonb) from public,anon;grant execute on function public.record_operational_blood_counts(uuid,uuid,date,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
