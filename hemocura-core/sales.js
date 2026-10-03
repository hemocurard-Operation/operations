import {
  loadSalesWorkspace,
  getDailySales,
  getSaleLines,
  adjustSaleLine
} from './sales-data.js';

const money = new Intl.NumberFormat('es-DO', {
  style:'currency',
  currency:'DOP',
  maximumFractionDigits:2
});
const num = new Intl.NumberFormat('es-DO', { maximumFractionDigits:2 });

function esc(value='') {
  return String(value ?? '').replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

function statusClass(status='') {
  const s=String(status).toUpperCase();
  if(s==='CONFIRMADO') return 'sale-confirmed';
  if(s==='CERRADO') return 'sale-closed';
  if(s==='REABIERTO') return 'sale-reopened';
  return 'sale-draft';
}

function defaultDates() {
  const today = new Date();
  const to = today.toISOString().slice(0,10);
  const fromDate = new Date(today);
  fromDate.setDate(fromDate.getDate()-30);
  return { from: fromDate.toISOString().slice(0,10), to };
}

function summary(sales) {
  return sales.reduce((a,s)=>{
    a.units += Number(s.total_units||0);
    a.revenue += Number(s.total_revenue||0);
    a.cost += Number(s.total_cost||0);
    a.margin += Number(s.gross_margin||0);
    return a;
  }, {units:0,revenue:0,cost:0,margin:0});
}

function salesRows(sales, branchMap) {
  if(!sales.length) return `<tr><td colspan="8" class="muted">No hay ventas para los filtros seleccionados.</td></tr>`;

  return sales.map(s=>`
    <tr>
      <td>${esc(s.sale_date)}</td>
      <td>${esc(branchMap[s.branch_id]?.name || s.branch_id)}</td>
      <td><span class="sale-status ${statusClass(s.status)}">${esc(s.status)}</span></td>
      <td class="num">${num.format(Number(s.total_units||0))}</td>
      <td class="num">${money.format(Number(s.total_revenue||0))}</td>
      <td class="num">${money.format(Number(s.total_cost||0))}</td>
      <td class="num">${money.format(Number(s.gross_margin||0))}</td>
      <td><button class="secondary compact" data-sale-id="${esc(s.id)}">Ver detalle</button></td>
    </tr>`).join('');
}

function lineRows(lines) {
  if(!lines.length) return `<tr><td colspan="11" class="muted">La venta no contiene líneas visibles.</td></tr>`;

  return lines.map(l=>`
    <tr>
      <td>${esc(l.product_code || '')}</td>
      <td><strong>${esc(l.product_name || '')}</strong></td>
      <td>${esc(l.customer || '—')}</td>
      <td>${esc(l.source_type || '')}</td>
      <td class="num">${num.format(Number(l.source_units||0))}</td>
      <td class="num">${num.format(Number(l.adjustment_units||0))}</td>
      <td class="num"><strong>${num.format(Number(l.final_units||0))}</strong></td>
      <td class="num">${money.format(Number(l.unit_price||0))}</td>
      <td class="num">${money.format(Number(l.total_amount||0))}</td>
      <td class="num">${money.format(Number(l.gross_margin||0))}</td>
      <td><button class="secondary compact" data-adjust-line="${esc(l.line_id)}"
              data-product="${esc(l.product_name || '')}"
              data-current="${esc(l.adjustment_units || 0)}">Ajustar</button></td>
    </tr>`).join('');
}

export async function mountSales(root) {
  if(!root) return;
  const dates=defaultDates();

  root.innerHTML=`
    <section class="card">
      <h3>Ventas</h3>
      <div class="status info">Cargando ventas desde Supabase…</div>
    </section>`;

  try {
    const workspace=await loadSalesWorkspace({from:dates.from,to:dates.to});

    root.innerHTML=`
      <div class="sales-toolbar">
        <div>
          <h2 class="section-heading">Ventas operativas</h2>
          <div class="muted">Origen + ajuste = unidades finales. Los ajustes requieren motivo.</div>
        </div>
        <button id="sales-refresh" class="secondary">Actualizar</button>
      </div>

      <section class="card filters-card">
        <div class="filter-grid">
          <label>Desde<input id="sales-from" type="date" value="${dates.from}"></label>
          <label>Hasta<input id="sales-to" type="date" value="${dates.to}"></label>
          <label>Sucursal
            <select id="sales-branch">
              <option value="">Todas las autorizadas</option>
              ${workspace.branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}
            </select>
          </label>
          <label>Estado
            <select id="sales-status">
              <option value="">Todos</option>
              <option>BORRADOR</option>
              <option>CONFIRMADO</option>
              <option>CERRADO</option>
              <option>REABIERTO</option>
            </select>
          </label>
        </div>
        <button id="sales-search">Aplicar filtros</button>
      </section>

      <div id="sales-summary"></div>

      <section class="card">
        <div class="card-head">
          <h3>Ventas por día y sucursal</h3>
          <span class="muted" id="sales-count"></span>
        </div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr>
              <th>Fecha</th><th>Sucursal</th><th>Estado</th><th>Unidades</th>
              <th>Ingresos</th><th>Costo</th><th>Margen</th><th></th>
            </tr></thead>
            <tbody id="sales-body"></tbody>
          </table>
        </div>
      </section>

      <section class="card hidden" id="sale-detail-card">
        <div class="card-head">
          <div>
            <h3>Detalle de venta</h3>
            <div class="muted" id="sale-detail-meta"></div>
          </div>
          <button id="sale-detail-close" class="secondary">Cerrar</button>
        </div>
        <div id="sale-detail-status"></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr>
              <th>Código</th><th>Producto</th><th>Cliente</th><th>Origen</th>
              <th>Origen</th><th>Ajuste</th><th>Final</th><th>Precio</th>
              <th>Total</th><th>Margen</th><th></th>
            </tr></thead>
            <tbody id="sale-lines-body"></tbody>
          </table>
        </div>
      </section>

      <dialog id="adjust-dialog" class="sales-dialog">
        <form method="dialog" id="adjust-form">
          <h3>Ajustar línea</h3>
          <p id="adjust-product" class="muted"></p>
          <input type="hidden" id="adjust-line-id">
          <label>Ajuste de unidades
            <input id="adjust-units" type="number" step="0.01" required>
          </label>
          <label>Motivo
            <textarea id="adjust-reason" minlength="3" required placeholder="Explique el motivo del ajuste"></textarea>
          </label>
          <div id="adjust-status"></div>
          <div class="dialog-actions">
            <button type="button" class="secondary" id="adjust-cancel">Cancelar</button>
            <button type="submit">Guardar ajuste</button>
          </div>
        </form>
      </dialog>

      <div class="debug-strip">[HEMOCURA_SALES] listo</div>`;

    const state={workspace,currentSales:workspace.sales,currentSaleId:null};

    function renderSummary(){
      const s=summary(state.currentSales);
      document.getElementById('sales-summary').innerHTML=`
        <div class="grid sales-kpis">
          <section class="card"><div class="muted">Unidades</div><div class="kpi">${num.format(s.units)}</div></section>
          <section class="card"><div class="muted">Ingresos</div><div class="kpi">${money.format(s.revenue)}</div></section>
          <section class="card"><div class="muted">Costo</div><div class="kpi">${money.format(s.cost)}</div></section>
          <section class="card"><div class="muted">Margen</div><div class="kpi">${money.format(s.margin)}</div></section>
        </div>`;
    }

    function renderSales(){
      document.getElementById('sales-body').innerHTML=salesRows(state.currentSales,state.workspace.branchMap);
      document.getElementById('sales-count').textContent=`${state.currentSales.length} registro(s)`;
      renderSummary();

      document.querySelectorAll('[data-sale-id]').forEach(btn=>{
        btn.addEventListener('click',()=>openSale(btn.dataset.saleId));
      });
    }

    async function applyFilters(){
      const filters={
        from:document.getElementById('sales-from').value,
        to:document.getElementById('sales-to').value,
        branchId:document.getElementById('sales-branch').value,
        status:document.getElementById('sales-status').value
      };
      document.getElementById('sales-body').innerHTML=`<tr><td colspan="8">Consultando…</td></tr>`;
      try{
        state.currentSales=await getDailySales(filters);
        renderSales();
        console.info('[HEMOCURA_SALES] filtros OK',filters);
      }catch(error){
        console.error('[HEMOCURA_SALES_ERROR]',error);
        document.getElementById('sales-body').innerHTML=`<tr><td colspan="8"><div class="status bad">${esc(error.message)}</div></td></tr>`;
      }
    }

    async function openSale(id){
      state.currentSaleId=id;
      const card=document.getElementById('sale-detail-card');
      card.classList.remove('hidden');
      document.getElementById('sale-lines-body').innerHTML=`<tr><td colspan="11">Cargando detalle…</td></tr>`;
      const sale=state.currentSales.find(x=>x.id===id);
      document.getElementById('sale-detail-meta').textContent=sale
        ? `${sale.sale_date} · ${state.workspace.branchMap[sale.branch_id]?.name || sale.branch_id} · ${sale.status}`
        : id;

      try{
        const lines=await getSaleLines(id);
        document.getElementById('sale-lines-body').innerHTML=lineRows(lines);
        document.getElementById('sale-detail-status').innerHTML='';
        document.querySelectorAll('[data-adjust-line]').forEach(btn=>{
          btn.addEventListener('click',()=>openAdjust(btn));
        });
      }catch(error){
        document.getElementById('sale-lines-body').innerHTML=`<tr><td colspan="11"><div class="status bad">${esc(error.message)}</div></td></tr>`;
      }
    }

    function openAdjust(btn){
      document.getElementById('adjust-line-id').value=btn.dataset.adjustLine;
      document.getElementById('adjust-product').textContent=btn.dataset.product;
      document.getElementById('adjust-units').value=btn.dataset.current || 0;
      document.getElementById('adjust-reason').value='';
      document.getElementById('adjust-status').innerHTML='';
      document.getElementById('adjust-dialog').showModal();
    }

    document.getElementById('sales-search').addEventListener('click',applyFilters);
    document.getElementById('sales-refresh').addEventListener('click',applyFilters);
    document.getElementById('sale-detail-close').addEventListener('click',()=>{
      document.getElementById('sale-detail-card').classList.add('hidden');
    });
    document.getElementById('adjust-cancel').addEventListener('click',()=>{
      document.getElementById('adjust-dialog').close();
    });

    document.getElementById('adjust-form').addEventListener('submit',async event=>{
      event.preventDefault();
      const lineId=document.getElementById('adjust-line-id').value;
      const units=document.getElementById('adjust-units').value;
      const reason=document.getElementById('adjust-reason').value;
      const status=document.getElementById('adjust-status');
      status.innerHTML=`<div class="status info">Guardando ajuste…</div>`;
      try{
        await adjustSaleLine(lineId,units,reason);
        status.innerHTML=`<div class="status ok">Ajuste guardado.</div>`;
        await openSale(state.currentSaleId);
        await applyFilters();
        setTimeout(()=>document.getElementById('adjust-dialog').close(),400);
      }catch(error){
        status.innerHTML=`<div class="status bad">${esc(error.message)}</div>`;
      }
    });

    renderSales();
    console.info('[HEMOCURA_SALES] módulo OK');
  } catch(error) {
    console.error('[HEMOCURA_SALES_ERROR]',error);
    root.innerHTML=`
      <section class="card">
        <h3>Ventas no disponible</h3>
        <div class="status bad">${esc(error.message)}</div>
        <p>Abra F12 → Console y busque <code>HEMOCURA_SALES_ERROR</code>.</p>
      </section>`;
  }
}
