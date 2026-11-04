begin;
-- Hyperbaric appointments carry patient_name/patient_phone in plain text,
-- readable by anyone with HYPERBARIC_VIEW (today: ADMIN, SUPER_USUARIO,
-- MEDICO_GERENTE_TECNICO). The business asked that only the person who
-- books the appointment ("camarista", i.e. whoever holds HYPERBARIC_WRITE)
-- and the clinical staff (HYPERBARIC_SESSION_WRITE) see the real identity;
-- everyone else with mere view access should see a stable, non-reversible
-- tracking code instead — enough to follow the service, not to identify
-- the patient.

alter table public.hyperbaric_appointments add column if not exists patient_code text;

create or replace function private.stamp_hyperbaric_patient_code()
returns trigger language plpgsql set search_path=public,pg_temp as $$
declare parts text[]; initials text:='';
begin
  if NEW.patient_code is null then
    parts:=regexp_split_to_array(btrim(coalesce(NEW.patient_name,'')),'\s+');
    for i in 1..least(coalesce(array_length(parts,1),0),2) loop
      if nullif(parts[i],'') is not null then initials:=initials||upper(substr(parts[i],1,1)); end if;
    end loop;
    if initials='' then initials:='PX'; end if;
    NEW.patient_code:=initials||'-'||upper(substr(replace(NEW.id::text,'-',''),1,4));
  end if;
  return NEW;
end $$;

drop trigger if exists hyperbaric_patient_code on public.hyperbaric_appointments;
create trigger hyperbaric_patient_code before insert on public.hyperbaric_appointments
for each row execute function private.stamp_hyperbaric_patient_code();

-- Backfill existing rows.
update public.hyperbaric_appointments set patient_code =
  upper(coalesce(substring(btrim(patient_name) from '^(\S)'),'P')) ||
  coalesce(upper(substring(split_part(btrim(patient_name),' ',2) from '^(\S)')),'X') ||
  '-' || upper(substr(replace(id::text,'-',''),1,4))
where patient_code is null;

insert into public.app_permissions(permission_code,module,description,risk_level) values
('HYPERBARIC_PATIENT_PII','HYPERBARIC','Ver nombre y teléfono real del paciente de cámara hiperbárica','CRITICO')
on conflict(permission_code) do update set active=true;

-- Grant it to the roles that currently book appointments or perform the
-- clinical session (i.e. the only ones who legitimately need the real
-- identity); every other HYPERBARIC_VIEW holder keeps seeing patient_code.
insert into public.role_permissions(role_id,permission_code)
select distinct rp.role_id,'HYPERBARIC_PATIENT_PII'
from public.role_permissions rp
where rp.permission_code in ('HYPERBARIC_WRITE','HYPERBARIC_SESSION_WRITE')
on conflict do nothing;

create or replace view public.vw_hyperbaric_appointments_display
with (security_invoker=true) as
select
  id, branch_id, resource_id, customer_id,
  case when public.has_permission('HYPERBARIC_PATIENT_PII') then patient_name else patient_code end as patient_name,
  case when public.has_permission('HYPERBARIC_PATIENT_PII') then patient_phone else null end as patient_phone,
  patient_code,
  starts_at, ends_at, operational_date, shift, price, currency, session_label,
  referrer_id, referrer_name, note, status, created_by, created_at
from public.hyperbaric_appointments;

grant select on public.vw_hyperbaric_appointments_display to authenticated;

notify pgrst,'reload schema';
commit;
