-- Source-declared history is distinct from governed donation/contact/laboratory records.
-- This migration contains no donor identities or spreadsheet data.
alter table public.donors add column donor_import_metadata jsonb;
alter table public.donors add constraint donor_import_metadata_object check(donor_import_metadata is null or jsonb_typeof(donor_import_metadata)='object');
create function public.guard_donor_import_provenance() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
begin
 if current_user not in ('postgres','service_role') and
 ((tg_op='INSERT' and new.donor_import_metadata is not null) or
  (tg_op='UPDATE' and new.donor_import_metadata is distinct from old.donor_import_metadata)) then
  raise exception 'Los antecedentes originales de importación se conservan sin edición desde la ficha.' using errcode='42501';
 end if;
 return new;
end $$;
revoke all on function public.guard_donor_import_provenance() from public,anon,authenticated;
create trigger guard_donor_import_provenance before insert or update of donor_import_metadata on public.donors for each row execute function public.guard_donor_import_provenance();
notify pgrst,'reload schema';
