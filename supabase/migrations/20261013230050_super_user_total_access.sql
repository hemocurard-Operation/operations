-- Deployment candidate: generate a CLI migration after live preflight is available.
-- Preserves clinical workflow invariants and existing non-super branch rules.
begin;
do $$begin
 if not exists(select 1 from public.roles where code='SUPER_USUARIO') then
  raise exception 'SUPER_USUARIO no existe; no se modifica el acceso';
 end if;
 if (select count(distinct u.user_id) from public.user_roles u join public.roles r on r.id=u.role_id where r.code='SUPER_USUARIO')<>1 then
  raise exception 'Debe existir exactamente un titular Super Usuario';
 end if;
 if not exists(select 1 from public.user_roles u join public.roles r on r.id=u.role_id join public.profiles p on p.id=u.user_id where r.code='SUPER_USUARIO' and p.active) then
  raise exception 'El Super Usuario debe tener un perfil activo';
 end if;
end$$;

delete from public.role_permissions rp using public.roles r
where rp.role_id=r.id and rp.permission_code='ACCESS_ADMIN' and r.code<>'SUPER_USUARIO';
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r cross join public.app_permissions p
where r.code='SUPER_USUARIO' and p.active on conflict do nothing;

-- Active superuser receives every active permission, including future modules.
-- ACCESS_ADMIN cannot become effective for any other role, even if mistakenly mapped.
create or replace function public.has_permission(p_permission_code text)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.profiles where id=auth.uid() and active)
 and exists(select 1 from public.app_permissions ap where ap.permission_code=p_permission_code and ap.active
 and (public.has_role('SUPER_USUARIO') or
 (ap.permission_code<>'ACCESS_ADMIN' and exists(select 1 from public.user_roles ur join public.role_permissions rp on rp.role_id=ur.role_id
 where ur.user_id=auth.uid() and rp.permission_code=ap.permission_code))));
$$;
revoke all on function public.has_permission(text) from public,anon;
grant execute on function public.has_permission(text) to authenticated;

create schema if not exists private;
revoke all on schema private from public,anon,authenticated;
-- Clone the current branch predicate once, rather than inventing non-super scopes.
do $$declare definition text;begin
 if to_regprocedure('private.legacy_can_access_branch(uuid)') is null then
  select pg_get_functiondef('public.can_access_branch(uuid)'::regprocedure) into definition;
  definition:=replace(definition,'public.can_access_branch(', 'private.legacy_can_access_branch(');
  execute definition;
 end if;
end$$;
revoke all on function private.legacy_can_access_branch(uuid) from public,anon,authenticated;
create or replace function public.can_access_branch(target_branch uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.profiles where id=auth.uid() and active)
 and (public.has_role('SUPER_USUARIO') or private.legacy_can_access_branch(target_branch));
$$;
revoke all on function public.can_access_branch(uuid) from public,anon;
grant execute on function public.can_access_branch(uuid) to authenticated;

create or replace view public.vw_my_access with(security_invoker=true) as
select distinct p.id user_id,p.branch_id profile_branch_id,r.code role_code,r.name role_name,
ur.branch_id role_branch_id,ap.permission_code,ap.module,ap.risk_level
from public.profiles p join public.user_roles ur on ur.user_id=p.id join public.roles r on r.id=ur.role_id
join public.app_permissions ap on ap.active
left join public.role_permissions rp on rp.role_id=r.id and rp.permission_code=ap.permission_code
where p.id=auth.uid() and p.active and (r.code='SUPER_USUARIO' or (rp.permission_code is not null and ap.permission_code<>'ACCESS_ADMIN'));
revoke all on public.vw_my_access from public,anon;
grant select on public.vw_my_access to authenticated;

