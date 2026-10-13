-- Calculated administrative planning reference; never sets clinical eligibility or confirms a visit.
create function public.donor_agenda_date(p text) returns date language plpgsql immutable security invoker set search_path='' as $$
begin
 if p is null or p !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then return null;end if;
 return p::date;
exception when datetime_field_overflow or invalid_datetime_format then return null;
end $$;
revoke all on function public.donor_agenda_date(text) from public,anon;
grant execute on function public.donor_agenda_date(text) to authenticated;
create view public.vw_donor_next_donation with(security_invoker=true) as
with references_by_donor as (
 select d.id,d.donor_code,d.branch_id,d.full_name,d.cedula,d.sex,d.phone,d.preferred_channel,d.abo,d.rh,d.status,d.deferral_reason,d.effective_donation,d.observations,d.registration_date,d.donor_type,
 src.source_date,src.invalid_date_count,registered.registered_date,
 greatest(src.source_date,registered.registered_date) as last_donation_date
 from public.donors d
 left join lateral (
  select max(public.donor_agenda_date(x->>'date')) as source_date,
   count(*) filter(where public.donor_agenda_date(x->>'date') is null)::integer as invalid_date_count
  from jsonb_array_elements(case when jsonb_typeof(d.donor_import_metadata->'donation_history')='array' then d.donor_import_metadata->'donation_history' else '[]'::jsonb end) x
 ) src on true
 left join lateral (
  select max(coalesce(n.donation_date,(n.collected_at at time zone 'America/Santo_Domingo')::date)) as registered_date
  from public.donations n where n.donor_id=d.id and n.collection_effective is true
 ) registered on true
), dates as (
 select r.*,case when last_donation_date<=(now() at time zone 'America/Santo_Domingo')::date then last_donation_date+84 end as next_donation_date,
 case when registered_date is not null and registered_date=last_donation_date then 'REGISTRO_HEMOCURA' when source_date is not null then 'EXCEL_IMPORTADO' end as reference_source
 from references_by_donor r
)
select id,donor_code,branch_id,full_name,cedula,sex,phone,preferred_channel,abo,rh,status,deferral_reason,effective_donation,observations,registration_date,donor_type,last_donation_date,next_donation_date,reference_source,invalid_date_count,
 case when last_donation_date is null then 'SIN_FECHA' when next_donation_date is null then 'FECHA_POR_VERIFICAR' when next_donation_date<=(now() at time zone 'America/Santo_Domingo')::date then 'FECHA_ALCANZADA' else 'PROXIMA' end as agenda_state
from dates;
revoke all on public.vw_donor_next_donation from public,anon;
grant select on public.vw_donor_next_donation to authenticated;
notify pgrst,'reload schema';
