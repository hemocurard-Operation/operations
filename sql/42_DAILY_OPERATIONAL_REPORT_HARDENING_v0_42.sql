-- HemoCura v0.42.0
-- Endurece transiciones de estado del Reporte Operativo Diario.

begin;

drop policy if exists daily_operational_closes_update on public.daily_operational_closes;
create policy daily_operational_closes_update on public.daily_operational_closes
for update to authenticated
using(
  public.can_access_branch(branch_id) and (
    public.has_permission('DAILY_REPORT_WRITE') or
    public.has_permission('DAILY_REPORT_SUBMIT') or
    public.has_permission('DAILY_REPORT_CLOSE') or
    public.has_permission('DAILY_REPORT_REOPEN')
  )
)
with check(
  public.can_access_branch(branch_id) and (
    public.has_permission('DAILY_REPORT_WRITE') or
    public.has_permission('DAILY_REPORT_SUBMIT') or
    public.has_permission('DAILY_REPORT_CLOSE') or
    public.has_permission('DAILY_REPORT_REOPEN')
  )
);

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create or replace function private.enforce_daily_report_transition()
returns trigger
language plpgsql
security definer
set search_path=public,private
as $$
begin
  if old.status='CERRADO' then
    if new.status<>'REABIERTO' then raise exception 'Un reporte cerrado solo puede pasar a REABIERTO'; end if;
    if not public.has_permission('DAILY_REPORT_REOPEN') then raise exception 'Sin permiso para reabrir'; end if;
    if nullif(trim(new.reopen_reason),'') is null then raise exception 'Debe indicar el motivo de reapertura'; end if;
  elsif old.status in ('BORRADOR','REABIERTO') then
    if new.status='EN_REVISION' and not public.has_permission('DAILY_REPORT_SUBMIT') then raise exception 'Sin permiso para enviar a revisión'; end if;
    if new.status='CERRADO' then raise exception 'El reporte debe pasar primero a EN_REVISION'; end if;
  elsif old.status='EN_REVISION' then
    if new.status<>'CERRADO' then raise exception 'Un reporte EN_REVISION solo puede pasar a CERRADO'; end if;
    if not public.has_permission('DAILY_REPORT_CLOSE') then raise exception 'Sin permiso para cerrar'; end if;
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_daily_report_transition() from public,anon,authenticated;
drop trigger if exists trg_daily_report_transition on public.daily_operational_closes;
create trigger trg_daily_report_transition
before update on public.daily_operational_closes
for each row when (old.status is distinct from new.status)
execute function private.enforce_daily_report_transition();

create or replace function public.close_daily_operational_report(p_report_id uuid)
returns uuid language plpgsql security invoker set search_path=public as $$
declare r public.daily_operational_closes%rowtype;
begin
  if auth.uid() is null then raise exception 'Autenticación requerida'; end if;
  select * into r from public.daily_operational_closes where id=p_report_id;
  if r.id is null then raise exception 'Reporte no encontrado'; end if;
  if not public.can_access_branch(r.branch_id) or not public.has_permission('DAILY_REPORT_CLOSE') then raise exception 'Sin permiso para cerrar el reporte'; end if;
  if r.status<>'EN_REVISION' then raise exception 'El reporte debe estar EN_REVISION antes de cerrar'; end if;
  update public.daily_operational_closes set status='CERRADO',closed_by=auth.uid(),closed_at=now(),last_modified_by=auth.uid(),report_version=report_version+1,updated_at=now() where id=p_report_id;
  return p_report_id;
end; $$;
revoke all on function public.close_daily_operational_report(uuid) from public,anon;
grant execute on function public.close_daily_operational_report(uuid) to authenticated;

create or replace function public.reopen_daily_operational_report(p_report_id uuid,p_reason text)
returns uuid language plpgsql security invoker set search_path=public as $$
declare r public.daily_operational_closes%rowtype;
begin
  if auth.uid() is null then raise exception 'Autenticación requerida'; end if;
  select * into r from public.daily_operational_closes where id=p_report_id;
  if r.id is null then raise exception 'Reporte no encontrado'; end if;
  if not public.can_access_branch(r.branch_id) or not public.has_permission('DAILY_REPORT_REOPEN') then raise exception 'Sin permiso para reabrir'; end if;
  if r.status<>'CERRADO' then raise exception 'Solo se puede reabrir un reporte cerrado'; end if;
  if nullif(trim(p_reason),'') is null then raise exception 'Debe indicar el motivo de reapertura'; end if;
  update public.daily_operational_closes set status='REABIERTO',reopened_by=auth.uid(),reopened_at=now(),reopen_reason=trim(p_reason),last_modified_by=auth.uid(),report_version=report_version+1,updated_at=now() where id=p_report_id;
  return p_report_id;
end; $$;
revoke all on function public.reopen_daily_operational_report(uuid,text) from public,anon;
grant execute on function public.reopen_daily_operational_report(uuid,text) to authenticated;

commit;
