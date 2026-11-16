begin;
-- Keep the arrival-based snapshot keys for existing incentive review.
-- Capture both endpoints for operational reporting; historical rows are untouched.
create function public.logistics_trip_timing(p_departure timestamptz,p_arrival timestamptz)
returns jsonb language sql immutable security invoker set search_path=public,pg_temp as $$
 with points as (
 select public.logistics_trip_schedule(p_departure) as departure,
        public.logistics_trip_schedule(p_arrival) as arrival
 )
 select arrival || jsonb_build_object(
  'timing_version','HC-LOG-EXTREMOS-001-1','departure',departure,'arrival',arrival,
  'start_outside_work_hours',departure->>'classification'<>'DENTRO_DE_JORNADA',
  'end_outside_work_hours',arrival->>'classification'<>'DENTRO_DE_JORNADA'
 ) from points;
$$;
revoke all on function public.logistics_trip_timing(timestamptz,timestamptz) from public,anon;
grant execute on function public.logistics_trip_timing(timestamptz,timestamptz) to authenticated;
CREATE OR REPLACE FUNCTION private.guard_logistics_trip()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare actor uuid:=auth.uid();facts_changed boolean;reviewer boolean;settler boolean;name text;
begin
 if not public.logistics_access(new.branch_id) then raise exception 'Tu usuario no tiene acceso a esta sucursal.' using errcode='42501';end if;
 select full_name into name from public.profiles where id=actor;
 if not isfinite(new.departure_at) or not isfinite(new.arrival_at) then raise exception 'Indica una fecha y hora válidas.';end if;
 if new.arrival_at>clock_timestamp() then raise exception 'Revisa la llegada: el viaje debe haber terminado.';end if;
 if new.arrival_at<=new.departure_at then raise exception 'La llegada debe ser posterior a la salida. Si llegaste al día siguiente, marca esa opción.';end if;
 if tg_op='INSERT' then
  if not public.has_permission('TRIPS_WRITE') or new.worker_id<>actor or new.status<>'ENVIADO' then raise exception 'Solo puedes registrar tus propios viajes.' using errcode='42501';end if;
  new.schedule_snapshot:=public.logistics_trip_timing(new.departure_at,new.arrival_at);
  new.worker_name:=coalesce(nullif(trim(name),''),'Colaborador');new.created_at:=now();new.updated_at:=now();new.revision:=1;
  new.scheduled_end_at:=null;new.amount:=null;new.currency:='DOP';new.reviewed_by:=null;new.reviewer_name:=null;new.reviewed_at:=null;new.review_note:=null;new.settled_by:=null;new.settled_at:=null;new.payroll_reference:=null;new.withdraw_reason:=null;
 else
  if row(new.id,new.trip_no,new.branch_id,new.worker_id,new.worker_name,new.created_at,new.request_id,new.request_hash) is distinct from row(old.id,old.trip_no,old.branch_id,old.worker_id,old.worker_name,old.created_at,old.request_id,old.request_hash) then raise exception 'La identidad del viaje es inmutable.';end if;
  if not (old.status='DEVUELTO' and new.status='ENVIADO' and old.worker_id=actor) and new.schedule_snapshot is distinct from old.schedule_snapshot then raise exception 'El horario aplicado es inmutable.';end if;
  if row(new.revision,new.updated_at) is distinct from row(old.revision,old.updated_at) then raise exception 'No puedes cambiar la trazabilidad del registro.';end if;
  facts_changed:=row(new.origin,new.destination,new.departure_at,new.arrival_at,new.purpose,new.delivery_reference,new.note) is distinct from row(old.origin,old.destination,old.departure_at,old.arrival_at,old.purpose,old.delivery_reference,old.note);
  reviewer:=actor<>old.worker_id and public.has_permission('TRIPS_REVIEW');settler:=actor<>old.worker_id and public.has_permission('TRIPS_SETTLE');
  if old.status='DEVUELTO' and new.status='ENVIADO' and old.worker_id=actor and public.has_permission('TRIPS_WRITE') then
   new.schedule_snapshot:=public.logistics_trip_timing(new.departure_at,new.arrival_at);
   new.scheduled_end_at:=null;new.amount:=null;new.reviewed_by:=null;new.reviewer_name:=null;new.reviewed_at:=null;new.review_note:=null;new.withdraw_reason:=null;
   if row(new.settled_by,new.settled_at,new.payroll_reference,new.currency) is distinct from row(old.settled_by,old.settled_at,old.payroll_reference,old.currency) then raise exception 'No puedes registrar una liquidación.';end if;
  elsif old.status in ('ENVIADO','DEVUELTO') and new.status='ANULADO' and old.worker_id=actor and public.has_permission('TRIPS_WRITE') then
   if facts_changed or nullif(trim(new.withdraw_reason),'') is null or (to_jsonb(new)-array['status','withdraw_reason']) is distinct from (to_jsonb(old)-array['status','withdraw_reason']) then raise exception 'Indica el motivo para anular el viaje sin cambiar otros datos.';end if;
  elsif (old.status='ENVIADO' and new.status in ('APROBADO','DEVUELTO','RECHAZADO') or old.status='APROBADO' and new.status='DEVUELTO') and reviewer then
   if facts_changed or nullif(trim(new.review_note),'') is null or row(new.settled_by,new.settled_at,new.payroll_reference,new.withdraw_reason,new.currency) is distinct from row(old.settled_by,old.settled_at,old.payroll_reference,old.withdraw_reason,old.currency) then raise exception 'Documenta la revisión sin modificar el viaje del colaborador.';end if;
   if new.status='APROBADO' then
    if new.schedule_snapshot->>'classification'='DENTRO_DE_JORNADA' then raise exception 'El viaje terminó dentro del horario laboral; no se aprueba incentivo fuera de horario.';end if;
    new.scheduled_end_at:=(new.schedule_snapshot->>'work_end_local')::timestamp at time zone 'America/Santo_Domingo';
    if new.amount is null or new.amount<=0 or new.amount::text in ('NaN','Infinity','-Infinity') then raise exception 'Indica el incentivo autorizado, mayor que cero.';end if;
   else new.amount:=null;new.scheduled_end_at:=null;end if;
   new.reviewed_by:=actor;new.reviewer_name:=name;new.reviewed_at:=now();
  elsif old.status='APROBADO' and new.status='LIQUIDADO' and settler then
   if nullif(trim(new.payroll_reference),'') is null or (to_jsonb(new)-array['status','payroll_reference','settled_by','settled_at']) is distinct from (to_jsonb(old)-array['status','payroll_reference','settled_by','settled_at']) then raise exception 'Indica la referencia de nómina o liquidación sin cambiar el incentivo aprobado.';end if;
   new.settled_by:=actor;new.settled_at:=now();
  else raise exception 'El viaje cambió de estado o no tienes autorización para esta acción.' using errcode='42501';end if;
  new.revision:=old.revision+1;new.updated_at:=now();
 end if;
 -- Serialize each worker globally: changing branches cannot create overlapping duplicate claims.
 if tg_op='INSERT' or old.status='DEVUELTO' and new.status='ENVIADO' then
  perform pg_advisory_xact_lock(hashtextextended(actor::text,773));
  if exists(select 1 from public.logistics_trips t where t.worker_id=new.worker_id and t.id<>new.id and t.status not in ('RECHAZADO','ANULADO') and new.departure_at<t.arrival_at and new.arrival_at>t.departure_at) then raise exception 'Ya hay un viaje tuyo registrado en ese horario. Revisa Mis viajes.';end if;
 end if;
 return new;
end$function$;

update public.app_module_catalog set title='Reporte de viajes' where route_key='extratrips';
notify pgrst,'reload schema';
commit;

