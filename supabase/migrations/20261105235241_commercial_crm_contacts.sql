begin;
insert into public.app_feature_flags(key,enabled,mode,description) values('commercial_crm',false,'OFF','Fichas comerciales, prospectos, referidores e importación revisada por sucursal');
create table public.crm_services(id uuid primary key default gen_random_uuid(),code text not null unique,name text not null,active boolean not null default true);
insert into public.crm_services(code,name) select code,name from public.services where active on conflict do nothing;
insert into public.crm_services(code,name) values('SANGRE','Banco de sangre'),('CAMARA_HIPERBARICA','Cámara hiperbárica') on conflict do nothing;
create table public.crm_contacts(
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),
 kind text not null check(kind in ('PROSPECTO','REFERIDOR','CENTRO')),full_name text not null check(length(trim(full_name)) between 2 and 200),
 phone text,email text,whatsapp text,center text,specialty text,city text,address text,
 preferred_channel text not null default 'SIN_PREFERENCIA' check(preferred_channel in ('SIN_PREFERENCIA','TELEFONO','WHATSAPP','CORREO','VISITA','NO_CONTACTAR')),
 preferences text,objective text,goal_service_id uuid references public.crm_services(id),service_ids uuid[] not null default '{}',
 stage text not null default 'PROSPECTO' check(stage in ('PROSPECTO','CONTACTADO','SEGUIMIENTO','ACTIVO','NO_INTERESADO','ARCHIVADO')),
 follow_up_at timestamptz,customer_id uuid references public.customers(id),referrer_id uuid references public.medical_referrers(id),
 owner_id uuid not null references public.profiles(id),revision integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create unique index crm_referrer_identity on public.crm_contacts(branch_id,referrer_id) where referrer_id is not null;
