-- HemoCura Operations
-- Hotfix: daily report audit trigger fails with
--   record "new" has no field "exception_code"
--
-- Root cause:
-- public.audit_management_change() is shared by multiple tables and
-- referenced table-specific NEW/OLD fields directly. PostgreSQL raises
-- an error when the trigger row type does not contain one of those fields.
--
-- Fix:
-- Read table-specific fields from to_jsonb(NEW/OLD), preserving the
-- existing audit behavior without changing RLS, grants or clinical logic.

begin;

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

  insert into public.audit_events(
    user_id,
    branch_id,
    module,
    action,
    entity_table,
    entity_id,
    entity_reference,
    before_data,
    after_data
  ) values(
    auth.uid(),
    v_branch,
    'GESTION',
    v_action,
    tg_table_name,
    coalesce(nullif(v_new->>'id','')::uuid, nullif(v_old->>'id','')::uuid),
    v_ref,
    case when tg_op in ('UPDATE','DELETE') then v_old else null end,
    case when tg_op in ('INSERT','UPDATE') then v_new else null end
  );

  return coalesce(new,old);
end;
$function$;

commit;

-- Verification performed in production on 2026-10-10:
-- 1. Function definition contains no direct NEW.exception_code,
--    NEW.action_code or NEW.close_date references.
-- 2. Transactional INSERT into daily_operational_closes succeeded and
--    was rolled back, leaving no test row behind.
