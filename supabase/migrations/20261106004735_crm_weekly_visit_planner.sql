begin;
insert into public.app_feature_flags(key,enabled,mode,description) values('crm_weekly_planner',false,'OFF','Mapa y planificación semanal de visitas comerciales con reglas del médico');
create table public.crm_contact_branch_access(contact_id uuid not null references public.crm_contacts(id),branch_id uuid not null references public.branches(id),primary key(contact_id,branch_id));
alter table public.crm_contact_branch_access enable row level security;revoke all on public.crm_contact_branch_access from public,anon,authenticated;grant select on public.crm_contact_branch_access to authenticated;
create policy crm_branch_links_read on public.crm_contact_branch_access for select to authenticated using(private.crm_scope(branch_id));
create function private.crm_contact_in_branch(b uuid,c uuid) returns boolean language sql stable security definer set search_path=public,pg_temp as $$select private.crm_scope(b) and exists(select 1 from public.crm_contacts x where x.id=c and (x.branch_id=b or exists(select 1 from public.crm_contact_branch_access a where a.contact_id=x.id and a.branch_id=b)))$$;
revoke all on function private.crm_contact_in_branch(uuid,uuid) from public,anon;grant execute on function private.crm_contact_in_branch(uuid,uuid) to authenticated;
create function private.crm_branch_contacts(b uuid) returns setof public.crm_contacts language plpgsql stable security definer set search_path=public,pg_temp as $$begin if not private.crm_scope(b) then raise exception 'Cartera no autorizada' using errcode='42501';end if;return query select c.* from public.crm_contacts c where c.branch_id=b or exists(select 1 from public.crm_contact_branch_access a where a.contact_id=c.id and a.branch_id=b) order by c.full_name,c.id;end;$$;
revoke all on function private.crm_branch_contacts(uuid) from public,anon;grant execute on function private.crm_branch_contacts(uuid) to authenticated;
create function public.crm_branch_contacts(p_branch uuid) returns setof public.crm_contacts language sql stable security invoker set search_path=public,pg_temp as $$select * from private.crm_branch_contacts(p_branch)$$;
revoke all on function public.crm_branch_contacts(uuid) from public,anon;grant execute on function public.crm_branch_contacts(uuid) to authenticated;
create table public.crm_contact_sources(
 contact_id uuid primary key references public.crm_contacts(id),branch_id uuid not null references public.branches(id),batch_sha256 text not null,source_rows integer[] not null,
 historical_dates jsonb not null default '[]',legacy_values jsonb not null default '{}',notes text,imported_at timestamptz not null default now());
create table public.crm_visit_rules(
 contact_id uuid primary key references public.crm_contacts(id),branch_id uuid not null references public.branches(id),slots jsonb not null default '[]',
 appointment_required boolean not null default false,after_patients boolean not null default false,arrival_order boolean not null default false,
 representative_limit integer check(representative_limit between 1 and 100),priority text not null default 'MEDIA' check(priority in ('ALTA','MEDIA','BAJA')),
 rule_text text not null default '',needs_review boolean not null default true,revision integer not null default 1,updated_by uuid references public.profiles(id),updated_at timestamptz not null default now(),check(jsonb_typeof(slots)='array' and jsonb_array_length(slots)<=14));
create table public.crm_center_locations(
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),center text not null,latitude numeric not null check(latitude between -90 and 90),longitude numeric not null check(longitude between -180 and 180),
 verified boolean not null default false,source text not null,revision integer not null default 1,updated_by uuid references public.profiles(id),updated_at timestamptz not null default now(),unique(branch_id,center));
create table public.crm_weekly_visits(
 id uuid primary key default gen_random_uuid(),branch_id uuid not null references public.branches(id),contact_id uuid not null references public.crm_contacts(id),agent_id uuid not null references public.profiles(id),
 scheduled_at timestamptz not null,duration_minutes integer not null check(duration_minutes between 10 and 240),status text not null default 'PLANIFICADA' check(status in ('PLANIFICADA','CANCELADA')),
 objective text not null,exception_reason text,rule_revision integer not null,revision integer not null default 1,created_by uuid not null references public.profiles(id),updated_at timestamptz not null default now(),request_id uuid not null unique,payload jsonb not null);
