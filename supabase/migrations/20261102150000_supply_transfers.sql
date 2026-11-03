begin;
-- Traslado de insumos entre sucursales. Replica exactamente el patrón ya probado
-- por blood_transfers/wf_send_transfer/wf_receive_transfer: se descuenta del origen
-- al enviar (TRANSFER_OUT) y solo se acredita al destino al confirmar recepción
-- (TRANSFER_IN) — ambos tipos de movimiento ya existían en movement_type sin que
-- ningún código los generara. Sin estados intermedios de "reserva": al no haber
-- unidades físicas individuales para insumos, el envío mismo retira la cantidad
-- del saldo teórico de origen (igual que ocurre con RESERVADA para sangre).

create table public.supply_transfers(
 id uuid primary key default gen_random_uuid(),
 branch_id uuid not null references public.branches(id),
 destination_branch_id uuid not null references public.branches(id),
 batch_code text not null,
 request_id uuid not null unique,
 status text not null default 'EN_TRANSITO' check(status in ('EN_TRANSITO','PARCIAL','RECIBIDA')),
 transport_evidence text not null,
 sent_by uuid not null references public.profiles(id),
 sent_at timestamptz not null default now(),
 check(branch_id<>destination_branch_id),
 unique(branch_id,batch_code)
);
create table public.supply_transfer_lines(
 id uuid primary key default gen_random_uuid(),
 transfer_id uuid not null references public.supply_transfers(id),
 product_id uuid not null references public.products(id),
 quantity numeric not null check(quantity>0 and quantity<=1000000000),
 received_at timestamptz,
 received_by uuid references public.profiles(id),
 receipt_evidence text,
 receipt_condition text check(receipt_condition is null or receipt_condition in ('CONFORME','OBSERVADA','RECHAZADA'))
);
create index supply_transfers_branch_idx on public.supply_transfers(branch_id,sent_at desc,id);
create index supply_transfers_destination_idx on public.supply_transfers(destination_branch_id,sent_at desc,id);
create index supply_transfer_lines_transfer_idx on public.supply_transfer_lines(transfer_id,id);

create unique index ux_inventory_supply_transfer_out
on public.inventory_movements(source_table,source_id,movement_type)
where source_table='supply_transfer_lines' and movement_type='TRANSFER_OUT';
create unique index ux_inventory_supply_transfer_in
on public.inventory_movements(source_table,source_id,movement_type)
where source_table='supply_transfer_lines' and movement_type='TRANSFER_IN';

insert into public.app_permissions(permission_code,module,description,risk_level) values
 ('SUPPLY_TRANSFER_VIEW','SUPPLIES','Consultar traslados de insumos entre sucursales','SENSIBLE'),
 ('SUPPLY_TRANSFER_WRITE','SUPPLIES','Enviar traslados de insumos entre sucursales','CRITICO'),
 ('SUPPLY_TRANSFER_RECEIVE','SUPPLIES','Recibir traslados de insumos entre sucursales','CRITICO')
