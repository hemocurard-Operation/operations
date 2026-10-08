-- HemoCura S07 · C13-C2B Legacy RPC Cutover
-- Purpose: remove authenticated execute from the three legacy RPCs after frontend cutover.
-- Guardrail: controlled hc_* wrappers remain available to authenticated and closed to anon.

begin;

revoke execute on function public.adjust_sale_line(uuid,numeric,text) from authenticated;
revoke execute on function public.calculate_monthly_product_costs(uuid) from authenticated;
revoke execute on function public.production_healthcheck() from authenticated;

insert into public.app_migrations(migration_code,version,description,notes)
values(
  'C13C2B_LEGACY_RPC_CUTOVER_v0_44_7',
  '0.44.7',
  'Retira EXECUTE authenticated de RPC legacy sustituidos por wrappers hc_*',
  'S07: frontend ya usa hc_adjust_sale_line, hc_calculate_monthly_product_costs y hc_production_healthcheck.'
)
on conflict (migration_code) do update
set version=excluded.version,
    description=excluded.description,
    notes=excluded.notes;

commit;
