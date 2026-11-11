begin;
insert into public.app_feature_flags(key,enabled,mode,description) values('twelve_week_execution',false,'OFF','Ciclos de ejecución de 12 semanas enlazados a tareas y revisión de Agenda por área');
insert into public.app_module_catalog(route_key,title,group_name,permission_code) values('twelveweek','Plan de 12 Semanas','GESTIÓN','PROJECTS_VIEW') on conflict(route_key) do nothing;
insert into public.role_module_access(role_id,route_key,enabled) select role_id,'twelveweek',true from public.role_permissions where permission_code='PROJECTS_VIEW' on conflict do nothing;
create table public.twelve_week_cycles(id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),area_code text not null references public.work_areas(code),title text not null check(length(trim(title)) between 3 and 200),start_date date not null,end_date date not null,objective text not null default '',status text not null check(status in ('BORRADOR','ACTIVO','CERRADO')),revision integer not null default 1,created_by uuid not null references public.profiles(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),check(end_date=start_date+83));
create table public.twelve_week_goals(id uuid primary key default gen_random_uuid(),cycle_id uuid not null references public.twelve_week_cycles(id),week_number integer not null check(week_number between 1 and 12),goal text not null check(length(trim(goal)) between 3 and 1000),target_metric text,target_value numeric check(target_value>=0 and target_value::text not in ('NaN','Infinity','-Infinity')),revision integer not null default 1,updated_by uuid not null references public.profiles(id),updated_at timestamptz not null default now(),unique(cycle_id,week_number));
create table public.twelve_week_task_links(task_id uuid primary key references public.work_tasks(id),cycle_id uuid not null references public.twelve_week_cycles(id),week_number integer not null check(week_number between 1 and 12),created_by uuid not null references public.profiles(id),created_at timestamptz not null default now());
create index twelve_week_cycles_scope on public.twelve_week_cycles(branch_id,area_code,start_date desc);
create index twelve_week_links_cycle on public.twelve_week_task_links(cycle_id,week_number);
create table public.twelve_week_requests(actor_id uuid not null,request_id uuid not null,payload jsonb not null,response jsonb not null,created_at timestamptz not null default now(),primary key(actor_id,request_id));
create function private.twelve_week_scope(b uuid,a text,manage boolean default false) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and public.wf_active_actor() and exists(select 1 from public.branches where id=b and active) and exists(select 1 from public.work_areas where code=a) and exists(
 select 1 from public.user_roles ur join public.roles ro on ro.id=ur.role_id
 where ur.user_id=auth.uid() and (ur.branch_id=b or ro.code='SUPER_USUARIO')
 and exists(select 1 from public.role_permissions rp join public.app_permissions ap on ap.permission_code=rp.permission_code and ap.active where rp.role_id=ur.role_id and rp.permission_code='PROJECTS_VIEW')
 and exists(select 1 from public.role_permissions rp join public.app_permissions ap on ap.permission_code=rp.permission_code and ap.active where rp.role_id=ur.role_id and rp.permission_code='WORK_AGENDA_VIEW')
 and (not manage or exists(select 1 from public.role_permissions rp join public.app_permissions ap on ap.permission_code=rp.permission_code and ap.active where rp.role_id=ur.role_id and rp.permission_code='WORK_AGENDA_MANAGE') and exists(select 1 from public.role_permissions rp join public.app_permissions ap on ap.permission_code=rp.permission_code and ap.active where rp.role_id=ur.role_id and rp.permission_code='WORK_AGENDA_WRITE'))
 and (ro.code='SUPER_USUARIO' or exists(select 1 from public.work_area_roles ar where ar.role_id=ur.role_id and ar.area_code=a and (not manage or ar.can_manage))));
