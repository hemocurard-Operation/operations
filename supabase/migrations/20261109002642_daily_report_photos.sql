begin;
-- Immutable private photographic evidence. Payload is fetched only when opening an image.
create table public.daily_report_photos(
 id uuid primary key default gen_random_uuid(),
 report_id uuid not null references public.daily_operational_closes(id),
 content_sha256 text not null check(content_sha256 ~ '^[0-9a-f]{64}$'),
 file_name text not null check(length(file_name) between 1 and 255),
 mime_type text not null check(mime_type in ('image/jpeg','image/png','image/webp')),
 image_base64 text not null check(length(image_base64) between 16 and 6990508),
 reviewed_inventory jsonb not null,
 recorded_at timestamptz not null default clock_timestamp(),
 created_by uuid not null default auth.uid() references public.profiles(id),
 unique(report_id,content_sha256)
);
create index daily_report_photos_creator on public.daily_report_photos(created_by);
create function public.validate_daily_report_photo() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
declare image bytea;g record;f record;
begin
 -- Lock the parent so submission/closure cannot race an attachment into a locked report.
 perform 1 from public.daily_operational_closes r where r.id=new.report_id and r.status in ('BORRADOR','REABIERTO') and public.can_access_branch(r.branch_id) for share;
 if not found then raise exception 'Reporte no editable o no accesible';end if;
 image:=decode(new.image_base64,'base64');
 if octet_length(image)<12 or octet_length(image)>5242880 or encode(sha256(image),'hex')<>new.content_sha256 then raise exception 'Imagen o huella inválida';end if;
 if not ((new.mime_type='image/jpeg' and substring(image from 1 for 3)=decode('ffd8ff','hex')) or (new.mime_type='image/png' and substring(image from 1 for 8)=decode('89504e470d0a1a0a','hex')) or (new.mime_type='image/webp' and substring(image from 1 for 4)=decode('52494646','hex') and substring(image from 9 for 4)=decode('57454250','hex'))) then raise exception 'Formato de imagen inválido';end if;
 if jsonb_typeof(new.reviewed_inventory) is distinct from 'object' or new.reviewed_inventory='{}'::jsonb then raise exception 'Cantidades revisadas requeridas';end if;
 for g in select * from jsonb_each(new.reviewed_inventory) loop
  if g.key not in ('A+','A-','B+','B-','O+','O-','AB+','AB-') or jsonb_typeof(g.value) is distinct from 'object' or g.value='{}'::jsonb then raise exception 'Grupo inválido';end if;
  for f in select * from jsonb_each(g.value) loop
   if f.key not in ('whole_blood','packed_cells') or jsonb_typeof(f.value) is distinct from 'number' or f.value::text !~ '^[0-9]{1,5}$' then raise exception 'Cantidad inválida';end if;
  end loop;
 end loop;
 return new;
end $$;
revoke all on function public.validate_daily_report_photo() from public,anon,authenticated;
create trigger validate_daily_report_photo before insert on public.daily_report_photos for each row execute function public.validate_daily_report_photo();
alter table public.daily_report_photos enable row level security;
revoke all on public.daily_report_photos from public,anon,authenticated;
grant select on public.daily_report_photos to authenticated;
grant insert(report_id,content_sha256,file_name,mime_type,image_base64,reviewed_inventory) on public.daily_report_photos to authenticated;
create policy daily_report_photos_read on public.daily_report_photos for select to authenticated
 using(public.wf_active_actor() and public.has_permission('DAILY_REPORT_VIEW') and exists(select 1 from public.daily_operational_closes r where r.id=report_id and public.can_access_branch(r.branch_id)));
create policy daily_report_photos_insert on public.daily_report_photos for insert to authenticated
 with check(public.wf_active_actor() and created_by=auth.uid() and public.has_permission('DAILY_REPORT_WRITE') and exists(select 1 from public.daily_operational_closes r where r.id=report_id and r.status in ('BORRADOR','REABIERTO') and public.can_access_branch(r.branch_id)));
-- No UPDATE/DELETE grants and no public URLs; images are not copied to generic audit JSON.
notify pgrst,'reload schema';
commit;
