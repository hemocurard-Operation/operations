import { getSupabase } from './supabase.js';

export async function getInventoryStatus(filters = {}) {
  console.info('[HEMOCURA_INVENTORY] vw_inventory_status', filters);

  let q = getSupabase()
    .from('vw_inventory_status')
    .select('branch_id,branch,product_id,product_code,product_name,theoretical_qty,physical_qty,count_date,variance')
    .order('branch', { ascending: true })
    .order('product_name', { ascending: true });

  if (filters.branchId) q = q.eq('branch_id', filters.branchId);
  if (filters.productId) q = q.eq('product_id', filters.productId);

  const { data, error } = await q;
  if (error) {
    console.error('[HEMOCURA_INVENTORY_ERROR] status', error);
    throw new Error(`Estado de inventario: ${error.message}`);
  }
  return data || [];
}

export async function getInventoryPolicies(filters = {}) {
  console.info('[HEMOCURA_INVENTORY] inventory_policies');
  let q = getSupabase()
    .from('inventory_policies')
    .select('id,branch_id,product_id,minimum_stock,warning_stock,target_stock,active')
    .eq('active', true);

  if (filters.branchId) q = q.eq('branch_id', filters.branchId);

  const { data, error } = await q;
  if (error) {
    console.error('[HEMOCURA_INVENTORY_ERROR] policies', error);
    throw new Error(`Políticas: ${error.message}`);
  }
  return data || [];
}

export async function getInventoryMovements(filters = {}) {
  console.info('[HEMOCURA_INVENTORY_MOVEMENTS]', filters);

  let q = getSupabase()
    .from('inventory_movements')
    .select('id,movement_date,branch_id,product_id,movement_type,quantity,source_table,source_id,notes,created_at')
    .order('movement_date', { ascending: false })
    .order('created_at', { ascending: false })
    .limit(150);

  if (filters.branchId) q = q.eq('branch_id', filters.branchId);
  if (filters.productId) q = q.eq('product_id', filters.productId);
  if (filters.from) q = q.gte('movement_date', filters.from);
  if (filters.to) q = q.lte('movement_date', filters.to);

  const { data, error } = await q;
  if (error) {
    console.error('[HEMOCURA_INVENTORY_ERROR] movements', error);
    throw new Error(`Movimientos: ${error.message}`);
  }
  return data || [];
}

export async function savePhysicalCount({ countDate, branchId, productId, physicalQty, notes }) {
  console.info('[HEMOCURA_INVENTORY_COUNT]', { countDate, branchId, productId, physicalQty });

  const payload = {
    count_date: countDate,
    branch_id: branchId,
    product_id: productId,
    physical_qty: Number(physicalQty),
    notes: notes?.trim() || null
  };

  const { data, error } = await getSupabase()
    .from('physical_inventory_counts')
    .upsert(payload, { onConflict: 'count_date,branch_id,product_id' })
    .select()
    .single();

  if (error) {
    console.error('[HEMOCURA_INVENTORY_ERROR] physical count', error);
    throw new Error(`Conteo físico: ${error.message}`);
  }
  return data;
}

export async function loadInventoryWorkspace(filters = {}) {
  const results = await Promise.allSettled([
    getInventoryStatus(filters),
    getInventoryPolicies(filters),
    getInventoryMovements(filters)
  ]);

  const status = results[0].status === 'fulfilled' ? results[0].value : [];
  const policies = results[1].status === 'fulfilled' ? results[1].value : [];
  const movements = results[2].status === 'fulfilled' ? results[2].value : [];

  const errors = [];
  for (const r of results) {
    if (r.status === 'rejected') errors.push(r.reason?.message || 'Error');
  }

  return { status, policies, movements, errors };
}
