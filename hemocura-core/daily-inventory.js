import { commandData } from './command-data.js';
import { resourcesData } from './resources-data.js';
import { loadAccess } from './access-control.js';

const GROUPS=['A+','A-','B+','B-','O+','O-','AB+','AB-'];
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const today=()=>new Date().toISOString().slice(0,10);
const n=v=>Math.max(0,Number(v||0));
const key=g=>g.replace('+','p').replace('-','n');

function lotRow(x={},i=0){return `<tr data-lot-row><td><input data-f="lot" value="${esc(x.lot||'')}" placeholder="Tanda / lote"></td><td><input data-f="received" type="number" min="0" inputmode="numeric" value="${n(x.received)}"></td><td><input data-f="non_reactive" type="number" min="0" inputmode="numeric" value="${n(x.non_reactive)}"></td><td><input data-f="reactive" type="number" min="0" inputmode="numeric" value="${n(x.reactive)}"></td><td><input data-f="pending" type="number" min="0" inputmode="numeric" value="${n(x.pending)}"></td><td><input data-f="discarded" type="number" min="0" inputmode="numeric" value="${n(x.discarded)}"></td><td><button type="button" class="secondary compact" data-remove-row>×</button></td></tr>`}
function dispatchRow(x={},i=0){return `<tr data-dispatch-row><td><input data-f="destination" value="${esc(x.destination||'')}" placeholder="Centro / destino"></td><td><select data-f="group"><option value="">—</option>${GROUPS.map(g=>`<option ${x.group===g?'selected':''}>${g}</option>`).join('')}</select></td><td><input data-f="component" value="${esc(x.component||'')}" placeholder="Componente"></td><td><input data-f="quantity" type="number" min="0" inputmode="numeric" value="${n(x.quantity)}"></td><td><input data-f="note" value="${esc(x.note||'')}" placeholder="Opcional"></td><td><button type="button" class="secondary compact" data-remove-row>×</button></td></tr>`}
function inventoryRows(data={}){return GROUPS.map(g=>{const x=data[g]||{},k=key(g);return `<tr><th>${g}</th><td><input id="inv-${k}-whole" type="number" min="0" inputmode="numeric" value="${n(x.whole_blood)}"></td><td><input id="inv-${k}-packed" type="number" min="0" inputmode="numeric" value="${n(x.packed_cells)}"></td><td><input id="inv-${k}-plasma" type="number" min="0" inputmode="numeric" value="${n(x.plasma)}"></td><td><input id="inv-${k}-platelets" type="number" min="0" inputmode="numeric" value="${n(x.platelets)}"></td></tr>`}).join('')}