$$;
revoke all on function private.twelve_week_scope(uuid,text,boolean) from public,anon;grant execute on function private.twelve_week_scope(uuid,text,boolean) to authenticated;
alter table public.twelve_week_cycles enable row level security;alter table public.twelve_week_goals enable row level security;alter table public.twelve_week_task_links enable row level security;alter table public.twelve_week_requests enable row level security;
revoke all on public.twelve_week_cycles,public.twelve_week_goals,public.twelve_week_task_links,public.twelve_week_requests from public,anon,authenticated;
grant select on public.twelve_week_cycles,public.twelve_week_goals,public.twelve_week_task_links to authenticated;
create policy twelve_week_cycles_read on public.twelve_week_cycles for select to authenticated using(private.twelve_week_scope(branch_id,area_code));
create policy twelve_week_goals_read on public.twelve_week_goals for select to authenticated using(exists(select 1 from public.twelve_week_cycles c where c.id=cycle_id and private.twelve_week_scope(c.branch_id,c.area_code)));
create policy twelve_week_links_read on public.twelve_week_task_links for select to authenticated using(exists(select 1 from public.twelve_week_cycles c where c.id=cycle_id and private.twelve_week_scope(c.branch_id,c.area_code)));
create function private.twelve_week_context() returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
 if not public.wf_active_actor() or not public.has_permission('PROJECTS_VIEW') then raise exception 'Sesión o permiso de proyectos requerido' using errcode='42501';end if;
 return jsonb_build_object('enabled',coalesce((select enabled from public.app_feature_flags where key='twelve_week_execution'),false),'actorId',auth.uid(),
 'branches',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'name',b.name) order by b.name) from public.branches b where b.active and exists(select 1 from public.work_areas a where private.twelve_week_scope(b.id,a.code))),'[]'),
 'areas',coalesce((select jsonb_agg(jsonb_build_object('code',a.code,'name',a.name,'branch_ids',(select coalesce(jsonb_agg(b.id),'[]') from public.branches b where b.active and private.twelve_week_scope(b.id,a.code)),'can_manage',exists(select 1 from public.branches b where b.active and private.twelve_week_scope(b.id,a.code,true)),'can_review',false) order by a.name) from public.work_areas a where exists(select 1 from public.branches b where b.active and private.twelve_week_scope(b.id,a.code))),'[]'));
end;$$;
create function private.twelve_week_catalog(b uuid,a text) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
 if not private.twelve_week_scope(b,a) then raise exception 'Plan no autorizado en esta sucursal y área' using errcode='42501';end if;
 return jsonb_build_object('enabled',coalesce((select enabled from public.app_feature_flags where key='twelve_week_execution'),false),'can_manage',private.twelve_week_scope(b,a,true),
 'cycles',coalesce((select jsonb_agg(to_jsonb(c) order by c.start_date desc,c.id) from public.twelve_week_cycles c where c.branch_id=b and c.area_code=a),'[]'),
 'goals',coalesce((select jsonb_agg(to_jsonb(g) order by g.week_number,g.id) from public.twelve_week_goals g join public.twelve_week_cycles c on c.id=g.cycle_id where c.branch_id=b and c.area_code=a),'[]'),
 'tasks',coalesce((select jsonb_agg(to_jsonb(t)||jsonb_build_object('cycle_id',l.cycle_id,'week_number',l.week_number) order by t.due_at,t.id) from public.twelve_week_task_links l join public.twelve_week_cycles c on c.id=l.cycle_id join public.work_tasks t on t.id=l.task_id where c.branch_id=b and c.area_code=a and t.branch_id=b and t.area_code=a),'[]'));
