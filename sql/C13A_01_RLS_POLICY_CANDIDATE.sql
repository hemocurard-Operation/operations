-- =====================================================================
-- HemoCura · C13-A · RLS POLICY CANDIDATE
-- Basado en inventario real de Supabase 2026-10-06.
-- NO aplicar sin ejecutar primero C13A_00_PREFLIGHT_RLS_NO_POLICY.sql.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 0. El navegador anónimo no necesita acceso directo a estas tablas.
-- ---------------------------------------------------------------------
revoke all on public.app_feature_flags from anon;
revoke all on public.blood_unit_tests from anon;
revoke all on public.deployment_events from anon;
revoke all on public.deployment_releases from anon;
revoke all on public.dispatch_unit_allocations from anon;
revoke all on public.hc_gate_requirements from anon;
revoke all on public.hc_gate_versions from anon;
revoke all on public.integration_outbox from anon;
revoke all on public.inventory_lots from anon;
revoke all on public.migration_issues from anon;
revoke all on public.product_control_modes from anon;
revoke all on public.recipient_issues from anon;
revoke all on public.stg_requerimientos from anon;
revoke all on public.stg_resp_despachos from anon;
revoke all on public.storage_devices from anon;
revoke all on public.storage_excursions from anon;
revoke all on public.system_operating_mode from anon;
revoke all on public.temperature_policies from anon;
revoke all on public.temperature_readings from anon;

-- Se eliminan grants heredados demasiado amplios del rol authenticated.
revoke all on public.app_feature_flags from authenticated;
revoke all on public.blood_unit_tests from authenticated;
revoke all on public.deployment_events from authenticated;
revoke all on public.deployment_releases from authenticated;
revoke all on public.dispatch_unit_allocations from authenticated;
revoke all on public.hc_gate_requirements from authenticated;
revoke all on public.hc_gate_versions from authenticated;
revoke all on public.integration_outbox from authenticated;
revoke all on public.inventory_lots from authenticated;
revoke all on public.migration_issues from authenticated;
revoke all on public.product_control_modes from authenticated;
revoke all on public.recipient_issues from authenticated;
revoke all on public.stg_requerimientos from authenticated;
revoke all on public.stg_resp_despachos from authenticated;
revoke all on public.storage_devices from authenticated;
revoke all on public.storage_excursions from authenticated;
revoke all on public.system_operating_mode from authenticated;
revoke all on public.temperature_policies from authenticated;
revoke all on public.temperature_readings from authenticated;

-- ---------------------------------------------------------------------
-- 1. Configuración / Release / Diagnóstico
-- ---------------------------------------------------------------------
grant select,insert,update on public.app_feature_flags to authenticated;
create policy c13a_app_feature_flags_select on public.app_feature_flags
for select to authenticated
using (
  public.has_permission('RELEASE_GATE_VIEW')
  or public.has_permission('BLOOD_INVENTORY_VIEW')
  or public.has_permission('BLOOD_INVENTORY_WRITE')
);
create policy c13a_app_feature_flags_insert on public.app_feature_flags
for insert to authenticated
with check (public.has_permission('ACCESS_ADMIN'));
create policy c13a_app_feature_flags_update on public.app_feature_flags
for update to authenticated
using (public.has_permission('ACCESS_ADMIN'))
with check (public.has_permission('ACCESS_ADMIN'));

grant select,insert,update on public.deployment_releases to authenticated;
create policy c13a_deployment_releases_select on public.deployment_releases
for select to authenticated
using (public.has_permission('RELEASE_GATE_VIEW'));
create policy c13a_deployment_releases_insert on public.deployment_releases
for insert to authenticated
with check (public.has_permission('ACCESS_ADMIN'));
create policy c13a_deployment_releases_update on public.deployment_releases
for update to authenticated
using (public.has_permission('ACCESS_ADMIN'))
with check (public.has_permission('ACCESS_ADMIN'));

grant select,insert on public.deployment_events to authenticated;
create policy c13a_deployment_events_select on public.deployment_events
for select to authenticated
using (public.has_permission('RELEASE_GATE_VIEW'));
create policy c13a_deployment_events_insert on public.deployment_events
for insert to authenticated
with check (public.has_permission('ACCESS_ADMIN'));

