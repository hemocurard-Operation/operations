-- hc-lint: allow=HC009 reason=Only REVOKE of the TRUNCATE privilege; no TRUNCATE command is executed.
begin;
-- Hemocura only. Preserve existing authenticated view ACLs and RPC signature.
-- Filename aligned with the production migration history assigned by Supabase MCP.
-- Containment, not a wholesale security_invoker conversion of legacy views.
set local lock_timeout='5s';

do $contain$
declare v record;
begin
 for v in select n.nspname,c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='v'
   and not coalesce(c.reloptions @> array['security_invoker=true'],false)
 loop
  execute format('revoke all privileges on table %I.%I from public,anon',v.nspname,v.relname);
 end loop;
end $contain$;

-- Do not replace legacy event policies: restrictive policies compose with them.
-- General legacy events without branch remain supported; delivery NCs require one.
create policy hemovig_actor_read_guard on public.hemovigilance_events
 as restrictive for select to authenticated
 using (public.wf_active_actor() and public.has_permission('HEMOVIGILANCE_VIEW')
  and (branch_id is null or public.can_access_branch(branch_id)));
create policy hemovig_actor_insert_guard on public.hemovigilance_events
 as restrictive for insert to authenticated
 with check (public.wf_active_actor() and public.has_permission('HEMOVIGILANCE_WRITE')
  and ((branch_id is null and event_type<>'NC_ENTREGA') or public.can_access_branch(branch_id))
  and (event_type<>'NC_ENTREGA' or branch_id is not null));
create policy hemovig_actor_update_guard on public.hemovigilance_events
 as restrictive for update to authenticated
 using (public.wf_active_actor() and public.has_permission('HEMOVIGILANCE_WRITE')
  and (branch_id is null or public.can_access_branch(branch_id)))
 with check (public.wf_active_actor() and public.has_permission('HEMOVIGILANCE_WRITE')
  and ((branch_id is null and event_type<>'NC_ENTREGA') or public.can_access_branch(branch_id))
  and (event_type<>'NC_ENTREGA' or branch_id is not null));
create policy hemovig_actor_delete_guard on public.hemovigilance_events
 as restrictive for delete to authenticated using (false);

-- Existing broad policy is replaced; parent policies also restrict the lookup.
drop policy hemovig_delivery_auth on public.hemovigilance_delivery_details;
create policy hemovig_delivery_read on public.hemovigilance_delivery_details
 for select to authenticated using (
  public.wf_active_actor() and public.has_permission('HEMOVIGILANCE_VIEW') and exists(
   select 1 from public.hemovigilance_events e where e.id=event_id
    and e.branch_id is not null and public.can_access_branch(e.branch_id)));
create policy hemovig_delivery_insert on public.hemovigilance_delivery_details
 for insert to authenticated with check (
  public.wf_active_actor() and public.has_permission('HEMOVIGILANCE_WRITE') and exists(
   select 1 from public.hemovigilance_events e where e.id=event_id
    and e.branch_id is not null and public.can_access_branch(e.branch_id)));
create policy hemovig_delivery_update on public.hemovigilance_delivery_details
 for update to authenticated using (
  public.wf_active_actor() and public.has_permission('HEMOVIGILANCE_WRITE') and exists(
   select 1 from public.hemovigilance_events e where e.id=event_id
    and e.branch_id is not null and public.can_access_branch(e.branch_id)))
 with check (
  public.wf_active_actor() and public.has_permission('HEMOVIGILANCE_WRITE') and exists(
   select 1 from public.hemovigilance_events e where e.id=event_id
    and e.branch_id is not null and public.can_access_branch(e.branch_id)));
revoke all privileges on public.hemovigilance_delivery_details from public,anon;
revoke delete,truncate on public.hemovigilance_delivery_details from authenticated;
revoke delete,truncate on public.hemovigilance_events from anon,authenticated;

