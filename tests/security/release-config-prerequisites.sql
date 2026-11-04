-- Local configuration structures only. No production users, records, flags, or approvals copied.
create table if not exists public."app_feature_flags" (
 "key" text not null,
 "enabled" boolean default false not null,
 "mode" text default 'OFF'::text not null,
 "description" text,
 "updated_at" timestamp with time zone default now() not null,
 "updated_by" uuid,
CHECK ((mode = ANY (ARRAY['OFF'::text, 'SHADOW'::text, 'LIVE_LIMITED'::text, 'LIVE'::text]))),
PRIMARY KEY (key)
);
alter table public."app_feature_flags" enable row level security;
drop policy if exists "c13a_app_feature_flags_insert" on public."app_feature_flags";
create policy "c13a_app_feature_flags_insert" on public."app_feature_flags" as PERMISSIVE for INSERT to "authenticated" with check (has_permission('ACCESS_ADMIN'::text));
drop policy if exists "c13a_app_feature_flags_select" on public."app_feature_flags";
create policy "c13a_app_feature_flags_select" on public."app_feature_flags" as PERMISSIVE for SELECT to "authenticated" using ((has_permission('RELEASE_GATE_VIEW'::text) OR has_permission('BLOOD_INVENTORY_VIEW'::text) OR has_permission('BLOOD_INVENTORY_WRITE'::text)));
drop policy if exists "c13a_app_feature_flags_update" on public."app_feature_flags";
create policy "c13a_app_feature_flags_update" on public."app_feature_flags" as PERMISSIVE for UPDATE to "authenticated" using (has_permission('ACCESS_ADMIN'::text)) with check (has_permission('ACCESS_ADMIN'::text));
grant select,insert,update on public."app_feature_flags" to authenticated;
create table if not exists public."system_operating_mode" (
 "id" smallint default 1 not null,
 "mode" text default 'PARALLEL'::text not null,
 "excel_parallel_required" boolean default true not null,
 "clinical_unit_dispatch_enabled" boolean default false not null,
 "temperature_blocking_enabled" boolean default false not null,
 "donor_recipient_traceability_enabled" boolean default false not null,
 "updated_at" timestamp with time zone default now() not null,
 "updated_by" uuid,
CHECK ((id = 1)),
CHECK ((mode = ANY (ARRAY['PARALLEL'::text, 'LIVE_LIMITED'::text, 'LIVE'::text, 'MAINTENANCE'::text]))),
PRIMARY KEY (id)
);
alter table public."system_operating_mode" enable row level security;
drop policy if exists "c13a_system_operating_mode_select" on public."system_operating_mode";
create policy "c13a_system_operating_mode_select" on public."system_operating_mode" as PERMISSIVE for SELECT to "authenticated" using ((has_permission('DASHBOARD_VIEW'::text) OR has_permission('RELEASE_GATE_VIEW'::text)));
drop policy if exists "c13a_system_operating_mode_update" on public."system_operating_mode";
create policy "c13a_system_operating_mode_update" on public."system_operating_mode" as PERMISSIVE for UPDATE to "authenticated" using (has_permission('ACCESS_ADMIN'::text)) with check (has_permission('ACCESS_ADMIN'::text));
grant select,insert,update on public."system_operating_mode" to authenticated;
insert into public.system_operating_mode(id,mode,excel_parallel_required,clinical_unit_dispatch_enabled,temperature_blocking_enabled,donor_recipient_traceability_enabled) values(1,'LIVE_LIMITED',true,false,false,false) on conflict do nothing;
insert into public.app_feature_flags(key,enabled,mode,description) values('clinical_fefo',false,'SHADOW','Isolated test only'),('cold_chain_auto_block',false,'SHADOW','Isolated test only'),('donor_recipient_traceability',false,'SHADOW','Isolated test only'),('clinical_supply_demand',false,'SHADOW','Isolated test only') on conflict(key) do update set enabled=false,mode='SHADOW';