grant select on public.hc_gate_versions to authenticated;
create policy c13a_hc_gate_versions_select on public.hc_gate_versions
for select to authenticated
using (public.has_permission('RELEASE_GATE_VIEW'));

grant select on public.hc_gate_requirements to authenticated;
create policy c13a_hc_gate_requirements_select on public.hc_gate_requirements
for select to authenticated
using (public.has_permission('RELEASE_GATE_VIEW'));

grant select on public.migration_issues to authenticated;
create policy c13a_migration_issues_select on public.migration_issues
for select to authenticated
using (
  public.has_permission('RELEASE_GATE_VIEW')
  or public.has_permission('ACCESS_ADMIN')
);

grant select on public.integration_outbox to authenticated;
create policy c13a_integration_outbox_admin_select on public.integration_outbox
for select to authenticated
using (public.has_permission('ACCESS_ADMIN'));

grant select on public.stg_requerimientos to authenticated;
create policy c13a_stg_requerimientos_admin_select on public.stg_requerimientos
for select to authenticated
using (public.has_permission('ACCESS_ADMIN'));

grant select on public.stg_resp_despachos to authenticated;
create policy c13a_stg_resp_despachos_admin_select on public.stg_resp_despachos
for select to authenticated
using (public.has_permission('ACCESS_ADMIN'));

grant select,update on public.system_operating_mode to authenticated;
create policy c13a_system_operating_mode_select on public.system_operating_mode
for select to authenticated
using (
  public.has_permission('DASHBOARD_VIEW')
  or public.has_permission('RELEASE_GATE_VIEW')
);
create policy c13a_system_operating_mode_update on public.system_operating_mode
for update to authenticated
using (public.has_permission('ACCESS_ADMIN'))
with check (public.has_permission('ACCESS_ADMIN'));

grant select,insert,update on public.product_control_modes to authenticated;
create policy c13a_product_control_modes_select on public.product_control_modes
for select to authenticated
using (
  public.has_permission('BLOOD_INVENTORY_VIEW')
  or public.has_permission('BLOOD_INVENTORY_WRITE')
  or public.has_permission('ACCESS_ADMIN')
);
create policy c13a_product_control_modes_insert on public.product_control_modes
for insert to authenticated
with check (public.has_permission('ACCESS_ADMIN'));
create policy c13a_product_control_modes_update on public.product_control_modes
for update to authenticated
using (public.has_permission('ACCESS_ADMIN'))
with check (public.has_permission('ACCESS_ADMIN'));

-- ---------------------------------------------------------------------
-- 2. Tamizaje de unidades: sucursal de blood_units
-- ---------------------------------------------------------------------
grant select,insert,update on public.blood_unit_tests to authenticated;
create policy c13a_blood_unit_tests_select on public.blood_unit_tests
for select to authenticated
using (
  public.has_permission('SCREENING_VIEW')
  and exists (
    select 1 from public.blood_units bu
    where bu.id=blood_unit_id
      and public.can_access_branch(bu.branch_id)
  )
);
create policy c13a_blood_unit_tests_insert on public.blood_unit_tests
for insert to authenticated
with check (
  public.has_permission('SCREENING_WRITE')
  and exists (
    select 1 from public.blood_units bu
    where bu.id=blood_unit_id
      and public.can_access_branch(bu.branch_id)
  )
);
create policy c13a_blood_unit_tests_update on public.blood_unit_tests
for update to authenticated
using (
  public.has_permission('SCREENING_WRITE')
  and exists (
    select 1 from public.blood_units bu
    where bu.id=blood_unit_id
      and public.can_access_branch(bu.branch_id)
  )
)
with check (
  public.has_permission('SCREENING_WRITE')
  and exists (
    select 1 from public.blood_units bu
    where bu.id=blood_unit_id
      and public.can_access_branch(bu.branch_id)
  )
);

