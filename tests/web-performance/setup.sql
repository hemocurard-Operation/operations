alter table public.donors add column full_name text,add column cedula text,add column last_donation_date date;
create view public.vw_donor_coordination with(security_invoker=true) as
 select id,donor_code,branch_id,full_name,cedula,abo,rh,registration_date,last_donation_date from public.donors;
grant select on public.vw_donor_coordination to authenticated;
