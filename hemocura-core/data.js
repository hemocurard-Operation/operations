import { getSupabase } from './supabase.js';

export async function getCommandCenterToday() {
  console.info('[HEMOCURA_DASHBOARD] consultando vw_command_center_today');
  const { data, error } = await getSupabase()
    .from('vw_command_center_today')
    .select('*')
    .order('branch', { ascending: true });

  if (error) {
    console.error('[HEMOCURA_DASHBOARD_ERROR] command center', error);
    throw new Error(`Command Center: ${error.message}`);
  }
  return data || [];
}

export async function getOpenManagementAlerts(limit = 10) {
  console.info('[HEMOCURA_DASHBOARD] consultando vw_open_management_alerts');
  const { data, error } = await getSupabase()
    .from('vw_open_management_alerts')
    .select('id,alert_date,branch_id,branch,category,severity,title,description,status,due_at')
    .order('alert_date', { ascending: false })
    .limit(limit);

  if (error) {
    console.error('[HEMOCURA_DASHBOARD_ERROR] alerts', error);
    throw new Error(`Alertas: ${error.message}`);
  }
  return data || [];
}

export async function loadDashboardData() {
  const started = performance.now();

  const results = await Promise.allSettled([
    getCommandCenterToday(),
    getOpenManagementAlerts(10)
  ]);

  const command = results[0].status === 'fulfilled' ? results[0].value : [];
  const alerts = results[1].status === 'fulfilled' ? results[1].value : [];

  const errors = [];
  if (results[0].status === 'rejected') errors.push(results[0].reason?.message || 'Error Command Center');
  if (results[1].status === 'rejected') errors.push(results[1].reason?.message || 'Error Alertas');

  const totals = command.reduce((acc, row) => {
    acc.units_sold += Number(row.units_sold || 0);
    acc.units_dispatched += Number(row.units_dispatched || 0);
    acc.revenue += Number(row.revenue || 0);
    acc.cost += Number(row.cost || 0);
    acc.margin += Number(row.margin || 0);
    acc.incidents += Number(row.incidents || 0);
    acc.open_alerts += Number(row.open_alerts || 0);
    acc.critical_alerts += Number(row.critical_alerts || 0);
    return acc;
  }, {
    units_sold:0, units_dispatched:0, revenue:0, cost:0,
    margin:0, incidents:0, open_alerts:0, critical_alerts:0
  });

  totals.margin_pct = totals.revenue > 0 ? (totals.margin / totals.revenue) * 100 : 0;

  console.info('[HEMOCURA_DASHBOARD] datos OK', {
    branches: command.length,
    alerts: alerts.length,
    ms: Math.round(performance.now() - started)
  });

  return {
    command,
    alerts,
    totals,
    errors,
    loadedAt: new Date()
  };
}
