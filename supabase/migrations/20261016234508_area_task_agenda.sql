begin;
create table public.work_areas(code text primary key,name text not null);
insert into public.work_areas values('OPERACIONES','Operaciones'),('LABORATORIO','Laboratorio'),('DONANTES','Donantes y citas'),('INVENTARIO','Inventario'),('COMPRAS','Compras y recepción'),('COMERCIAL','Comercial'),('FINANZAS','Finanzas'),('CALIDAD','Calidad'),('SISTEMAS','Sistemas');
create table public.work_area_roles(role_id uuid not null references public.roles(id),area_code text not null references public.work_areas(code),can_manage boolean not null default false,can_review boolean not null default false,primary key(role_id,area_code));
insert into public.work_area_roles
select r.id,a.code,
 r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','GERENCIA_GENERAL') or r.code='CALIDAD' and a.code='CALIDAD' or r.code='ENCARGADA_LABORATORIO' or r.code in ('INVENTARIO','FINANZAS','MEDICO_GERENTE_TECNICO'),
 r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','GERENCIA_GENERAL','CALIDAD','ENCARGADA_LABORATORIO','MEDICO_GERENTE_TECNICO')
from public.roles r cross join public.work_areas a where
 r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','GERENCIA_GENERAL','CALIDAD','SOCIO','CONSULTA')
 or r.code='ASISTENTE_OPERACIONES' and a.code in ('OPERACIONES','DONANTES','COMPRAS','COMERCIAL')
 or r.code='LABORATORIO' and a.code in ('LABORATORIO','DONANTES')
 or r.code='ENCARGADA_LABORATORIO' and a.code in ('LABORATORIO','DONANTES','CALIDAD')
 or r.code='INVENTARIO' and a.code in ('INVENTARIO','COMPRAS')
 or r.code='FINANZAS' and a.code='FINANZAS'
 or r.code='MEDICO_GERENTE_TECNICO' and a.code in ('LABORATORIO','CALIDAD')
 or r.code='SUCURSAL' and a.code in ('OPERACIONES','LABORATORIO','DONANTES','INVENTARIO')
 or r.code='TI' and a.code='SISTEMAS';
insert into public.app_permissions(permission_code,module,description,risk_level) values
('WORK_AGENDA_VIEW','WORK_AGENDA','Consultar tareas y seguimiento por área','SENSIBLE'),
('WORK_AGENDA_WRITE','WORK_AGENDA','Registrar y ejecutar tareas de su ámbito','CRITICO'),
('WORK_AGENDA_MANAGE','WORK_AGENDA','Asignar, reprogramar y supervisar tareas','CRITICO'),
('WORK_AGENDA_REVIEW','WORK_AGENDA','Revisar evidencias de otro ejecutor','CRITICO');
insert into public.role_permissions(role_id,permission_code) select r.id,p.permission_code from public.roles r cross join public.app_permissions p where
 p.permission_code='WORK_AGENDA_VIEW'
 or p.permission_code='WORK_AGENDA_WRITE' and r.code not in ('SOCIO','CONSULTA')
 or p.permission_code='WORK_AGENDA_MANAGE' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','GERENCIA_GENERAL','CALIDAD','ENCARGADA_LABORATORIO','INVENTARIO','FINANZAS','MEDICO_GERENTE_TECNICO')
 or p.permission_code='WORK_AGENDA_REVIEW' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','GERENCIA_GENERAL','CALIDAD','ENCARGADA_LABORATORIO','MEDICO_GERENTE_TECNICO')
