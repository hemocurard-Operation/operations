import { getSupabase } from './supabase.js';

async function safeQuery(label, runner) {
  try {
    const result = await runner();
    if (result?.error) throw result.error;
    return { ok:true, label, data:result?.data ?? result, error:null };
  } catch (error) {
    console.warn('[HEMOCURA_DIAGNOSTICS]', label, error);
    return { ok:false, label, data:null, error:error?.message || String(error) };
  }
}

export async function getProfiles() {
  console.info('[HEMOCURA_SETTINGS] profiles');
  const { data, error } = await getSupabase()
    .from('profiles')
    .select('id,full_name,branch_id,active,created_at,updated_at')
    .order('full_name', { ascending:true });

  if (error) {
    console.error('[HEMOCURA_SETTINGS_ERROR] profiles', error);
    throw new Error(`Perfiles: ${error.message}`);
  }
  return data || [];
}

export async function getRoles() {
  console.info('[HEMOCURA_PERMISSIONS] roles');
  const { data, error } = await getSupabase()
    .from('roles')
    .select('id,code,name,created_at')
    .order('code');

  if (error) {
    console.error('[HEMOCURA_SETTINGS_ERROR] roles', error);
    throw new Error(`Roles: ${error.message}`);
  }
  return data || [];
}

export async function getUserRoles() {
  console.info('[HEMOCURA_PERMISSIONS] user_roles');
  const { data, error } = await getSupabase()
    .from('user_roles')
    .select('user_id,role_id,branch_id');

  if (error) {
    console.error('[HEMOCURA_SETTINGS_ERROR] user_roles', error);
    throw new Error(`Roles de usuario: ${error.message}`);
  }
  return data || [];
}

export async function getBranchesSettings() {
  const { data, error } = await getSupabase()
    .from('branches')
    .select('id,code,name,active,created_at,updated_at')
    .order('name');

  if (error) throw new Error(`Sucursales: ${error.message}`);
  return data || [];
}

export async function getProductsSettings() {
  const { data, error } = await getSupabase()
    .from('products')
    .select('id,code,name,category,unit_of_measure,active,created_at,updated_at')
    .order('name');

  if (error) throw new Error(`Productos: ${error.message}`);
  return data || [];
}

export async function getServicesSettings() {
  const { data, error } = await getSupabase()
    .from('services')
    .select('id,code,name,active,created_at')
    .order('name');

  if (error) throw new Error(`Servicios: ${error.message}`);
  return data || [];
}

export async function getProductionControl() {
  console.info('[HEMOCURA_PRODUCTION_CONTROL] leyendo control de producción');

  const mode = await safeQuery('system_operating_mode', () =>
    getSupabase()
      .from('system_operating_mode')
      .select('id,mode,excel_parallel_required,clinical_unit_dispatch_enabled,temperature_blocking_enabled,donor_recipient_traceability_enabled,updated_at,updated_by')
      .eq('id',1)
      .maybeSingle()
  );

  const flags = await safeQuery('app_feature_flags', () =>
    getSupabase()
      .from('app_feature_flags')
      .select('key,enabled,mode,description,updated_at,updated_by')
      .order('key')
  );

  const releases = await safeQuery('deployment_releases', () =>
    getSupabase()
      .from('deployment_releases')
      .select('id,version,environment,status,notes,deployed_at,deployed_by,created_at')
      .order('created_at',{ascending:false})
      .limit(10)
  );

  const events = await safeQuery('deployment_events', () =>
    getSupabase()
      .from('deployment_events')
      .select('id,release_id,event_type,severity,payload,created_at')
      .order('created_at',{ascending:false})
      .limit(20)
  );

  const health = await safeQuery('production_healthcheck', () =>
    getSupabase().rpc('production_healthcheck')
  );

  return { mode, flags, releases, events, health };
}

export async function runSystemDiagnostics() {
  console.info('[HEMOCURA_DIAGNOSTICS] iniciando');

  const checks = [
    ['branches', () => getSupabase().from('branches').select('id').limit(1)],
    ['products', () => getSupabase().from('products').select('id').limit(1)],
    ['profiles', () => getSupabase().from('profiles').select('id').limit(1)],
    ['roles', () => getSupabase().from('roles').select('id').limit(1)],
    ['daily_sales', () => getSupabase().from('daily_sales').select('id').limit(1)],
    ['dispatches', () => getSupabase().from('dispatches').select('id').limit(1)],
    ['inventory_movements', () => getSupabase().from('inventory_movements').select('id').limit(1)],
    ['monthly_cost_periods', () => getSupabase().from('monthly_cost_periods').select('id').limit(1)],
    ['incidents', () => getSupabase().from('incidents').select('id').limit(1)],
    ['nonconformities', () => getSupabase().from('nonconformities').select('id').limit(1)],
    ['capa', () => getSupabase().from('capa').select('id').limit(1)],
    ['operational_plans', () => getSupabase().from('operational_plans').select('id').limit(1)],
    ['vw_command_center_today', () => getSupabase().from('vw_command_center_today').select('*').limit(1)],
    ['vw_inventory_status', () => getSupabase().from('vw_inventory_status').select('*').limit(1)],
    ['vw_monthly_product_costs', () => getSupabase().from('vw_monthly_product_costs').select('*').limit(1)],
    ['vw_quality_today', () => getSupabase().from('vw_quality_today').select('*').limit(1)],
    ['vw_plan_vs_actual_status', () => getSupabase().from('vw_plan_vs_actual_status').select('*').limit(1)]
  ];

  const results = [];
  for (const [label, runner] of checks) {
    results.push(await safeQuery(label, runner));
  }

  console.info('[HEMOCURA_DIAGNOSTICS] finalizado', results);
  return results;
}

export async function loadSettingsWorkspace() {
  const results = await Promise.allSettled([
    getProfiles(),
    getRoles(),
    getUserRoles(),
    getBranchesSettings(),
    getProductsSettings(),
    getServicesSettings(),
    getProductionControl()
  ]);

  const values = results.map(r => r.status === 'fulfilled' ? r.value : []);
  const errors = results
    .filter(r => r.status === 'rejected')
    .map(r => r.reason?.message || 'Error');

  return {
    profiles: values[0] || [],
    roles: values[1] || [],
    userRoles: values[2] || [],
    branches: values[3] || [],
    products: values[4] || [],
    services: values[5] || [],
    production: values[6] || {},
    errors
  };
}
