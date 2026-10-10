-- HemoCura · Hotfix reporte diario · auditoría sin INSERT directo
-- Corrige: permission denied for table audit_events
-- Estrategia: el trigger reutiliza public.log_audit_event(), que es SECURITY DEFINER,
-- exige sesión autenticada y valida alcance de sucursal.

create or replace function public.audit_management_change()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
declare
  v_branch uuid;
  v_ref text;
  v_action text;
  v_new jsonb := case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else '{}'::jsonb end;
  v_old jsonb := case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else '{}'::jsonb end;
begin
  v_branch := coalesce(
    nullif(v_new->>'branch_id','')::uuid,
    nullif(v_old->>'branch_id','')::uuid
  );

  v_ref := case tg_table_name
    when 'daily_operational_closes' then coalesce(v_new->>'close_date', v_old->>'close_date', '')
    when 'operational_exceptions' then coalesce(v_new->>'exception_code', v_old->>'exception_code', '')
    when 'management_actions' then coalesce(v_new->>'action_code', v_old->>'action_code', '')
    else ''
  end;

  v_action := tg_op;

  perform public.log_audit_event(
    'GESTION',
    v_action,
    v_branch,
    tg_table_name,
    coalesce(nullif(v_new->>'id','')::uuid, nullif(v_old->>'id','')::uuid),
    v_ref,
    case when tg_op in ('UPDATE','DELETE') then v_old else null end,
    case when tg_op in ('INSERT','UPDATE') then v_new else null end,
    jsonb_build_object('source','trigger','trigger_name',tg_name)
  );

  return coalesce(new,old);
end;
$function$;
