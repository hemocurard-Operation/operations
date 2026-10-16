create function pg_temp.ok(b boolean,label text) returns void language plpgsql as $$begin if b is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.fails(q text,expected text,label text) returns void language plpgsql as $$begin begin execute q;exception when others then if position(expected in sqlerrm)=0 then raise exception 'Unexpected error [%] for %',sqlerrm,label;end if;raise notice 'PASS %',label;return;end;raise exception 'FAIL expected rejection: %',label;end$$;
set role authenticated;select set_config('test.actor','e2000000-0000-0000-0000-000000000001',false);
select procurement_action('SUPPLIER','{"legal_name":"Proveedor sintético","phone":"8095550100"}') as supplier \gset
select (:'supplier'::jsonb->>'id') as sid \gset
select procurement_action('CREATE',jsonb_build_object('branch_id','e1000000-0000-0000-0000-000000000001','supplier_id',:'sid','currency','DOP','lines',jsonb_build_array(jsonb_build_object('description','Reactivo sintético','quantity',10,'unit_price',25)))) as result \gset
select (:'result'::jsonb->>'id') as oid \gset
select id as lid from purchase_order_lines where purchase_order_id=:'oid' \gset
select pg_temp.ok((select total_amount=250 and revision=1 and status='BORRADOR' from purchase_orders where id=:'oid'),'draft totals computed by database');
select pg_temp.ok((select received_quantity=0 and requires_lot and requires_expiry from purchase_order_lines where id=:'lid'),'new items require traceability');
select pg_temp.fails('update purchase_orders set status=''RECIBIDA''','permission denied','direct header tampering denied');
select pg_temp.fails('update purchase_order_lines set received_quantity=999','permission denied','direct balance tampering denied');
select pg_temp.fails(format('select procurement_action(''CREATE'',%L::jsonb)',jsonb_build_object('branch_id','e1000000-0000-0000-0000-000000000002','supplier_id',:'sid')),'Sucursal no autorizada','cross branch creation denied');
select pg_temp.fails(format('select procurement_action(''APPROVE'',%L::jsonb)',jsonb_build_object('id',:'oid','revision',99)),'La orden cambió','stale revision rejected');
select procurement_action('APPROVE',jsonb_build_object('id',:'oid','revision',1));
select pg_temp.fails(format('select procurement_action(''UPDATE'',%L::jsonb)',jsonb_build_object('id',:'oid','revision',2)),'Solo se puede editar','approved terms locked');
select procurement_action('SEND',jsonb_build_object('id',:'oid','revision',2));
-- Keep a canonical, entirely synthetic receipt payload for failure and success checks.
select jsonb_build_object('id',:'oid','revision',3,'request_id',gen_random_uuid(),'received_at',now(),'delivery_reference','FAC-TEST-1','condition','CONFORME','packaging','INTEGRO','documents','COMPLETA','lines',jsonb_build_array(jsonb_build_object('line_id',:'lid','quantity',4,'accepted_quantity',4,'unit_price',26,'lot','TEST-LOT','expiry_date',current_date+200)))::text as receipt \gset
select pg_temp.fails(format('select procurement_action(''RECEIVE'',%L::jsonb)',jsonb_set(:'receipt'::jsonb,'{lines,0,lot}','""')),'requiere lote','missing lot rejected');
select pg_temp.fails(format('select procurement_action(''RECEIVE'',%L::jsonb)',jsonb_set(:'receipt'::jsonb,'{lines,0,expiry_date}','null')),'requiere fecha','missing expiry rejected');
select pg_temp.fails(format('select procurement_action(''RECEIVE'',%L::jsonb)',jsonb_set(:'receipt'::jsonb,'{lines,0,expiry_date}',to_jsonb(current_date))),'artículos vencidos','expired accepted lot rejected');
select pg_temp.fails(format('select procurement_action(''RECEIVE'',%L::jsonb)',jsonb_set(:'receipt'::jsonb,'{lines,0,line_id}',to_jsonb(gen_random_uuid()))),'Artículo ajeno','foreign line rejected');
select pg_temp.fails(format('select procurement_action(''RECEIVE'',%L::jsonb)',jsonb_set(:'receipt'::jsonb,'{received_at}',to_jsonb(now()+interval '1 day'))),'Fecha de recepción','future delivery rejected');
select pg_temp.ok((select count(*)=0 from purchase_receipts),'failed receipts roll back completely');
select procurement_action('RECEIVE',:'receipt'::jsonb);
select pg_temp.ok((select status='PARCIAL' and revision=4 from purchase_orders where id=:'oid'),'partial receipt updates status and revision');
select pg_temp.ok((select received_quantity=4 from purchase_order_lines where id=:'lid'),'partial balance correct');
select pg_temp.ok((select unit_price=25 from purchase_order_lines where id=:'lid'),'actual received price preserves agreed price');
select pg_temp.ok((procurement_action('RECEIVE',:'receipt'::jsonb)->>'already_recorded')::boolean,'receipt retry is idempotent');
select pg_temp.ok((select count(*)=1 from purchase_receipts),'receipt retry does not duplicate history');
select pg_temp.fails(format('select procurement_action(''RECEIVE'',%L::jsonb)',jsonb_set(:'receipt'::jsonb,'{notes}','"Changed details"')),'otros datos','reused request token cannot conceal a changed payload');
select pg_temp.fails('update purchase_receipts set notes=''rewrite''','permission denied','history is immutable');
select pg_temp.fails('delete from purchase_receipt_lines','permission denied','history cannot be deleted');
select pg_temp.fails(format('select procurement_action(''CANCEL'',%L::jsonb)',jsonb_build_object('id',:'oid','revision',4,'reason','Prueba')),'No se puede cancelar','received order cannot be canceled');
select pg_temp.fails(format('select procurement_action(''RECEIVE'',%L::jsonb)',jsonb_set(jsonb_set(jsonb_set(:'receipt'::jsonb,'{revision}','4'),'{request_id}',to_jsonb(gen_random_uuid())),'{lines,0,accepted_quantity}','7')),'Cantidad o precio','accepted cannot exceed delivered');
select pg_temp.fails(format('select procurement_action(''RECEIVE'',%L::jsonb)',jsonb_set(jsonb_set(jsonb_set(jsonb_set(:'receipt'::jsonb,'{revision}','4'),'{request_id}',to_jsonb(gen_random_uuid())),'{lines,0,quantity}','7'),'{lines,0,accepted_quantity}','7')),'supera el saldo','over receipt rejected');
-- A rejected expired delivery is recorded but does not reduce the pending quantity.
select jsonb_set(jsonb_set(jsonb_set(jsonb_set(jsonb_set(jsonb_set(jsonb_set(:'receipt'::jsonb,'{revision}','4'),'{request_id}',to_jsonb(gen_random_uuid())),'{condition}','"RECHAZADA"'),'{notes}','"Lote vencido, devolver"'),'{lines,0,accepted_quantity}','0'),'{lines,0,expiry_date}',to_jsonb(current_date-1)),'{lines,0,notes}','"Vencido"')::text as rejected \gset
select procurement_action('RECEIVE',:'rejected'::jsonb);
select pg_temp.ok((select received_quantity=4 from purchase_order_lines where id=:'lid'),'rejected items remain pending replacement');
select pg_temp.ok((select count(*)=2 from purchase_receipts),'rejection remains in receipt history');
select jsonb_set(jsonb_set(jsonb_set(jsonb_set(:'receipt'::jsonb,'{revision}','5'),'{request_id}',to_jsonb(gen_random_uuid())),'{lines,0,quantity}','6'),'{lines,0,accepted_quantity}','6')::text as final \gset
select procurement_action('RECEIVE',:'final'::jsonb);
select pg_temp.ok((select status='RECIBIDA' from purchase_orders where id=:'oid'),'final accepted delivery closes order');
select pg_temp.ok((select received_quantity=10 from purchase_order_lines where id=:'lid'),'accepted totals match purchase quantity');
select pg_temp.ok((select count(*)>=7 from workflow_audit),'mutations produce audit events');
select set_config('test.actor','e2000000-0000-0000-0000-000000000002',false);
select pg_temp.ok((select count(*)=1 from purchase_orders),'authorized read only user can view');
select pg_temp.fails('select procurement_action(''SUPPLIER'',''{"legal_name":"Denied"}'')','No tiene permiso','reader cannot write');
select set_config('test.actor','e2000000-0000-0000-0000-000000000003',false);
select pg_temp.ok((select count(*)=0 from purchase_orders),'inactive user cannot read');
select pg_temp.fails('select procurement_action(''SUPPLIER'',''{"legal_name":"Denied"}'')','sesión no está activa','inactive actor cannot mutate');
reset role;
insert into purchase_orders(po_code,branch_id,supplier_id) values('OTHER-BRANCH','e1000000-0000-0000-0000-000000000002',:'sid');
set role authenticated;select set_config('test.actor','e2000000-0000-0000-0000-000000000001',false);
select pg_temp.ok((select count(*)=1 from purchase_orders),'other branch orders hidden');
set role anon;
select pg_temp.fails('select * from purchase_receipts','permission denied','anonymous receipt access denied');
select pg_temp.fails('select procurement_action(''CREATE'',''{}'')','permission denied','anonymous API denied');
reset role;