on conflict(permission_code) do update set active=true,description=excluded.description;
insert into public.role_permissions(role_id,permission_code)
select r.id,p.permission_code from public.roles r cross join public.app_permissions p
where (p.permission_code='SUPPLY_TRANSFER_VIEW' and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','GERENCIA_GENERAL','ASISTENTE_OPERACIONES','INVENTARIO','ENCARGADA_LABORATORIO','CALIDAD'))
 or (p.permission_code in ('SUPPLY_TRANSFER_WRITE','SUPPLY_TRANSFER_RECEIVE') and r.code in ('SUPER_USUARIO','ADMIN','GERENCIA_OPERATIVA','ASISTENTE_OPERACIONES','INVENTARIO'))
on conflict do nothing;

alter table public.supply_transfers enable row level security;
revoke all privileges on public.supply_transfers from public,authenticated,anon;
create policy supply_transfers_read on public.supply_transfers for select to authenticated
 using(public.wf_active_actor() and public.has_permission('SUPPLY_TRANSFER_VIEW') and (public.can_access_branch(branch_id) or public.can_access_branch(destination_branch_id)));
grant select on public.supply_transfers to authenticated;
create trigger wf_audit after insert or update on public.supply_transfers for each row execute function public.wf_audit_change();

alter table public.supply_transfer_lines enable row level security;
revoke all privileges on public.supply_transfer_lines from public,authenticated,anon;
create policy supply_transfer_lines_read on public.supply_transfer_lines for select to authenticated
 using(public.wf_active_actor() and exists(select 1 from public.supply_transfers t where t.id=transfer_id));
grant select on public.supply_transfer_lines to authenticated;
create trigger wf_audit after insert or update on public.supply_transfer_lines for each row execute function public.wf_audit_change();

create or replace view public.vw_supply_transfer_lines with (security_invoker=true) as
select l.*,t.branch_id,t.destination_branch_id,t.batch_code,t.status as transfer_status,t.transport_evidence,t.sent_by,t.sent_at
from public.supply_transfer_lines l join public.supply_transfers t on t.id=l.transfer_id;
grant select on public.vw_supply_transfer_lines to authenticated;

-- wf_audit_change() ya resuelve branch_id leyendo blood_transfers para blood_transfer_lines;
-- se extiende con el mismo criterio para supply_transfer_lines.
create or replace function public.wf_audit_change()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare b uuid; j jsonb:=to_jsonb(new);
begin
 b:=nullif(j->>'branch_id','')::uuid;
 if b is null and tg_table_name='blood_transfer_lines' then select branch_id into b from public.blood_transfers where id=new.transfer_id;end if;
 if b is null and tg_table_name='supply_transfer_lines' then select branch_id into b from public.supply_transfers where id=new.transfer_id;end if;
 insert into public.workflow_audit(branch_id,actor_id,table_name,record_id,operation,old_status,new_status)
 values(b,auth.uid(),tg_table_name,(j->>'id')::uuid,tg_op,case when tg_op='UPDATE' then to_jsonb(old)->>'status' end,j->>'status');
 return new;
end $$;
revoke execute on function public.wf_audit_change() from public,anon,authenticated;

create or replace function public.wf_send_supply_transfer(p_branch uuid,p_destination uuid,p_batch text,p_lines jsonb,p_evidence text,p_request_id uuid)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare result uuid; x jsonb; pid uuid; qty numeric; n integer; balance numeric; existing uuid; lid uuid;
begin
 perform public.wf_require('SUPPLY_TRANSFER_WRITE',p_branch);
 if p_destination is null or p_destination=p_branch or not exists(select 1 from public.branches where id=p_destination and active)
  or nullif(btrim(p_batch),'') is null or nullif(btrim(p_evidence),'') is null then raise exception 'Destino, lote y evidencia requeridos';end if;
 if p_request_id is null then raise exception 'Falta identificador de envío.';end if;
 select id into existing from public.supply_transfers where request_id=p_request_id;
 if found then return existing;end if;
 if jsonb_typeof(p_lines) is distinct from 'array' then raise exception 'Agregue los productos a trasladar.';end if;
 n:=jsonb_array_length(p_lines);if n<1 or n>200 then raise exception 'El traslado admite entre 1 y 200 productos.';end if;
 insert into public.supply_transfers(branch_id,destination_branch_id,batch_code,request_id,transport_evidence,sent_by)
 values(p_branch,p_destination,btrim(p_batch),p_request_id,btrim(p_evidence),auth.uid()) returning id into result;
 for x in select value from jsonb_array_elements(p_lines) loop
  pid:=(x->>'product_id')::uuid;qty:=(x->>'quantity')::numeric;
  if pid is null or qty is null or qty<=0 or qty>1000000000 then raise exception 'Cada línea requiere producto y cantidad positiva.';end if;
  if not exists(select 1 from public.products where id=pid and active) then raise exception 'Producto inactivo o inexistente.';end if;
  -- Serializa envíos concurrentes del mismo producto/sucursal; no hay fila de saldo física que bloquear.
  perform pg_advisory_xact_lock(hashtextextended(p_branch::text||pid::text,0));
  select coalesce(sum(case movement_type
    when 'INITIAL' then quantity when 'PURCHASE' then quantity when 'TRANSFER_IN' then quantity
    when 'RETURN' then quantity when 'ADJUSTMENT_POSITIVE' then quantity
    when 'TRANSFER_OUT' then -quantity when 'CONSUMPTION' then -quantity when 'DISPATCH' then -quantity
    when 'DISCARD' then -quantity when 'ADJUSTMENT_NEGATIVE' then -quantity else 0 end),0) into balance
  from public.inventory_movements where branch_id=p_branch and product_id=pid;
  if qty>balance then raise exception 'Existencia insuficiente en la sucursal de origen para trasladar la cantidad solicitada.';end if;
  insert into public.supply_transfer_lines(transfer_id,product_id,quantity) values(result,pid,qty) returning id into lid;
  insert into public.inventory_movements(movement_date,branch_id,product_id,movement_type,quantity,source_table,source_id,notes,created_by)
  values((now() at time zone 'America/Santo_Domingo')::date,p_branch,pid,'TRANSFER_OUT',qty,'supply_transfer_lines',lid,'Enviado en traslado '||result::text,auth.uid())
  on conflict (source_table,source_id,movement_type) where source_table='supply_transfer_lines' and movement_type='TRANSFER_OUT' do nothing;
 end loop;
 return result;
end $$;
revoke execute on function public.wf_send_supply_transfer(uuid,uuid,text,jsonb,text,uuid) from public,anon;
grant execute on function public.wf_send_supply_transfer(uuid,uuid,text,jsonb,text,uuid) to authenticated;

create or replace function public.wf_receive_supply_transfer(p_transfer uuid,p_lines jsonb,p_evidence text,p_condition text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare t public.supply_transfers%rowtype; x jsonb; lid uuid; line public.supply_transfer_lines%rowtype;
begin
 select * into t from public.supply_transfers where id=p_transfer for update;
 if not found then raise exception 'Traslado no encontrado';end if;
 perform public.wf_require('SUPPLY_TRANSFER_RECEIVE',t.destination_branch_id);
 if p_condition is null or p_condition not in ('CONFORME','OBSERVADA','RECHAZADA') then raise exception 'Indique la condición de recepción.';end if;
 if nullif(btrim(p_evidence),'') is null then raise exception 'Evidencia de recepción requerida.';end if;
 if jsonb_typeof(p_lines) is distinct from 'array' or coalesce(jsonb_array_length(p_lines),0)<1 then raise exception 'Seleccione al menos un producto recibido.';end if;
 for x in select value from jsonb_array_elements(p_lines) loop
  lid:=(x->>'line_id')::uuid;
  select * into line from public.supply_transfer_lines where id=lid and transfer_id=t.id for update;
  if not found then raise exception 'Línea ajena al traslado';end if;
  if line.received_at is not null then continue;end if; -- Ya recibida: no vuelve a mover inventario.
  update public.supply_transfer_lines set received_at=now(),received_by=auth.uid(),receipt_evidence=p_evidence,receipt_condition=p_condition where id=lid;
  if p_condition<>'RECHAZADA' then
   insert into public.inventory_movements(movement_date,branch_id,product_id,movement_type,quantity,source_table,source_id,notes,created_by)
   values((now() at time zone 'America/Santo_Domingo')::date,t.destination_branch_id,line.product_id,'TRANSFER_IN',line.quantity,'supply_transfer_lines',lid,'Recibido en traslado '||t.id::text,auth.uid())
   on conflict (source_table,source_id,movement_type) where source_table='supply_transfer_lines' and movement_type='TRANSFER_IN' do nothing;
  end if;
  -- RECHAZADA: la cantidad ya salió del origen y no se acredita a ningún destino; queda documentada en la línea para investigar la pérdida.
 end loop;
 update public.supply_transfers set status=case when exists(select 1 from public.supply_transfer_lines where transfer_id=t.id and received_at is null) then 'PARCIAL' else 'RECIBIDA' end where id=t.id;
 return t.id;
end $$;
revoke execute on function public.wf_receive_supply_transfer(uuid,jsonb,text,text) from public,anon;
grant execute on function public.wf_receive_supply_transfer(uuid,jsonb,text,text) to authenticated;

comment on table public.supply_transfers is 'Traslados de insumos entre sucursales. El envío descuenta el origen (TRANSFER_OUT); solo la recepción CONFORME/OBSERVADA acredita el destino (TRANSFER_IN). RECHAZADA deja la cantidad fuera de ambos saldos, documentada para investigación.';
notify pgrst,'reload schema';
commit;
