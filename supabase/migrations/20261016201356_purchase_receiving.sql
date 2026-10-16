begin;
-- Preserve the existing purchasing catalog. All mutations now use one atomic, authorized API.
alter table public.purchase_orders
 add column revision integer not null default 1,
 add column created_at timestamptz not null default now(),
 add column updated_at timestamptz not null default now(),
 add column payment_terms text,
 add column delivery_address text,
 add column supplier_snapshot jsonb not null default '{}',
 add column branch_snapshot jsonb not null default '{}';
alter table public.purchase_order_lines
 add column requires_lot boolean not null default true,
 add column requires_expiry boolean not null default true;
create table public.purchase_receipts(
 id uuid primary key default gen_random_uuid(),
 purchase_order_id uuid not null references public.purchase_orders(id),
 branch_id uuid not null references public.branches(id),
 receipt_code text not null unique,
 request_id uuid not null unique,
 payload_hash text not null,
 received_at timestamptz not null,
 recorded_at timestamptz not null default now(),
 received_by uuid not null references public.profiles(id),
 receiver_name text not null,
 delivery_reference text not null,
 condition text not null check(condition in ('CONFORME','OBSERVADA','RECHAZADA')),
 packaging text not null check(packaging in ('INTEGRO','DANADO','NO_APLICA')),
 documents text not null check(documents in ('COMPLETA','INCOMPLETA','NO_APLICA')),
 temperature_c numeric check(temperature_c between -100 and 100),
 notes text,
 unique(id,purchase_order_id)
);
create table public.purchase_receipt_lines(
 id uuid primary key default gen_random_uuid(),
 receipt_id uuid not null references public.purchase_receipts(id),
 purchase_order_line_id uuid not null references public.purchase_order_lines(id),
 quantity numeric not null check(quantity>0 and quantity<=1000000000),
 accepted_quantity numeric not null check(accepted_quantity>=0 and accepted_quantity<=quantity),
 unit_price numeric not null check(unit_price>=0 and unit_price<=1000000000),
 lot text,
 expiry_date date,
 notes text
);
create index purchase_orders_branch_date_idx on public.purchase_orders(branch_id,order_date desc,id);
create index purchase_order_lines_order_idx on public.purchase_order_lines(purchase_order_id,id);
create index purchase_receipts_order_idx on public.purchase_receipts(purchase_order_id,recorded_at desc,id);
create index purchase_receipt_lines_receipt_idx on public.purchase_receipt_lines(receipt_id,id);
create index purchase_receipt_lines_order_line_idx on public.purchase_receipt_lines(purchase_order_line_id);
insert into public.app_permissions(permission_code,module,description,risk_level) values
 ('PURCHASE_VIEW','SUPPLIERS','Consultar órdenes de compra y recepciones','SENSIBLE'),
 ('PURCHASE_WRITE','SUPPLIERS','Preparar órdenes de compra y proveedores','CRITICO'),
 ('PURCHASE_APPROVE','SUPPLIERS','Aprobar y enviar órdenes de compra','CRITICO'),
 ('PURCHASE_RECEIVE','SUPPLIERS','Registrar recepción y condiciones de entrega','CRITICO')