on conflict do nothing;
insert into public.app_module_catalog(route_key,title,group_name,permission_code) values('areaagenda','Agenda por área','TRABAJO DIARIO','WORK_AGENDA_VIEW');
insert into public.role_module_access(role_id,route_key,enabled) select id,'areaagenda',true from public.roles;
create table public.work_tasks(
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),area_code text not null references public.work_areas(code),
 title text not null check(length(trim(title)) between 1 and 250),description text,owner_id uuid not null references public.profiles(id),owner_name text not null,
 due_at timestamptz not null,original_due_at timestamptz not null,priority text not null check(priority in ('NORMAL','ALTA','CRITICA')),
 status text not null default 'PENDIENTE' check(status in ('PENDIENTE','EN_CURSO','BLOQUEADA','EN_REVISION','COMPLETADA','CANCELADA')),
 checklist jsonb not null default '[]',evidence text,requires_review boolean not null default true,
 source_route text references public.app_module_catalog(route_key),source_reference text,
 submitted_by uuid references public.profiles(id),submitted_at timestamptz,reviewed_by uuid references public.profiles(id),reviewer_name text,reviewed_at timestamptz,review_note text,
 completed_at timestamptz,last_note text,revision integer not null default 1,
 creation_key uuid not null,creation_hash text not null,occurrence integer not null default 0,unique(creation_key,occurrence),
 created_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.work_task_history(id uuid primary key default gen_random_uuid(),task_id uuid not null references public.work_tasks(id),branch_id uuid not null references public.branches(id),area_code text not null,actor_id uuid not null references public.profiles(id),actor_name text not null,changed_at timestamptz not null default now(),before_data jsonb,after_data jsonb not null);
create index work_tasks_branch_due_idx on public.work_tasks(branch_id,due_at,id);
create index work_tasks_owner_due_idx on public.work_tasks(owner_id,due_at) where status not in ('COMPLETADA','CANCELADA');
create index work_task_history_task_idx on public.work_task_history(task_id,changed_at,id);
create function public.work_agenda_access(p_branch uuid,p_area text,p_manage boolean default false,p_review boolean default false) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and public.wf_active_actor() and public.has_permission('WORK_AGENDA_VIEW') and public.can_access_branch(p_branch)
 and (not p_manage or public.has_permission('WORK_AGENDA_MANAGE')) and (not p_review or public.has_permission('WORK_AGENDA_REVIEW'))
 and (public.has_role('SUPER_USUARIO') or exists(select 1 from public.work_area_roles ar join public.user_roles ur on ur.role_id=ar.role_id where ur.user_id=auth.uid() and ar.area_code=p_area and (not p_manage or ar.can_manage) and (not p_review or ar.can_review)));
$$;
revoke all on function public.work_agenda_access(uuid,text,boolean,boolean) from public,anon;
grant execute on function public.work_agenda_access(uuid,text,boolean,boolean) to authenticated;
create function private.work_owner_eligible(p_user uuid,p_branch uuid,p_area text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.profiles p join public.user_roles ur on ur.user_id=p.id join public.roles r on r.id=ur.role_id join public.work_area_roles ar on ar.role_id=r.id where p.id=p_user and p.active and ar.area_code=p_area and (r.code='SUPER_USUARIO' or ur.branch_id=p_branch) and (r.code='SUPER_USUARIO' or exists(select 1 from public.role_permissions rp join public.app_permissions ap on ap.permission_code=rp.permission_code where rp.role_id=r.id and rp.permission_code='WORK_AGENDA_WRITE' and ap.active)));
$$;
revoke all on function private.work_owner_eligible(uuid,uuid,text) from public,anon,authenticated;
create function public.work_agenda_people(p_branch uuid,p_area text) returns table(id uuid,full_name text) language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
 if not public.work_agenda_access(p_branch,p_area) then raise exception 'Área o sucursal no autorizada.' using errcode='42501';end if;
 return query select p.id,p.full_name from public.profiles p where private.work_owner_eligible(p.id,p_branch,p_area) and (p.id=auth.uid() or public.work_agenda_access(p_branch,p_area,true)) order by p.full_name,p.id;