-- Narrow privileged trigger: atomic audit, no patient/contact/free-text copies.
create or replace function private.audit_hemovigilance_change()
returns trigger language plpgsql security definer set search_path='' as $audit$
declare b uuid; prior jsonb; next_row jsonb; changed jsonb; event_id uuid;
begin
 if TG_TABLE_SCHEMA<>'public' or TG_TABLE_NAME not in ('hemovigilance_events','hemovigilance_delivery_details') then
  raise exception 'Unsupported audit table';
 end if;
 if TG_OP='UPDATE' and NEW.id is distinct from OLD.id then
  raise exception 'No se permite cambiar la identidad del registro' using errcode='23514';
 end if;
 if TG_TABLE_NAME='hemovigilance_delivery_details' then
  if TG_OP='UPDATE' then
   if NEW.event_id is distinct from OLD.event_id then
    raise exception 'No se permite mover el detalle a otro evento' using errcode='23514';
   end if;
  end if;
 end if;
 prior:=case when TG_OP='INSERT' then '{}'::jsonb else to_jsonb(OLD) end;
 next_row:=case when TG_OP='DELETE' then '{}'::jsonb else to_jsonb(NEW) end;
 if TG_OP='UPDATE' and prior=next_row then return NEW;end if;
 select coalesce(jsonb_agg(k order by k),'[]'::jsonb) into changed
 from (select key k from jsonb_object_keys(prior||next_row) as x(key)
       where prior->key is distinct from next_row->key) fields;
 event_id:=case when TG_TABLE_NAME='hemovigilance_events'
  then coalesce(next_row->>'id',prior->>'id')::uuid
  else coalesce(next_row->>'event_id',prior->>'event_id')::uuid end;
 if TG_TABLE_NAME='hemovigilance_events' then
  b:=coalesce(next_row->>'branch_id',prior->>'branch_id')::uuid;
 else
  select e.branch_id into b from public.hemovigilance_events e where e.id=event_id;
 end if;
 insert into public.audit_events(user_id,branch_id,module,action,entity_table,entity_id,entity_reference,
  before_data,after_data,metadata)
 values(auth.uid(),b,'HEMOVIGILANCE',TG_OP,TG_TABLE_NAME,
  coalesce(next_row->>'id',prior->>'id')::uuid,event_id::text,
  (select coalesce(jsonb_object_agg(key,value),'{}'::jsonb) from jsonb_each(prior)
   where key in ('id','event_id','branch_id','event_type','severity','status','reported_by','units','abo','rh','product_returned','doctor_notified','nonconformity_id','capa_id')),
  (select coalesce(jsonb_object_agg(key,value),'{}'::jsonb) from jsonb_each(next_row)
   where key in ('id','event_id','branch_id','event_type','severity','status','reported_by','units','abo','rh','product_returned','doctor_notified','nonconformity_id','capa_id')),
  jsonb_build_object('event_id',event_id,'changed_fields',changed,'redacted',true));
 if TG_OP='DELETE' then return OLD;end if;return NEW;
end $audit$;
revoke all on function private.audit_hemovigilance_change() from public,anon,authenticated;
create trigger hemovig_audit_change after insert or update or delete on public.hemovigilance_events
 for each row execute function private.audit_hemovigilance_change();
create trigger hemovig_delivery_audit_change after insert or update or delete on public.hemovigilance_delivery_details
 for each row execute function private.audit_hemovigilance_change();

create or replace function public.hemovig_delivery_nc_create(p_branch uuid, p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_event_id uuid;
begin
  if auth.uid() is null or not public.wf_active_actor()
     or not public.has_permission('HEMOVIGILANCE_WRITE')
     or p_branch is null or not public.can_access_branch(p_branch) then
    raise exception 'Sin permiso de hemovigilancia para esta sucursal' using errcode='42501';
  end if;
  if nullif(btrim(p_data->>'event_code'),'') is null then raise exception 'Código de evento requerido'; end if;
  if nullif(btrim(p_data->>'description'),'') is null then raise exception 'Descripción requerida'; end if;

  insert into public.hemovigilance_events(
    event_code,branch_id,event_type,severity,source_unit_code,patient_reference,
    description,immediate_action,reported_by,status
  ) values(
    btrim(p_data->>'event_code'),p_branch,'NC_ENTREGA',
    coalesce(p_data->>'severity','MEDIA'),nullif(p_data->>'product_code',''),
    btrim(p_data->>'patient_name'),btrim(p_data->>'description'),
    nullif(btrim(p_data->>'immediate_action'),''),auth.uid(),'ABIERTO'
  ) returning id into v_event_id;

  insert into public.hemovigilance_delivery_details(
    event_id,health_center,patient_name,delivered_at,reporter_name,reporter_role,reporter_phone,
    component_type,units,abo,rh,product_code,collection_date,expiry_date,volume_ml,origin,
    nc_category,nc_subtype,temp_registered,temp_expected,product_returned,doctor_notified,
    evidence_package_ref,evidence_card_ref
  ) values(
    v_event_id,btrim(p_data->>'health_center'),btrim(p_data->>'patient_name'),
    nullif(p_data->>'delivered_at','')::timestamptz,
    btrim(p_data->>'reporter_name'),btrim(p_data->>'reporter_role'),btrim(p_data->>'reporter_phone'),
    btrim(p_data->>'component_type'),(p_data->>'units')::integer,p_data->>'abo',p_data->>'rh',
    nullif(p_data->>'product_code',''),nullif(p_data->>'collection_date','')::date,
    nullif(p_data->>'expiry_date','')::date,nullif(p_data->>'volume_ml','')::numeric,
    nullif(p_data->>'origin',''),p_data->>'nc_category',btrim(p_data->>'nc_subtype'),
    nullif(p_data->>'temp_registered',''),nullif(p_data->>'temp_expected',''),
    (p_data->>'product_returned')::boolean,nullif(p_data->>'doctor_notified','')::boolean,
    nullif(p_data->>'evidence_package_ref',''),nullif(p_data->>'evidence_card_ref','')
  );

  return v_event_id;
end $$;

revoke execute on function public.hemovig_delivery_nc_create(uuid,jsonb) from public,anon;
grant execute on function public.hemovig_delivery_nc_create(uuid,jsonb) to authenticated;

notify pgrst,'reload schema';
commit;
