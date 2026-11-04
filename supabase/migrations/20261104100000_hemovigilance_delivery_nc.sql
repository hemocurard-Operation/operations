begin;
-- Structured post-delivery nonconformity report (hemocomponent delivered to
-- an outside health center). Adapted from a standalone paper-replacement
-- form the business already uses; that form saved nothing server-side, so
-- this gives it a real event_type on hemovigilance_events plus a satellite
-- table for the delivery-specific fields instead of widening the base
-- event table (whose other event types don't have a health center,
-- patient, or hemocomponent to report on) with a long run of null columns.

alter table public.hemovigilance_events drop constraint if exists hemovigilance_events_event_type_check;
alter table public.hemovigilance_events add constraint hemovigilance_events_event_type_check
  check(event_type in ('REACCION_DONANTE','REACCION_TRANSFUSIONAL','ERROR','CASI_EVENTO','QUEJA','RETIRO','OTRO','NC_ENTREGA'));

create table if not exists public.hemovigilance_delivery_details(
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null unique references public.hemovigilance_events(id) on delete cascade,
  health_center text not null,
  patient_name text not null,
  delivered_at timestamptz,
  reporter_name text not null,
  reporter_role text not null,
  reporter_phone text not null,
  component_type text not null,
  units integer not null check(units>0),
  abo text not null check(abo in ('A','B','AB','O')),
  rh text not null check(rh in ('POSITIVO','NEGATIVO')),
  product_code text,
  collection_date date,
  expiry_date date,
  volume_ml numeric,
  origin text,
  nc_category text not null check(nc_category in (
    'cadena_frio','integridad','etiquetado','documentacion',
    'compatibilidad','aspecto','transporte','volumen','otro'
  )),
  nc_subtype text not null,
  temp_registered text,
  temp_expected text,
  product_returned boolean not null,
  doctor_notified boolean,
  evidence_package_ref text,
  evidence_card_ref text
);

alter table public.hemovigilance_delivery_details enable row level security;
drop policy if exists hemovig_delivery_auth on public.hemovigilance_delivery_details;
create policy hemovig_delivery_auth on public.hemovigilance_delivery_details for all
  using(auth.role()='authenticated') with check(auth.role()='authenticated');
grant select,insert,update on public.hemovigilance_delivery_details to authenticated;

create or replace function public.hemovig_delivery_nc_create(p_branch uuid, p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_event_id uuid;
begin
  if auth.role()<>'authenticated' then raise exception 'No autorizado'; end if;
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
