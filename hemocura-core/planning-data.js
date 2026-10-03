import { getSupabase } from './supabase.js';

export async function getOperationalPlans(filters = {}) {
  console.info('[HEMOCURA_PLANNING] operational_plans', filters);

  let q = getSupabase()
    .from('operational_plans')
    .select('id,branch_id,period_start,period_end,period_type,status,notes,created_by,approved_by,created_at,approved_at')
    .order('period_start', { ascending:false })
    .limit(100);

  if (filters.branchId) q = q.eq('branch_id', filters.branchId);
  if (filters.status) q = q.eq('status', filters.status);
  if (filters.periodType) q = q.eq('period_type', filters.periodType);

  const { data, error } = await q;
  if (error) {
    console.error('[HEMOCURA_PLANNING_ERROR] plans', error);
    throw new Error(`Planes: ${error.message}`);
  }
  return data || [];
}

export async function getPlanLines(planId) {
  console.info('[HEMOCURA_PLANNING] operational_plan_lines', planId);

  const { data, error } = await getSupabase()
    .from('operational_plan_lines')
    .select('id,plan_id,product_id,metric_code,target_value,warning_threshold_pct,critical_threshold_pct,created_at')
    .eq('plan_id', planId)
    .order('metric_code')
    .order('product_id');

  if (error) {
    console.error('[HEMOCURA_PLANNING_ERROR] plan lines', error);
    throw new Error(`Líneas del plan: ${error.message}`);
  }
  return data || [];
}

export async function getPlanVsActual(filters = {}) {
  console.info('[HEMOCURA_PLAN_VS_ACTUAL]', filters);

  let q = getSupabase()
    .from('vw_plan_vs_actual_status')
    .select('plan_id,branch_id,branch,period_start,period_end,period_type,product_id,product_code,product_name,metric_code,target_value,actual_value,warning_threshold_pct,critical_threshold_pct,attainment_pct,status')
    .order('period_start', { ascending:false })
    .order('branch', { ascending:true })
    .order('metric_code', { ascending:true })
    .limit(500);

  if (filters.branchId) q = q.eq('branch_id', filters.branchId);
  if (filters.from) q = q.gte('period_start', filters.from);
  if (filters.to) q = q.lte('period_end', filters.to);

  const { data, error } = await q;
  if (error) {
    console.error('[HEMOCURA_PLANNING_ERROR] plan vs actual', error);
    throw new Error(`Plan vs Real: ${error.message}`);
  }
  return data || [];
}

export async function getForecasts(filters = {}) {
  console.info('[HEMOCURA_FORECAST]', filters);

  let q = getSupabase()
    .from('forecast_snapshots')
    .select('id,forecast_date,branch_id,product_id,metric_code,horizon_days,forecast_value,method,source_days,confidence_note,created_at')
    .order('forecast_date', { ascending:false })
    .order('horizon_days', { ascending:true })
    .order('metric_code', { ascending:true })
    .limit(500);

  if (filters.branchId) q = q.eq('branch_id', filters.branchId);
  if (filters.forecastDate) q = q.eq('forecast_date', filters.forecastDate);
  if (filters.horizonDays) q = q.eq('horizon_days', Number(filters.horizonDays));

  const { data, error } = await q;
  if (error) {
    console.error('[HEMOCURA_PLANNING_ERROR] forecast', error);
    throw new Error(`Forecast: ${error.message}`);
  }
  return data || [];
}

export async function refreshForecasts(forecastDate) {
  console.info('[HEMOCURA_FORECAST_REFRESH]', forecastDate);

  const { error } = await getSupabase()
    .rpc('refresh_forecasts', { p_forecast_date: forecastDate });

  if (error) {
    console.error('[HEMOCURA_PLANNING_ERROR] refresh forecast', error);
    throw new Error(`Actualizar forecast: ${error.message}`);
  }
}

export async function createOperationalPlan(payload) {
  console.info('[HEMOCURA_PLANNING] create plan', payload);

  const { data, error } = await getSupabase()
    .from('operational_plans')
    .insert({
      branch_id: payload.branchId,
      period_start: payload.periodStart,
      period_end: payload.periodEnd,
      period_type: payload.periodType,
      status: 'DRAFT',
      notes: payload.notes || null
    })
    .select()
    .single();

  if (error) {
    console.error('[HEMOCURA_PLANNING_ERROR] create plan', error);
    throw new Error(`Crear plan: ${error.message}`);
  }
  return data;
}

export async function addPlanLine(payload) {
  console.info('[HEMOCURA_PLANNING] add line', payload);

  const { data, error } = await getSupabase()
    .from('operational_plan_lines')
    .insert({
      plan_id: payload.planId,
      product_id: payload.productId || null,
      metric_code: payload.metricCode,
      target_value: Number(payload.targetValue),
      warning_threshold_pct: Number(payload.warningPct || 90),
      critical_threshold_pct: Number(payload.criticalPct || 80)
    })
    .select()
    .single();

  if (error) {
    console.error('[HEMOCURA_PLANNING_ERROR] add line', error);
    throw new Error(`Agregar línea: ${error.message}`);
  }
  return data;
}

export async function loadPlanningWorkspace(filters = {}) {
  const results = await Promise.allSettled([
    getOperationalPlans(filters),
    getPlanVsActual(filters),
    getForecasts(filters)
  ]);

  const plans = results[0].status === 'fulfilled' ? results[0].value : [];
  const planVsActual = results[1].status === 'fulfilled' ? results[1].value : [];
  const forecasts = results[2].status === 'fulfilled' ? results[2].value : [];

  const errors = results
    .filter(r => r.status === 'rejected')
    .map(r => r.reason?.message || 'Error');

  return { plans, planVsActual, forecasts, errors };
}