end$$;
revoke all on function public.work_agenda_people(uuid,text) from public,anon;
grant execute on function public.work_agenda_people(uuid,text) to authenticated;
alter table public.work_areas enable row level security;alter table public.work_area_roles enable row level security;alter table public.work_tasks enable row level security;alter table public.work_task_history enable row level security;
revoke all on public.work_areas,public.work_area_roles,public.work_tasks,public.work_task_history from public,anon,authenticated;
grant select on public.work_areas,public.work_area_roles,public.work_tasks,public.work_task_history to authenticated;
grant insert,update on public.work_tasks to authenticated;
create policy work_areas_read on public.work_areas for select to authenticated using((select public.wf_active_actor()) and (select public.has_permission('WORK_AGENDA_VIEW')));
create policy work_area_roles_read on public.work_area_roles for select to authenticated using((select public.wf_active_actor()) and role_id in(select role_id from public.user_roles where user_id=(select auth.uid())));
create policy work_tasks_read on public.work_tasks for select to authenticated using(public.work_agenda_access(branch_id,area_code));
create policy work_tasks_insert on public.work_tasks for insert to authenticated with check(public.work_agenda_access(branch_id,area_code) and (select public.has_permission('WORK_AGENDA_WRITE')));
create policy work_tasks_update on public.work_tasks for update to authenticated using(public.work_agenda_access(branch_id,area_code) and (owner_id=(select auth.uid()) or public.work_agenda_access(branch_id,area_code,true) or public.work_agenda_access(branch_id,area_code,false,true))) with check(public.work_agenda_access(branch_id,area_code));
create policy work_history_read on public.work_task_history for select to authenticated using(public.work_agenda_access(branch_id,area_code));
create view public.vw_my_work_areas with(security_invoker=true) as select a.code,a.name,bool_or(ar.can_manage) and public.has_permission('WORK_AGENDA_MANAGE') as can_manage,bool_or(ar.can_review) and public.has_permission('WORK_AGENDA_REVIEW') as can_review from public.work_areas a join public.work_area_roles ar on ar.area_code=a.code join public.user_roles ur on ur.role_id=ar.role_id where ur.user_id=auth.uid() group by a.code,a.name;
grant select on public.vw_my_work_areas to authenticated;revoke all on public.vw_my_work_areas from public,anon;
create view public.vw_work_agenda_branches with(security_invoker=true) as select id,code,name from public.branches where active and public.wf_active_actor() and public.has_permission('WORK_AGENDA_VIEW') and public.can_access_branch(id);
revoke all on public.vw_work_agenda_branches from public,anon;grant select on public.vw_work_agenda_branches to authenticated;
create function private.guard_work_task() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare actor uuid:=auth.uid();manager boolean;reviewer boolean;x jsonb;changed_header boolean;
begin
 if actor is null or not public.work_agenda_access(new.branch_id,new.area_code) then raise exception 'Área o sucursal no autorizada.' using errcode='42501';end if;
 manager:=public.work_agenda_access(new.branch_id,new.area_code,true);reviewer:=public.work_agenda_access(new.branch_id,new.area_code,false,true);
 if not public.has_permission('WORK_AGENDA_WRITE') and not manager and not reviewer then raise exception 'No tiene permiso para gestionar tareas.' using errcode='42501';end if;
 if not new.requires_review and (new.area_code='CALIDAD' or new.priority='CRITICA' or (tg_op='INSERT' or new.requires_review is distinct from old.requires_review) and not manager) then raise exception 'Esta tarea requiere revisión independiente.';end if;
 if (tg_op='INSERT' or new.owner_id is distinct from old.owner_id) and not private.work_owner_eligible(new.owner_id,new.branch_id,new.area_code) then raise exception 'Seleccione un responsable activo con acceso al área y sucursal.';end if;
 if jsonb_typeof(new.checklist) is distinct from 'array' or jsonb_array_length(new.checklist)>30 then raise exception 'La lista de comprobación admite hasta 30 puntos.';end if;
 for x in select value from jsonb_array_elements(new.checklist) loop
  if jsonb_typeof(x) is distinct from 'object' or nullif(trim(x->>'label'),'') is null or jsonb_typeof(x->'done') is distinct from 'boolean' then raise exception 'Punto de comprobación no válido.';end if;
 end loop;
 if new.status='BLOQUEADA' and nullif(trim(new.last_note),'') is null then raise exception 'Documente el bloqueo y la ayuda requerida.';end if;
 if tg_op='INSERT' then
  if not public.has_permission('WORK_AGENDA_WRITE') or not manager and new.owner_id<>actor then raise exception 'Solo puede crear tareas propias.' using errcode='42501';end if;
  if new.status<>'PENDIENTE' then raise exception 'La tarea debe iniciar pendiente.';end if;
  new.created_by:=actor;new.created_at:=now();new.updated_at:=now();new.revision:=1;new.original_due_at:=new.due_at;
  new.checklist:=coalesce((select jsonb_agg(jsonb_build_object('label',trim(v->>'label'),'done',false)) from jsonb_array_elements(new.checklist)v),'[]');
  new.evidence:=null;new.completed_at:=null;new.submitted_by:=null;new.submitted_at:=null;new.reviewed_by:=null;new.reviewed_at:=null;new.reviewer_name:=null;new.review_note:=null;
 else
  if new.id<>old.id or new.branch_id<>old.branch_id or new.area_code<>old.area_code or new.created_by<>old.created_by or new.creation_key<>old.creation_key or new.creation_hash<>old.creation_hash or new.occurrence<>old.occurrence or new.original_due_at<>old.original_due_at or new.created_at<>old.created_at then raise exception 'La identidad y fecha original de la tarea son inmutables.';end if;
  if (to_jsonb(new)-array['status','title','description','owner_id','due_at','priority','checklist','evidence','requires_review','source_route','source_reference','last_note','review_note']) is distinct from (to_jsonb(old)-array['status','title','description','owner_id','due_at','priority','checklist','evidence','requires_review','source_route','source_reference','last_note','review_note']) then raise exception 'No puede modificar los campos de trazabilidad.';end if;
  changed_header:=row(new.title,new.description,new.owner_id,new.due_at,new.priority,new.requires_review,new.source_route,new.source_reference) is distinct from row(old.title,old.description,old.owner_id,old.due_at,old.priority,old.requires_review,old.source_route,old.source_reference);
  if changed_header and (not manager or old.status in ('EN_REVISION','COMPLETADA','CANCELADA')) then raise exception 'Solo la gerencia del área puede editar una tarea activa.';end if;
  if (new.owner_id<>old.owner_id or new.due_at<>old.due_at) and nullif(trim(new.last_note),'') is null then raise exception 'Explique la reasignación o reprogramación.';end if;
  if new.review_note is distinct from old.review_note and not (old.status='EN_REVISION' and new.status in ('COMPLETADA','EN_CURSO') and reviewer and actor<>old.owner_id) then raise exception 'Solo el revisor puede documentar una revisión.';end if;
  if row(new.evidence,new.checklist) is distinct from row(old.evidence,old.checklist) and (actor<>old.owner_id or not public.has_permission('WORK_AGENDA_WRITE') or old.status in ('EN_REVISION','COMPLETADA','CANCELADA')) then raise exception 'Solo el responsable puede registrar la ejecución activa.';end if;
  if new.status<>old.status then
   if new.status='CANCELADA' then
    if not manager or old.status in ('COMPLETADA','CANCELADA') or nullif(trim(new.last_note),'') is null then raise exception 'La cancelación requiere gerencia y motivo.';end if;
   elsif old.status in ('COMPLETADA','CANCELADA') then
    if new.status<>'EN_CURSO' or not manager or nullif(trim(new.last_note),'') is null then raise exception 'La reapertura requiere gerencia y motivo.';end if;
    new.evidence:=null;new.checklist:=coalesce((select jsonb_agg(jsonb_build_object('label',v->>'label','done',false)) from jsonb_array_elements(new.checklist)v),'[]');new.completed_at:=null;new.submitted_at:=null;new.submitted_by:=null;new.reviewed_at:=null;new.reviewed_by:=null;new.reviewer_name:=null;new.review_note:=null;
   elsif old.status='EN_REVISION' then
    if new.status not in ('COMPLETADA','EN_CURSO') or not reviewer or actor=old.owner_id or actor=old.submitted_by or nullif(trim(new.review_note),'') is null then raise exception 'La revisión requiere otra persona autorizada y su observación.';end if;
    new.reviewed_by:=actor;new.reviewer_name:=(select full_name from public.profiles where id=actor);new.reviewed_at:=now();if new.status='COMPLETADA' then new.completed_at:=now();end if;
   else
    if actor<>old.owner_id or not public.has_permission('WORK_AGENDA_WRITE') or new.status not in ('EN_CURSO','BLOQUEADA','EN_REVISION','COMPLETADA') then raise exception 'Transición de tarea no autorizada.';end if;
    if new.status='BLOQUEADA' and nullif(trim(new.last_note),'') is null then raise exception 'Documente el bloqueo y la ayuda requerida.';end if;
    if new.status in ('EN_REVISION','COMPLETADA') then
     if nullif(trim(new.evidence),'') is null or exists(select 1 from jsonb_array_elements(new.checklist)v where not (v->>'done')::boolean) then raise exception 'Complete la lista y registre evidencia antes de enviar.';end if;
     if new.requires_review and new.status<>'EN_REVISION' then raise exception 'La tarea requiere revisión independiente.';end if;
     new.submitted_by:=actor;new.submitted_at:=now();new.reviewed_by:=null;new.reviewed_at:=null;new.reviewer_name:=null;new.review_note:=null;
     if new.status='COMPLETADA' then new.completed_at:=now();end if;
    end if;
   end if;
  elsif old.status in ('COMPLETADA','CANCELADA') then raise exception 'La tarea está archivada; use una reapertura con motivo.';
  end if;
  if new.owner_id<>old.owner_id then new.evidence:=null;new.checklist:=coalesce((select jsonb_agg(jsonb_build_object('label',v->>'label','done',false)) from jsonb_array_elements(new.checklist)v),'[]');end if;
  new.revision:=old.revision+1;new.updated_at:=now();
 end if;
 new.owner_name:=(select coalesce(full_name,'Usuario activo') from public.profiles where id=new.owner_id);
 return new;