on conflict(permission_code) do update set active=true,description=excluded.description;
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r cross join public.app_permissions p
where (p.permission_code in ('PURCHASE_VIEW','SUPPLIERS_VIEW') and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','GERENCIA_GENERAL','ASISTENTE_OPERACIONES','INVENTARIO','ENCARGADA_LABORATORIO','CALIDAD','FINANZAS'))
 or (p.permission_code='PURCHASE_WRITE' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','ASISTENTE_OPERACIONES','INVENTARIO'))
 or (p.permission_code='PURCHASE_APPROVE' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','GERENCIA_GENERAL'))
 or (p.permission_code='PURCHASE_RECEIVE' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','ASISTENTE_OPERACIONES','INVENTARIO','ENCARGADA_LABORATORIO'))
on conflict do nothing;
-- Remove permissive legacy policies; identity administration remains exclusive to the super user.
do $$declare t text;p record;begin
 foreach t in array array['purchase_orders','purchase_order_lines','purchase_receipts','purchase_receipt_lines'] loop
  for p in select policyname from pg_policies where schemaname='public' and tablename=t loop
   execute format('drop policy %I on public.%I',p.policyname,t);
  end loop;
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated',t);
  execute format('grant select on public.%I to authenticated',t);
 end loop;
end$$;
create policy purchase_orders_read on public.purchase_orders for select to authenticated
 using(public.wf_active_actor() and public.has_permission('PURCHASE_VIEW') and branch_id is not null and public.can_access_branch(branch_id));
create policy purchase_order_lines_read on public.purchase_order_lines for select to authenticated
 using(exists(select 1 from public.purchase_orders p where p.id=purchase_order_id));
create policy purchase_receipts_read on public.purchase_receipts for select to authenticated
 using(exists(select 1 from public.purchase_orders p where p.id=purchase_order_id));
create policy purchase_receipt_lines_read on public.purchase_receipt_lines for select to authenticated
 using(exists(select 1 from public.purchase_receipts r where r.id=receipt_id));
create trigger purchase_order_audit after insert or update on public.purchase_orders for each row execute function public.wf_audit_change();
create trigger purchase_receipt_audit after insert on public.purchase_receipts for each row execute function public.wf_audit_change();

-- SECURITY DEFINER is needed for atomic multi-table receipts. No SQL identifiers come from input.
-- Direct table writes are revoked; authorization, active actor, branch, state and revision checked here.
create function public.procurement_action(p_action text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
 actor uuid:=auth.uid(); branch uuid; oid uuid; rid uuid; req uuid; existing uuid;
 po public.purchase_orders%rowtype; li public.purchase_order_lines%rowtype;
 x jsonb; s public.suppliers%rowtype; amount numeric; qty numeric; accepted numeric; price numeric;
 total numeric:=0; expiry date; received timestamptz; cond text; n integer; required_perm text;
begin
 if actor is null or not public.wf_active_actor() then raise exception 'La sesión no está activa.' using errcode='42501';end if;
 required_perm:=case p_action when 'CREATE' then 'PURCHASE_WRITE' when 'UPDATE' then 'PURCHASE_WRITE' when 'SUPPLIER' then 'PURCHASE_WRITE' when 'APPROVE' then 'PURCHASE_APPROVE' when 'SEND' then 'PURCHASE_APPROVE' when 'CANCEL' then 'PURCHASE_APPROVE' when 'RECEIVE' then 'PURCHASE_RECEIVE' else null end;
 if required_perm is null or not public.has_permission(required_perm) or not public.has_permission('PURCHASE_VIEW') then raise exception 'No tiene permiso para esta acción.' using errcode='42501';end if;
 if p_action='SUPPLIER' then
  if nullif(trim(p_payload->>'legal_name'),'') is null then raise exception 'Indique la razón social.';end if;
  insert into public.suppliers(supplier_code,legal_name,tax_id,contact_name,phone,email,address,supplier_type,critical)
  values('PRV-'||upper(left(replace(gen_random_uuid()::text,'-',''),12)),trim(p_payload->>'legal_name'),nullif(trim(p_payload->>'tax_id'),''),nullif(trim(p_payload->>'contact_name'),''),nullif(trim(p_payload->>'phone'),''),nullif(trim(p_payload->>'email'),''),nullif(trim(p_payload->>'address'),''),coalesce(nullif(trim(p_payload->>'supplier_type'),''),'GENERAL'),coalesce((p_payload->>'critical')::boolean,false)) returning id into oid;
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
 if branch is null or not public.can_access_branch(branch) then raise exception 'Sucursal no autorizada.' using errcode='42501';end if;
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
  select * into s from public.suppliers where id=(p_payload->>'supplier_id')::uuid and status in ('ACTIVO','CONDICIONAL');
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
   insert into public.purchase_order_lines(purchase_order_id,item_type,item_reference,description,quantity,unit,unit_price,received_quantity,requires_lot,requires_expiry)
   values(oid,'INSUMO',nullif(trim(x->>'item_reference'),''),trim(x->>'description'),qty,coalesce(nullif(trim(x->>'unit'),''),'unidad'),price,0,coalesce((x->>'requires_lot')::boolean,true),coalesce((x->>'requires_expiry')::boolean,true));
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
   values(rid,li.id,qty,accepted,price,nullif(trim(x->>'lot'),''),expiry,nullif(trim(x->>'notes'),''));
   update public.purchase_order_lines set received_quantity=coalesce(received_quantity,0)+accepted where id=li.id;
  end loop;
  update public.purchase_orders set status=case when not exists(select 1 from public.purchase_order_lines where purchase_order_id=oid and coalesce(received_quantity,0)<quantity) then 'RECIBIDA' else 'PARCIAL' end,revision=revision+1,updated_at=now() where id=oid;
 end if;
 return jsonb_build_object('id',oid,'receipt_id',rid);
end$$;
revoke all on function public.procurement_action(text,jsonb) from public,anon;
grant execute on function public.procurement_action(text,jsonb) to authenticated;
comment on column public.purchase_order_lines.received_quantity is 'Cantidad aceptada acumulada; las cantidades rechazadas permanecen pendientes y constan en el historial.';
comment on table public.purchase_receipts is 'Recepciones históricas inmutables. No contabiliza existencias automáticamente.';
notify pgrst,'reload schema';
commit;
