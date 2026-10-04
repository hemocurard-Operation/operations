import { getSupabase } from './supabase.js';

export async function getDispatches(filters = {}) {
  console.info('[HEMOCURA_DISPATCH] dispatches', filters);

  let q = getSupabase()
    .from('dispatches')
    .select('id,dispatch_date,branch_id,customer_id,shift,dispatch_type,status,notes,created_by,created_at,confirmed_at')
    .order('dispatch_date', { ascending: false })
    .order('created_at', { ascending: false })
    .limit(100);

  if (filters.branchId) q = q.eq('branch_id', filters.branchId);
  if (filters.status) q = q.eq('status', filters.status);
  if (filters.from) q = q.gte('dispatch_date', filters.from);
  if (filters.to) q = q.lte('dispatch_date', filters.to);

  const { data, error } = await q;
  if (error) {
    console.error('[HEMOCURA_DISPATCH_ERROR] dispatches', error);
    throw new Error(`Despachos: ${error.message}`);
  }
  return data || [];
}

export async function getDispatchLines(dispatchId) {
  console.info('[HEMOCURA_DISPATCH_DETAIL]', dispatchId);

  const { data, error } = await getSupabase()
    .from('dispatch_lines')
    .select('id,dispatch_id,product_id,units,is_sale,sale_generated,created_at')
    .eq('dispatch_id', dispatchId)
    .order('created_at', { ascending: true });

  if (error) {
    console.error('[HEMOCURA_DISPATCH_ERROR] detail', error);
    throw new Error(`Detalle despacho: ${error.message}`);
  }
  return data || [];
}

export async function getProductsForDispatch() {
  const { data, error } = await getSupabase()
    .from('products')
    .select('id,code,name,active')
    .order('name');

  if (error) {
    console.error('[HEMOCURA_DISPATCH_ERROR] products', error);
    throw new Error(`Productos: ${error.message}`);
  }
  return data || [];
}

export async function getReconciliation(filters = {}) {
  console.info('[HEMOCURA_DISPATCH_RECON]', filters);

  let q = getSupabase()
    .from('vw_dispatch_sales_reconciliation')
    .select('dispatch_date,branch_id,product_id,dispatched_sale_units,recognized_sale_units,difference_units')
    .order('dispatch_date', { ascending: false })
    .limit(200);

  if (filters.branchId) q = q.eq('branch_id', filters.branchId);
  if (filters.from) q = q.gte('dispatch_date', filters.from);
  if (filters.to) q = q.lte('dispatch_date', filters.to);

  const { data, error } = await q;
  if (error) {
    console.error('[HEMOCURA_DISPATCH_ERROR] reconciliation', error);
    throw new Error(`Conciliación: ${error.message}`);
  }
  return data || [];
}

export async function loadDispatchWorkspace(filters = {}) {
  const [dispatches, reconciliation] = await Promise.allSettled([
    getDispatches(filters),
    getReconciliation(filters)
  ]);

  return {
    dispatches: dispatches.status === 'fulfilled' ? dispatches.value : [],
    reconciliation: reconciliation.status === 'fulfilled' ? reconciliation.value : [],
    errors: [
      ...(dispatches.status === 'rejected' ? [dispatches.reason.message] : []),
      ...(reconciliation.status === 'rejected' ? [reconciliation.reason.message] : [])
    ]
  };
}
