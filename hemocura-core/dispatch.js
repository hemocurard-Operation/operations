import { loadDispatchWorkspace, getDispatchLines } from './dispatch-data.js';
import { getBranches } from './sales-data.js';

const num = new Intl.NumberFormat('es-DO', {maximumFractionDigits:2});

function esc(value=''){
  return String(value ?? '').replace(/[&<>"']/g,c=>({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

function defaultDates(){
  const today=new Date();
  const to=today.toISOString().slice(0,10);
  const d=new Date(today); d.setDate(d.getDate()-30);
  return {from:d.toISOString().slice(0,10),to};
}

function statusClass(s=''){
  const x=String(s).toUpperCase();
  if(x==='CONFIRMADO') return 'sale-confirmed';
  if(x==='CERRADO') return 'sale-closed';
  if(x==='CANCELADO') return 'sev-critical';
  return 'sale-draft';
}

function dispatchRows(rows, branchMap){
  if(!rows.length) return `<tr><td colspan="7" class="muted">No hay despachos para los filtros seleccionados.</td></tr>`;
  return rows.map(r=>`
    <tr>
      <td>${esc(r.dispatch_date)}</td>
      <td>${esc(branchMap[r.branch_id]?.name || r.branch_id)}</td>
      <td><span class="sale-status ${statusClass(r.status)}">${esc(r.status)}</span></td>
      <td>${esc(r.reference || '—')}</td>
      <td>${esc(r.customer_id || '—')}</td>
      <td>${esc(r.notes || '')}</td>
      <td><button class="secondary compact" data-dispatch-id="${esc(r.id)}">Ver detalle</button></td>
    </tr>`).join('');
}

function lineRows(rows){
  if(!rows.length) return `<tr><td colspan="6" class="muted">No hay líneas visibles.</td></tr>`;
  return rows.map(r=>`
    <tr>
      <td>${esc(r.product_id)}</td>
      <td>${esc(r.customer_id || '—')}</td>
      <td class="num">${num.format(Number(r.units||0))}</td>
      <td class="num">${num.format(Number(r.unit_price||0))}</td>
      <td class="num">${num.format(Number(r.total_amount||0))}</td>
      <td>${esc(r.notes || '')}</td>
    </tr>`).join('');
}

function reconRows(rows){
  if(!rows.length) return `<tr><td colspan="7" class="muted">No hay datos de conciliación visibles.</td></tr>`;
  return rows.map(r=>`
    <tr>
      <td>${esc(r.date || r.sale_date || r.dispatch_date || '')}</td>
      <td>${esc(r.branch || r.branch_name || r.branch_id || '')}</td>
      <td>${esc(r.product_name || r.product_code || r.product_id || '')}</td>
      <td class="num">${num.format(Number(r.dispatched_units||0))}</td>
      <td class="num">${num.format(Number(r.sold_units||0))}</td>
      <td class="num">${num.format(Number(r.difference_units||0))}</td>
      <td>${Number(r.difference_units||0)===0 ? '<span class="status ok">OK</span>' : '<span class="status warn">Revisar</span>'}</td>
    </tr>`).join('');
}

export async function mountDispatches(root){
  if(!root) return;
  const dates=defaultDates();
  root.innerHTML=`<section class="card"><h3>Despachos</h3><div class="status info">Cargando datos…</div></section>`;

  try{
    const branches=await getBranches();
    const branchMap=Object.fromEntries(branches.map(b=>[b.id,b]));
    const state={branches,branchMap,current:null};

    root.innerHTML=`
      <div class="sales-toolbar">
        <div>
          <h2 class="section-heading">Despachos operativos</h2>
          <div class="muted">Separación explícita entre despacho físico y venta.</div>
        </div>
        <button id="dispatch-refresh" class="secondary">Actualizar</button>
      </div>

      <section class="card filters-card">
        <div class="filter-grid">
          <label>Desde<input id="dispatch-from" type="date" value="${dates.from}"></label>
          <label>Hasta<input id="dispatch-to" type="date" value="${dates.to}"></label>
          <label>Sucursal
            <select id="dispatch-branch">
              <option value="">Todas las autorizadas</option>
              ${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}
            </select>
          </label>
          <label>Estado
            <select id="dispatch-status">
              <option value="">Todos</option>
              <option>BORRADOR</option>
              <option>CONFIRMADO</option>
              <option>CERRADO</option>
              <option>CANCELADO</option>
            </select>
          </label>
        </div>
        <button id="dispatch-search">Aplicar filtros</button>
      </section>

      <div id="dispatch-errors"></div>

      <section class="card">
        <div class="card-head"><h3>Despachos</h3><span id="dispatch-count" class="muted"></span></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Fecha</th><th>Sucursal</th><th>Estado</th><th>Referencia</th><th>Cliente</th><th>Notas</th><th></th></tr></thead>
            <tbody id="dispatch-body"></tbody>
          </table>
        </div>
      </section>

      <section class="card hidden" id="dispatch-detail-card">
        <div class="card-head">
          <div><h3>Detalle de despacho</h3><div class="muted" id="dispatch-detail-meta"></div></div>
          <button class="secondary" id="dispatch-detail-close">Cerrar</button>
        </div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Producto</th><th>Cliente</th><th>Unidades</th><th>Precio</th><th>Total</th><th>Notas</th></tr></thead>
            <tbody id="dispatch-lines-body"></tbody>
          </table>
        </div>
      </section>

      <section class="card">
        <div class="card-head"><h3>Conciliación despacho vs venta</h3><span class="muted">Control operativo</span></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Fecha</th><th>Sucursal</th><th>Producto</th><th>Despachado</th><th>Vendido</th><th>Diferencia</th><th>Estado</th></tr></thead>
            <tbody id="recon-body"></tbody>
          </table>
        </div>
      </section>

      <div class="debug-strip">[HEMOCURA_DISPATCH] listo</div>`;

    async function load(){
      const filters={
        from:document.getElementById('dispatch-from').value,
        to:document.getElementById('dispatch-to').value,
        branchId:document.getElementById('dispatch-branch').value,
        status:document.getElementById('dispatch-status').value
      };

      document.getElementById('dispatch-body').innerHTML=`<tr><td colspan="7">Consultando…</td></tr>`;
      document.getElementById('recon-body').innerHTML=`<tr><td colspan="7">Consultando…</td></tr>`;

      const ws=await loadDispatchWorkspace(filters);
      state.current=ws;

      document.getElementById('dispatch-body').innerHTML=dispatchRows(ws.dispatches,branchMap);
      document.getElementById('dispatch-count').textContent=`${ws.dispatches.length} registro(s)`;
      document.getElementById('recon-body').innerHTML=reconRows(ws.reconciliation);

      document.getElementById('dispatch-errors').innerHTML=ws.errors.length
        ? `<div class="status warn">Carga parcial: ${esc(ws.errors.join(' · '))}</div>`
        : '';

      document.querySelectorAll('[data-dispatch-id]').forEach(btn=>{
        btn.addEventListener('click',()=>openDetail(btn.dataset.dispatchId));
      });

      console.info('[HEMOCURA_DISPATCH] módulo OK');
    }

    async function openDetail(id){
      const card=document.getElementById('dispatch-detail-card');
      card.classList.remove('hidden');
      document.getElementById('dispatch-lines-body').innerHTML=`<tr><td colspan="6">Cargando detalle…</td></tr>`;
      const item=state.current?.dispatches?.find(x=>x.id===id);
      document.getElementById('dispatch-detail-meta').textContent=item
        ? `${item.dispatch_date} · ${branchMap[item.branch_id]?.name || item.branch_id} · ${item.status}`
        : id;

      try{
        const lines=await getDispatchLines(id);
        document.getElementById('dispatch-lines-body').innerHTML=lineRows(lines);
      }catch(error){
        document.getElementById('dispatch-lines-body').innerHTML=
          `<tr><td colspan="6"><div class="status bad">${esc(error.message)}</div></td></tr>`;
      }
    }

    document.getElementById('dispatch-search').addEventListener('click',()=>load().catch(showFatal));
    document.getElementById('dispatch-refresh').addEventListener('click',()=>load().catch(showFatal));
    document.getElementById('dispatch-detail-close').addEventListener('click',()=>{
      document.getElementById('dispatch-detail-card').classList.add('hidden');
    });

    function showFatal(error){
      console.error('[HEMOCURA_DISPATCH_ERROR]',error);
      document.getElementById('dispatch-errors').innerHTML=`<div class="status bad">${esc(error.message)}</div>`;
    }

    await load();
  }catch(error){
    console.error('[HEMOCURA_DISPATCH_ERROR]',error);
    root.innerHTML=`<section class="card"><h3>Despachos no disponible</h3><div class="status bad">${esc(error.message)}</div><p>Abra F12 → Console y busque <code>HEMOCURA_DISPATCH_ERROR</code>.</p></section>`;
  }
}
