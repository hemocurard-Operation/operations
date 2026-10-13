-- Follow-up to 20261013120000. Additive catalogue requisitions and multi-platform daily evidence.
begin;
set local lock_timeout='5s';
set local statement_timeout='120s';
create or replace function public.wf_save_daily_sections(p_report_id uuid,p_data jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.daily_operational_closes%rowtype; rowdata jsonb; x jsonb; row jsonb; entries jsonb; tested bigint; nonreactive bigint; reactive bigint;
begin
 select * into r from public.daily_operational_closes where id=p_report_id for update;
 if not found then raise exception 'Reporte no encontrado';end if;
 perform public.wf_require('DAILY_REPORT_WRITE',r.branch_id);
 if r.status not in ('BORRADOR','REABIERTO') then raise exception 'Reporte no editable';end if;
 if nullif(btrim(p_data->>'donor_batch'),'') is null then raise exception 'Lote de captación requerido';end if;
 if jsonb_typeof(p_data->'markers') is distinct from 'array' or jsonb_typeof(p_data->'receipts') is distinct from 'array'
    or jsonb_array_length(p_data->'markers')<>6 or jsonb_array_length(p_data->'receipts')<>8 then raise exception 'Se requieren 6 marcadores y 8 grupos';end if;
 if (select count(distinct v->>'marker') from jsonb_array_elements(p_data->'markers')v)<>6
    or (select count(distinct v->>'group') from jsonb_array_elements(p_data->'receipts')v)<>8 then raise exception 'Marcadores/grupos duplicados';end if;
 for x in select value from jsonb_array_elements(p_data->'markers') loop
  if x->>'marker' is null or x->>'marker' not in ('VIH (Ag/Ac)','HBsAg','Anti-HCV','Sífilis','HTLV I/II','CORE') then raise exception 'Marcador inválido';end if;
  entries:=case when x ? 'platforms' then x->'platforms' else jsonb_build_array(x) end;
  if jsonb_typeof(entries) is distinct from 'array' or jsonb_array_length(entries)<1 or jsonb_array_length(entries)>3
    or (select count(distinct v->>'platform') from jsonb_array_elements(entries)v)<>jsonb_array_length(entries) then raise exception 'Plataformas duplicadas o ausentes';end if;
  tested:=0;nonreactive:=0;reactive:=0;
  for row in select value from jsonb_array_elements(entries) loop
   if row->>'platform' is null or row->>'platform' not in ('AutoLumo','MiniVidas','ELISA')
      or coalesce(row->>'tested','') !~ '^[0-9]+$' or coalesce(row->>'nonreactive','') !~ '^[0-9]+$' or coalesce(row->>'reactive','') !~ '^[0-9]+$'
      or (row->>'tested')::bigint<>(row->>'nonreactive')::bigint+(row->>'reactive')::bigint then raise exception 'Plataforma/conteo inválido';end if;
   if (row->>'tested')::bigint>0 and (nullif(btrim(row->>'reagent_lot'),'') is null or nullif(btrim(row->>'control_reference'),'') is null) then raise exception 'Lote de reactivo y control requeridos por plataforma';end if;
   tested:=tested+(row->>'tested')::bigint;nonreactive:=nonreactive+(row->>'nonreactive')::bigint;reactive:=reactive+(row->>'reactive')::bigint;
  end loop;
  if coalesce(x->>'tested','') !~ '^[0-9]+$' or coalesce(x->>'nonreactive','') !~ '^[0-9]+$' or coalesce(x->>'reactive','') !~ '^[0-9]+$'
     or (x->>'tested')::bigint<>tested or (x->>'nonreactive')::bigint<>nonreactive or (x->>'reactive')::bigint<>reactive then raise exception 'Total y desglose de plataformas no coinciden';end if;
 end loop;
 for x in select value from jsonb_array_elements(p_data->'receipts') loop
  if x->>'group' is null or x->>'group' not in ('A+','A-','B+','B-','O+','O-','AB+','AB-') or not (x ?& array['received','pending','discarded']) or x->>'received' is null or x->>'pending' is null or x->>'discarded' is null or (x->>'received')::integer<0
    or (x->>'pending')::integer<0 or (x->>'discarded')::integer<0
    or (x->>'pending')::integer+(x->>'discarded')::integer>(x->>'received')::integer then raise exception 'Recepciones incoherentes';end if;
 end loop;
 -- Integer casts plus NOT NULL/CHECK constraints reject missing, negative or fractional donor counts.
 insert into public.workflow_daily_sections(report_id,branch_id,report_date,donor_batch,accepted,deferred,discarded,markers,receipts,updated_by)
 values(r.id,r.branch_id,r.close_date,btrim(p_data->>'donor_batch'),(p_data->>'accepted')::integer,
 (p_data->>'deferred')::integer,(p_data->>'discarded')::integer,p_data->'markers',p_data->'receipts',auth.uid())
 on conflict(report_id) do update set donor_batch=excluded.donor_batch,accepted=excluded.accepted,deferred=excluded.deferred,
 discarded=excluded.discarded,markers=excluded.markers,receipts=excluded.receipts,updated_by=auth.uid(),updated_at=now()
 returning to_jsonb(workflow_daily_sections.*) into rowdata;
 -- Preserve each extension change in the report's existing version history.
 update public.daily_operational_closes set report_version=report_version+1,last_modified_by=auth.uid(),updated_at=now() where id=r.id;

 return (rowdata->>'id')::uuid;
end $$;

revoke execute on function public.wf_save_daily_sections(uuid,jsonb) from public,anon;
grant execute on function public.wf_save_daily_sections(uuid,jsonb) to authenticated;

insert into public.app_permissions(permission_code,module,description,risk_level)
values('REQUISITION_WRITE','SUPPLY','Solicitar insumos aprobados del catálogo','SENSIBLE') on conflict do nothing;
insert into public.role_permissions(role_id,permission_code)
select distinct role_id,'REQUISITION_WRITE' from public.role_permissions where permission_code in ('DISPATCH_WRITE','SUPPLY_WRITE') on conflict do nothing;
alter table public.requisition_lines add column if not exists catalog_item_id uuid references public.workflow_supply_catalog(id);
alter table public.requisition_lines add column if not exists product_id uuid references public.products(id);

create or replace function public.wf_create_catalog_requisition(p_header jsonb,p_lines jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare branch uuid; request_id uuid; item public.workflow_supply_catalog%rowtype; line jsonb; qty numeric; code text;
begin
 branch:=(p_header->>'requesting_branch_id')::uuid;perform public.wf_require('REQUISITION_WRITE',branch);
 code:=nullif(btrim(p_header->>'requisition_code'),'');
 if code is null or p_header->>'request_date' is null or p_header->>'priority' is null or p_header->>'priority' not in ('NORMAL','URGENTE') then raise exception 'Código, fecha y prioridad requeridos';end if;
 if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines)<1 or jsonb_array_length(p_lines)>100 then raise exception 'Entre 1 y 100 insumos requeridos';end if;
 if (select count(distinct v->>'catalog_item_id') from jsonb_array_elements(p_lines)v)<>jsonb_array_length(p_lines) then raise exception 'Insumos duplicados o ausentes';end if;
 -- Header and lines are committed together; any failed item rolls back the header.
 insert into public.requisitions(requisition_code,request_date,requesting_branch_id,requested_by,department,priority,justification,status)
 values(code,(p_header->>'request_date')::date,branch,auth.uid(),nullif(btrim(p_header->>'department'),''),p_header->>'priority',nullif(btrim(p_header->>'justification'),''),'PENDIENTE') returning id into request_id;
 for line in select value from jsonb_array_elements(p_lines) order by value->>'catalog_item_id' loop
  select * into item from public.workflow_supply_catalog where id=(line->>'catalog_item_id')::uuid for share;
  if not found or item.reviewed_at is null or item.product_id is null or nullif(btrim(item.approved_name),'') is null or nullif(btrim(item.unit_of_measure),'') is null then raise exception 'Insumo no aprobado';end if;
  perform 1 from public.products where id=item.product_id and active and unit_of_measure=item.unit_of_measure for share;
  if not found then raise exception 'Producto inactivo o unidad no concordante';end if;
  qty:=(line->>'requested_qty')::numeric;
  if qty is null or qty<=0 or qty::text in ('NaN','Infinity','-Infinity') then raise exception 'Cantidad positiva y finita requerida';end if;
  insert into public.requisition_lines(requisition_id,catalog_item_id,product_id,item_name,category,unit,requested_qty)
  values(request_id,item.id,item.product_id,item.approved_name,'INSUMO',item.unit_of_measure,qty);
 end loop;
 insert into public.workflow_audit(branch_id,actor_id,table_name,record_id,operation)
 values(branch,auth.uid(),'requisitions',request_id,'CREATE_CATALOG_REQUISITION');
 return request_id;
end $$;
revoke execute on function public.wf_create_catalog_requisition(jsonb,jsonb) from public,anon;
grant execute on function public.wf_create_catalog_requisition(jsonb,jsonb) to authenticated;
insert into public.app_migrations(migration_code,version,description)
values('20261013133000_workflow_refinements','0.49.1','Requisiciones de catálogo y evidencia multiplataforma') on conflict(migration_code) do nothing;
notify pgrst,'reload schema';
commit;
