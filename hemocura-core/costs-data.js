import { getSupabase } from './supabase.js';

export async function getCostPeriods(filters = {}) {
  console.info('[HEMOCURA_COSTS_PERIOD]', filters);

  let q = getSupabase()
    .from('monthly_cost_periods')
    .select('id,period_month,branch_id,status,opened_at,approved_at,closed_at,notes')
    .order('period_month', { ascending: false })
    .limit(36);

  if (filters.branchId) q = q.eq('branch_id', filters.branchId);
  if (filters.status) q = q.eq('status', filters.status);

  const { data, error } = await q;
  if (error) {
    console.error('[HEMOCURA_COSTS_ERROR] periods', error);
    throw new Error(`Períodos: ${error.message}`);
  }
  return data || [];
}

export async function getMonthlyProductCosts(filters = {}) {
  console.info('[HEMOCURA_COSTS] vw_monthly_product_costs', filters);

  let q = getSupabase()
    .from('vw_monthly_product_costs')
    .select('period_month,branch_id,branch,product_id,product_code,product_name,units_basis,material_cost,labor_cost,screening_cost,indirect_cost,waste_cost,transport_cost,other_cost,total_cost,cost_per_unit,previous_cost_per_unit,variance_amount,variance_pct,status')
    .order('period_month', { ascending: false })
    .order('product_name', { ascending: true })
    .limit(500);

  if (filters.branchId) q = q.eq('branch_id', filters.branchId);
  if (filters.month) q = q.eq('period_month', filters.month);

  const { data, error } = await q;
  if (error) {
    console.error('[HEMOCURA_COSTS_ERROR] product costs', error);
    throw new Error(`Costos por producto: ${error.message}`);
  }
  return data || [];
}

export async function getPriceVersions() {
  console.info('[HEMOCURA_PRICING] price_versions');

  const { data, error } = await getSupabase()
    .from('price_versions')
    .select('id,product_id,service_id,customer_type,effective_from,effective_to,list_price,created_at')
    .order('effective_from', { ascending: false });

  if (error) {
    console.error('[HEMOCURA_COSTS_ERROR] prices', error);
    throw new Error(`Precios: ${error.message}`);
  }
  return data || [];
}

export async function getProducts() {
  const { data, error } = await getSupabase()
    .from('products')
    .select('id,code,name,active')
    .eq('active', true)
    .order('name');

  if (error) throw new Error(`Productos: ${error.message}`);
  return data || [];
}

export async function getCostEntries(periodId) {
  console.info('[HEMOCURA_COSTS] entries', periodId);

  const { data, error } = await getSupabase()
    .from('monthly_cost_entries')
    .select('id,period_id,branch_id,product_id,category,driver_code,description,quantity,unit_cost,total_cost,source,source_reference,status,created_at,updated_at')
    .eq('period_id', periodId)
    .order('category')
    .order('description');

  if (error) {
    console.error('[HEMOCURA_COSTS_ERROR] entries', error);
    throw new Error(`Entradas de costo: ${error.message}`);
  }
  return data || [];
}

export async function recalculateMonthlyCosts(periodId) {
  console.info('[HEMOCURA_COSTS_RECALC]', periodId);

  const { data, error } = await getSupabase()
    .rpc('hc_calculate_monthly_product_costs', { p_period_id: periodId });

  if (error) {
    console.error('[HEMOCURA_COSTS_ERROR] recalc', error);
    throw new Error(`Recalcular costos: ${error.message}`);
  }
  return data;
}

export async function loadCostWorkspace(filters = {}) {
  const results = await Promise.allSettled([
    getCostPeriods(filters),
    getMonthlyProductCosts(filters),
    getPriceVersions(),
    getProducts()
  ]);

  const periods = results[0].status === 'fulfilled' ? results[0].value : [];
  const costs = results[1].status === 'fulfilled' ? results[1].value : [];
  const prices = results[2].status === 'fulfilled' ? results[2].value : [];
  const products = results[3].status === 'fulfilled' ? results[3].value : [];

  const errors = results
    .filter(r => r.status === 'rejected')
    .map(r => r.reason?.message || 'Error');

  return { periods, costs, prices, products, errors };
}