end;$$;
create function private.twelve_week_action(b uuid,a text,op text,j jsonb,req uuid) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare old_request public.twelve_week_requests;c public.twelve_week_cycles;g public.twelve_week_goals;response jsonb;before_data jsonb;ident uuid;target numeric;d date;next_status text;week integer;due timestamptz;task_result jsonb;owner uuid;
begin
 if not private.twelve_week_scope(b,a,true) then raise exception 'Gestión del plan no autorizada en esta sucursal y área' using errcode='42501';end if;
 if not coalesce((select enabled from public.app_feature_flags where key='twelve_week_execution'),false) then raise exception 'Ciclos de 12 semanas desactivados';end if;
 if req is null or coalesce(jsonb_typeof(j),'null')<>'object' then raise exception 'Solicitud inválida';end if;
 perform pg_advisory_xact_lock(hashtextextended('tw:'||auth.uid()::text||req::text,0));
 select * into old_request from public.twelve_week_requests where actor_id=auth.uid() and request_id=req;
 if found then if old_request.payload<>jsonb_build_object('branch',b,'area',a,'action',op,'data',j) then raise exception 'Solicitud reutilizada con otros datos';end if;return old_request.response;end if;
 if op='CYCLE_SAVE' then
  if length(trim(coalesce(j->>'title',''))) not between 3 and 200 or length(coalesce(j->>'objective',''))>2000 then raise exception 'Título de 3 a 200 caracteres y objetivo de máximo 2000';end if;
  d:=nullif(j->>'start_date','')::date;next_status:=j->>'status';if d is null or not isfinite(d) or next_status not in ('BORRADOR','ACTIVO','CERRADO') or next_status is null then raise exception 'Inicio y estado válidos requeridos';end if;
  ident:=nullif(j->>'id','')::uuid;
  if ident is null then
   if next_status='CERRADO' then raise exception 'Un ciclo nuevo debe iniciar borrador o activo';end if;
   insert into public.twelve_week_cycles(branch_id,area_code,title,start_date,end_date,objective,status,created_by) values(b,a,trim(j->>'title'),d,d+83,trim(coalesce(j->>'objective','')),next_status,auth.uid()) returning * into c;
  else
   select * into c from public.twelve_week_cycles where id=ident and branch_id=b and area_code=a for update;if not found then raise exception 'Ciclo no accesible' using errcode='42501';end if;
   if c.revision is distinct from (j->>'revision')::integer then raise exception 'El ciclo cambió; actualice' using errcode='40001';end if;
   before_data:=to_jsonb(c);
   if c.status='CERRADO' or d<>c.start_date or c.status='ACTIVO' and next_status='BORRADOR' then raise exception 'Inicio inmutable y ciclo cerrado sin reapertura';end if;
   update public.twelve_week_cycles set title=trim(j->>'title'),objective=trim(coalesce(j->>'objective','')),status=next_status,revision=revision+1,updated_at=now() where id=ident returning * into c;
  end if;
  ident:=c.id;response:=to_jsonb(c);
 elsif op in ('GOAL_SAVE','TASK_CREATE') then
  select * into c from public.twelve_week_cycles where id=(j->>'cycle_id')::uuid and branch_id=b and area_code=a for update;if not found then raise exception 'Ciclo no accesible' using errcode='42501';end if;
  if c.status='CERRADO' then raise exception 'El ciclo está cerrado';end if;
  week:=(j->>'week_number')::integer;if week is null or week not between 1 and 12 then raise exception 'Semana entre 1 y 12 requerida';end if;
  if op='GOAL_SAVE' then
   if length(trim(coalesce(j->>'goal',''))) not between 3 and 1000 or length(coalesce(j->>'target_metric',''))>200 then raise exception 'Meta de 3 a 1000 caracteres y métrica de máximo 200';end if;
   target:=nullif(j->>'target_value','')::numeric;if target<0 or target::text in ('NaN','Infinity','-Infinity') then raise exception 'Valor objetivo finito y no negativo requerido';end if;
   select * into g from public.twelve_week_goals where cycle_id=c.id and week_number=week for update;
   if found then
    if g.id is distinct from nullif(j->>'id','')::uuid or g.revision is distinct from (j->>'revision')::integer then raise exception 'La meta cambió; actualice' using errcode='40001';end if;
    before_data:=to_jsonb(g);
    update public.twelve_week_goals set goal=trim(j->>'goal'),target_metric=nullif(trim(j->>'target_metric'),''),target_value=nullif(j->>'target_value','')::numeric,revision=revision+1,updated_by=auth.uid(),updated_at=now() where id=g.id returning * into g;
   else
    if nullif(j->>'id','') is not null then raise exception 'Meta no accesible' using errcode='42501';end if;
    insert into public.twelve_week_goals(cycle_id,week_number,goal,target_metric,target_value,updated_by) values(c.id,week,trim(j->>'goal'),nullif(trim(j->>'target_metric'),''),nullif(j->>'target_value','')::numeric,auth.uid()) returning * into g;
   end if;
   response:=to_jsonb(g);ident:=g.id;
  else
   if c.status<>'ACTIVO' then raise exception 'Active el ciclo antes de crear tareas';end if;
   due:=nullif(j->>'due_at','')::timestamptz;owner:=nullif(j->>'owner_id','')::uuid;
   if due is null or not isfinite(due) or (due at time zone 'America/Santo_Domingo')::date<c.start_date+(week-1)*7 or (due at time zone 'America/Santo_Domingo')::date>c.start_date+week*7-1 then raise exception 'La fecha debe estar dentro de la semana seleccionada, hora Santo Domingo';end if;
   if not private.work_owner_eligible(owner,b,a) then raise exception 'Responsable no elegible para esta área y sucursal' using errcode='42501';end if;
   if length(trim(coalesce(j->>'title',''))) not between 1 and 250 or length(coalesce(j->>'description',''))>4000 or coalesce(j->>'priority','') not in ('NORMAL','ALTA','CRITICA') then raise exception 'Título, prioridad y descripción de tarea no válidos';end if;
   task_result:=public.work_task_action('CREATE',jsonb_build_object('branch_id',b,'area_code',a,'title',trim(j->>'title'),'description',j->>'description','owner_id',owner,'due_at',due,'priority',j->>'priority','requires_review',true,'checklist','[]'::jsonb,'source_route','twelveweek','source_reference',c.id::text||':S'||week::text,'request_id',req,'occurrences',1,'interval_days',1));
   ident:=(task_result->'ids'->>0)::uuid;
   insert into public.twelve_week_task_links(task_id,cycle_id,week_number,created_by) values(ident,c.id,week,auth.uid());
   response:=jsonb_build_object('id',ident,'task_id',ident,'cycle_id',c.id,'week_number',week);
  end if;
 else raise exception 'Acción de ciclo no reconocida';end if;
 perform public.log_audit_event('TWELVE_WEEK',op,b,case op when 'CYCLE_SAVE' then 'twelve_week_cycles' when 'GOAL_SAVE' then 'twelve_week_goals' else 'work_tasks' end,ident,ident::text,before_data,response,jsonb_build_object('request_id',req,'area',a));
 insert into public.twelve_week_requests(actor_id,request_id,payload,response) values(auth.uid(),req,jsonb_build_object('branch',b,'area',a,'action',op,'data',j),response);
 return response;
