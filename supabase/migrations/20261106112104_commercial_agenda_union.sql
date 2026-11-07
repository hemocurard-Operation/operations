begin;
insert into public.app_feature_flags(key,enabled,mode,description) values('commercial_agenda_union',false,'OFF','Agenda comercial con visitas del mapa y origen trazable; las reservas se protegen en ambos puntos de registro');
create function private.guard_commercial_reservation() returns trigger language plpgsql volatile security definer set search_path=public,pg_temp as $$
declare new_active boolean;old_active boolean;finishes timestamptz;
begin
 new_active:=case when tg_table_name='crm_weekly_visits' then new.status='PLANIFICADA' else new.status not in ('REALIZADA','CANCELADA') end;
 if not new_active then return new;end if;
 if tg_op='UPDATE' then
  old_active:=case when tg_table_name='crm_weekly_visits' then old.status='PLANIFICADA' else old.status not in ('REALIZADA','CANCELADA') end;
  if old_active and row(new.agent_id,new.scheduled_at,new.duration_minutes) is not distinct from row(old.agent_id,old.scheduled_at,old.duration_minutes) then return new;end if;
 end if;
 if new.agent_id is null or new.scheduled_at is null or not isfinite(new.scheduled_at) or new.duration_minutes is null or new.duration_minutes<=0 then raise exception 'Responsable, fecha finita y duración positiva requeridos' using errcode='22023';end if;
 finishes:=new.scheduled_at+make_interval(mins=>new.duration_minutes);
 -- Same lock as crm_plan_action. Separate SPI commands give a fresh READ COMMITTED snapshot after the wait.
 perform pg_advisory_xact_lock(hashtextextended('crmplan-agent:'||new.agent_id::text,0));
 if exists(select 1 from public.commercial_visits w where w.agent_id=new.agent_id and w.status not in ('REALIZADA','CANCELADA') and (tg_table_name<>'commercial_visits' or w.id<>new.id) and tstzrange(w.scheduled_at,w.scheduled_at+make_interval(mins=>w.duration_minutes),'[)') && tstzrange(new.scheduled_at,finishes,'[)'))
 or exists(select 1 from public.crm_weekly_visits w where w.agent_id=new.agent_id and w.status='PLANIFICADA' and (tg_table_name<>'crm_weekly_visits' or w.id<>new.id) and tstzrange(w.scheduled_at,w.scheduled_at+make_interval(mins=>w.duration_minutes),'[)') && tstzrange(new.scheduled_at,finishes,'[)')) then
  raise exception 'El responsable ya tiene una visita en esa franja. Revise la agenda comercial y el mapa.' using errcode='23P01';
 end if;
 return new;
end;$$;
revoke all on function private.guard_commercial_reservation() from public,anon,authenticated;
create trigger commercial_visit_reservation_guard before insert or update of agent_id,scheduled_at,duration_minutes,status on public.commercial_visits for each row execute function private.guard_commercial_reservation();
create trigger crm_visit_reservation_guard before insert or update of agent_id,scheduled_at,duration_minutes,status on public.crm_weekly_visits for each row execute function private.guard_commercial_reservation();
create function private.commercial_agenda(b uuid) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare enabled boolean;
begin
 if not exists(select 1 from public.branches where id=b and active) or not private.crm_scope(b) then raise exception 'Agenda comercial no autorizada en esta sucursal' using errcode='42501';end if;
 enabled:=coalesce((select f.enabled from public.app_feature_flags f where f.key='commercial_agenda_union'),false);
 if not enabled then return jsonb_build_object('enabled',false,'visits','[]'::jsonb);end if;
 return jsonb_build_object('enabled',true,'visits',coalesce((select jsonb_agg(to_jsonb(v)||jsonb_build_object('source','crm_weekly_visits','full_name',c.full_name,'center',c.center,'specialty',c.specialty,'owner_name',p.full_name) order by v.scheduled_at,v.id)
 from public.crm_weekly_visits v join public.crm_contacts c on c.id=v.contact_id join public.profiles p on p.id=v.agent_id where v.branch_id=b and (c.branch_id=b or exists(select 1 from public.crm_contact_branch_access a where a.contact_id=c.id and a.branch_id=b))),'[]'::jsonb));
end;$$;
revoke all on function private.commercial_agenda(uuid) from public,anon;grant execute on function private.commercial_agenda(uuid) to authenticated;
create function public.commercial_agenda(p_branch uuid) returns jsonb language sql stable security invoker set search_path=public,pg_temp as $$select private.commercial_agenda(p_branch)$$;
revoke all on function public.commercial_agenda(uuid) from public,anon;grant execute on function public.commercial_agenda(uuid) to authenticated;
comment on function private.guard_commercial_reservation() is 'Restricts new or changed active reservations across both commercial agendas. Does not rewrite historical records or alter terminal-state transitions. Integrity remains active when the calendar display flag is off.';
notify pgrst,'reload schema';commit;
