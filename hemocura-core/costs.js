import {
  loadCostWorkspace,
  getMonthlyProductCosts,
  getCostEntries,
  recalculateMonthlyCosts
} from './costs-data.js';
import { getBranches } from './sales-data.js';

const money = new Intl.NumberFormat('es-DO', {
  style:'currency', currency:'DOP', maximumFractionDigits:2
});
const num = new Intl.NumberFormat('es-DO', { maximumFractionDigits:2 });

function esc(v='') {
  return String(v ?? '').replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

function priceMap(prices) {
  const now = new Date().toISOString().slice(0,10);
  const map = {};
  for (const p of prices) {
    if (!p.product_id) continue;
    const active = p.effective_from <= now && (!p.effective_to || p.effective_to >= now);
    if (!active) continue;
    if (!map[p.product_id] || p.effective_from > map[p.product_id].effective_from) {
      map[p.product_id] = p;
    }
  }
  return map;
}

function statusPill(status='') {
  const s=String(status).toUpperCase();
  const cls = ['APROBADO','CERRADO'].includes(s) ? 'stock-ok'
    : ['VALIDACION','PRECIERRE'].includes(s) ? 'stock-warning'
    : 'stock-none';
  return `<span class="stock-pill ${cls}">${esc(status)}</span>`;
}

function costRows(rows, prices) {
  const pm = priceMap(prices);
  if (!rows.length) {
    return `<tr><td colspan="14" class="muted">No hay costos calculados para el filtro seleccionado.</td></tr>`;
  }

  return rows.map(r => {
    const price = pm[r.product_id]?.list_price;
    const cpu = Number(r.cost_per_unit || 0);
    const margin = price == null ? null : Number(price) - cpu;
    const marginPct = price && Number(price) !== 0 ? (margin / Number(price))*100 : null;
    const below = price != null && Number(price) < cpu;

    return `
      <tr class="${below ? 'row-danger' : ''}">
        <td>${esc(r.period_month)}</td>
        <td>${esc(r.branch || 'Corporativo')}</td>
        <td>${esc(r.product_code)}</td>
        <td><strong>${esc(r.product_name)}</strong></td>
        <td class="num">${num.format(Number(r.units_basis||0))}</td>
        <td class="num">${money.format(cpu)}</td>
        <td class="num">${r.previous_cost_per_unit == null ? '—' : money.format(Number(r.previous_cost_per_unit))}</td>
        <td class="num">${r.variance_pct == null ? '—' : num.format(Number(r.variance_pct))+'%'}</td>
        <td class="num">${price == null ? '—' : money.format(Number(price))}</td>
        <td class="num">${margin == null ? '—' : money.format(margin)}</td>
        <td class="num">${marginPct == null ? '—' : num.format(marginPct)+'%'}</td>
        <td class="num">${money.format(Number(r.material_cost||0))}</td>
        <td class="num">${money.format(Number(r.labor_cost||0))}</td>
        <td>${statusPill(r.status)}</td>
      </tr>`;
  }).join('');
}

function entryRows(rows, productMap) {
  if (!rows.length) {
    return `<tr><td colspan="9" class="muted">No hay entradas de costo visibles.</td></tr>`;
  }
  return rows.map(r => `
    <tr>
      <td>${esc(r.category)}</td>
      <td>${esc(productMap[r.product_id] || 'General')}</td>
      <td>${esc(r.description)}</td>
      <td class="num">${num.format(Number(r.quantity||0))}</td>
      <td class="num">${money.format(Number(r.unit_cost||0))}</td>
      <td class="num">${money.format(Number(r.total_cost||0))}</td>
      <td>${esc(r.source || '—')}</td>
      <td>${statusPill(r.status)}</td>
      <td>${esc(r.source_reference || '')}</td>
    </tr>`).join('');
}

function summary(rows, prices) {
  const pm=priceMap(prices);
  let totalCost=0, products=0, belowCost=0, avgVariance=0, varianceCount=0;

  for (const r of rows) {
    totalCost += Number(r.total_cost||0);
    products++;
    const price=pm[r.product_id]?.list_price;
    if (price != null && Number(price) < Number(r.cost_per_unit||0)) belowCost++;
    if (r.variance_pct != null) {
      avgVariance += Number(r.variance_pct);
      varianceCount++;
    }
  }

  return {
    totalCost,
    products,
    belowCost,
    avgVariance: varianceCount ? avgVariance/varianceCount : 0
  };
}

export async function mountCosts(root) {
  if (!root) return;

  root.innerHTML = `<section class="card"><h3>Costos</h3><div class="status info">Cargando motor mensual de costos…</div></section>`;

  try {
    const branches = await getBranches();
    const state = { workspace:null };

    root.innerHTML = `
      <div class="sales-toolbar">
        <div>
          <h2 class="section-heading">Costos, precios y rentabilidad</h2>
          <div class="muted">Costo unitario mensual, variación, precio vigente y margen estimado.</div>
        </div>
        <button id="cost-refresh" class="secondary">Actualizar</button>
      </div>

      <section class="card filters-card">
        <div class="filter-grid">
          <label>Mes
            <input id="cost-month" type="month">
          </label>
          <label>Sucursal
            <select id="cost-branch">
              <option value="">Corporativo / todas visibles</option>
              ${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}
            </select>
          </label>
          <label>Estado período
            <select id="cost-status">
              <option value="">Todos</option>
              <option>ABIERTO</option>
              <option>PRECIERRE</option>
              <option>VALIDACION</option>
              <option>APROBADO</option>
              <option>CERRADO</option>
              <option>REABIERTO</option>
            </select>
          </label>
        </div>
        <button id="cost-search">Aplicar filtros</button>
      </section>

      <div id="cost-errors"></div>
      <div id="cost-summary"></div>

      <section class="card">
        <div class="card-head">
          <h3>Costos por producto</h3>
          <span class="muted" id="cost-count"></span>
        </div>
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th>Mes</th><th>Sucursal</th><th>Código</th><th>Producto</th>
                <th>Base uds.</th><th>Costo/u</th><th>Costo previo</th><th>Var. %</th>
                <th>Precio vigente</th><th>Margen/u</th><th>Margen %</th>
                <th>Material</th><th>Mano obra</th><th>Estado</th>
              </tr>
            </thead>
            <tbody id="cost-body"></tbody>
          </table>
        </div>
      </section>

      <section class="card">
        <div class="card-head">
          <div>
            <h3>Períodos mensuales</h3>
            <span class="muted">Seleccione un período para ver entradas o recalcular.</span>
          </div>
        </div>
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr><th>Mes</th><th>Sucursal</th><th>Estado</th><th>Notas</th><th></th></tr>
            </thead>
            <tbody id="period-body"></tbody>
          </table>
        </div>
      </section>

      <section class="card hidden" id="entries-card">
        <div class="card-head">
          <div>
            <h3>Entradas del período</h3>
            <div class="muted" id="entries-meta"></div>
          </div>
          <button id="entries-close" class="secondary">Cerrar</button>
        </div>
        <div id="entries-actions"></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr><th>Categoría</th><th>Producto</th><th>Descripción</th><th>Cantidad</th><th>Costo unit.</th><th>Total</th><th>Fuente</th><th>Estado</th><th>Referencia</th></tr>
            </thead>
            <tbody id="entries-body"></tbody>
          </table>
        </div>
      </section>

      <div class="debug-strip">[HEMOCURA_COSTS] listo</div>`;

    async function load() {
      const monthValue = document.getElementById('cost-month').value;
      const filters = {
        month: monthValue ? `${monthValue}-01` : '',
        branchId: document.getElementById('cost-branch').value,
        status: document.getElementById('cost-status').value
      };

      document.getElementById('cost-body').innerHTML = `<tr><td colspan="14">Consultando…</td></tr>`;
      const ws = await loadCostWorkspace(filters);
      state.workspace = ws;

      document.getElementById('cost-body').innerHTML = costRows(ws.costs, ws.prices);
      document.getElementById('cost-count').textContent = `${ws.costs.length} registro(s)`;

      const s = summary(ws.costs, ws.prices);
      document.getElementById('cost-summary').innerHTML = `
        <div class="grid sales-kpis">
          <section class="card"><div class="muted">Costo mensual total</div><div class="kpi">${money.format(s.totalCost)}</div></section>
          <section class="card"><div class="muted">Productos calculados</div><div class="kpi">${num.format(s.products)}</div></section>
          <section class="card"><div class="muted">Precio bajo costo</div><div class="kpi">${num.format(s.belowCost)}</div></section>
          <section class="card"><div class="muted">Variación promedio</div><div class="kpi">${num.format(s.avgVariance)}%</div></section>
        </div>`;

      document.getElementById('cost-errors').innerHTML = ws.errors.length
        ? `<div class="status warn">Carga parcial: ${esc(ws.errors.join(' · '))}</div>`
        : '';

      const branchMap = Object.fromEntries(branches.map(b=>[b.id,b]));
      document.getElementById('period-body').innerHTML = ws.periods.length
        ? ws.periods.map(p=>`
          <tr>
            <td>${esc(p.period_month)}</td>
            <td>${esc(branchMap[p.branch_id]?.name || (p.branch_id ? p.branch_id : 'Corporativo'))}</td>
            <td>${statusPill(p.status)}</td>
            <td>${esc(p.notes || '')}</td>
            <td><button class="secondary compact" data-period="${esc(p.id)}">Ver entradas</button></td>
          </tr>`).join('')
        : `<tr><td colspan="5" class="muted">No hay períodos visibles.</td></tr>`;

      document.querySelectorAll('[data-period]').forEach(btn=>{
        btn.addEventListener('click',()=>openPeriod(btn.dataset.period));
      });

      console.info('[HEMOCURA_COSTS] módulo OK');
    }

    async function openPeriod(periodId) {
      const p = state.workspace?.periods?.find(x=>x.id===periodId);
      document.getElementById('entries-card').classList.remove('hidden');
      document.getElementById('entries-meta').textContent = p
        ? `${p.period_month} · ${p.status}`
        : periodId;
      document.getElementById('entries-body').innerHTML = `<tr><td colspan="9">Cargando entradas…</td></tr>`;

      try {
        const rows = await getCostEntries(periodId);
        const productMap = Object.fromEntries(
          (state.workspace.products||[]).map(x=>[x.id,`${x.code} · ${x.name}`])
        );
        document.getElementById('entries-body').innerHTML = entryRows(rows, productMap);

        const editable = p && ['ABIERTO','PRECIERRE','VALIDACION','REABIERTO'].includes(p.status);
        document.getElementById('entries-actions').innerHTML = editable
          ? `<div class="status info">
               Período editable. Después de validar las entradas puede recalcular el costo por producto.
               <button id="recalc-period" class="compact">Recalcular costos</button>
             </div>`
          : `<div class="status ok">Período ${esc(p?.status || '')}: solo consulta desde este módulo.</div>`;

        document.getElementById('recalc-period')?.addEventListener('click', async ()=>{
          const box=document.getElementById('entries-actions');
          box.innerHTML=`<div class="status info">Recalculando…</div>`;
          try {
            await recalculateMonthlyCosts(periodId);
            box.innerHTML=`<div class="status ok">Costos recalculados correctamente.</div>`;
            await load();
          } catch(error) {
            box.innerHTML=`<div class="status bad">${esc(error.message)}</div>`;
          }
        });

      } catch(error) {
        document.getElementById('entries-body').innerHTML =
          `<tr><td colspan="9"><div class="status bad">${esc(error.message)}</div></td></tr>`;
      }
    }

    document.getElementById('cost-search').addEventListener('click',()=>load().catch(showError));
    document.getElementById('cost-refresh').addEventListener('click',()=>load().catch(showError));
    document.getElementById('entries-close').addEventListener('click',()=>{
      document.getElementById('entries-card').classList.add('hidden');
    });

    function showError(error) {
      console.error('[HEMOCURA_COSTS_ERROR]', error);
      document.getElementById('cost-errors').innerHTML =
        `<div class="status bad">${esc(error.message)}</div>`;
    }

    await load();

  } catch(error) {
    console.error('[HEMOCURA_COSTS_ERROR]', error);
    root.innerHTML = `
      <section class="card">
        <h3>Costos no disponible</h3>
        <div class="status bad">${esc(error.message)}</div>
        <p>Abra F12 → Console y busque <code>HEMOCURA_COSTS_ERROR</code>.</p>
      </section>`;
  }
}