create index crm_contacts_branch on public.crm_contacts(branch_id,updated_at desc);
create index crm_contacts_followup on public.crm_contacts(branch_id,follow_up_at) where stage<>'ARCHIVADO';
create table public.crm_activities(id uuid primary key default gen_random_uuid(),contact_id uuid not null references public.crm_contacts(id),branch_id uuid not null references public.branches(id),channel text not null check(channel in ('VISITA','LLAMADA','WHATSAPP','CORREO','NOTA')),occurred_at timestamptz not null,notes text not null,outcome text,service_id uuid references public.crm_services(id),follow_up_at timestamptz,created_by uuid not null references public.profiles(id),created_at timestamptz not null default now());
create index crm_activities_contact on public.crm_activities(contact_id,occurred_at desc);
create table public.crm_history(id uuid primary key default gen_random_uuid(),contact_id uuid not null references public.crm_contacts(id),branch_id uuid not null references public.branches(id),actor_id uuid not null references public.profiles(id),action text not null,before_data jsonb,after_data jsonb not null,metadata jsonb not null default '{}',occurred_at timestamptz not null default now());
create index crm_history_contact on public.crm_history(contact_id,occurred_at);
create table public.crm_requests(actor_id uuid not null,request_id uuid not null,payload jsonb not null,response jsonb not null,created_at timestamptz not null default now(),primary key(actor_id,request_id));
create function private.crm_scope(b uuid,p text default 'COMMERCIAL_VIEW') returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and public.wf_active_actor() and exists(select 1 from public.user_roles u join public.roles r on r.id=u.role_id join public.role_permissions rp on rp.role_id=r.id join public.app_permissions ap on ap.permission_code=rp.permission_code and ap.active where u.user_id=auth.uid() and rp.permission_code=p and (u.branch_id=b or r.code='SUPER_USUARIO'));
$$;
revoke all on function private.crm_scope(uuid,text) from public,anon;grant execute on function private.crm_scope(uuid,text) to authenticated;
alter table public.crm_contacts enable row level security;alter table public.crm_activities enable row level security;alter table public.crm_history enable row level security;alter table public.crm_requests enable row level security;alter table public.crm_services enable row level security;
revoke all on public.crm_contacts,public.crm_activities,public.crm_history,public.crm_requests,public.crm_services from public,anon,authenticated;
grant select on public.crm_contacts,public.crm_activities,public.crm_history,public.crm_services to authenticated;
create policy crm_contacts_read on public.crm_contacts for select to authenticated using(private.crm_scope(branch_id));
create policy crm_activities_read on public.crm_activities for select to authenticated using(private.crm_scope(branch_id));
create policy crm_history_read on public.crm_history for select to authenticated using(private.crm_scope(branch_id));
create policy crm_services_read on public.crm_services for select to authenticated using(public.wf_active_actor() and public.has_permission('COMMERCIAL_VIEW'));
create function private.crm_phone(t text) returns text language sql immutable set search_path=public,pg_temp as $$select case when d ~ '^(809|829|849)[0-9]{7}$' then '1'||d else nullif(d,'') end from (select regexp_replace(coalesce(t,''),'[^0-9]','','g') d)x$$;
create function private.crm_clean(j jsonb) returns jsonb language plpgsql stable set search_path=public,pg_temp as $$
declare c jsonb:='{}';k text;v text;s uuid[];sid uuid;
begin
 if jsonb_typeof(j)<>'object' or j is null then raise exception 'Ficha inválida';end if;
 foreach k in array array['full_name','phone','email','whatsapp','center','specialty','city','address','preferences','objective','kind','stage','preferred_channel'] loop
  if j?k and jsonb_typeof(j->k) not in ('string','null') then raise exception 'El campo % debe ser texto',k;end if;
  v:=nullif(trim(j->>k),'');if length(coalesce(v,''))>(case when k in ('preferences','objective') then 2000 when k='address' then 500 else 200 end) then raise exception 'El campo % excede el máximo permitido',k;end if;
  if k='email' then v:=lower(v);if v is not null and v !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Correo no válido: %',v;end if;end if;
  if k in ('phone','whatsapp') and v is not null and (length(private.crm_phone(v)) not between 7 and 15 or private.crm_phone(v) is null) then raise exception 'Teléfono o WhatsApp no válido';end if;
  c:=c||jsonb_build_object(k,v);
 end loop;
 c:=c||jsonb_build_object('kind',coalesce(c->>'kind','PROSPECTO'),'stage',coalesce(c->>'stage','PROSPECTO'),'preferred_channel',coalesce(c->>'preferred_channel','SIN_PREFERENCIA'));
 if length(coalesce(c->>'full_name',''))<2 then raise exception 'Nombre de al menos dos caracteres requerido';end if;
 if c->>'kind' not in ('PROSPECTO','REFERIDOR','CENTRO') or c->>'stage' not in ('PROSPECTO','CONTACTADO','SEGUIMIENTO','ACTIVO','NO_INTERESADO','ARCHIVADO') or c->>'preferred_channel' not in ('SIN_PREFERENCIA','TELEFONO','WHATSAPP','CORREO','VISITA','NO_CONTACTAR') then raise exception 'Tipo, etapa o canal no válido';end if;
 if j?'service_ids' and jsonb_typeof(j->'service_ids')<>'array' then raise exception 'Servicios debe ser una lista';end if;
 if jsonb_array_length(coalesce(j->'service_ids','[]'))>30 then raise exception 'Máximo 30 servicios por ficha';end if;
 select coalesce(array_agg(distinct value::uuid),'{}') into s from jsonb_array_elements_text(coalesce(j->'service_ids','[]'));
 if exists(select 1 from unnest(s) id where not exists(select 1 from public.crm_services x where x.id=id and x.active)) then raise exception 'Servicio de interés inválido o inactivo';end if;
 sid:=nullif(j->>'goal_service_id','')::uuid;
 if sid is not null and not exists(select 1 from public.crm_services where id=sid and active) then raise exception 'Objetivo requiere un servicio activo del catálogo';end if;
 if nullif(j->>'follow_up_at','') is not null and not isfinite((j->>'follow_up_at')::timestamptz) then raise exception 'Fecha de seguimiento no válida';end if;
 return c||jsonb_build_object('service_ids',to_jsonb(s),'goal_service_id',sid,'follow_up_at',nullif(j->>'follow_up_at','')::timestamptz,'customer_id',nullif(j->>'customer_id','')::uuid,'referrer_id',nullif(j->>'referrer_id','')::uuid);