end$$;
revoke all on function private.guard_work_task() from public,anon,authenticated;
create trigger work_task_guard before insert or update on public.work_tasks for each row execute function private.guard_work_task();
create function private.audit_work_task() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$begin
 insert into public.work_task_history(task_id,branch_id,area_code,actor_id,actor_name,before_data,after_data) values(new.id,new.branch_id,new.area_code,auth.uid(),(select coalesce(full_name,'Usuario activo') from public.profiles where id=auth.uid()),case when tg_op='UPDATE' then to_jsonb(old) end,to_jsonb(new));return new;
end$$;
revoke all on function private.audit_work_task() from public,anon,authenticated;
create trigger work_task_audit after insert or update on public.work_tasks for each row execute function private.audit_work_task();
create function public.work_task_action(p_action text,p_data jsonb) returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare t public.work_tasks%rowtype;key uuid;n integer;step integer;i integer;ids jsonb:='[]';due timestamptz;
begin
 if not public.wf_active_actor() or not public.has_permission('WORK_AGENDA_VIEW') then raise exception 'Sesión o permiso no válido.' using errcode='42501';end if;
 if p_action='CREATE' then
  key:=(p_data->>'request_id')::uuid;n:=coalesce((p_data->>'occurrences')::integer,1);step:=coalesce((p_data->>'interval_days')::integer,1);due:=(p_data->>'due_at')::timestamptz;
  if key is null or n not between 1 and 31 or step not in (1,7) or due is null then raise exception 'Revise fechas y repeticiones: máximo 31 ocurrencias diarias o semanales.';end if;
  if exists(select 1 from public.work_tasks where creation_key=key) then
   if exists(select 1 from public.work_tasks where creation_key=key and (creation_hash<>md5(p_data::text) or created_by<>auth.uid())) then raise exception 'La solicitud ya existe con otros datos.';end if;
   return (select jsonb_build_object('ids',jsonb_agg(id),'already_created',true) from public.work_tasks where creation_key=key);
  end if;
  for i in 0..n-1 loop
   insert into public.work_tasks(branch_id,area_code,title,description,owner_id,owner_name,due_at,original_due_at,priority,checklist,requires_review,source_route,source_reference,creation_key,creation_hash,occurrence,created_by)
   values((p_data->>'branch_id')::uuid,p_data->>'area_code',trim(p_data->>'title'),nullif(trim(p_data->>'description'),''),(p_data->>'owner_id')::uuid,'',due+make_interval(days=>i*step),due,p_data->>'priority',coalesce(p_data->'checklist','[]'),coalesce((p_data->>'requires_review')::boolean,true),nullif(p_data->>'source_route',''),nullif(trim(p_data->>'source_reference'),''),key,md5(p_data::text),i,auth.uid()) returning * into t;
   ids:=ids||jsonb_build_array(t.id);
  end loop;
  return jsonb_build_object('ids',ids);
 end if;
 select * into t from public.work_tasks where id=(p_data->>'id')::uuid for update;
 if not found then raise exception 'Tarea no disponible en su ámbito.';end if;
 if (p_data->>'revision')::integer is distinct from t.revision then raise exception 'La tarea cambió. Actualice y vuelva a intentar.' using errcode='40001';end if;
 if p_action='START' and t.status not in ('PENDIENTE','BLOQUEADA') or p_action='BLOCK' and t.status not in ('PENDIENTE','EN_CURSO') or p_action='SUBMIT' and t.status not in ('PENDIENTE','EN_CURSO','BLOQUEADA') or p_action in ('APPROVE','RETURN') and t.status<>'EN_REVISION' or p_action='REOPEN' and t.status not in ('COMPLETADA','CANCELADA') then raise exception 'La acción no corresponde al estado de la tarea.';end if;
 if p_action in ('BLOCK','CANCEL','REOPEN') and nullif(trim(p_data->>'last_note'),'') is null then raise exception 'Documente el bloqueo o el motivo del cambio.';end if;
 if p_action='SAVE' then
  update public.work_tasks set evidence=nullif(trim(p_data->>'evidence'),''),checklist=p_data->'checklist',last_note=nullif(trim(p_data->>'last_note'),'') where id=t.id;
 elsif p_action='PLAN' then
  update public.work_tasks set title=trim(p_data->>'title'),description=nullif(trim(p_data->>'description'),''),owner_id=(p_data->>'owner_id')::uuid,due_at=(p_data->>'due_at')::timestamptz,priority=p_data->>'priority',requires_review=case when p_data->>'priority'='CRITICA' then true else requires_review end,last_note=trim(p_data->>'last_note') where id=t.id;
 elsif p_action in ('START','BLOCK','SUBMIT','APPROVE','RETURN','CANCEL','REOPEN') then
  update public.work_tasks set evidence=case when p_action='SUBMIT' and p_data?'evidence' then nullif(trim(p_data->>'evidence'),'') else evidence end,checklist=case when p_action='SUBMIT' and p_data?'checklist' then p_data->'checklist' else checklist end,status=case p_action when 'START' then 'EN_CURSO' when 'BLOCK' then 'BLOQUEADA' when 'SUBMIT' then case when t.requires_review then 'EN_REVISION' else 'COMPLETADA' end when 'APPROVE' then 'COMPLETADA' when 'RETURN' then 'EN_CURSO' when 'CANCEL' then 'CANCELADA' when 'REOPEN' then 'EN_CURSO' end,last_note=coalesce(nullif(trim(p_data->>'last_note'),''),last_note),review_note=case when p_action in ('APPROVE','RETURN') then trim(p_data->>'review_note') else review_note end where id=t.id;
 else raise exception 'Acción de tarea no válida.';end if;
 if not found then raise exception 'No se pudo actualizar la tarea.' using errcode='42501';end if;
 return jsonb_build_object('id',t.id);
end$$;
revoke all on function public.work_task_action(text,jsonb) from public,anon;
grant execute on function public.work_task_action(text,jsonb) to authenticated;
comment on table public.work_tasks is 'Agenda de responsabilidades. Completar seguimiento no cierra CAPA, libera sangre ni recibe compras automáticamente. Repeticiones finitas generan ocurrencias independientes.';
notify pgrst,'reload schema';
commit;
