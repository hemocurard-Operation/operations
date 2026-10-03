import { loadInventoryWorkspace, savePhysicalCount } from './inventory-data.js';
import { getBranches } from './sales-data.js';

const num = new Intl.NumberFormat('es-DO', { maximumFractionDigits: 2 });

function esc(value='') {
  return String(value ?? '').replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

function todayISO() {
  return new Date().toISOString().slice(0,10);
}

function daysAgoISO(days=30) {
  const d = new Date();
  d.setDate(d.getDate()-days);
  return d.toISOString().slice(0,10);
}

function policyMap(policies) {
  return Object.fromEntries(
    policies.map(p => [`${p.branch_id}:${p.product_id}`, p])
  );
}

function stockState(row, policy) {
  const qty = Number(row.theoretical_qty || 0);
  if (!policy) return {label:'SIN POLÍTICA', cls:'stock-none'};

  const min = Number(policy.minimum_stock || 0);
  const warn = policy.warning_stock == null ? null : Number(policy.warning_stock);

  if (qty <= min) return {label:'CRÍTICO', cls:'stock-critical'};
  if (warn != null && qty <= warn) return {label:'ADVERTENCIA', cls:'stock-warning'};
  return {label:'OK', cls:'stock-ok'};
}

function inventoryRows(rows, policies) {
  const pm = policyMap(policies);
  if (!rows.length) {
    return `<tr><td colspan="10" class="muted">No hay inventario visible.</td></tr>`;
  }

  return rows.map(r => {
    const p = pm[`${r.branch_id}:${r.product_id}`];
    const state = stockState(r,p);
    return `
      <tr>
        <td>${esc(r.branch)}</td>
        <td>${esc(r.product_code)}</td>
        <td><strong>${esc(r.product_name)}</strong></td>
        <td class="num">${num.format(Number(r.theoretical_qty||0))}</td>
        <td class="num">${r.physical_qty == null ? '—' : num.format(Number(r.physical_qty))}</td>
        <td class="num">${r.variance == null ? '—' : num.format(Number(r.variance))}</td>
        <td>${esc(r.count_date || '—')}</td>
        <td class="num">${p ? num.format(Number(p.minimum_stock||0)) : '—'}</td>
        <td><span class="stock-pill ${state.cls}">${state.label}</span></td>
        <td>
          <button class="secondary compact"
            data-count-branch="${esc(r.branch_id)}"
            data-count-product="${esc(r.product_id)}"
            data-count-label="${esc(r.branch)} · ${esc(r.product_name)}"
            data-count-current="${esc(r.physical_qty ?? '')}">
            Conteo físico
          </button>
        </td>
      </tr>`;
  }).join('');
}

function movementRows(rows, branchMap, productMap) {
  if (!rows.length) {
    return `<tr><td colspan="8" class="muted">No hay movimientos para el período.</td></tr>`;
  }

  return rows.map(r => `
    <tr>
      <td>${esc(r.movement_date)}</td>
      <td>${esc(branchMap[r.branch_id]?.name || r.branch_id)}</td>
      <td>${esc(productMap[r.product_id] || r.product_id)}</td>
      <td><span class="movement-pill">${esc(r.movement_type)}</span></td>
      <td class="num">${num.format(Number(r.quantity||0))}</td>
      <td>${esc(r.source_table || '—')}</td>
      <td>${esc(r.notes || '')}</td>
      <td>${esc(r.created_at ? new Date(r.created_at).toLocaleString('es-DO') : '')}</td>
    </tr>`).join('');
}

function summarize(rows, policies) {
  const pm = policyMap(policies);
  let total = 0, critical = 0, warning = 0, variances = 0;

  for (const r of rows) {
    total += Number(r.theoretical_qty || 0);
    if (r.variance != null && Number(r.variance) !== 0) variances++;
    const s = stockState(r, pm[`${r.branch_id}:${r.product_id}`]);
    if (s.label === 'CRÍTICO') critical++;
    if (s.label === 'ADVERTENCIA') warning++;
  }

  return { total, critical, warning, variances };
}

export async function mountInventory(root) {
  if (!root) return;

  root.innerHTML = `
    <section class="card">
      <h3>Inventario</h3>
      <div class="status info">Consultando inventario agregado…</div>
    </section>`;

  try {
    const branches = await getBranches();

    root.innerHTML = `
      <div class="sales-toolbar">
        <div>
          <h2 class="section-heading">Inventario agregado</h2>
          <div class="muted">
            Inventario teórico + último conteo físico. FEFO clínico por unidad permanece fuera de esta versión.
          </div>
        </div>
        <button id="inventory-refresh" class="secondary">Actualizar</button>
      </div>

      <section class="card filters-card">
        <div class="filter-grid">
          <label>Sucursal
            <select id="inventory-branch">
              <option value="">Todas las autorizadas</option>
              ${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}
            </select>
          </label>
          <label>Movimientos desde
            <input id="inventory-from" type="date" value="${daysAgoISO(30)}">
          </label>
          <label>Movimientos hasta
            <input id="inventory-to" type="date" value="${todayISO()}">
          </label>
        </div>
        <button id="inventory-search">Aplicar filtros</button>
      </section>

      <div id="inventory-errors"></div>
      <div id="inventory-summary"></div>

      <section class="card">
        <div class="card-head">
          <h3>Estado actual</h3>
          <span class="muted" id="inventory-count"></span>
        </div>
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th>Sucursal</th><th>Código</th><th>Producto</th>
                <th>Teórico</th><th>Físico</th><th>Variación</th><th>Último conteo</th>
                <th>Mínimo</th><th>Estado</th><th></th>
              </tr>
            </thead>
            <tbody id="inventory-body"></tbody>
          </table>
        </div>
      </section>

      <section class="card">
        <div class="card-head">
          <h3>Movimientos recientes</h3>
          <span class="muted">Últimos 150 visibles</span>
        </div>
        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th>Fecha</th><th>Sucursal</th><th>Producto</th><th>Tipo</th>
                <th>Cantidad</th><th>Origen</th><th>Notas</th><th>Creado</th>
              </tr>
            </thead>
            <tbody id="movement-body"></tbody>
          </table>
        </div>
      </section>

      <dialog id="count-dialog" class="sales-dialog">
        <form id="count-form" method="dialog">
          <h3>Registrar conteo físico</h3>
          <p class="muted" id="count-label"></p>

          <input type="hidden" id="count-branch">
          <input type="hidden" id="count-product">

          <label>Fecha del conteo
            <input id="count-date" type="date" value="${todayISO()}" required>
          </label>

          <label>Cantidad física
            <input id="count-qty" type="number" min="0" step="0.01" required>
          </label>

          <label>Notas
            <textarea id="count-notes" placeholder="Observaciones del conteo"></textarea>
          </label>

          <div id="count-status"></div>

          <div class="dialog-actions">
            <button type="button" id="count-cancel" class="secondary">Cancelar</button>
            <button type="submit">Guardar conteo</button>
          </div>
        </form>
      </dialog>

      <div class="debug-strip">[HEMOCURA_INVENTORY] listo</div>`;

    const state = { branches, workspace:null };

    async function load() {
      const filters = {
        branchId: document.getElementById('inventory-branch').value,
        from: document.getElementById('inventory-from').value,
        to: document.getElementById('inventory-to').value
      };

      document.getElementById('inventory-body').innerHTML =
        `<tr><td colspan="10">Consultando…</td></tr>`;
      document.getElementById('movement-body').innerHTML =
        `<tr><td colspan="8">Consultando…</td></tr>`;

      const ws = await loadInventoryWorkspace(filters);
      state.workspace = ws;

      const branchMap = Object.fromEntries(branches.map(b=>[b.id,b]));
      const productMap = Object.fromEntries(ws.status.map(r=>[r.product_id,`${r.product_code} · ${r.product_name}`]));

      document.getElementById('inventory-body').innerHTML =
        inventoryRows(ws.status, ws.policies);

      document.getElementById('movement-body').innerHTML =
        movementRows(ws.movements, branchMap, productMap);

      document.getElementById('inventory-count').textContent =
        `${ws.status.length} combinación(es) sucursal/producto`;

      const s = summarize(ws.status, ws.policies);

      document.getElementById('inventory-summary').innerHTML = `
        <div class="grid sales-kpis">
          <section class="card"><div class="muted">Stock teórico total</div><div class="kpi">${num.format(s.total)}</div></section>
          <section class="card"><div class="muted">Stock crítico</div><div class="kpi">${num.format(s.critical)}</div></section>
          <section class="card"><div class="muted">Advertencias</div><div class="kpi">${num.format(s.warning)}</div></section>
          <section class="card"><div class="muted">Variaciones físicas</div><div class="kpi">${num.format(s.variances)}</div></section>
        </div>`;

      document.getElementById('inventory-errors').innerHTML =
        ws.errors.length
          ? `<div class="status warn">Carga parcial: ${esc(ws.errors.join(' · '))}</div>`
          : '';

      document.querySelectorAll('[data-count-branch]').forEach(btn=>{
        btn.addEventListener('click',()=>openCount(btn));
      });

      console.info('[HEMOCURA_INVENTORY] módulo OK', {
        status: ws.status.length,
        movements: ws.movements.length
      });
    }

    function openCount(btn) {
      document.getElementById('count-branch').value = btn.dataset.countBranch;
      document.getElementById('count-product').value = btn.dataset.countProduct;
      document.getElementById('count-label').textContent = btn.dataset.countLabel;
      document.getElementById('count-qty').value = btn.dataset.countCurrent || '';
      document.getElementById('count-notes').value = '';
      document.getElementById('count-status').innerHTML = '';
      document.getElementById('count-date').value = todayISO();
      document.getElementById('count-dialog').showModal();
    }

    document.getElementById('inventory-search').addEventListener('click',
      ()=>load().catch(showError));

    document.getElementById('inventory-refresh').addEventListener('click',
      ()=>load().catch(showError));

    document.getElementById('count-cancel').addEventListener('click',()=>{
      document.getElementById('count-dialog').close();
    });

    document.getElementById('count-form').addEventListener('submit', async event=>{
      event.preventDefault();
      const status = document.getElementById('count-status');

      status.innerHTML = `<div class="status info">Guardando conteo…</div>`;

      try {
        await savePhysicalCount({
          countDate: document.getElementById('count-date').value,
          branchId: document.getElementById('count-branch').value,
          productId: document.getElementById('count-product').value,
          physicalQty: document.getElementById('count-qty').value,
          notes: document.getElementById('count-notes').value
        });

        status.innerHTML = `<div class="status ok">Conteo guardado.</div>`;
        await load();
        setTimeout(()=>document.getElementById('count-dialog').close(), 450);
      } catch(error) {
        console.error('[HEMOCURA_INVENTORY_ERROR] save count', error);
        status.innerHTML = `<div class="status bad">${esc(error.message)}</div>`;
      }
    });

    function showError(error) {
      console.error('[HEMOCURA_INVENTORY_ERROR]', error);
      document.getElementById('inventory-errors').innerHTML =
        `<div class="status bad">${esc(error.message)}</div>`;
    }

    await load();

  } catch(error) {
    console.error('[HEMOCURA_INVENTORY_ERROR]', error);
    root.innerHTML = `
      <section class="card">
        <h3>Inventario no disponible</h3>
        <div class="status bad">${esc(error.message)}</div>
        <p>Abra F12 → Console y busque <code>HEMOCURA_INVENTORY_ERROR</code>.</p>
      </section>`;
  }
}