end;$$;
create function private.crm_matches(b uuid,j jsonb,exclude_id uuid default null) returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce(jsonb_agg(x),'[]') from (
 select 'CRM' as source,c.id,c.full_name,c.center,c.revision from public.crm_contacts c where c.branch_id=b and c.id is distinct from exclude_id and (
 private.crm_phone(j->>'phone') is not null and private.crm_phone(c.phone)=private.crm_phone(j->>'phone') or nullif(j->>'email','') is not null and lower(c.email)=lower(j->>'email') or lower(c.full_name)=lower(j->>'full_name') and lower(coalesce(c.center,''))=lower(coalesce(j->>'center','')))
 union all select 'REFERIDOR',r.id,r.full_name,r.organization,null::integer from public.medical_referrers r where (r.branch_id=b or r.branch_id is null) and (not exists(select 1 from public.crm_contacts c where c.branch_id=b and c.referrer_id=r.id)) and (private.crm_phone(j->>'phone') is not null and private.crm_phone(r.phone)=private.crm_phone(j->>'phone') or nullif(j->>'email','') is not null and lower(r.email)=lower(j->>'email') or lower(r.full_name)=lower(j->>'full_name') and lower(coalesce(r.organization,''))=lower(coalesce(j->>'center','')))
 )x;
$$;
create function private.crm_customer_allowed(b uuid,customer uuid) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.customers c where c.id=customer and c.active and (
 exists(select 1 from public.commercial_locations l where l.branch_id=b and l.customer_id=c.id) or
 exists(select 1 from public.commercial_visits v where v.branch_id=b and v.customer_id=c.id) or
 exists(select 1 from public.crm_contacts x where x.branch_id=b and x.customer_id=c.id)));
$$;
revoke all on function private.crm_customer_allowed(uuid,uuid) from public,anon,authenticated;
create function private.crm_save(b uuid,j jsonb,target uuid,expected integer,allow_duplicate boolean,reason text) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare c public.crm_contacts;old_data jsonb;v jsonb;r public.medical_referrers;ref uuid;cust uuid;rid uuid;
begin
 if not private.crm_scope(b,'COMMERCIAL_WRITE') then raise exception 'Edición comercial no autorizada en esta sucursal' using errcode='42501';end if;
 if target is not null then
  select * into c from public.crm_contacts where id=target and branch_id=b for update;if not found then raise exception 'Ficha no accesible';end if;
  if expected is distinct from c.revision then raise exception 'Ficha modificada por otro usuario; vuelva a validar' using errcode='40001';end if;old_data:=to_jsonb(c);
 end if;
 if j?'initial_note' and (jsonb_typeof(j->'initial_note') not in ('string','null') or length(coalesce(j->>'initial_note',''))>4000) then raise exception 'Nota inicial de máximo 4000 caracteres';end if;
 v:=private.crm_clean(coalesce(old_data,'{}')||j);ref:=(v->>'referrer_id')::uuid;cust:=(v->>'customer_id')::uuid;
 if old_data is not null and ref is distinct from c.referrer_id then raise exception 'No se puede reemplazar el vínculo del referidor de una ficha existente';end if;
 if cust is not null and not private.crm_customer_allowed(b,cust) then raise exception 'Cliente activo vinculado a esta sucursal requerido';end if;
 if ref is not null and v->>'kind'<>'REFERIDOR' then raise exception 'Una ficha vinculada a un referidor debe conservar ese tipo';end if;
 if ref is not null then
  select * into r from public.medical_referrers where id=ref and (branch_id=b or branch_id is null);if not found then raise exception 'Referidor de otra sucursal o inexistente';end if;
  if exists(select 1 from public.crm_contacts where branch_id=b and referrer_id=ref and id is distinct from target) then raise exception 'Este referidor ya tiene ficha CRM; actualice la existente';end if;
 end if;
 if jsonb_array_length(private.crm_matches(b,v,target))>0 and ref is null and (not coalesce(allow_duplicate,false) or length(trim(coalesce(reason,'')))<3) then raise exception 'Posible duplicado: vincule la ficha existente o justifique crear otra persona';end if;
 if v->>'kind'='REFERIDOR' and ref is null then
  ref:=gen_random_uuid();
  insert into public.medical_referrers(id,branch_id,referrer_code,full_name,specialty,organization,phone,email,city,status,created_by) values(ref,b,'CRM-'||ref::text,v->>'full_name',v->>'specialty',v->>'center',v->>'phone',v->>'email',v->>'city','ACTIVO',auth.uid());
 elsif ref is not null and r.branch_id=b then
  update public.medical_referrers set full_name=v->>'full_name',specialty=v->>'specialty',organization=v->>'center',phone=v->>'phone',email=v->>'email',city=v->>'city',updated_at=now() where id=ref;
 end if;
 if target is null then
  insert into public.crm_contacts(branch_id,kind,full_name,phone,email,whatsapp,center,specialty,city,address,preferred_channel,preferences,objective,goal_service_id,service_ids,stage,follow_up_at,customer_id,referrer_id,owner_id)
  values(b,v->>'kind',v->>'full_name',v->>'phone',v->>'email',v->>'whatsapp',v->>'center',v->>'specialty',v->>'city',v->>'address',v->>'preferred_channel',v->>'preferences',v->>'objective',(v->>'goal_service_id')::uuid,array(select value::uuid from jsonb_array_elements_text(v->'service_ids')),v->>'stage',(v->>'follow_up_at')::timestamptz,cust,ref,auth.uid()) returning * into c;
 else
  update public.crm_contacts set kind=v->>'kind',full_name=v->>'full_name',phone=v->>'phone',email=v->>'email',whatsapp=v->>'whatsapp',center=v->>'center',specialty=v->>'specialty',city=v->>'city',address=v->>'address',preferred_channel=v->>'preferred_channel',preferences=v->>'preferences',objective=v->>'objective',goal_service_id=(v->>'goal_service_id')::uuid,service_ids=array(select value::uuid from jsonb_array_elements_text(v->'service_ids')),stage=v->>'stage',follow_up_at=(v->>'follow_up_at')::timestamptz,customer_id=cust,referrer_id=ref,revision=revision+1,updated_at=now() where id=target returning * into c;
 end if;
 insert into public.crm_history(contact_id,branch_id,actor_id,action,before_data,after_data,metadata) values(c.id,b,auth.uid(),case when target is null then 'CREAR_FICHA' else 'ACTUALIZAR_FICHA' end,old_data,to_jsonb(c),jsonb_build_object('duplicate_reason',reason));
 if nullif(trim(j->>'initial_note'),'') is not null then
  insert into public.crm_activities(contact_id,branch_id,channel,occurred_at,notes,outcome,created_by) values(c.id,b,'NOTA',now(),trim(j->>'initial_note'),'Nota previa registrada al guardar ficha',auth.uid());
  insert into public.crm_history(contact_id,branch_id,actor_id,action,after_data) values(c.id,b,auth.uid(),'AGREGAR_NOTA_DE_FICHA',jsonb_build_object('notes',trim(j->>'initial_note')));
 end if;
 perform public.log_audit_event('CRM','GUARDAR_FICHA',b,'crm_contacts',c.id,c.id::text,null,null,'{}');
 return to_jsonb(c);