-- ---------------------------------------------------------------------
-- 3. Despacho serializado / receptor: sucursal del despacho
-- ---------------------------------------------------------------------
grant select,insert,update on public.dispatch_unit_allocations to authenticated;
create policy c13a_dispatch_alloc_select on public.dispatch_unit_allocations
for select to authenticated
using (
  public.has_permission('DISPATCH_VIEW')
  and exists (
    select 1
    from public.dispatch_lines dl
    join public.dispatches d on d.id=dl.dispatch_id
    where dl.id=dispatch_line_id
      and public.can_access_branch(d.branch_id)
  )
);
create policy c13a_dispatch_alloc_insert on public.dispatch_unit_allocations
for insert to authenticated
with check (
  public.has_permission('DISPATCH_WRITE')
  and exists (
    select 1
    from public.dispatch_lines dl
    join public.dispatches d on d.id=dl.dispatch_id
    where dl.id=dispatch_line_id
      and public.can_access_branch(d.branch_id)
  )
);
create policy c13a_dispatch_alloc_update on public.dispatch_unit_allocations
for update to authenticated
using (
  public.has_permission('DISPATCH_WRITE')
  and exists (
    select 1
    from public.dispatch_lines dl
    join public.dispatches d on d.id=dl.dispatch_id
    where dl.id=dispatch_line_id
      and public.can_access_branch(d.branch_id)
  )
)
with check (
  public.has_permission('DISPATCH_WRITE')
  and exists (
    select 1
    from public.dispatch_lines dl
    join public.dispatches d on d.id=dl.dispatch_id
    where dl.id=dispatch_line_id
      and public.can_access_branch(d.branch_id)
  )
);

grant select,insert,update on public.recipient_issues to authenticated;
create policy c13a_recipient_issues_select on public.recipient_issues
for select to authenticated
using (
  (public.has_permission('DISPATCH_VIEW') or public.has_permission('HEMOVIGILANCE_VIEW'))
  and exists (
    select 1
    from public.dispatch_unit_allocations a
    join public.dispatch_lines dl on dl.id=a.dispatch_line_id
    join public.dispatches d on d.id=dl.dispatch_id
    where a.id=dispatch_unit_allocation_id
      and public.can_access_branch(d.branch_id)
  )
);
create policy c13a_recipient_issues_insert on public.recipient_issues
for insert to authenticated
with check (
  public.has_permission('DISPATCH_WRITE')
  and exists (
    select 1
    from public.dispatch_unit_allocations a
    join public.dispatch_lines dl on dl.id=a.dispatch_line_id
    join public.dispatches d on d.id=dl.dispatch_id
    where a.id=dispatch_unit_allocation_id
      and public.can_access_branch(d.branch_id)
  )
);
create policy c13a_recipient_issues_update on public.recipient_issues
for update to authenticated
using (
  public.has_permission('DISPATCH_WRITE')
  and exists (
    select 1
    from public.dispatch_unit_allocations a
    join public.dispatch_lines dl on dl.id=a.dispatch_line_id
    join public.dispatches d on d.id=dl.dispatch_id
    where a.id=dispatch_unit_allocation_id
      and public.can_access_branch(d.branch_id)
  )
)
with check (
  public.has_permission('DISPATCH_WRITE')
  and exists (
    select 1
    from public.dispatch_unit_allocations a
    join public.dispatch_lines dl on dl.id=a.dispatch_line_id
    join public.dispatches d on d.id=dl.dispatch_id
    where a.id=dispatch_unit_allocation_id
      and public.can_access_branch(d.branch_id)
  )
);

-- ---------------------------------------------------------------------
-- 4. Inventario por lote
-- ---------------------------------------------------------------------
grant select,insert,update on public.inventory_lots to authenticated;
create policy c13a_inventory_lots_select on public.inventory_lots
for select to authenticated
using (
  public.has_permission('BLOOD_INVENTORY_VIEW')
  and public.can_access_branch(branch_id)
);
create policy c13a_inventory_lots_insert on public.inventory_lots
for insert to authenticated
with check (
  public.has_permission('BLOOD_INVENTORY_WRITE')
  and public.can_access_branch(branch_id)
);
create policy c13a_inventory_lots_update on public.inventory_lots
for update to authenticated
using (
  public.has_permission('BLOOD_INVENTORY_WRITE')
  and public.can_access_branch(branch_id)
)
with check (
  public.has_permission('BLOOD_INVENTORY_WRITE')
  and public.can_access_branch(branch_id)
);

