create table public.requisitions(id uuid primary key,requesting_branch_id uuid references branches(id),requisition_code text);
grant select on public.requisitions to authenticated;
insert into public.requisitions values('e4000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','REQ-1');
