import { loadDashboardData } from './data.js';

const money = new Intl.NumberFormat('es-DO', {
  style: 'currency',
  currency: 'DOP',
  maximumFractionDigits: 0
});
const num = new Intl.NumberFormat('es-DO', { maximumFractionDigits: 2 });

function esc(value='') {
  return String(value).replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

function severityClass(value='') {
  const s = String(value).toUpperCase();
  if (s === 'CRITICA') return 'sev-critical';
  if (s === 'ALTA') return 'sev-high';
  if (s === 'MEDIA') return 'sev-medium';
  return 'sev-low';
}

function kpi(label, value, note='', cls='') {
  return `
    <section class="card kpi-card ${cls}">
      <div class="muted">${esc(label)}</div>
      <div class="kpi">${esc(value)}</div>
      <small>${esc(note)}</small>
    </section>`;
}

function branchRows(rows) {
  if (!rows.length) {
    return `<tr><td colspan="9" class="muted">No hay datos visibles para las sucursales autorizadas hoy.</td></tr>`;
  }
  return rows.map(r => `
    <tr>
      <td><strong>${esc(r.branch || '—')}</strong></td>
      <td class="num">${num.format(Number(r.units_sold || 0))}</td>
      <td class="num">${num.format(Number(r.units_dispatched || 0))}</td>
      <td class="num">${money.format(Number(r.revenue || 0))}</td>
      <td class="num">${money.format(Number(r.cost || 0))}</td>
      <td class="num">${money.format(Number(r.margin || 0))}</td>
      <td class="num">${num.format(Number(r.incidents || 0))}</td>
      <td class="num">${num.format(Number(r.open_alerts || 0))}</td>
      <td class="num">${num.format(Number(r.critical_alerts || 0))}</td>
    </tr>`).join('');
}

function alertRows(rows) {
  if (!rows.length) {
    return `<div class="status ok">No hay alertas de gestión abiertas visibles.</div>`;
  }
  return rows.map(a => `
    <article class="alert-row">
      <div>
        <span class="severity ${severityClass(a.severity)}">${esc(a.severity || 'SIN NIVEL')}</span>
        <strong>${esc(a.title || 'Alerta')}</strong>
        <div class="muted">${esc(a.branch || 'Corporativo')} · ${esc(a.category || '')}</div>
      </div>
      <p>${esc(a.description || '')}</p>
    </article>`).join('');
}

function renderLoading(root) {
  root.innerHTML = `
    <section class="card">
      <h3>Command Center</h3>
      <div class="status info">Consultando Supabase…</div>
    </section>`;
}

function renderError(root, message) {
  root.innerHTML = `
    <section class="card">
      <h3>Dashboard no disponible</h3>
      <div class="status bad">${esc(message)}</div>
      <p>Abra <b>F12 → Console</b> y busque <code>HEMOCURA_DASHBOARD_ERROR</code>.</p>
      <button id="dashboard-retry">Reintentar</button>
    </section>`;
  document.getElementById('dashboard-retry')?.addEventListener('click', () => mountDashboard(root));
}

export async function mountDashboard(root) {
  if (!root) return;
  renderLoading(root);

  try {
    const data = await loadDashboardData();
    const t = data.totals;
    const reconciliationGap = t.units_dispatched - t.units_sold;

    root.innerHTML = `
      <div class="dashboard-toolbar">
        <div>
          <h2 class="section-heading">Command Center · Hoy</h2>
          <div class="muted">Última actualización: ${data.loadedAt.toLocaleString('es-DO')}</div>
        </div>
        <button id="dashboard-refresh" class="secondary">Actualizar</button>
      </div>

      ${data.errors.length ? `<div class="status warn">Carga parcial: ${esc(data.errors.join(' · '))}</div>` : ''}

      <div class="grid dashboard-kpis">
        ${kpi('Unidades vendidas', num.format(t.units_sold), 'Total visible por RLS')}
        ${kpi('Unidades despachadas', num.format(t.units_dispatched), 'Despachos confirmados')}
        ${kpi('Ingresos', money.format(t.revenue), 'Ventas de hoy')}
        ${kpi('Margen bruto', money.format(t.margin), `${num.format(t.margin_pct)}%`)}
        ${kpi('Brecha despacho/venta', num.format(reconciliationGap), 'Despachadas - vendidas',
          reconciliationGap !== 0 ? 'kpi-warning' : 'kpi-ok')}
        ${kpi('Incidencias', num.format(t.incidents), 'Registradas hoy')}
        ${kpi('Alertas abiertas', num.format(t.open_alerts), 'Gestión')}
        ${kpi('Alertas críticas', num.format(t.critical_alerts), 'Atención inmediata',
          t.critical_alerts > 0 ? 'kpi-danger' : 'kpi-ok')}
      </div>

      <section class="card">
        <div class="card-head">
          <h3>Operación por sucursal</h3>
          <span class="muted">${data.command.length} sucursal(es) visibles</span>
        </div>
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th>Sucursal</th><th>Vendidas</th><th>Despachadas</th>
                <th>Ingresos</th><th>Costo</th><th>Margen</th>
                <th>Incidencias</th><th>Alertas</th><th>Críticas</th>
              </tr>
            </thead>
            <tbody>${branchRows(data.command)}</tbody>
          </table>
        </div>
      </section>

      <section class="card">
        <div class="card-head">
          <h3>Alertas de gestión abiertas</h3>
          <span class="muted">Últimas ${data.alerts.length}</span>
        </div>
        <div class="alerts-list">${alertRows(data.alerts)}</div>
      </section>

      <div class="debug-strip">
        [HEMOCURA_DASHBOARD] OK · vw_command_center_today · vw_open_management_alerts
      </div>`;

    document.getElementById('dashboard-refresh')?.addEventListener('click', () => mountDashboard(root));
  } catch (error) {
    console.error('[HEMOCURA_DASHBOARD_ERROR]', error);
    renderError(root, error.message || String(error));
  }
}
