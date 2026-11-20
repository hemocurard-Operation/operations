begin;
-- Branch responsibility comes from the server profile; only the super user has cross-branch purchasing access.
create function public.operations_branch_allowed(p_branch uuid) returns boolean language sql stable security invoker set search_path=public,pg_temp as $$
 select auth.uid() is not null and public.wf_active_actor() and p_branch is not null and public.can_access_branch(p_branch)
 and (public.has_role('SUPER_USUARIO') or p_branch=(select branch_id from public.profiles where id=auth.uid()));
$$;
revoke all on function public.operations_branch_allowed(uuid) from public,anon;grant execute on function public.operations_branch_allowed(uuid) to authenticated;
alter table public.suppliers add column branch_id uuid references public.branches(id);
alter table public.supplier_evaluations add column branch_id uuid references public.branches(id);
-- Assign legacy suppliers only when existing documents identify a single branch unambiguously.
with usage as(select supplier_id,branch_id from public.purchase_orders where branch_id is not null union select supplier_id,branch_id from public.supplier_quotations),one_branch as(select supplier_id,min(branch_id::text)::uuid as branch_id from usage group by supplier_id having count(distinct branch_id)=1)
update public.suppliers s set branch_id=b.branch_id from one_branch b where b.supplier_id=s.id;
update public.supplier_evaluations e set branch_id=s.branch_id from public.suppliers s where s.id=e.supplier_id;
create index suppliers_branch_lookup on public.suppliers(branch_id,legal_name,id);
create index supplier_evaluations_branch_lookup on public.supplier_evaluations(branch_id,supplier_id,evaluation_date desc);
do $$declare p record;begin for p in select tablename,policyname from pg_policies where schemaname='public' and tablename in ('suppliers','supplier_evaluations','supplier_incidents') loop execute format('drop policy %I on public.%I',p.policyname,p.tablename);end loop;end$$;
create policy suppliers_scoped_read on public.suppliers for select to authenticated using(public.wf_active_actor() and (public.has_permission('PURCHASE_VIEW') or public.has_permission('SUPPLIERS_VIEW')) and (public.operations_branch_allowed(branch_id) or branch_id is null and public.has_role('SUPER_USUARIO')));
create policy suppliers_scoped_write on public.suppliers for all to authenticated using(public.operations_branch_allowed(branch_id) and (public.has_permission('PURCHASE_WRITE') or public.has_permission('SUPPLIERS_WRITE'))) with check(public.operations_branch_allowed(branch_id) and (public.has_permission('PURCHASE_WRITE') or public.has_permission('SUPPLIERS_WRITE')));
create policy supplier_evaluations_scoped on public.supplier_evaluations for select to authenticated using(public.operations_branch_allowed(branch_id) or branch_id is null and public.wf_active_actor() and public.has_role('SUPER_USUARIO'));
create policy supplier_evaluations_write_scoped on public.supplier_evaluations for all to authenticated using(public.operations_branch_allowed(branch_id) and public.has_permission('SUPPLIERS_WRITE')) with check(public.operations_branch_allowed(branch_id) and public.has_permission('SUPPLIERS_WRITE'));
create policy supplier_incidents_scoped on public.supplier_incidents for select to authenticated using(public.operations_branch_allowed(branch_id) or branch_id is null and public.wf_active_actor() and public.has_role('SUPER_USUARIO'));
create policy supplier_incidents_write_scoped on public.supplier_incidents for all to authenticated using(public.operations_branch_allowed(branch_id) and public.has_permission('SUPPLIERS_WRITE')) with check(public.operations_branch_allowed(branch_id) and public.has_permission('SUPPLIERS_WRITE'));
alter view public.vw_supplier_performance set(security_invoker=true);
create or replace view public.vw_supplier_performance with(security_invoker=true) as
select s.id,s.supplier_code,s.legal_name,s.critical,s.status,e.evaluation_date,e.total_score,e.result,e.next_review_date,
case when e.next_review_date is not null and e.next_review_date<current_date then true else false end review_overdue,s.branch_id
from public.suppliers s left join lateral(select * from public.supplier_evaluations x where x.supplier_id=s.id and x.branch_id is not distinct from s.branch_id order by evaluation_date desc,id limit 1)e on true;
-- Restrictive policies compose with the existing permission and record-specific policies.
create policy purchase_branch_boundary on public.purchase_orders as restrictive for all to authenticated using(public.operations_branch_allowed(branch_id)) with check(public.operations_branch_allowed(branch_id));
create policy quotation_branch_boundary on public.supplier_quotations as restrictive for all to authenticated using(public.operations_branch_allowed(branch_id)) with check(public.operations_branch_allowed(branch_id));
create policy decision_branch_boundary on public.quotation_decisions as restrictive for all to authenticated using(public.operations_branch_allowed(branch_id)) with check(public.operations_branch_allowed(branch_id));
create policy receipt_branch_boundary on public.purchase_receipts as restrictive for all to authenticated using(public.operations_branch_allowed(branch_id)) with check(public.operations_branch_allowed(branch_id));
create policy requisition_branch_boundary on public.requisitions as restrictive for all to authenticated using(public.operations_branch_allowed(requesting_branch_id)) with check(public.operations_branch_allowed(requesting_branch_id));
create function private.guard_purchase_branch() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
declare owner_branch uuid;b uuid;
begin
 -- Owner migrations and isolated SQL fixtures may load historical records without an application identity.
 if auth.uid() is null then if current_user in ('postgres','supabase_admin') then return new;end if;raise exception 'Inicia sesión.' using errcode='42501';end if;
 b:=new.branch_id;
 if tg_table_name='suppliers' and b is null then if public.has_role('SUPER_USUARIO') then raise exception 'Selecciona la sucursal del proveedor.';end if;select branch_id into b from public.profiles where id=auth.uid();new.branch_id:=b;end if;
 if tg_table_name='supplier_evaluations' and b is null then select branch_id into b from public.suppliers where id=new.supplier_id;new.branch_id:=b;end if;
 if not public.operations_branch_allowed(b) then raise exception 'Solo puedes operar datos de tu sucursal asignada.' using errcode='42501';end if;
 if tg_table_name<>'suppliers' then
  select branch_id into owner_branch from public.suppliers where id=new.supplier_id;
  if not found or owner_branch is distinct from b then raise exception 'El proveedor no pertenece a la sucursal seleccionada.' using errcode='42501';end if;
 end if;
 return new;
