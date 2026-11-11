set role authenticated;
select set_config('test.actor','e2000000-0000-0000-0000-000000000001',false);
select public.procurement_action('SUPPLIER','{"legal_name":"Proveedor sintético"}'::jsonb);
create function pg_temp.sample_quote(code text,branch uuid default 'e1000000-0000-0000-0000-000000000001') returns void language sql as $$
 insert into public.supplier_quotations(branch_id,supplier_id,requisition_id,code,quote_date,valid_until,currency,delivery_days,payment_terms,lines,pdf_name,pdf_base64)
 values(branch,(select id from suppliers limit 1),'e4000000-0000-0000-0000-000000000001',code,current_date,current_date+30,'DOP',3,'30 días','[{"reference":"R-1","description":"Reactivo","unit":"caja","quantity":"10","unit_price":"100","tax":"18","freight":"0"}]','oferta.pdf',encode(convert_to('%PDF-1.4 synthetic','UTF8'),'base64'));
$$;
select pg_temp.sample_quote('C-1');
do $$begin
 if (select count(*) from supplier_quotations)<>1 then raise exception 'Quote not saved';end if;
 raise notice 'PASS valid PDF quotation inserted';
 begin perform pg_temp.sample_quote('FOREIGN','e1000000-0000-0000-0000-000000000002');raise exception 'Cross branch allowed';exception when insufficient_privilege then null;when raise_exception then if sqlerrm not like '%requisición%' then raise;end if;end;
 raise notice 'PASS cross branch rejected';
 begin perform pg_temp.sample_quote('C-1');raise exception 'Duplicate allowed';exception when unique_violation then null;end;
 raise notice 'PASS duplicate rejected';
 begin update supplier_quotations set code='tampered';raise exception 'Update allowed';exception when insufficient_privilege then null;end;
 begin delete from supplier_quotations;raise exception 'Delete allowed';exception when insufficient_privilege then null;end;
 raise notice 'PASS immutable quotation history';
 begin insert into supplier_quotations(id,branch_id) values(gen_random_uuid(),'e1000000-0000-0000-0000-000000000001');raise exception 'Audit spoof allowed';exception when insufficient_privilege then null;end;
 raise notice 'PASS client cannot spoof IDs or audit fields';
 insert into quotation_decisions(branch_id,quotation_id,reason) select branch_id,id,'Calidad y entrega verificadas' from supplier_quotations;
 if (select count(*) from quotation_decisions)<>1 then raise exception 'Decision not saved';end if;
 raise notice 'PASS purchase decision with rationale';
end$$;
reset role;
-- Malformed values still fail server-side without relying on browser validation.
do $$declare q supplier_quotations%rowtype;begin
 select * into q from supplier_quotations limit 1;
 q.id:=gen_random_uuid();q.code:='BAD-PDF';q.pdf_base64:=encode(convert_to('not PDF','UTF8'),'base64');
 begin insert into supplier_quotations select (q).*;raise exception 'Bad PDF accepted';exception when raise_exception then if sqlerrm not like '%PDF inválido%' then raise;end if;end;
 q.pdf_base64:=encode(convert_to('%PDF-1.4','UTF8'),'base64');q.lines:='[{"reference":"R","description":"R","unit":"U","quantity":"0","unit_price":"1","tax":"0","freight":"0"}]';
 begin insert into supplier_quotations select (q).*;raise exception 'Zero accepted';exception when raise_exception then if sqlerrm not like '%fuera de rango%' then raise;end if;end;
 q.lines:='[{"reference":"R","description":"R","unit":"U","quantity":"1","unit_price":"NaN","tax":"0","freight":"0"}]';
 begin insert into supplier_quotations select (q).*;raise exception 'NaN accepted';exception when raise_exception then if sqlerrm not like '%Importe inválido%' then raise;end if;end;
 raise notice 'PASS server validates PDF and numeric amounts';
 update supplier_quotations set valid_until=(now() at time zone 'America/Santo_Domingo')::date-1,quote_date=(now() at time zone 'America/Santo_Domingo')::date-2;
end$$;
set role authenticated;
do $$begin
 begin insert into quotation_decisions(branch_id,quotation_id,reason) select branch_id,id,'Oferta vencida no elegible' from supplier_quotations;raise exception 'Expired accepted';exception when insufficient_privilege then null;end;
 raise notice 'PASS expired quote decision rejected';
end$$;
select set_config('test.actor','e2000000-0000-0000-0000-000000000002',false);
do $$begin
 if (select count(*) from supplier_quotations)<>1 then raise exception 'Reader cannot read';end if;
 begin perform pg_temp.sample_quote('READONLY');raise exception 'Reader wrote';exception when insufficient_privilege then null;end;
 begin insert into quotation_decisions(branch_id,quotation_id,reason) select branch_id,id,'Sin autorización de aprobación' from supplier_quotations;raise exception 'Reader decided';exception when insufficient_privilege then null;end;
 raise notice 'PASS read only permissions enforced';
end$$;
select set_config('test.actor','e2000000-0000-0000-0000-000000000003',false);
do $$begin
 if exists(select 1 from supplier_quotations) or exists(select 1 from quotation_decisions) then raise exception 'Inactive read';end if;
 begin perform pg_temp.sample_quote('INACTIVE');raise exception 'Inactive wrote';exception when insufficient_privilege then null;end;
 raise notice 'PASS inactive actor blocked';
end$$;
reset role;
-- Active actor with access to the other branch sees neither documents nor decisions.
insert into profiles values('e2000000-0000-0000-0000-000000000004','Other branch',true);
insert into test_permissions values('e2000000-0000-0000-0000-000000000004','PURCHASE_VIEW');
insert into test_branches values('e2000000-0000-0000-0000-000000000004','e1000000-0000-0000-0000-000000000002');
set role authenticated;
select set_config('test.actor','e2000000-0000-0000-0000-000000000004',false);
do $$begin
 if exists(select 1 from supplier_quotations) or exists(select 1 from quotation_decisions) then raise exception 'Cross branch PDF leaked';end if;
 raise notice 'PASS cross branch PDF and decision isolation';
end$$;
