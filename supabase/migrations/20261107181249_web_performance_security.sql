begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
-- Both tables are currently under 64 KiB. Abort rather than build blocking indexes on a large installation.
do $$begin
 if pg_total_relation_size('public.supplier_quotations')>67108864 or pg_total_relation_size('public.quotation_decisions')>67108864 then
  raise exception 'Prepare índices concurrentes antes de esta migración: tablas de cotización mayores de 64 MiB.';
 end if;
end$$;
create index if not exists supplier_quotations_created_by_idx on public.supplier_quotations(created_by);
create index if not exists quotation_decisions_created_by_idx on public.quotation_decisions(created_by);
alter policy supplier_quotations_insert on public.supplier_quotations with check (
 public.wf_active_actor() and created_by=(select auth.uid()) and public.has_permission('PURCHASE_VIEW')
 and public.has_permission('PURCHASE_WRITE') and public.can_access_branch(branch_id));
alter policy quotation_decisions_insert on public.quotation_decisions with check (
 public.wf_active_actor() and created_by=(select auth.uid()) and public.has_permission('PURCHASE_VIEW')
 and public.has_permission('PURCHASE_APPROVE') and public.can_access_branch(branch_id)
 and exists(select 1 from public.supplier_quotations q join public.suppliers s on s.id=q.supplier_id
  where q.id=quotation_id and q.branch_id=quotation_decisions.branch_id
   and q.valid_until>=(now() at time zone 'America/Santo_Domingo')::date and s.status in ('ACTIVO','CONDICIONAL')));

-- Read only, explicit summary projection, current role and branch RLS retained.
-- Filters use literal substring matching: no dynamic SQL or interpolated PostgREST expressions.
create function public.donor_search_page(
 p_branch uuid default null,p_search text default '',p_group text default '',
 p_offset integer default 0,p_limit integer default 25,p_focus uuid default null
) returns jsonb language plpgsql stable security invoker set search_path=public,pg_temp as $$
declare term text:=lower(trim(coalesce(p_search,'')));digits text:='';result jsonb;
begin
 if not public.wf_active_actor() or not public.has_permission('DONORS_VIEW') then
  raise exception 'Usuario activo y permiso de donantes requeridos.' using errcode='42501';
 end if;
 if p_branch is not null and not public.can_access_branch(p_branch) then
  raise exception 'Sucursal no autorizada.' using errcode='42501';
 end if;
 if p_offset is null or p_offset<0 or p_offset>10000000 or p_limit is null or p_limit not between 1 and 100 or length(term)>120 then
  raise exception 'Parámetros de búsqueda inválidos.' using errcode='22023';
 end if;
 if coalesce(p_group,'') not in ('','A+','A−','B+','B−','AB+','AB−','O+','O−','Pendiente') then
  raise exception 'Grupo sanguíneo inválido.' using errcode='22023';
 end if;
 if term~'^[0-9[:space:].-]+$' then digits:=regexp_replace(term,'[^0-9]','','g');end if;
 with filtered as materialized (
  select d.id,d.donor_code,d.branch_id,d.full_name,d.cedula,d.abo,d.rh,d.registration_date,d.last_donation_date
  from public.vw_donor_coordination d
  where (p_branch is null or d.branch_id=p_branch)
   and (coalesce(p_group,'')='' or
    case when coalesce(d.abo,'')<>'' and coalesce(d.rh,'')<>'' then d.abo||case when d.rh='POSITIVO' then '+' else '−' end else 'Pendiente' end=p_group)
   and (term='' or position(term in lower(coalesce(d.full_name,'')))>0
    or position(term in lower(coalesce(d.donor_code,'')))>0 or position(term in lower(coalesce(d.cedula,'')))>0
    or (digits<>'' and position(digits in regexp_replace(coalesce(d.cedula,''),'[^0-9]','','g'))>0))
 ), ranked as materialized (
  select f.*,row_number() over(order by registration_date desc nulls last,id) as ordinal from filtered f
 ), metadata as (
  select count(*)::integer as total,coalesce(max(ordinal-1) filter(where id=p_focus),p_offset::bigint) as requested from ranked
 ), bounds as (
  select total,case when total=0 then 0 else least((requested/p_limit)*p_limit,((total-1)/p_limit)*p_limit)::integer end as start from metadata
 )
 select jsonb_build_object('total',b.total,'offset',b.start,'rows',coalesce((
  select jsonb_agg(to_jsonb(r)-'ordinal' order by r.ordinal) from ranked r where r.ordinal>b.start and r.ordinal<=b.start+p_limit
 ),'[]'::jsonb)) into result from bounds b;
 return result;
end$$;
revoke all on function public.donor_search_page(uuid,text,text,integer,integer,uuid) from public,anon;
grant execute on function public.donor_search_page(uuid,text,text,integer,integer,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