end$$;
revoke all on function private.guard_purchase_branch() from public,anon,authenticated;
create trigger supplier_branch_guard before insert or update on public.suppliers for each row execute function private.guard_purchase_branch();
create trigger evaluation_branch_guard before insert or update on public.supplier_evaluations for each row execute function private.guard_purchase_branch();
create trigger incident_branch_guard before insert or update on public.supplier_incidents for each row execute function private.guard_purchase_branch();
create trigger order_branch_guard before insert or update on public.purchase_orders for each row execute function private.guard_purchase_branch();
create trigger quotation_branch_guard before insert or update on public.supplier_quotations for each row execute function private.guard_purchase_branch();
alter table public.requisitions add column client_request_id uuid,add column request_payload_hash text;
create unique index requisitions_client_request on public.requisitions(client_request_id) where client_request_id is not null;
create sequence public.operational_requisition_code_seq;
revoke all on sequence public.operational_requisition_code_seq from public,anon,authenticated;

create or replace function public.wf_create_catalog_requisition(p_header jsonb,p_lines jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare branch uuid; request_id uuid; item public.workflow_supply_catalog%rowtype; line jsonb; qty numeric; code text; client_key uuid; digest text; old_hash text;serial_no bigint;
begin
 branch:=(p_header->>'requesting_branch_id')::uuid;perform public.wf_require('REQUISITION_WRITE',branch);
 if not public.operations_branch_allowed(branch) then raise exception 'Sucursal no autorizada.' using errcode='42501';end if;
 client_key:=nullif(p_header->>'client_request_id','')::uuid;digest:=md5(jsonb_build_object('header',p_header,'lines',p_lines)::text);
 if client_key is not null then
  perform pg_advisory_xact_lock(hashtextextended(client_key::text,792));
  select id,request_payload_hash into request_id,old_hash from public.requisitions where client_request_id=client_key and requested_by=auth.uid();
  if found then if old_hash is distinct from digest then raise exception 'La solicitud ya fue enviada con otros datos.';end if;return request_id;end if;
 end if;
 p_header:=p_header||jsonb_build_object('request_date',coalesce(nullif(p_header->>'request_date',''),(now() at time zone 'America/Santo_Domingo')::date::text),'priority',coalesce(nullif(p_header->>'priority',''),'NORMAL'),'department',coalesce(nullif(trim(p_header->>'department'),''),case when public.has_role('ENCARGADA_LABORATORIO') or public.has_role('LABORATORIO') then 'Laboratorio' else 'Operaciones' end));
 code:=nullif(btrim(p_header->>'requisition_code'),'');
 if code is null then loop serial_no:=nextval('public.operational_requisition_code_seq');code:='REQ-'||to_char((now() at time zone 'America/Santo_Domingo')::date,'YYYYMMDD')||'-'||lpad(serial_no::text,greatest(6,length(serial_no::text)),'0');exit when not exists(select 1 from public.requisitions where requisition_code=code);end loop;end if;
 if code is null or p_header->>'request_date' is null or p_header->>'priority' is null or p_header->>'priority' not in ('NORMAL','URGENTE') then raise exception 'Código, fecha y prioridad requeridos';end if;
 if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines)<1 or jsonb_array_length(p_lines)>100 then raise exception 'Entre 1 y 100 insumos requeridos';end if;
 if (select count(distinct v->>'catalog_item_id') from jsonb_array_elements(p_lines)v)<>jsonb_array_length(p_lines) then raise exception 'Insumos duplicados o ausentes';end if;
 -- Header and lines are committed together; any failed item rolls back the header.
 insert into public.requisitions(requisition_code,request_date,requesting_branch_id,requested_by,department,priority,justification,status,client_request_id,request_payload_hash)
 values(code,(p_header->>'request_date')::date,branch,auth.uid(),nullif(btrim(p_header->>'department'),''),p_header->>'priority',nullif(btrim(p_header->>'justification'),''),'PENDIENTE',client_key,digest) returning id into request_id;
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
create or replace function public.procurement_action(p_action text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
 actor uuid:=auth.uid(); branch uuid; oid uuid; rid uuid; rline uuid; req uuid; existing uuid;
 po public.purchase_orders%rowtype; li public.purchase_order_lines%rowtype;
 x jsonb; s public.suppliers%rowtype; amount numeric; qty numeric; accepted numeric; price numeric;
 total numeric:=0; expiry date; received timestamptz; cond text; n integer; required_perm text;
 v_auto boolean; v_line_product uuid;
begin
 if actor is null or not public.wf_active_actor() then raise exception 'La sesión no está activa.' using errcode='42501';end if;
 required_perm:=case p_action when 'CREATE' then 'PURCHASE_WRITE' when 'UPDATE' then 'PURCHASE_WRITE' when 'SUPPLIER' then 'PURCHASE_WRITE' when 'APPROVE' then 'PURCHASE_APPROVE' when 'SEND' then 'PURCHASE_APPROVE' when 'CANCEL' then 'PURCHASE_APPROVE' when 'RECEIVE' then 'PURCHASE_RECEIVE' else null end;
 if required_perm is null or not public.has_permission(required_perm) or not public.has_permission('PURCHASE_VIEW') then raise exception 'No tiene permiso para esta acción.' using errcode='42501';end if;
 if p_action='SUPPLIER' then
  if nullif(trim(p_payload->>'legal_name'),'') is null then raise exception 'Indique la razón social.';end if;
  insert into public.suppliers(branch_id,supplier_code,legal_name,tax_id,contact_name,phone,email,address,supplier_type,critical)
  values((p_payload->>'branch_id')::uuid,'PRV-'||upper(left(replace(gen_random_uuid()::text,'-',''),12)),trim(p_payload->>'legal_name'),nullif(trim(p_payload->>'tax_id'),''),nullif(trim(p_payload->>'contact_name'),''),nullif(trim(p_payload->>'phone'),''),nullif(trim(p_payload->>'email'),''),nullif(trim(p_payload->>'address'),''),coalesce(nullif(trim(p_payload->>'supplier_type'),''),'GENERAL'),coalesce((p_payload->>'critical')::boolean,false)) returning id into oid;
  return jsonb_build_object('id',oid);
 end if;
 if p_action='CREATE' then
  branch:=(p_payload->>'branch_id')::uuid;
 else
  oid:=(p_payload->>'id')::uuid;
  select * into po from public.purchase_orders where id=oid for update;
  if not found then raise exception 'Orden no disponible.';end if;
  branch:=po.branch_id;
 end if;
 if branch is null or not public.operations_branch_allowed(branch) then raise exception 'Sucursal no autorizada.' using errcode='42501';end if;
 if p_action='RECEIVE' then
  req:=(p_payload->>'request_id')::uuid;
  if req is null then raise exception 'Falta identificador de recepción.';end if;
  select id into existing from public.purchase_receipts where request_id=req and purchase_order_id=oid;
  if found then
   if not exists(select 1 from public.purchase_receipts where id=existing and payload_hash=md5(p_payload::text)) then raise exception 'El identificador ya pertenece a una recepción con otros datos.';end if;
   return jsonb_build_object('id',oid,'receipt_id',existing,'already_recorded',true);
  end if;
 end if;
 if p_action<>'CREATE' and (p_payload->>'revision')::integer is distinct from po.revision then raise exception 'La orden cambió. Actualice antes de guardar.' using errcode='40001';end if;
 if p_action in ('CREATE','UPDATE') then
  if p_action='UPDATE' and po.status<>'BORRADOR' then raise exception 'Solo se puede editar un borrador.';end if;
  select * into s from public.suppliers where id=(p_payload->>'supplier_id')::uuid and branch_id=branch and status in ('ACTIVO','CONDICIONAL');
  if not found then raise exception 'Seleccione un proveedor activo.';end if;
  if coalesce(p_payload->>'currency','DOP') not in ('DOP','USD','EUR') then raise exception 'Moneda no válida.';end if;
  if jsonb_typeof(p_payload->'lines') is distinct from 'array' then raise exception 'Agregue los artículos.';end if;
  n:=jsonb_array_length(p_payload->'lines');if n<1 or n>200 then raise exception 'La orden admite entre 1 y 200 artículos.';end if;
  if nullif(p_payload->>'required_date','')::date < coalesce(nullif(p_payload->>'order_date','')::date,(now() at time zone 'America/Santo_Domingo')::date) then raise exception 'La fecha requerida no puede preceder la orden.';end if;
  if p_action='CREATE' then
   insert into public.purchase_orders(po_code,branch_id,supplier_id,requested_by,supplier_snapshot,branch_snapshot)
   values('OC-'||to_char(now() at time zone 'America/Santo_Domingo','YYYYMMDD')||'-'||upper(left(replace(gen_random_uuid()::text,'-',''),12)),branch,s.id,actor,to_jsonb(s),(select to_jsonb(b) from public.branches b where b.id=branch)) returning id into oid;
  else delete from public.purchase_order_lines where purchase_order_id=oid;
  end if;
  for x in select value from jsonb_array_elements(p_payload->'lines') loop
   qty:=(x->>'quantity')::numeric;price:=(x->>'unit_price')::numeric;
   if qty is null or qty<=0 or qty>1000000000 or price is null or price<0 or price>1000000000 or nullif(trim(x->>'description'),'') is null then raise exception 'Cada artículo requiere descripción, cantidad positiva y precio no negativo.';end if;
   v_line_product:=nullif(x->>'product_id','')::uuid;
   if v_line_product is not null and not exists(select 1 from public.products where id=v_line_product and active) then raise exception 'El producto vinculado no existe o está inactivo.';end if;
   insert into public.purchase_order_lines(purchase_order_id,item_type,item_reference,description,quantity,unit,unit_price,received_quantity,requires_lot,requires_expiry,product_id)
   values(oid,'INSUMO',nullif(trim(x->>'item_reference'),''),trim(x->>'description'),qty,coalesce(nullif(trim(x->>'unit'),''),'unidad'),price,0,coalesce((x->>'requires_lot')::boolean,true),coalesce((x->>'requires_expiry')::boolean,true),v_line_product);
   total:=total+round(qty*price,2);
  end loop;
  update public.purchase_orders set supplier_id=s.id,supplier_snapshot=to_jsonb(s),order_date=coalesce(nullif(p_payload->>'order_date','')::date,(now() at time zone 'America/Santo_Domingo')::date),required_date=nullif(p_payload->>'required_date','')::date,
   currency=coalesce(p_payload->>'currency','DOP'),payment_terms=nullif(trim(p_payload->>'payment_terms'),''),delivery_address=nullif(trim(p_payload->>'delivery_address'),''),notes=nullif(trim(p_payload->>'notes'),''),total_amount=total,
   revision=case when p_action='UPDATE' then revision+1 else revision end,updated_at=now() where id=oid;
 elsif p_action='APPROVE' then
  if not exists(select 1 from public.suppliers where id=po.supplier_id and status in ('ACTIVO','CONDICIONAL')) then raise exception 'El proveedor no está activo.';end if;
  if po.status<>'BORRADOR' or not exists(select 1 from public.purchase_order_lines where purchase_order_id=oid) then raise exception 'Solo se aprueban borradores con artículos.';end if;
  update public.purchase_orders set status='APROBADA',approved_by=actor,revision=revision+1,updated_at=now() where id=oid;
 elsif p_action='SEND' then
  if po.status<>'APROBADA' then raise exception 'La orden debe estar aprobada.';end if;
  update public.purchase_orders set status='ENVIADA',revision=revision+1,updated_at=now() where id=oid;
 elsif p_action='CANCEL' then
  if po.status not in ('BORRADOR','APROBADA','ENVIADA') or exists(select 1 from public.purchase_receipts where purchase_order_id=oid) then raise exception 'No se puede cancelar una orden con recepciones.';end if;
  if nullif(trim(p_payload->>'reason'),'') is null then raise exception 'Indique el motivo de cancelación.';end if;
  update public.purchase_orders set status='CANCELADA',notes=concat_ws(E'\n',notes,'Cancelación: '||trim(p_payload->>'reason')),revision=revision+1,updated_at=now() where id=oid;
 elsif p_action='RECEIVE' then
  if po.status not in ('APROBADA','ENVIADA','PARCIAL') then raise exception 'La orden no admite recepciones.';end if;
  received:=(p_payload->>'received_at')::timestamptz;
  if received is null or received>now()+interval '5 minutes' or (received at time zone 'America/Santo_Domingo')::date<po.order_date then raise exception 'Fecha de recepción no válida.';end if;
  cond:=p_payload->>'condition';
  if cond is null or cond not in ('CONFORME','OBSERVADA','RECHAZADA') then raise exception 'Indique las condiciones de recepción.';end if;
  if nullif(trim(p_payload->>'delivery_reference'),'') is null then raise exception 'Indique factura o conduce.';end if;
  if (cond<>'CONFORME' or p_payload->>'packaging'='DANADO' or p_payload->>'documents'='INCOMPLETA') and nullif(trim(p_payload->>'notes'),'') is null then raise exception 'Documente las observaciones de recepción.';end if;
  if cond='CONFORME' and (p_payload->>'packaging'='DANADO' or p_payload->>'documents'='INCOMPLETA') then raise exception 'Use OBSERVADA o RECHAZADA para una entrega con incidencias.';end if;
  if jsonb_typeof(p_payload->'lines') is distinct from 'array' or coalesce(jsonb_array_length(p_payload->'lines'),0) not between 1 and 200 then raise exception 'Agregue entre 1 y 200 lotes a la recepción.';end if;
  select coalesce(enabled,false) and mode in ('LIVE','LIVE_LIMITED') into v_auto
  from public.app_feature_flags where key='purchase_receipt_auto_inventory';
  v_auto:=coalesce(v_auto,false);
  insert into public.purchase_receipts(purchase_order_id,branch_id,receipt_code,request_id,payload_hash,received_at,received_by,receiver_name,delivery_reference,condition,packaging,documents,temperature_c,notes)
  values(oid,branch,'REC-'||upper(left(replace(gen_random_uuid()::text,'-',''),12)),req,md5(p_payload::text),received,actor,(select coalesce(full_name,'Usuario') from public.profiles where id=actor),trim(p_payload->>'delivery_reference'),cond,p_payload->>'packaging',p_payload->>'documents',nullif(p_payload->>'temperature_c','')::numeric,nullif(trim(p_payload->>'notes'),'')) returning id into rid;
  for x in select value from jsonb_array_elements(p_payload->'lines') loop
   select * into li from public.purchase_order_lines where id=(x->>'line_id')::uuid and purchase_order_id=oid for update;
   if not found then raise exception 'Artículo ajeno a esta orden.';end if;
   qty:=(x->>'quantity')::numeric;accepted:=(x->>'accepted_quantity')::numeric;price:=(x->>'unit_price')::numeric;expiry:=nullif(x->>'expiry_date','')::date;
   if qty is null or qty<=0 or qty>1000000000 or accepted is null or accepted<0 or accepted>qty or price is null or price<0 or price>1000000000 then raise exception 'Cantidad o precio de recepción no válido.';end if;
   if accepted+coalesce(li.received_quantity,0)>li.quantity then raise exception 'La cantidad aceptada supera el saldo pendiente de la orden.';end if;
   if li.requires_lot and nullif(trim(x->>'lot'),'') is null then raise exception 'El artículo requiere lote.';end if;
   if li.requires_expiry and expiry is null then raise exception 'El artículo requiere fecha de vencimiento.';end if;
   if accepted>0 and expiry is not null and expiry<=(received at time zone 'America/Santo_Domingo')::date then raise exception 'No se pueden aceptar artículos vencidos.';end if;
   if cond='RECHAZADA' and accepted>0 then raise exception 'Una entrega rechazada no admite cantidades aceptadas.';end if;
   if accepted<qty and nullif(trim(x->>'notes'),'') is null then raise exception 'Indique el motivo de la cantidad rechazada.';end if;
   if cond='CONFORME' and accepted<qty then raise exception 'Use OBSERVADA o RECHAZADA si hay cantidades rechazadas.';end if;
   insert into public.purchase_receipt_lines(receipt_id,purchase_order_line_id,quantity,accepted_quantity,unit_price,lot,expiry_date,notes)
   values(rid,li.id,qty,accepted,price,nullif(trim(x->>'lot'),''),expiry,nullif(trim(x->>'notes'),'')) returning id into rline;
   update public.purchase_order_lines set received_quantity=coalesce(received_quantity,0)+accepted where id=li.id;
   if v_auto and accepted>0 and li.product_id is not null then
    insert into public.inventory_movements(movement_date,branch_id,product_id,movement_type,quantity,source_table,source_id,notes,created_by)
    values((received at time zone 'America/Santo_Domingo')::date,branch,li.product_id,'PURCHASE',accepted,'purchase_receipt_lines',rline,'Generado al aceptar recepción '||rid::text,actor)
    on conflict (source_table,source_id,movement_type) where source_table='purchase_receipt_lines' and movement_type='PURCHASE' do nothing;
   end if;
  end loop;
  update public.purchase_orders set status=case when not exists(select 1 from public.purchase_order_lines where purchase_order_id=oid and coalesce(received_quantity,0)<quantity) then 'RECIBIDA' else 'PARCIAL' end,revision=revision+1,updated_at=now() where id=oid;
 end if;
 return jsonb_build_object('id',oid,'receipt_id',rid);
end$$;
revoke all on function public.procurement_action(text,jsonb) from public,anon;
grant execute on function public.procurement_action(text,jsonb) to authenticated;

create or replace function public.admin_workspace_preview(p_target uuid default null,p_search text default '',p_offset integer default 0)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
 if not public.has_permission('WORKSPACE_PREVIEW_VIEW') or
    not (public.has_role('ADMIN') or public.has_role('SUPER_USUARIO')) then
  raise exception 'Administrador activo y permiso de consulta requeridos' using errcode='42501';
 end if;
 if p_offset<0 or p_offset>100000 or length(coalesce(p_search,''))>100 then
  raise exception 'Consulta fuera de límites' using errcode='22023';
 end if;
 if p_target is not null and not exists(select 1 from public.profiles where id=p_target) then
  raise exception 'Usuario no disponible' using errcode='P0002';
 end if;
 with page as (
  select p.id,p.full_name,p.active,p.branch_id,(select name from public.branches where id=p.branch_id) as branch_name from public.profiles p
  where coalesce(p.full_name,'') ilike '%'||coalesce(p_search,'')||'%'
  order by p.full_name nulls last,p.id limit 50 offset p_offset
 ), selected as (
  select * from page union
  select p.id,p.full_name,p.active,p.branch_id,(select name from public.branches where id=p.branch_id) as branch_name from public.profiles p where p.id=p_target
 ), users as (
  select p.*,coalesce((select jsonb_agg(jsonb_build_object(
   'role_id',r.id,'role_code',r.code,'role_name',r.name,
   'branch_id',ur.branch_id,'branch_name',b.name) order by r.code,ur.branch_id)
   from public.user_roles ur join public.roles r on r.id=ur.role_id
   left join public.branches b on b.id=ur.branch_id where ur.user_id=p.id),'[]'::jsonb) as roles
  from selected p
 )
 select jsonb_build_object('caller_user_id',auth.uid(),
  'users',coalesce((select jsonb_agg(to_jsonb(u) order by u.full_name nulls last,u.id) from users u),'[]'::jsonb),
  'has_more',(select count(*)>p_offset+50 from public.profiles where coalesce(full_name,'') ilike '%'||coalesce(p_search,'')||'%'),
  'branches',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'active',active)) from public.branches where active),'[]'::jsonb),
  'catalog',coalesce((select jsonb_agg(jsonb_build_object('route_key',route_key,'title',title,'group_name',group_name,'permission_code',permission_code,'active',active)) from public.app_module_catalog),'[]'::jsonb),
  'settings',coalesce((select jsonb_agg(jsonb_build_object('role_id',role_id,'route_key',route_key,'enabled',enabled)) from public.role_module_access),'[]'::jsonb),
  'permissions',coalesce((select jsonb_agg(jsonb_build_object('permission_code',permission_code,'active',active)) from public.app_permissions),'[]'::jsonb),
  'rolePermissions',coalesce((select jsonb_agg(jsonb_build_object('role_id',role_id,'permission_code',permission_code)) from public.role_permissions),'[]'::jsonb)
 ) into result;
 insert into public.workspace_preview_access_log(actor_id,target_id) values(auth.uid(),p_target);
 return result;
end;$$;
revoke all on function public.admin_workspace_preview(uuid,text,integer) from public,anon;
grant execute on function public.admin_workspace_preview(uuid,text,integer) to authenticated;

notify pgrst,'reload schema';
commit;