create index crm_weekly_visits_branch_date on public.crm_weekly_visits(branch_id,scheduled_at);
alter table public.crm_contact_sources enable row level security;alter table public.crm_visit_rules enable row level security;alter table public.crm_center_locations enable row level security;alter table public.crm_weekly_visits enable row level security;
revoke all on public.crm_contact_sources,public.crm_visit_rules,public.crm_center_locations,public.crm_weekly_visits from public,anon,authenticated;
grant select on public.crm_contact_sources,public.crm_visit_rules,public.crm_center_locations,public.crm_weekly_visits to authenticated;
create policy crm_source_read on public.crm_contact_sources for select to authenticated using(private.crm_scope(branch_id) or exists(select 1 from public.crm_contact_branch_access a where a.contact_id=crm_contact_sources.contact_id and private.crm_scope(a.branch_id)));
create policy crm_rules_read on public.crm_visit_rules for select to authenticated using(private.crm_scope(branch_id) or exists(select 1 from public.crm_contact_branch_access a where a.contact_id=crm_visit_rules.contact_id and private.crm_scope(a.branch_id)));
create policy crm_centers_read on public.crm_center_locations for select to authenticated using(private.crm_scope(branch_id));
create policy crm_weekly_read on public.crm_weekly_visits for select to authenticated using(private.crm_scope(branch_id));
create function private.crm_plan_action(b uuid,op text,j jsonb,req uuid) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare c public.crm_contacts;r public.crm_visit_rules;v public.crm_weekly_visits;l public.crm_center_locations;response jsonb;old jsonb;slot jsonb;ts timestamptz;minutes integer;issue boolean;agent uuid;ident uuid;rev integer;
begin
 if not private.crm_scope(b,'COMMERCIAL_WRITE') or not coalesce((select enabled from public.app_feature_flags where key='crm_weekly_planner'),false) then raise exception 'Planificador no autorizado o desactivado' using errcode='42501';end if;
 if req is null or coalesce(jsonb_typeof(j),'null')<>'object' then raise exception 'Solicitud inválida';end if;
 perform pg_advisory_xact_lock(hashtextextended('crmplan:'||b::text,0));
 if op='LOCATION' then
  if length(trim(coalesce(j->>'center',''))) not between 2 and 200 or length(trim(coalesce(j->>'source',''))) not between 3 and 500 then raise exception 'Centro y fuente de coordenadas requeridos';end if;
  if not exists(select 1 from public.crm_contacts x where x.center=j->>'center' and (x.branch_id=b or exists(select 1 from public.crm_contact_branch_access a where a.contact_id=x.id and a.branch_id=b))) then raise exception 'Centro sin fichas de esta sucursal';end if;
  select * into l from public.crm_center_locations where branch_id=b and center=j->>'center' for update;old:=to_jsonb(l);
  if found and l.revision is distinct from (j->>'revision')::integer then raise exception 'Ubicación modificada: actualice' using errcode='40001';end if;
  insert into public.crm_center_locations(branch_id,center,latitude,longitude,verified,source,updated_by) values(b,j->>'center',(j->>'latitude')::numeric,(j->>'longitude')::numeric,coalesce((j->>'verified')::boolean,false),trim(j->>'source'),auth.uid()) on conflict(branch_id,center) do update set latitude=excluded.latitude,longitude=excluded.longitude,verified=excluded.verified,source=excluded.source,revision=crm_center_locations.revision+1,updated_by=auth.uid(),updated_at=now() returning * into l;
  response:=to_jsonb(l);ident:=l.id;
 elsif op='RULE' then
  select * into c from public.crm_contacts where id=(j->>'contact_id')::uuid and private.crm_contact_in_branch(b,id);if not found then raise exception 'Ficha no accesible';end if;
  select * into r from public.crm_visit_rules where contact_id=c.id for update;old:=to_jsonb(r);
  if found and r.revision is distinct from (j->>'revision')::integer then raise exception 'Regla modificada: actualice' using errcode='40001';end if;
  if jsonb_typeof(j->'slots') is distinct from 'array' or jsonb_array_length(j->'slots')>14 then raise exception 'Franjas inválidas';end if;
  for slot in select value from jsonb_array_elements(j->'slots') loop
   if coalesce((slot->>'day')::integer,0) not between 1 and 7 or coalesce(slot->>'period','') not in ('AM','PM') then raise exception 'Día o tanda inválidos';end if;
  end loop;
  if length(coalesce(j->>'rule_text',''))>2000 then raise exception 'Regla de máximo 2000 caracteres';end if;
  insert into public.crm_visit_rules(contact_id,branch_id,slots,appointment_required,after_patients,arrival_order,representative_limit,priority,rule_text,needs_review,updated_by)
  values(c.id,c.branch_id,j->'slots',coalesce((j->>'appointment_required')::boolean,false),coalesce((j->>'after_patients')::boolean,false),coalesce((j->>'arrival_order')::boolean,false),nullif(j->>'representative_limit','')::integer,coalesce(j->>'priority','MEDIA'),coalesce(j->>'rule_text',''),coalesce((j->>'needs_review')::boolean,true),auth.uid())
  on conflict(contact_id) do update set slots=excluded.slots,appointment_required=excluded.appointment_required,after_patients=excluded.after_patients,arrival_order=excluded.arrival_order,representative_limit=excluded.representative_limit,priority=excluded.priority,rule_text=excluded.rule_text,needs_review=excluded.needs_review,revision=crm_visit_rules.revision+1,updated_by=auth.uid(),updated_at=now() returning * into r;
  response:=to_jsonb(r);ident:=c.id;
 elsif op='SAVE' then
  select * into v from public.crm_weekly_visits where request_id=req;
  if found then if v.created_by<>auth.uid() or v.branch_id<>b or v.payload<>j then raise exception 'Solicitud reutilizada';end if;return to_jsonb(v);end if;
  select * into c from public.crm_contacts where id=(j->>'contact_id')::uuid and private.crm_contact_in_branch(b,id);if not found or c.stage in ('ARCHIVADO','NO_INTERESADO') or c.preferred_channel='NO_CONTACTAR' then raise exception 'Ficha no disponible para visitar';end if;
  select * into r from public.crm_visit_rules where contact_id=c.id;
  if not found or r.revision is distinct from (j->>'rule_revision')::integer then raise exception 'Revise la regla actual antes de planificar' using errcode='40001';end if;
  ts:=(j->>'scheduled_at')::timestamptz;minutes:=(j->>'duration_minutes')::integer;agent:=coalesce(nullif(j->>'agent_id','')::uuid,auth.uid());
  if agent<>auth.uid() then raise exception 'Solo puede agendar para su propia cuenta' using errcode='42501';end if;
  if ts is null or not isfinite(ts) or ts<now() or minutes is null or minutes not between 10 and 240 or length(trim(coalesce(j->>'objective',''))) not between 3 and 1000 then raise exception 'Fecha futura, duración y objetivo requeridos';end if;
  issue:=r.needs_review or r.appointment_required or r.after_patients or jsonb_array_length(r.slots)=0 or not exists(select 1 from jsonb_array_elements(r.slots) s where (s->>'day')::integer=extract(isodow from ts at time zone 'America/Santo_Domingo') and s->>'period'=case when extract(hour from ts at time zone 'America/Santo_Domingo')<12 then 'AM' else 'PM' end);
  if issue and length(trim(coalesce(j->>'exception_reason','')))<8 then raise exception 'Confirme cita, regla u horario pendiente y deje justificación';end if;
  if length(coalesce(j->>'exception_reason',''))>1000 then raise exception 'Justificación demasiado larga';end if;
  perform pg_advisory_xact_lock(hashtextextended('crmplan-agent:'||agent::text,0));
  if exists(select 1 from public.crm_weekly_visits w where w.agent_id=agent and w.status='PLANIFICADA' and tstzrange(w.scheduled_at,w.scheduled_at+make_interval(mins=>w.duration_minutes),'[)') && tstzrange(ts,ts+make_interval(mins=>minutes),'[)')) or exists(select 1 from public.commercial_visits w where w.agent_id=agent and w.status not in ('REALIZADA','CANCELADA') and tstzrange(w.scheduled_at,w.scheduled_at+make_interval(mins=>w.duration_minutes),'[)') && tstzrange(ts,ts+make_interval(mins=>minutes),'[)')) then raise exception 'El responsable ya tiene una visita en esa franja';end if;
  insert into public.crm_weekly_visits(branch_id,contact_id,agent_id,scheduled_at,duration_minutes,objective,exception_reason,rule_revision,created_by,request_id,payload) values(b,c.id,agent,ts,minutes,trim(j->>'objective'),nullif(trim(j->>'exception_reason'),''),r.revision,auth.uid(),req,j) returning * into v;response:=to_jsonb(v);ident:=v.id;
 elsif op='CANCEL' then
  select * into v from public.crm_weekly_visits where id=(j->>'id')::uuid and branch_id=b for update;
  if not found or v.created_by<>auth.uid() then raise exception 'Visita de otra cuenta o sucursal' using errcode='42501';end if;
  if v.status='CANCELADA' then return to_jsonb(v);end if;
  if v.revision is distinct from (j->>'revision')::integer or length(trim(coalesce(j->>'reason','')))<3 then raise exception 'Revise versión y motivo de cancelación';end if;
  old:=to_jsonb(v);update public.crm_weekly_visits set status='CANCELADA',revision=revision+1,updated_at=now() where id=v.id returning * into v;response:=to_jsonb(v);ident:=v.id;
 else raise exception 'Acción no reconocida';end if;
 perform public.log_audit_event('CRM_PLAN',op,b,case when op='RULE' then 'crm_visit_rules' when op='LOCATION' then 'crm_center_locations' else 'crm_weekly_visits' end,ident,ident::text,old,response,jsonb_build_object('request_id',req,'reason',j->>'reason'));
 return response;
end;$$;
revoke all on function private.crm_plan_action(uuid,text,jsonb,uuid) from public,anon;grant execute on function private.crm_plan_action(uuid,text,jsonb,uuid) to authenticated;
create function public.crm_plan_action(p_branch uuid,p_action text,p_data jsonb,p_request uuid) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select private.crm_plan_action(p_branch,p_action,p_data,p_request)$$;
revoke all on function public.crm_plan_action(uuid,text,jsonb,uuid) from public,anon;grant execute on function public.crm_plan_action(uuid,text,jsonb,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
