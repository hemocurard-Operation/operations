begin;
create table public.supplier_quotations(
 id uuid primary key default gen_random_uuid(),
 branch_id uuid not null references public.branches(id),
 supplier_id uuid not null references public.suppliers(id),
 requisition_id uuid references public.requisitions(id),
 code text not null check(length(trim(code)) between 1 and 150),
 quote_date date not null,
 valid_until date not null check(valid_until>=quote_date),
 currency text not null check(currency in ('DOP','USD','EUR')),
 delivery_days integer not null check(delivery_days between 0 and 3650),
 payment_terms text not null check(length(trim(payment_terms)) between 1 and 2000),
 notes text check(length(notes)<=4000),
 lines jsonb not null,
 pdf_name text not null check(length(pdf_name) between 1 and 255 and lower(pdf_name) like '%.pdf'),
 pdf_base64 text not null check(length(pdf_base64) between 8 and 6990508),
 recorded_at timestamptz not null default clock_timestamp(),
 created_by uuid not null default auth.uid() references public.profiles(id),
 unique(id,branch_id),
 unique(branch_id,supplier_id,code,quote_date)
);
create index supplier_quotations_branch_history on public.supplier_quotations(branch_id,recorded_at,id);
create index supplier_quotations_supplier on public.supplier_quotations(supplier_id);
create index supplier_quotations_requisition on public.supplier_quotations(requisition_id);
create table public.quotation_decisions(
 id uuid primary key default gen_random_uuid(),
 branch_id uuid not null references public.branches(id),
 quotation_id uuid not null,
 reason text not null check(length(trim(reason)) between 10 and 4000),
 recorded_at timestamptz not null default clock_timestamp(),
 created_by uuid not null default auth.uid() references public.profiles(id),
 foreign key(quotation_id,branch_id) references public.supplier_quotations(id,branch_id)
);
create index quotation_decisions_branch on public.quotation_decisions(branch_id,recorded_at,id);
create index quotation_decisions_quote on public.quotation_decisions(quotation_id,branch_id);
-- Invoker validation: no elevated privileges, no direct updates/deletes or client-supplied audit fields.
create function public.validate_supplier_quotation() returns trigger language plpgsql security invoker set search_path=public,pg_temp as $$
declare item jsonb; field_name text; number_value numeric; seen text[]:=array[]::text[]; item_key text; pdf bytea;
begin
 if jsonb_typeof(new.lines) is distinct from 'array' then raise exception 'Artículos inválidos.';end if;
 if jsonb_array_length(new.lines) not between 1 and 100 then raise exception 'Registre entre 1 y 100 artículos.';end if;
 for item in select value from jsonb_array_elements(new.lines) loop
  foreach field_name in array array['reference','description','unit'] loop
   if nullif(trim(item->>field_name),'') is null or length(item->>field_name)>1000 then raise exception 'Referencia, descripción y unidad obligatorias (máximo 1000 caracteres).';end if;
  end loop;
  item_key:=jsonb_build_array(upper(trim(item->>'reference')),upper(trim(item->>'unit')))::text;
  if item_key=any(seen) then raise exception 'Referencia y unidad duplicadas.';end if;seen:=array_append(seen,item_key);
  foreach field_name in array array['quantity','unit_price','tax','freight'] loop
   if coalesce(item->>field_name,'') !~ '^[0-9]+([.][0-9]+)?$' then raise exception 'Importe inválido: %',field_name;end if;
   number_value:=(item->>field_name)::numeric;
   if number_value>1000000000 or (field_name='quantity' and number_value<=0) or (field_name='tax' and number_value>100) then raise exception 'Importe fuera de rango: %',field_name;end if;
  end loop;
 end loop;
 pdf:=decode(new.pdf_base64,'base64');
 if octet_length(pdf)>5242880 or substring(pdf from 1 for 5)<>decode('255044462d','hex') then raise exception 'PDF inválido o mayor de 5 MB.';end if;
 if new.requisition_id is not null and not exists(select 1 from public.requisitions where id=new.requisition_id and requesting_branch_id=new.branch_id) then raise exception 'La requisición no corresponde a la sucursal o no es accesible.';end if;
 if not exists(select 1 from public.suppliers where id=new.supplier_id and status in ('ACTIVO','CONDICIONAL')) then raise exception 'Proveedor no disponible para compras.';end if;
 return new;
end$$;
revoke all on function public.validate_supplier_quotation() from public,anon,authenticated;
create trigger validate_supplier_quotation before insert on public.supplier_quotations for each row execute function public.validate_supplier_quotation();
alter table public.supplier_quotations enable row level security;
alter table public.quotation_decisions enable row level security;
revoke all on public.supplier_quotations,public.quotation_decisions from public,anon,authenticated;
grant select on public.supplier_quotations,public.quotation_decisions to authenticated;
grant insert(branch_id,supplier_id,requisition_id,code,quote_date,valid_until,currency,delivery_days,payment_terms,notes,lines,pdf_name,pdf_base64) on public.supplier_quotations to authenticated;
grant insert(branch_id,quotation_id,reason) on public.quotation_decisions to authenticated;
create policy supplier_quotations_read on public.supplier_quotations for select to authenticated
 using(public.wf_active_actor() and public.has_permission('PURCHASE_VIEW') and public.can_access_branch(branch_id));
create policy supplier_quotations_insert on public.supplier_quotations for insert to authenticated
 with check(public.wf_active_actor() and created_by=auth.uid() and public.has_permission('PURCHASE_VIEW') and public.has_permission('PURCHASE_WRITE') and public.can_access_branch(branch_id));
create policy quotation_decisions_read on public.quotation_decisions for select to authenticated
 using(public.wf_active_actor() and public.has_permission('PURCHASE_VIEW') and public.can_access_branch(branch_id));
create policy quotation_decisions_insert on public.quotation_decisions for insert to authenticated
 with check(public.wf_active_actor() and created_by=auth.uid() and public.has_permission('PURCHASE_VIEW') and public.has_permission('PURCHASE_APPROVE') and public.can_access_branch(branch_id)
 and exists(select 1 from public.supplier_quotations q join public.suppliers s on s.id=q.supplier_id where q.id=quotation_id and q.branch_id=quotation_decisions.branch_id and q.valid_until>=(now() at time zone 'America/Santo_Domingo')::date and s.status in ('ACTIVO','CONDICIONAL')));
-- Do not copy PDF payloads into the generic JSON audit log; the immutable records retain actor and timestamp.
notify pgrst, 'reload schema';
commit;