end;$$;
create function private.crm_catalog(b uuid) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
 if not private.crm_scope(b) then raise exception 'CRM no autorizado en esta sucursal' using errcode='42501';end if;
 return jsonb_build_object('enabled',coalesce((select enabled from public.app_feature_flags where key='commercial_crm'),false),'can_write',private.crm_scope(b,'COMMERCIAL_WRITE'),'can_manage_services',public.has_role('SUPER_USUARIO'),'people',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.full_name)) from public.profiles p where p.id=auth.uid() or exists(select 1 from public.crm_contacts c where c.branch_id=b and c.owner_id=p.id) or exists(select 1 from public.crm_activities a where a.branch_id=b and a.created_by=p.id) or exists(select 1 from public.crm_history h where h.branch_id=b and h.actor_id=p.id)),'[]'),'services',coalesce((select jsonb_agg(to_jsonb(s) order by s.name) from public.crm_services s),'[]'),'referrers',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'full_name',r.full_name,'phone',r.phone,'email',r.email,'center',r.organization,'specialty',r.specialty,'city',r.city)) from public.medical_referrers r where (r.branch_id=b or r.branch_id is null) and not exists(select 1 from public.crm_contacts c where c.branch_id=b and c.referrer_id=r.id)),'[]'),'customers',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.customers c where c.active and c.id in (select l.customer_id from public.commercial_locations l where l.branch_id=b union select v.customer_id from public.commercial_visits v where v.branch_id=b union select x.customer_id from public.crm_contacts x where x.branch_id=b)),'[]'));
end;$$;
create function private.crm_review(b uuid,rows jsonb) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare result jsonb:='[]';item jsonb;clean jsonb;err text;matches jsonb;idx integer:=0;
begin
 if not private.crm_scope(b,'COMMERCIAL_WRITE') then raise exception 'Importación no autorizada' using errcode='42501';end if;
 if coalesce(jsonb_typeof(rows),'null')<>'array' or jsonb_array_length(rows)>500 then raise exception 'Revise un máximo de 500 filas por lote';end if;
 for item in select value from jsonb_array_elements(rows) loop
  idx:=idx+1;err:=null;clean:=null;matches:='[]';
  begin clean:=private.crm_clean(item->'data');matches:=private.crm_matches(b,clean,null);exception when others then err:=sqlerrm;end;
  result:=result||jsonb_build_array(jsonb_build_object('index',idx,'data',clean,'error',err,'matches',matches));
 end loop;return result;
