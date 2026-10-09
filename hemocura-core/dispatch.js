import {
  loadDispatchWorkspace,
  getDispatchLines,
  getProductsForDispatch,
  createDispatch
} from './dispatch-data.js';
import { getBranches } from './sales-data.js';

const num = new Intl.NumberFormat('es-DO', {maximumFractionDigits:2});
const LS_BRANCH='hc:capture:last-branch';
const LS_SHIFT='hc:capture:last-shift';

function esc(value=''){
  return String(value ?? '').replace(/[&<>"']/g,c=>({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}
function todayISO(){return new Date().toISOString().slice(0,10)}
function defaultDates(){const today=new Date();const to=today.toISOString().slice(0,10);const d=new Date(today);d.setDate(d.getDate()-30);return {from:d.toISOString().slice(0,10),to}}
function statusClass(s=''){const x=String(s).toUpperCase();if(x==='CONFIRMADO')return 'sale-confirmed';if(x==='CERRADO')return 'sale-closed';if(x==='CANCELADO')return 'sev-critical';return 'sale-draft'}
function dispatchRows(rows, branchMap){if(!rows.length)return `<tr><td colspan="8" class="muted">No hay despachos para los filtros seleccionados.</td></tr>`;return rows.map(r=>`<tr><td>${esc(r.dispatch_date)}</td><td>${esc(branchMap[r.branch_id]?.name || r.branch_id)}</td><td><span class="sale-status ${statusClass(r.status)}">${esc(r.status)}</span></td><td>${esc(r.dispatch_type || 'venta')}</td><td>${esc(r.shift || '—')}</td><td>${esc(r.customer_id || '—')}</td><td>${esc(r.notes || '')}</td><td><button class="secondary compact" data-dispatch-id="${esc(r.id)}">Ver detalle</button></td></tr>`).join('')}
function lineRows(rows, productMap){if(!rows.length)return `<tr><td colspan="5" class="muted">No hay líneas visibles.</td></tr>`;return rows.map(r=>`<tr><td>${esc(productMap[r.product_id]?.name || r.product_id)}</td><td class="num">${num.format(Number(r.units||0))}</td><td>${r.is_sale ? '<span class="stock-pill stock-ok">Venta</span>' : '<span class="stock-pill stock-warning">No venta</span>'}</td><td>${r.sale_generated ? '<span class="stock-pill stock-ok">Sí</span>' : '<span class="stock-pill stock-none">No</span>'}</td><td>${esc(r.created_at ? new Date(r.created_at).toLocaleString('es-DO') : '')}</td></tr>`).join('')}
function reconRows(rows, branchMap, productMap){if(!rows.length)return `<tr><td colspan="7" class="muted">No hay datos de conciliación visibles.</td></tr>`;return rows.map(r=>`<tr><td>${esc(r.dispatch_date || '')}</td><td>${esc(branchMap[r.branch_id]?.name || r.branch_id || '')}</td><td>${esc(productMap[r.product_id]?.name || productMap[r.product_id]?.code || r.product_id || '')}</td><td class="num">${num.format(Number(r.dispatched_sale_units||0))}</td><td class="num">${num.format(Number(r.recognized_sale_units||0))}</td><td class="num">${num.format(Number(r.difference_units||0))}</td><td>${Number(r.difference_units||0)===0 ? '<span class="status ok">OK</span>' : '<span class="status warn">Revisar</span>'}</td></tr>`).join('')}

export async function mountDispatches(root){
  if(!root) return;
  const dates=defaultDates();
  root.innerHTML=`<section class="card"><h3>Despachos</h3><div class="status info">Cargando datos…</div></section>`;

  try{
    const [branches, products] = await Promise.all([getBranches(),getProductsForDispatch()]);
    const activeProducts=products.filter(p=>p.active!==false);
    const branchMap=Object.fromEntries(branches.map(b=>[b.id,b]));
    const productMap=Object.fromEntries(products.map(p=>[p.id,p]));
    const state={branches,branchMap,products,productMap,current:null};

    root.innerHTML=`
      <div class="sales-toolbar"><div><h2 class="section-heading">Despachos operativos</h2><div class="muted">Despacho físico separado de venta reconocida. Captura por líneas, sin una columna fija por componente.</div></div><div><button id="dispatch-new">Nuevo despacho</button> <button id="dispatch-refresh" class="secondary">Actualizar</button></div></div>

      <section class="card filters-card"><div class="filter-grid"><label>Desde<input id="dispatch-from" type="date" value="${dates.from}"></label><label>Hasta<input id="dispatch-to" type="date" value="${dates.to}"></label><label>Sucursal<select id="dispatch-branch"><option value="">Todas las autorizadas</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label><label>Estado<select id="dispatch-status"><option value="">Todos</option><option>BORRADOR</option><option>CONFIRMADO</option><option>CERRADO</option><option>CANCELADO</option></select></label></div><button id="dispatch-search">Aplicar filtros</button></section>

      <div id="dispatch-errors"></div>
      <section class="card"><div class="card-head"><h3>Despachos</h3><span id="dispatch-count" class="muted"></span></div><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Sucursal</th><th>Estado</th><th>Tipo</th><th>Turno</th><th>Cliente</th><th>Notas</th><th></th></tr></thead><tbody id="dispatch-body"></tbody></table></div></section>
      <section class="card hidden" id="dispatch-detail-card"><div class="card-head"><div><h3>Detalle de despacho</h3><div class="muted" id="dispatch-detail-meta"></div></div><button class="secondary" id="dispatch-detail-close">Cerrar</button></div><div class="table-wrap"><table class="data-table"><thead><tr><th>Producto</th><th>Unidades</th><th>Tipo</th><th>Venta generada</th><th>Creado</th></tr></thead><tbody id="dispatch-lines-body"></tbody></table></div></section>
      <section class="card"><div class="card-head"><h3>Conciliación despacho vs venta</h3><span class="muted">vw_dispatch_sales_reconciliation</span></div><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Sucursal</th><th>Producto</th><th>Despachado venta</th><th>Venta reconocida</th><th>Diferencia</th><th>Estado</th></tr></thead><tbody id="recon-body"></tbody></table></div></section>

      <dialog id="dispatch-new-dialog" class="sales-dialog"><form id="dispatch-new-form"><h3>Nuevo despacho</h3><div class="status info">Registre el encabezado una sola vez y agregue los componentes despachados como líneas. No se precargan cantidades clínicas.</div><div class="quick-form-grid"><label>Fecha<input id="dispatch-new-date" type="date" value="${todayISO()}" required></label><label>Sucursal<select id="dispatch-new-branch" required><option value="">Seleccionar…</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label><label>Turno<select id="dispatch-new-shift"><option>Día</option><option>Noche</option><option>Mixto</option></select></label><label>Tipo<select id="dispatch-new-type"><option value="venta">Venta</option><option value="traslado">Traslado</option><option value="otro">Otro</option></select></label><label class="full">Notas<textarea id="dispatch-new-notes"></textarea></label></div>
      <div class="card-head" style="margin-top:14px"><div><h4>Componentes</h4><div class="muted">Una línea por producto.</div></div><button type="button" id="dispatch-add-line" class="secondary compact">+ Agregar componente</button></div><div class="table-wrap"><table class="data-table"><thead><tr><th>Producto</th><th>Unidades</th><th>Es venta</th><th></th></tr></thead><tbody id="dispatch-new-lines"></tbody></table></div><div id="dispatch-new-status"></div><div class="dialog-actions"><button type="button" id="dispatch-new-cancel" class="secondary">Cancelar</button><button type="submit">Guardar borrador</button></div></form></dialog>
      <div class="debug-strip">[HEMOCURA_DISPATCH] schema v7.2 alineado · C15-A quick form</div>`;

    const productOptions=activeProducts.map(p=>`<option value="${esc(p.id)}">${esc(p.code ? `${p.code} · ${p.name}` : p.name)}</option>`).join('');
    function addNewLine(){const body=document.getElementById('dispatch-new-lines');body.insertAdjacentHTML('beforeend',`<tr data-dispatch-new-line><td><select data-field="product" required><option value="">Seleccionar…</option>${productOptions}</select></td><td><input data-field="units" type="number" min="1" step="1" required></td><td><input data-field="sale" type="checkbox" checked></td><td><button type="button" class="secondary compact" data-remove-dispatch-line>×</button></td></tr>`);bindRemoveLines()}
    function bindRemoveLines(){document.querySelectorAll('[data-remove-dispatch-line]').forEach(btn=>btn.onclick=()=>{const rows=document.querySelectorAll('[data-dispatch-new-line]');if(rows.length>1)btn.closest('tr').remove();else{btn.closest('tr').querySelector('[data-field="product"]').value='';btn.closest('tr').querySelector('[data-field="units"]').value='';btn.closest('tr').querySelector('[data-field="sale"]').checked=true}})}
    function resetNewForm(){document.getElementById('dispatch-new-form').reset();document.getElementById('dispatch-new-lines').innerHTML='';addNewLine();document.getElementById('dispatch-new-date').value=todayISO();const branch=localStorage.getItem(LS_BRANCH)||'';if(branch&&branches.some(b=>b.id===branch))document.getElementById('dispatch-new-branch').value=branch;const shift=localStorage.getItem(LS_SHIFT)||'';if(shift)document.getElementById('dispatch-new-shift').value=shift;document.getElementById('dispatch-new-status').innerHTML=''}
    function collectNewLines(){return [...document.querySelectorAll('[data-dispatch-new-line]')].map(row=>({productId:row.querySelector('[data-field="product"]').value,units:Number(row.querySelector('[data-field="units"]').value),isSale:row.querySelector('[data-field="sale"]').checked})).filter(x=>x.productId)}

    async function load(){
      const filters={from:document.getElementById('dispatch-from').value,to:document.getElementById('dispatch-to').value,branchId:document.getElementById('dispatch-branch').value,status:document.getElementById('dispatch-status').value};
      document.getElementById('dispatch-body').innerHTML=`<tr><td colspan="8">Consultando…</td></tr>`;document.getElementById('recon-body').innerHTML=`<tr><td colspan="7">Consultando…</td></tr>`;
      const ws=await loadDispatchWorkspace(filters);state.current=ws;document.getElementById('dispatch-body').innerHTML=dispatchRows(ws.dispatches,branchMap);document.getElementById('dispatch-count').textContent=`${ws.dispatches.length} registro(s)`;document.getElementById('recon-body').innerHTML=reconRows(ws.reconciliation,branchMap,productMap);document.getElementById('dispatch-errors').innerHTML=ws.errors.length?`<div class="status warn">Carga parcial: ${esc(ws.errors.join(' · '))}</div>`:'';document.querySelectorAll('[data-dispatch-id]').forEach(btn=>btn.addEventListener('click',()=>openDetail(btn.dataset.dispatchId)));console.info('[HEMOCURA_DISPATCH] módulo OK')
    }
    async function openDetail(id){const card=document.getElementById('dispatch-detail-card');card.classList.remove('hidden');document.getElementById('dispatch-lines-body').innerHTML=`<tr><td colspan="5">Cargando detalle…</td></tr>`;const item=state.current?.dispatches?.find(x=>x.id===id);document.getElementById('dispatch-detail-meta').textContent=item?`${item.dispatch_date} · ${branchMap[item.branch_id]?.name || item.branch_id} · ${item.status}`:id;try{const lines=await getDispatchLines(id);document.getElementById('dispatch-lines-body').innerHTML=lineRows(lines,productMap)}catch(error){document.getElementById('dispatch-lines-body').innerHTML=`<tr><td colspan="5"><div class="status bad">${esc(error.message)}</div></td></tr>`}}

    document.getElementById('dispatch-search').addEventListener('click',()=>load().catch(showFatal));document.getElementById('dispatch-refresh').addEventListener('click',()=>load().catch(showFatal));document.getElementById('dispatch-detail-close').addEventListener('click',()=>document.getElementById('dispatch-detail-card').classList.add('hidden'));
    document.getElementById('dispatch-new').addEventListener('click',()=>{resetNewForm();document.getElementById('dispatch-new-dialog').showModal()});document.getElementById('dispatch-new-cancel').addEventListener('click',()=>document.getElementById('dispatch-new-dialog').close());document.getElementById('dispatch-add-line').addEventListener('click',addNewLine);
    document.getElementById('dispatch-new-form').addEventListener('submit',async e=>{e.preventDefault();const box=document.getElementById('dispatch-new-status');try{const lines=collectNewLines();if(!lines.length)throw new Error('Agregue al menos un componente.');if(lines.some(x=>!Number.isInteger(x.units)||x.units<=0))throw new Error('Las unidades deben ser enteros mayores que cero.');const branch=document.getElementById('dispatch-new-branch').value,shift=document.getElementById('dispatch-new-shift').value;localStorage.setItem(LS_BRANCH,branch);localStorage.setItem(LS_SHIFT,shift);box.innerHTML='<div class="status info">Guardando…</div>';await createDispatch({dispatchDate:document.getElementById('dispatch-new-date').value,branchId:branch,shift,dispatchType:document.getElementById('dispatch-new-type').value,notes:document.getElementById('dispatch-new-notes').value.trim(),status:'BORRADOR'},lines);box.innerHTML='<div class="status ok">Despacho guardado como borrador.</div>';await load();setTimeout(()=>document.getElementById('dispatch-new-dialog').close(),400)}catch(error){box.innerHTML=`<div class="status bad">${esc(error.message)}</div>`}});

    function showFatal(error){console.error('[HEMOCURA_DISPATCH_ERROR]',error);document.getElementById('dispatch-errors').innerHTML=`<div class="status bad">${esc(error.message)}</div>`}
    await load();
  }catch(error){console.error('[HEMOCURA_DISPATCH_ERROR]',error);root.innerHTML=`<section class="card"><h3>Despachos no disponible</h3><div class="status bad">${esc(error.message)}</div><p>Abra F12 → Console y busque <code>HEMOCURA_DISPATCH_ERROR</code>.</p></section>`}
}
