begin;
-- Predictive route planning for doctor/specialist visits: adds reception
-- conditions (days received, shift, desired frequency) to medical_referrers
-- and a view that tells the agent, for each active referrer, whether today
-- is a valid day to visit and whether the visit is "due" per their
-- frequency. last_visit_at is the one field the business seeds manually
-- (no historical "visit to doctor" event existed before this feature) and
-- the app keeps it current from here on via logReferrerVisit.

alter table public.medical_referrers
  add column if not exists reception_days smallint[],
  add column if not exists reception_shift text
    check(reception_shift is null or reception_shift in ('MATUTINA','VESPERTINA','AMBAS')),
  add column if not exists visit_frequency_days integer
    check(visit_frequency_days is null or visit_frequency_days > 0),
  add column if not exists last_visit_at date,
  add column if not exists priority text not null default 'MEDIA'
    check(priority in ('ALTA','MEDIA','BAJA'));

comment on column public.medical_referrers.reception_days is 'ISO weekday numbers (1=Lunes..7=Domingo) the referrer receives visits.';

create or replace view public.vw_referrer_visit_route
with (security_invoker=true) as
select
  r.id, r.referrer_code, r.full_name, r.specialty, r.organization, r.branch_id,
  r.city, r.status, r.priority, r.reception_days, r.reception_shift,
  r.visit_frequency_days, r.last_visit_at,
  case when r.last_visit_at is not null and r.visit_frequency_days is not null
    then r.last_visit_at + r.visit_frequency_days
  end as next_due_date,
  case when r.last_visit_at is not null and r.visit_frequency_days is not null
    then (current_date - (r.last_visit_at + r.visit_frequency_days))
  end as days_overdue,
  (r.reception_days is not null and extract(isodow from current_date)::int = any(r.reception_days)) as receives_today,
  (r.last_visit_at is not null and r.visit_frequency_days is not null
    and current_date >= r.last_visit_at + r.visit_frequency_days) as is_due
from public.medical_referrers r
where r.status='ACTIVO';

grant select on public.vw_referrer_visit_route to authenticated;

notify pgrst,'reload schema';
commit;