export async function mountDailyInventory(root){
  root.innerHTML='<section class="card"><div class="status info">Preparando reporte operativo diario…</div></section>';
  const [branches,access]=await Promise.all([commandData.branches(),loadAccess()]);
  const preferred=access?.context?.branch_id||access?.context?.current_branch_id||'';
  root.innerHTML=`
    <div class="sales-toolbar"><div><h2 class="section-heading">Reporte operativo diario</h2><div class="muted">Digitaliza la estructura actual: tamizaje por lotes, inventario manual consolidado y despachos consolidados. Sin captura individual.</div></div><button id="dor-refresh" class="secondary">Cargar</button></div>
    <div id="dor-msg"></div>

    <section class="card quick-capture"><div class="quick-capture-head"><div><div class="eyebrow">Datos del reporte</div><h3>Identificación</h3></div><span id="dor-status" class="state-pill state-info">BORRADOR</span></div><div class="filter-grid">
      <label>Fecha<input id="dor-date" type="date" value="${today()}"></label>
      <label>Sucursal<select id="dor-branch"><option value="">Seleccionar…</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
      <label>Responsable / Bioanalista<input id="dor-responsible" placeholder="Nombre"></label>
    </div><p class="muted">Este reporte consolida el trabajo del día. Los módulos de Tamizaje, Inventario y Despachos quedan en modo consulta y no requieren registros unitarios.</p></section>

    <section class="card"><div class="card-head"><div><h3>1. Lotes diarios de tamizaje</h3><div class="muted">Una fila por tanda/lote. No capture resultados por unidad.</div></div><button id="dor-add-lot" type="button" class="secondary">+ Agregar lote</button></div><div class="table-wrap"><table class="data-table capture-table"><thead><tr><th>Lote / tanda</th><th>Recibidos</th><th>No reactivos</th><th>Reactivos</th><th>Pendientes</th><th>Descartados</th><th></th></tr></thead><tbody id="dor-lots"></tbody></table></div></section>

    <section class="card"><div class="card-head"><div><h3>2. Inventario disponible</h3><div class="muted">Conteo físico manual al momento del reporte.</div></div></div><div class="table-wrap"><table class="data-table capture-table"><thead><tr><th>Grupo</th><th>Sangre total</th><th>Paquete globular</th><th>Plasma</th><th>Plaquetas</th></tr></thead><tbody id="dor-inventory"></tbody></table></div></section>

    <section class="card"><div class="card-head"><div><h3>3. Despachos del día</h3><div class="muted">Capture el despacho consolidado por destino/componente, no por unidad individual.</div></div><button id="dor-add-dispatch" type="button" class="secondary">+ Agregar despacho</button></div><div class="table-wrap"><table class="data-table capture-table"><thead><tr><th>Destino</th><th>Grupo</th><th>Componente</th><th>Cantidad</th><th>Observación</th><th></th></tr></thead><tbody id="dor-dispatches"></tbody></table></div></section>

    <section class="card"><div class="card-head"><div><h3>4. Equipos con novedad</h3><div class="muted">Solo se muestran equipos con estado distinto de ACTIVO o con alerta.</div></div><a class="secondary" href="#resources">Gestionar equipos</a></div><div class="table-wrap"><table class="data-table"><thead><tr><th>Equipo</th><th>Tipo</th><th>Estado</th><th>Ubicación</th><th>Alerta</th></tr></thead><tbody id="dor-equipment"></tbody></table></div></section>

    <section class="card"><label><strong>Observaciones generales</strong><textarea id="dor-notes" rows="4" placeholder="Novedades, aclaraciones o incidencias del día"></textarea></label><div class="dialog-actions"><button id="dor-save" class="secondary">Guardar borrador</button><button id="dor-close">Cerrar reporte</button></div><p class="muted">Cerrar el reporte confirma la captura operacional diaria. No libera unidades ni sustituye decisiones clínicas.</p></section>

    <details class="card"><summary><strong>Reportes recientes</strong></summary><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Estado</th><th>Responsable</th><th>Lotes</th><th>Despachos</th><th>Actualizado</th></tr></thead><tbody id="dor-history"></tbody></table></div></details>`;

  if(preferred&&branches.some(b=>b.id===preferred))document.getElementById('dor-branch').value=preferred;else if(branches.length===1)document.getElementById('dor-branch').value=branches[0].id;

  const q=id=>document.getElementById(id);
  function bindRemove(){root.querySelectorAll('[data-remove-row]').forEach(b=>b.onclick=()=>b.closest('tr').remove())}
  function render(data=null){
    const d=data||{};q('dor-responsible').value=d.responsible_name||'';q('dor-status').textContent=d.status||'BORRADOR';q('dor-status').className=`state-pill ${d.status==='CERRADO'?'state-ok':'state-info'}`;
    const lots=Array.isArray(d.screening_lots)?d.screening_lots:[];q('dor-lots').innerHTML=(lots.length?lots:[{}]).map(lotRow).join('');
    q('dor-inventory').innerHTML=inventoryRows(d.manual_inventory||{});
    const disp=Array.isArray(d.manual_dispatches)?d.manual_dispatches:[];q('dor-dispatches').innerHTML=(disp.length?disp:[{}]).map(dispatchRow).join('');
    q('dor-notes').value=d.notes||'';bindRemove();
  }
  function rows(selector){return [...root.querySelectorAll(selector)].map(tr=>{const o={};tr.querySelectorAll('[data-f]').forEach(el=>o[el.dataset.f]=el.type==='number'?n(el.value):el.value.trim());return o}).filter(o=>Object.values(o).some(v=>v!==''&&v!==0)}
  function inventoryPayload(){const out={};for(const g of GROUPS){const k=key(g);out[g]={whole_blood:n(q(`inv-${k}-whole`).value),packed_cells:n(q(`inv-${k}-packed`).value),plasma:n(q(`inv-${k}-plasma`).value),platelets:n(q(`inv-${k}-platelets`).value)}}return out}
  async function equipmentSnapshot(){try{const [eq,alerts]=await Promise.all([resourcesData.equipment(),resourcesData.equipmentAlerts()]);const branchId=q('dor-branch').value,alertMap=Object.fromEntries(alerts.filter(a=>a.branch_id===branchId).map(a=>[a.equipment_id,a]));return eq.filter(x=>x.branch_id===branchId&&(x.status!=='ACTIVO'||alertMap[x.id])).map(x=>({equipment_code:x.equipment_code,equipment_type:x.equipment_type,status:x.status,location:x.location||null,alert:alertMap[x.id]?.message||null}))}catch{return []}}
  async function showEquipment(){const list=await equipmentSnapshot();q('dor-equipment').innerHTML=list.length?list.map(x=>`<tr><td><code>${esc(x.equipment_code)}</code></td><td>${esc(x.equipment_type)}</td><td>${esc(x.status)}</td><td>${esc(x.location||'—')}</td><td>${esc(x.alert||'—')}</td></tr>`).join(''):'<tr><td colspan="5"><span class="status ok">Sin novedades de equipos.</span></td></tr>';return list}
  async function history(){try{const branchId=q('dor-branch').value,all=await commandData.recentCloses(30),list=all.filter(x=>!branchId||x.branch_id===branchId);q('dor-history').innerHTML=list.length?list.map(x=>`<tr><td>${esc(x.close_date)}</td><td>${esc(x.status)}</td><td>${esc(x.responsible_name||'—')}</td><td>${Array.isArray(x.screening_lots)?x.screening_lots.length:0}</td><td>${Array.isArray(x.manual_dispatches)?x.manual_dispatches.length:0}</td><td>${esc(x.updated_at?new Date(x.updated_at).toLocaleString('es-DO'):'—')}</td></tr>`).join(''):'<tr><td colspan="6">Sin reportes recientes.</td></tr>'}catch(e){q('dor-msg').innerHTML=`<div class="status warn">${esc(e.message)} · Ejecute sql/40_DAILY_OPERATIONAL_REPORT_v0_40.sql.</div>`}}
  async function load(){const branchId=q('dor-branch').value;if(!branchId){q('dor-msg').innerHTML='<div class="status warn">Seleccione una sucursal.</div>';return}q('dor-msg').innerHTML='<div class="status info">Cargando reporte…</div>';try{const d=await commandData.dailyReport(q('dor-date').value,branchId);render(d);await showEquipment();await history();q('dor-msg').innerHTML=d?'<div class="status ok">Reporte existente cargado.</div>':'<div class="status info">No existe reporte para esta fecha. Inicie la captura.</div>';q('dor-close').disabled=d?.status==='CERRADO'}catch(e){q('dor-msg').innerHTML=`<div class="status bad">${esc(e.message)} · Ejecute sql/40_DAILY_OPERATIONAL_REPORT_v0_40.sql.</div>`}}
  async function save(status){const branchId=q('dor-branch').value;if(!branchId){q('dor-msg').innerHTML='<div class="status warn">Seleccione una sucursal.</div>';return}const button=status==='CERRADO'?q('dor-close'):q('dor-save'),old=button.textContent;button.disabled=true;button.textContent='Guardando…';try{const equipment=await equipmentSnapshot();await commandData.saveDailyReport({close_date:q('dor-date').value,branch_id:branchId,responsible_name:q('dor-responsible').value.trim(),screening_lots:rows('[data-lot-row]'),manual_inventory:inventoryPayload(),manual_dispatches:rows('[data-dispatch-row]'),equipment_snapshot:equipment,notes:q('dor-notes').value.trim()||null,status});q('dor-msg').innerHTML=`<div class="status ok">Reporte ${status==='CERRADO'?'cerrado':'guardado'}.</div>`;await load()}catch(e){q('dor-msg').innerHTML=`<div class="status bad">${esc(e.message)}</div>`}finally{button.disabled=false;button.textContent=old}}

  q('dor-add-lot').onclick=()=>{q('dor-lots').insertAdjacentHTML('beforeend',lotRow());bindRemove()};
  q('dor-add-dispatch').onclick=()=>{q('dor-dispatches').insertAdjacentHTML('beforeend',dispatchRow());bindRemove()};
  q('dor-refresh').onclick=load;q('dor-branch').onchange=load;q('dor-date').onchange=load;q('dor-save').onclick=()=>save('BORRADOR');q('dor-close').onclick=()=>save('CERRADO');
  render();await showEquipment();await history();if(q('dor-branch').value)await load();
}