-- ---------------------------------------------------------------------
-- 5. Cadena de frío nueva: branch del dispositivo
-- ---------------------------------------------------------------------
grant select,insert,update on public.storage_devices to authenticated;
create policy c13a_storage_devices_select on public.storage_devices
for select to authenticated
using (
  public.has_permission('COLD_CHAIN_VIEW')
  and public.can_access_branch(branch_id)
);
create policy c13a_storage_devices_insert on public.storage_devices
for insert to authenticated
with check (
  public.has_permission('COLD_CHAIN_WRITE')
  and public.can_access_branch(branch_id)
);
create policy c13a_storage_devices_update on public.storage_devices
for update to authenticated
using (
  public.has_permission('COLD_CHAIN_WRITE')
  and public.can_access_branch(branch_id)
)
with check (
  public.has_permission('COLD_CHAIN_WRITE')
  and public.can_access_branch(branch_id)
);

grant select,insert,update on public.temperature_policies to authenticated;
create policy c13a_temperature_policies_select on public.temperature_policies
for select to authenticated
using (
  public.has_permission('COLD_CHAIN_VIEW')
  and exists (
    select 1 from public.storage_devices sd
    where sd.id=storage_device_id
      and public.can_access_branch(sd.branch_id)
  )
);
create policy c13a_temperature_policies_insert on public.temperature_policies
for insert to authenticated
with check (
  public.has_permission('COLD_CHAIN_WRITE')
  and exists (
    select 1 from public.storage_devices sd
    where sd.id=storage_device_id
      and public.can_access_branch(sd.branch_id)
  )
);
create policy c13a_temperature_policies_update on public.temperature_policies
for update to authenticated
using (
  public.has_permission('COLD_CHAIN_WRITE')
  and exists (
    select 1 from public.storage_devices sd
    where sd.id=storage_device_id
      and public.can_access_branch(sd.branch_id)
  )
)
with check (
  public.has_permission('COLD_CHAIN_WRITE')
  and exists (
    select 1 from public.storage_devices sd
    where sd.id=storage_device_id
      and public.can_access_branch(sd.branch_id)
  )
);

-- temperature_readings es append-only desde el frontend.
grant select,insert on public.temperature_readings to authenticated;
create policy c13a_temperature_readings_select on public.temperature_readings
for select to authenticated
using (
  public.has_permission('COLD_CHAIN_VIEW')
  and exists (
    select 1 from public.storage_devices sd
    where sd.id=storage_device_id
      and public.can_access_branch(sd.branch_id)
  )
);
create policy c13a_temperature_readings_insert on public.temperature_readings
for insert to authenticated
with check (
  public.has_permission('COLD_CHAIN_WRITE')
  and exists (
    select 1 from public.storage_devices sd
    where sd.id=storage_device_id
      and public.can_access_branch(sd.branch_id)
  )
  and (created_by is null or created_by=auth.uid())
);

-- Las excursiones se crean por el evaluador de temperatura; la UI solo lee/resuelve.
grant select,update on public.storage_excursions to authenticated;
create policy c13a_storage_excursions_select on public.storage_excursions
for select to authenticated
using (
  public.has_permission('COLD_CHAIN_VIEW')
  and exists (
    select 1 from public.storage_devices sd
    where sd.id=storage_device_id
      and public.can_access_branch(sd.branch_id)
  )
);
create policy c13a_storage_excursions_update on public.storage_excursions
for update to authenticated
using (
  public.has_permission('COLD_CHAIN_WRITE')
  and exists (
    select 1 from public.storage_devices sd
    where sd.id=storage_device_id
      and public.can_access_branch(sd.branch_id)
  )
)
with check (
  public.has_permission('COLD_CHAIN_WRITE')
  and exists (
    select 1 from public.storage_devices sd
    where sd.id=storage_device_id
      and public.can_access_branch(sd.branch_id)
  )
  and (resolved_by is null or resolved_by=auth.uid())
);

-- ---------------------------------------------------------------------
-- 6. Registry de la corrección
-- ---------------------------------------------------------------------
insert into public.app_migrations(migration_code,version,description,applied_by,notes)
values(
  'C13A_RLS_NO_POLICY_v0_44_4',
  '0.44.4',
  'Policies específicas y reducción de grants para 19 tablas con RLS sin policy',
  auth.uid(),
  'Candidate C13-A: aplicar solo tras preflight y revisión.'
)
on conflict(migration_code) do nothing;

commit;