end;$$;
revoke all on function private.twelve_week_context(),private.twelve_week_catalog(uuid,text),private.twelve_week_action(uuid,text,text,jsonb,uuid) from public,anon;grant execute on function private.twelve_week_context(),private.twelve_week_catalog(uuid,text),private.twelve_week_action(uuid,text,text,jsonb,uuid) to authenticated;
create function public.twelve_week_context() returns jsonb language sql stable security invoker set search_path=public,pg_temp as $$select private.twelve_week_context()$$;
create function public.twelve_week_catalog(p_branch uuid,p_area text) returns jsonb language sql stable security invoker set search_path=public,pg_temp as $$select private.twelve_week_catalog(p_branch,p_area)$$;
create function public.twelve_week_action(p_branch uuid,p_area text,p_action text,p_data jsonb,p_request uuid) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select private.twelve_week_action(p_branch,p_area,p_action,p_data,p_request)$$;
revoke all on function public.twelve_week_context(),public.twelve_week_catalog(uuid,text),public.twelve_week_action(uuid,text,text,jsonb,uuid) from public,anon;
grant execute on function public.twelve_week_context(),public.twelve_week_catalog(uuid,text),public.twelve_week_action(uuid,text,text,jsonb,uuid) to authenticated;
notify pgrst,'reload schema';commit;
