begin;
-- Technical release permission remains sufficient without granting inventory administration.
create or replace function private.lab_unit_guard() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
begin
 if new.screening_status='APTO' and (tg_op='INSERT' or old.screening_status is distinct from new.screening_status or old.inventory_status='CUARENTENA' and new.inventory_status='DISPONIBLE') then
  if not (public.lab_scope(new.branch_id,'BLOOD_INVENTORY_WRITE',true) or public.lab_scope(new.branch_id,'UNIT_RELEASE',true)) or new.expiry_date is null or new.expiry_date<(now() at time zone 'America/Santo_Domingo')::date then raise exception 'Unidad sin vigencia o permiso';end if;
  if (select decision from public.unit_release_reviews where source_unit_code=new.source_unit_code and branch_id=new.branch_id order by review_date desc,id desc limit 1) is distinct from 'APTO' or exists(select 1 from public.screening_tests where source_unit_code=new.source_unit_code and branch_id=new.branch_id and (status<>'VALIDADO' or result<>'NO_REACTIVO')) then raise exception 'Se requiere decisión técnica vigente y pruebas validadas';end if;
 end if;
 return new;
end$$;
revoke all on function private.lab_unit_guard() from public,anon,authenticated;
commit;
