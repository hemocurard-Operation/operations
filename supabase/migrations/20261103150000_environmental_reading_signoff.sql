begin;
-- Hardens the "firma" requirement for environmental_readings: recorded_by was
-- insertable as any value the client sent, so the attribution shown on the
-- printed monthly report could not be trusted. A trigger now forces
-- recorded_by to the authenticated user on every insert, the same pattern
-- other modules use for updated_by (e.g. operations_coordination.sql).

create or replace function private.stamp_environmental_reading()
returns trigger
language plpgsql
security invoker
set search_path=public,pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'Debe iniciar sesión para registrar una lectura ambiental.' using errcode='28000';
  end if;
  new.recorded_by:=auth.uid();
  if new.source is null then new.source:='MANUAL'; end if;
  return new;
end;
$$;
revoke all on function private.stamp_environmental_reading() from public,anon,authenticated;

drop trigger if exists trg_stamp_environmental_reading on public.environmental_readings;
create trigger trg_stamp_environmental_reading
before insert on public.environmental_readings
for each row execute function private.stamp_environmental_reading();

notify pgrst,'reload schema';
commit;
