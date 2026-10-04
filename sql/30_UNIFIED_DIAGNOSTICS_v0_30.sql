-- ============================================================
-- HemoCura v0.30.0
-- Diagnóstico unificado
-- Requiere v0.29.0
-- ============================================================
begin;
create extension if not exists pgcrypto;

create table if not exists public.diagnostic_events (
  id uuid primary key default gen_random_uuid(),
  event_time timestamptz not null default now(),
  user_id uuid references public.profiles(id),
  branch_id uuid references public.branches(id),
  diagnostic_code text not null,
  severity text not null check(severity in ('INFO','WARN','ERROR','CRITICAL')),
  subsystem text not null,
  route text,
  message text not null,
  technical_detail text,
  recovery_action text,
  metadata jsonb
);

alter table public.diagnostic_events enable row level security;

drop policy if exists diagnostic_events_insert on public.diagnostic_events;
create policy diagnostic_events_insert on public.diagnostic_events for insert
with check(auth.role()='authenticated');

drop policy if exists diagnostic_events_read on public.diagnostic_events;
create policy diagnostic_events_read on public.diagnostic_events for select
using(
  user_id=auth.uid()
  or public.has_role('ADMIN')
  or public.has_role('GERENCIA_OPERATIVA')
  or public.has_role('CALIDAD')
);

grant select,insert on public.diagnostic_events to authenticated;

create or replace function public.log_diagnostic_event(
  p_diagnostic_code text,
  p_severity text,
  p_subsystem text,
  p_message text,
  p_route text default null,
  p_technical_detail text default null,
  p_recovery_action text default null,
  p_branch_id uuid default null,
  p_metadata jsonb default null
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare v_id uuid;
begin
  insert into public.diagnostic_events(
    user_id,branch_id,diagnostic_code,severity,subsystem,route,message,
    technical_detail,recovery_action,metadata
  )
  values(
    auth.uid(),p_branch_id,p_diagnostic_code,p_severity,p_subsystem,p_route,p_message,
    p_technical_detail,p_recovery_action,p_metadata
  )
  returning id into v_id;
  return v_id;
end;
$$;

grant execute on function public.log_diagnostic_event(text,text,text,text,text,text,text,uuid,jsonb)
to authenticated;

create or replace view public.vw_diagnostic_summary_30d as
select
  diagnostic_code,
  severity,
  subsystem,
  count(*) events,
  count(distinct user_id) users_affected,
  min(event_time) first_seen,
  max(event_time) last_seen
from public.diagnostic_events
where event_time>=now()-interval '30 days'
group by diagnostic_code,severity,subsystem
order by
  case severity when 'CRITICAL' then 1 when 'ERROR' then 2 when 'WARN' then 3 else 4 end,
  count(*) desc;

grant select on public.vw_diagnostic_summary_30d to authenticated;

create or replace view public.vw_current_user_health as
select
  auth.uid() user_id,
  auth.email() email,
  (p.id is not null) profile_exists,
  p.branch_id,
  b.code branch_code,
  exists(select 1 from public.user_roles ur where ur.user_id=auth.uid()) role_exists,
  exists(select 1 from public.vw_my_access a where a.user_id=auth.uid()) permission_exists
from (select 1) x
left join public.profiles p on p.id=auth.uid()
left join public.branches b on b.id=p.branch_id;

grant select on public.vw_current_user_health to authenticated;

insert into public.app_migrations(
  migration_code,version,description,applied_by
)
values(
  '30_UNIFIED_DIAGNOSTICS_v0_30',
  '0.30.0',
  'Diagnóstico unificado y recuperación guiada',
  auth.uid()
)
on conflict(migration_code) do update set
  version=excluded.version,
  description=excluded.description,
  applied_at=now(),
  applied_by=auth.uid();

commit;
