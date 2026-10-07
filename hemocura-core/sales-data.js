import { getSupabase } from './supabase.js';

export async function getBranches() {
  console.info('[HEMOCURA_SALES] branches');
  const { data, error } = await getSupabase()
    .from('branches')
    .select('id,name,code,active')
    .eq('active', true)
    .order('name');
  if (error) {
    console.error('[HEMOCURA_SALES_ERROR] branches', error);
    throw new Error(`Sucursales: ${error.message}`);
  }
  return data || [];
}

export async function getDailySales(filters = {}) {
  console.info('[HEMOCURA_SALES] daily_sales', filters);

  let q = getSupabase()
    .from('daily_sales')
    .select('id,sale_date,branch_id,status,total_units,total_revenue,total_cost,gross_margin,gross_margin_pct,notes,created_at,updated_at')
    .order('sale_date', { ascending: false })
    .order('created_at', { ascending: false })
    .limit(100);

  if (filters.branchId) q = q.eq('branch_id', filters.branchId);
  if (filters.status) q = q.eq('status', filters.status);
  if (filters.from) q = q.gte('sale_date', filters.from);
  if (filters.to) q = q.lte('sale_date', filters.to);

  const { data, error } = await q;
  if (error) {
    console.error('[HEMOCURA_SALES_ERROR] daily_sales', error);
    throw new Error(`Ventas: ${error.message}`);
  }
  return data || [];
}

export async function getSaleLines(dailySaleId) {
  console.info('[HEMOCURA_SALES_DETAIL]', dailySaleId);
  const { data, error } = await getSupabase()
    .from('vw_sale_lines_editable')
    .select('line_id,daily_sale_id,sale_date,branch_id,status,product_id,customer_id,product_code,product_name,customer,source_type,source_units,adjustment_units,final_units,adjustment_reason,unit_price,cost_per_unit,total_amount,total_cost,gross_margin,invoice_date,revenue_date,source_dispatch_line_id')
    .eq('daily_sale_id', dailySaleId)
    .order('product_name', { ascending: true });

  if (error) {
    console.error('[HEMOCURA_SALES_ERROR] detail', error);
    throw new Error(`Detalle de venta: ${error.message}`);
  }
  return data || [];
}

export async function adjustSaleLine(lineId, adjustment, reason) {
  if (!reason || reason.trim().length < 3) {
    throw new Error('El motivo del ajuste es obligatorio.');
  }

  console.info('[HEMOCURA_SALES_ADJUST]', { lineId, adjustment });

  // C13-C2: la UI usa el wrapper controlado; la función legacy queda interna.
  const { error } = await getSupabase().rpc('hc_adjust_sale_line', {
    p_line_id: lineId,
    p_adjustment: Number(adjustment),
    p_reason: reason.trim()
  });

  if (error) {
    console.error('[HEMOCURA_SALES_ERROR] adjust', error);
    throw new Error(`Ajuste: ${error.message}`);
  }
}

export async function loadSalesWorkspace(filters = {}) {
  const [branches, sales] = await Promise.all([
    getBranches(),
    getDailySales(filters)
  ]);

  const branchMap = Object.fromEntries(branches.map(b => [b.id, b]));

  return {
    branches,
    branchMap,
    sales,
    loadedAt: new Date()
  };
}