end;$$;
create function private.crm_action(b uuid,action text,data jsonb,request uuid) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare old_request public.crm_requests;response jsonb;item jsonb;v jsonb;c public.crm_contacts;result jsonb:='[]';decision text;target uuid;expected integer;reason text;seen uuid[]:='{}';service uuid;activity uuid;rownum integer:=0;notes text;
begin
 if not private.crm_scope(b,'COMMERCIAL_WRITE') then raise exception 'Acceso comercial de escritura requerido' using errcode='42501';end if;
 if request is null then raise exception 'Identificador de solicitud requerido';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||request::text,0));
 select * into old_request from public.crm_requests where actor_id=auth.uid() and request_id=request;
 if found then if old_request.payload<>jsonb_build_object('branch',b,'action',action,'data',data) then raise exception 'Solicitud reutilizada con otros datos';end if;return old_request.response;end if;
 if not coalesce((select enabled from public.app_feature_flags where key='commercial_crm'),false) then raise exception 'CRM desactivado: no se guardaron cambios';end if;
 -- Serializes duplicate checks and writes for the same branch, including bulk/manual races.
 perform pg_advisory_xact_lock(hashtextextended('crm:'||b::text,0));
 if action='SAVE' then
  response:=private.crm_save(b,data->'fields',nullif(data->>'id','')::uuid,(data->>'revision')::integer,coalesce((data->>'allow_duplicate')::boolean,false),data->>'duplicate_reason');
 elsif action='IMPORT' then
  if coalesce(jsonb_typeof(data->'rows'),'null')<>'array' or jsonb_array_length(data->'rows') not between 1 and 500 then raise exception 'Lote de 1 a 500 filas requerido';end if;
  for item in select value from jsonb_array_elements(data->'rows') loop
   rownum:=rownum+1;decision:=item->>'decision';
   if decision='SKIP' then result:=result||jsonb_build_array(jsonb_build_object('index',rownum,'skipped',true));continue;end if;
   if not coalesce((item->>'approved')::boolean,false) then raise exception 'Fila % pendiente de aprobación',rownum;end if;
   if decision not in ('CREATE','UPDATE','LINK_REFERRER') or decision is null then raise exception 'Decisión requerida en fila %',rownum;end if;
   v:=item->'data';target:=null;expected:=null;reason:=item->>'duplicate_reason';
   if decision='UPDATE' then
    target:=(item->>'target_id')::uuid;expected:=(item->>'revision')::integer;
    if target is null or target=any(seen) then raise exception 'Seleccione una ficha distinta por fila';end if;seen:=array_append(seen,target);
    v:=v-array(select value from jsonb_array_elements_text(coalesce(item->'empty_fields','[]')));
    -- Empty spreadsheet cells never erase existing fields during bulk update.
    select jsonb_object_agg(key,value) into v from jsonb_each(v) where value<>'null'::jsonb and value<>'""'::jsonb and value<>'[]'::jsonb;
   elsif decision='LINK_REFERRER' then
    if nullif(item->>'target_id','') is null then raise exception 'Seleccione el referidor existente';end if;
    select * into c from public.crm_contacts where branch_id=b and referrer_id=(item->>'target_id')::uuid;
    if found then raise exception 'El referidor ya tiene ficha; vuelva a revisar el lote';end if;
    v:=v||jsonb_build_object('referrer_id',(item->>'target_id')::uuid,'kind','REFERIDOR');
   end if;
   begin
    response:=private.crm_save(b,v,target,expected,coalesce((item->>'allow_duplicate')::boolean,false),reason);
   exception when others then raise exception 'Fila %: %',rownum,sqlerrm;end;
   insert into public.crm_history(contact_id,branch_id,actor_id,action,after_data,metadata) values((response->>'id')::uuid,b,auth.uid(),'IMPORTAR_FILA',response,jsonb_build_object('file',left(item->>'file',200),'row',item->>'row','decision',decision,'request_id',request));
   result:=result||jsonb_build_array(jsonb_build_object('index',rownum,'id',response->>'id'));
  end loop;response:=jsonb_build_object('rows',result,'saved',true);
 elsif action='ACTIVITY' then
  select * into c from public.crm_contacts where id=(data->>'contact_id')::uuid and branch_id=b for update;if not found then raise exception 'Ficha no disponible';end if;
  if c.revision is distinct from (data->>'revision')::integer then raise exception 'Ficha modificada: actualice antes de registrar seguimiento' using errcode='40001';end if;
  notes:=trim(coalesce(data->>'notes',''));if length(notes) not between 2 and 4000 then raise exception 'Notas de 2 a 4000 caracteres requeridas';end if;
  if data->>'channel' not in ('VISITA','LLAMADA','WHATSAPP','CORREO','NOTA') or data->>'channel' is null then raise exception 'Canal no válido';end if;
  service:=nullif(data->>'service_id','')::uuid;if service is not null and not exists(select 1 from public.crm_services where id=service and active) then raise exception 'Servicio no válido';end if;
  if nullif(data->>'occurred_at','') is null or not isfinite((data->>'occurred_at')::timestamptz) or (data->>'occurred_at')::timestamptz>now()+interval '5 minutes' then raise exception 'Registre una visita realizada; para la próxima use seguimiento';end if;
  insert into public.crm_activities(contact_id,branch_id,channel,occurred_at,notes,outcome,service_id,follow_up_at,created_by) values(c.id,b,data->>'channel',(data->>'occurred_at')::timestamptz,notes,left(data->>'outcome',1000),service,nullif(data->>'follow_up_at','')::timestamptz,auth.uid()) returning id into activity;
  update public.crm_contacts set follow_up_at=nullif(data->>'follow_up_at','')::timestamptz,revision=revision+1,updated_at=now() where id=c.id;
  response:=jsonb_build_object('id',activity);
  insert into public.crm_history(contact_id,branch_id,actor_id,action,after_data) values(c.id,b,auth.uid(),'REGISTRAR_ACTIVIDAD',data||response);
  perform public.log_audit_event('CRM','REGISTRAR_ACTIVIDAD',b,'crm_activities',activity,activity::text,null,null,'{}');
 elsif action='SERVICE' then
  if not public.has_role('SUPER_USUARIO') then raise exception 'Solo el Super Usuario configura servicios CRM' using errcode='42501';end if;
  if length(trim(coalesce(data->>'code',''))) not between 2 and 50 or length(trim(coalesce(data->>'name',''))) not between 2 and 200 then raise exception 'Código y nombre de servicio requeridos';end if;
  service:=nullif(data->>'id','')::uuid;
  if service is null then insert into public.crm_services(code,name) values(upper(trim(data->>'code')),trim(data->>'name')) returning id into service;
  else update public.crm_services set name=trim(data->>'name'),active=coalesce((data->>'active')::boolean,true) where id=service;if not found then raise exception 'Servicio no encontrado';end if;end if;
  response:=jsonb_build_object('id',service);perform public.log_audit_event('CRM','CONFIGURAR_SERVICIO',b,'crm_services',service,service::text,null,data,'{}');
 else raise exception 'Acción CRM no reconocida';end if;
 insert into public.crm_requests(actor_id,request_id,payload,response) values(auth.uid(),request,jsonb_build_object('branch',b,'action',action,'data',data),response);
 return response;
end;$$;
revoke all on function private.crm_phone(text),private.crm_clean(jsonb),private.crm_matches(uuid,jsonb,uuid),private.crm_save(uuid,jsonb,uuid,integer,boolean,text),private.crm_catalog(uuid),private.crm_review(uuid,jsonb),private.crm_action(uuid,text,jsonb,uuid) from public,anon,authenticated;
grant execute on function private.crm_catalog(uuid),private.crm_review(uuid,jsonb),private.crm_action(uuid,text,jsonb,uuid) to authenticated;
create function public.crm_catalog(p_branch uuid) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select private.crm_catalog(p_branch)$$;
create function public.crm_review(p_branch uuid,p_rows jsonb) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select private.crm_review(p_branch,p_rows)$$;
create function public.crm_action(p_branch uuid,p_action text,p_data jsonb,p_request uuid) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select private.crm_action(p_branch,p_action,p_data,p_request)$$;
revoke all on function public.crm_catalog(uuid),public.crm_review(uuid,jsonb),public.crm_action(uuid,text,jsonb,uuid) from public,anon;
grant execute on function public.crm_catalog(uuid),public.crm_review(uuid,jsonb),public.crm_action(uuid,text,jsonb,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