drop policy if exists app_permissions_write on public.app_permissions;
create policy app_permissions_write on public.app_permissions for all to authenticated
using(public.has_permission('ACCESS_ADMIN')) with check(public.has_permission('ACCESS_ADMIN'));
drop policy if exists role_permissions_write on public.role_permissions;
create policy role_permissions_write on public.role_permissions for all to authenticated
using(public.has_permission('ACCESS_ADMIN')) with check(public.has_permission('ACCESS_ADMIN'));
-- Any additional live write policy must be checked during deployment preflight.
create or replace function public.remove_user_role(
  p_user_id uuid,p_role_id uuid,p_branch_ids uuid[]
) returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare actor uuid:=auth.uid(); role_code text; assignment record; branch uuid; removed integer:=0;
begin
  perform pg_advisory_xact_lock(hashtextextended('hemocura.admin_role_changes',0));
  if actor is null or not exists(select 1 from public.profiles where id=actor and active)
     or not public.has_permission('ACCESS_ADMIN') then
    raise exception 'ACCESS_ADMIN y perfil activo requeridos' using errcode='42501';
  end if;
  if p_user_id=actor then
    raise exception 'No puede retirar sus propios roles administrativos' using errcode='23514';
  end if;
  if not exists(select 1 from public.profiles where id=p_user_id) then
    raise exception 'Usuario no encontrado' using errcode='P0002';
  end if;
  if p_branch_ids is null or cardinality(p_branch_ids)=0
     or array_position(p_branch_ids,null) is not null then
    raise exception 'Seleccione asignaciones por sucursal' using errcode='22023';
  end if;
  for branch in select distinct unnest(p_branch_ids) loop
    if not public.can_access_branch(branch) then raise exception 'Sucursal no autorizada' using errcode='42501';end if;
  end loop;
  select code into role_code from public.roles where id=p_role_id;
  if not found then raise exception 'Rol no encontrado' using errcode='P0002';end if;
  if role_code='SUPER_USUARIO' then
    raise exception 'El Superusuario requiere un procedimiento de transferencia de autoridad' using errcode='23514';
  end if;
  -- Only the actor's own session is used: no service key is accepted by this RPC.
  -- Lock selected assignments and validate every scope before deleting anything.
  for assignment in select * from public.user_roles
    where user_id=p_user_id and role_id=p_role_id and branch_id=any(p_branch_ids)
    order by branch_id for update
  loop
    if not public.can_access_branch(assignment.branch_id) then
      raise exception 'Sucursal no autorizada' using errcode='42501';
    end if;
  end loop;
  for assignment in delete from public.user_roles
    where user_id=p_user_id and role_id=p_role_id and branch_id=any(p_branch_ids)
    returning *
  loop
    removed:=removed+1;
  end loop;
  -- A repeated request is an idempotent no-op; failed audit rolls back deletion.
  return removed;
end;
$$;
-- Protect the same invariants when authenticated clients bypass the Edge UI.
create or replace function private.guard_user_role_changes()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare actor uuid:=auth.uid(); old_code text; new_code text;
begin
  perform pg_advisory_xact_lock(hashtextextended('hemocura.admin_role_changes',0));
  if auth.role()='authenticated' then
    if actor is null or not exists(select 1 from public.profiles where id=actor and active)
       or not public.has_permission('ACCESS_ADMIN') then
      raise exception 'ACCESS_ADMIN y perfil activo requeridos' using errcode='42501';
    end if;
    if tg_op in ('INSERT','UPDATE') and not public.can_access_branch(new.branch_id) then
      raise exception 'Sucursal no autorizada' using errcode='42501';
    end if;
  end if;
  if tg_op in ('DELETE','UPDATE') then
    select code into old_code from public.roles where id=old.role_id;
    if auth.role()='authenticated' then
      if actor is null or not exists(select 1 from public.profiles where id=actor and active)
         or not public.has_permission('ACCESS_ADMIN') then
        raise exception 'ACCESS_ADMIN y perfil activo requeridos' using errcode='42501';
      end if;
      if old.user_id=actor then raise exception 'No puede modificar sus propios roles' using errcode='23514';end if;
      if old_code='SUPER_USUARIO' then raise exception 'Transferencia de Superusuario requiere procedimiento separado' using errcode='23514';end if;
      if not public.can_access_branch(old.branch_id) then raise exception 'Sucursal no autorizada' using errcode='42501';end if;
      if tg_op='UPDATE' and not public.can_access_branch(new.branch_id) then raise exception 'Sucursal no autorizada' using errcode='42501';end if;
    end if;
  end if;
  if tg_op in ('INSERT','UPDATE') then
    select code into new_code from public.roles where id=new.role_id;
    if new_code='SUPER_USUARIO' and exists(select 1 from public.user_roles
      where role_id=new.role_id and user_id<>new.user_id) then
      raise exception 'HemoCura permite un solo Superusuario global' using errcode='23514';
    end if;
    return new;
  end if;
  return old;
end;
$$;
revoke execute on function private.guard_user_role_changes() from public,anon;
drop trigger if exists guard_user_role_changes on public.user_roles;
create trigger guard_user_role_changes before insert or update or delete on public.user_roles
for each row execute function private.guard_user_role_changes();

revoke execute on function public.remove_user_role(uuid,uuid,uuid[]) from public,anon;
grant execute on function public.remove_user_role(uuid,uuid,uuid[]) to authenticated;
create or replace function private.audit_user_role_changes()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare assignment record; action text;
begin
  if auth.role()='authenticated' then
    if tg_op='DELETE' then assignment:=old;action:='ROLE_REMOVED';
    elsif tg_op='INSERT' then assignment:=new;action:='ROLE_ASSIGNED';
    else assignment:=new;action:='ROLE_UPDATED';end if;
    perform public.log_audit_event('USERS_ADMIN',action,assignment.branch_id,
      'user_roles',assignment.user_id,assignment.user_id::text||':'||assignment.role_id::text,
      case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end,
      case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end,
      jsonb_build_object('source','guarded_user_role_changes'));
  end if;
  if tg_op='DELETE' then return old;end if;return new;
end;
$$;
revoke execute on function private.audit_user_role_changes() from public,anon;
drop trigger if exists audit_user_role_changes on public.user_roles;
create trigger audit_user_role_changes after insert or update or delete on public.user_roles
for each row execute function private.audit_user_role_changes();


notify pgrst,'reload schema';
commit;
