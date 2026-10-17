begin;
create or replace function private.lab_record_guard() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
begin
 if auth.uid() is null or not public.wf_active_actor() then raise exception 'Usuario inactivo o no autenticado' using errcode='42501';end if;
 if tg_table_name in ('screening_tests','reagent_lots') then
  if tg_op='INSERT' then new.entered_by:=auth.uid();elsif new.entered_by is distinct from old.entered_by then raise exception 'Autor inmutable';end if;
 end if;
 if tg_table_name='screening_tests' then
  if tg_op='UPDATE' and old.status='VALIDADO' and row(new.result,new.test_type,new.reagent,new.reagent_lot,new.reagent_expiry,new.screening_date) is distinct from row(old.result,old.test_type,old.reagent,old.reagent_lot,old.reagent_expiry,old.screening_date) then raise exception 'Resultado validado inmutable; registre la repetición con evidencia sin sobrescribir el original';end if;
  perform 1 from public.donations where source_unit_code=new.source_unit_code and branch_id=new.branch_id for update;if not found then raise exception 'Primero registre la donación y sucursal de la unidad';end if;
  if new.status='VALIDADO' and (tg_op='INSERT' or old.status is distinct from new.status) and (new.entered_by is null or new.entered_by=auth.uid() or not public.has_permission('QUALITY_DAILY_REVIEW')) then raise exception 'La prueba debe validarla otro revisor autorizado';end if;
  if new.reagent_expiry is not null and new.reagent_expiry<new.screening_date then raise exception 'Reactivo vencido en la fecha del ensayo';end if;
  if tg_op='UPDATE' and row(new.branch_id,new.source_unit_code,new.screening_code) is distinct from row(old.branch_id,old.source_unit_code,old.screening_code) then raise exception 'Identidad de tamizaje inmutable';end if;
 elsif tg_table_name='iqc_plans' then
  if new.lower_limit is null or new.upper_limit is null or new.lower_limit>=new.upper_limit then raise exception 'Defina límites inferior y superior válidos según procedimiento';end if;
 elsif tg_table_name='cold_chain_devices' then
  if new.min_temp>=new.max_temp then raise exception 'Rango térmico no válido';end if;
 elsif tg_table_name='reagent_lots' then
  if new.quantity_available>new.quantity_received then raise exception 'Disponible no puede superar recibido';end if;
  if new.verification_status='APROBADO' and new.expiry_date<(now() at time zone 'America/Santo_Domingo')::date then raise exception 'Reactivo vencido';end if;
  if new.verification_status='APROBADO' and (tg_op='INSERT' or old.verification_status is distinct from new.verification_status) then
   if new.entered_by is null or new.entered_by=auth.uid() or not public.has_permission('QUALITY_DAILY_REVIEW') or nullif(trim(new.certificate_reference),'') is null then raise exception 'Aprobación de lote requiere revisor independiente, autor identificado y evidencia';end if;
   new.verified_by:=auth.uid();new.verified_at:=now();
  end if;
 end if;
 return new;
end$$;
revoke all on function private.lab_record_guard() from public,anon,authenticated;
commit;
