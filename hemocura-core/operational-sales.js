import {bloodData} from './blood-operations-data.js';
import {workflowData} from './workflow-data.js';
import {loadAccess} from './access-control.js';
import {localDay} from './workflow-domain.js';
import {eligibleOutputUnits,outputPayload,outputSummary} from './inventory-output-domain.js';
const esc=(v='')=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
export async function mountOperationalSales(root){
 const [branches,customers,access]=await Promise.all([bloodData.branches(),workflowData.customers(),loadAccess()]);
 const canWrite=access.permissions.has('SALES_WRITE')&&access.permissions.has('DISPATCH_WRITE');
 const bm=Object.fromEntries(branches.map(b=>[b.id,b.name]));
 let rows=[],lines=[],units=[],busy=false,loading=false;
 root.innerHTML=`<div class="sales-toolbar"><div><h2 class="section-heading">Salidas de inventario</h2><div class="muted">Registre la entrega de unidades liberadas y conserve su trazabilidad por sucursal y centro.</div></div><div>${canWrite?'<button id="sale-new" disabled>Nueva salida</button> ':''}<button id="sale-refresh" class="secondary">Actualizar</button></div></div>
 <div id="sale-msg" role="status" aria-live="polite"></div>
 <form id="sale-filters" class="card filter-grid"><label>Sucursal<select id="sale-filter-branch"><option value="">Todas las autorizadas</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label><label>Buscar código o centro<input id="sale-search" type="search" placeholder="Código de salida, unidad o centro"></label></form>
 <div class="grid sales-kpis" id="sale-kpis"></div>
 <section class="card"><h3>Entregas registradas</h3><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha / turno</th><th>Código</th><th>Centro de destino</th><th>Sucursal</th><th>Unidades</th><th>Estado de salida</th><th>Detalle</th></tr></thead><tbody id="sale-body"></tbody></table></div></section>
 <section class="card"><h3>Continuar operación</h3><p><a href="#bloodinventory">Consultar inventario de sangre</a> · <a href="#requisitions">Requisiciones</a> · <a href="#transfers">Traslados entre sucursales</a> · <a href="#supply">Plan de abastecimiento</a></p></section>
 <dialog id="sale-dialog" class="sales-dialog" aria-labelledby="sale-dialog-title"><form id="sale-form"><h3 id="sale-dialog-title">Registrar salida de inventario</h3><p class="muted">Se entrega la unidad seleccionada completa. Compruebe destino y referencia antes de confirmar.</p>
 <label>Código de salida<input id="sale-code" required maxlength="100" placeholder="SAL-2026-001"></label><label>Fecha<input id="sale-date" type="date" value="${localDay()}" required></label>
 <label>Sucursal<select id="sale-branch" required><option value="">Seleccionar…</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
 <label>Centro de destino<select id="sale-customer" required><option value="">Seleccionar…</option>${customers.map(c=>`<option value="${esc(c.id)}">${esc(c.name)}</option>`).join('')}</select></label><label>Médico tratante<input id="sale-doctor" required></label><label>Turno<select id="sale-shift"><option>DIURNO</option><option>NOCTURNO</option></select></label><label>N.º solicitud<input id="sale-request"></label><label>Paciente / Código<input id="sale-patient"></label>
 <label>Unidad liberada<select id="sale-unit" required><option value="">Seleccione primero la sucursal</option></select></label><p id="sale-unit-info" class="muted" role="status"></p>
 <label>Observaciones de entrega<textarea id="sale-notes"></textarea></label><div id="sale-error" role="alert"></div><div class="dialog-actions"><button type="button" id="sale-cancel" class="secondary">Cancelar</button><button id="sale-submit">Confirmar entrega</button></div></form></dialog>`;
 const el=id=>root.querySelector('#'+id),dialog=el('sale-dialog'),form=el('sale-form');
 function message(text,bad=false){el('sale-msg').innerHTML=`<div class="status ${bad?'bad':'ok'}">${esc(text)}</div>`}
 function render(){
  const branch=el('sale-filter-branch').value,search=el('sale-search').value.trim().toLocaleLowerCase('es');
  const shown=rows.filter(r=>(!branch||r.branch_id===branch)&&`${r.sale_code} ${r.customer_name||r.destination_center||''} ${lines.filter(l=>l.sale_id===r.id).map(l=>l.blood_inventory_units?.unit_code||'').join(' ')}`.toLocaleLowerCase('es').includes(search));
  const s=outputSummary(shown,lines),available=eligibleOutputUnits(units,branch).length;
  el('sale-kpis').innerHTML=[['Entregas registradas',s.records],['Unidades entregadas',s.units],['Centros atendidos',s.centers],['Unidades vigentes disponibles',available]].map(([label,value])=>`<section class="card"><div class="muted">${label}</div><div class="kpi">${esc(value)}</div></section>`).join('')+'<p class="muted">Entregas y centros: registros activos del filtro. Disponibilidad: inventario actual de la sucursal; la búsqueda no modifica ese indicador.</p>';
  el('sale-body').innerHTML=shown.length?shown.map(r=>{const detail=lines.filter(l=>l.sale_id===r.id);return `<tr><td>${esc(r.sale_date)}<br>${esc(r.shift||'Sin turno')}</td><td><code>${esc(r.sale_code)}</code></td><td>${esc(r.customer_name||r.destination_center||'—')}</td><td>${esc(bm[r.branch_id]||'—')}</td><td>${esc(detail.reduce((s,l)=>s+Number(l.quantity||0),0))}</td><td>${r.status==='CANCELADA'?'Cancelada':'Entregada'}</td><td>${detail.map(l=>`${esc(l.blood_inventory_units?.unit_code||'Unidad histórica')} · ${esc(l.component_name)} · ${esc(l.abo||'')} ${esc(l.rh||'')} · ${esc(l.quantity)}`).join('<br>')||'Sin detalle visible'}</td></tr>`}).join(''):'<tr><td colspan="7">Sin salidas para los filtros seleccionados.</td></tr>';
 }
 function renderUnits(){
  const branch=el('sale-branch').value;
  el('sale-unit').innerHTML='<option value="">'+(branch?'Seleccionar unidad vigente':'Seleccione primero la sucursal')+'</option>'+(branch?eligibleOutputUnits(units,branch).map(u=>`<option value="${esc(u.id)}">${esc(u.unit_code)} · ${esc(u.component_name)} · ${esc(u.abo||'')} ${esc(u.rh||'')} · vence ${esc(u.expiry_date)}</option>`).join(''):'');
  el('sale-unit-info').textContent='';
 }
 async function load(){
  if(loading)return false;loading=true;el('sale-refresh').disabled=true;if(canWrite)el('sale-new').disabled=true;
  try{const data=await Promise.all([bloodData.outputRecords(),bloodData.outputLines(),bloodData.outputUnits()]);[rows,lines,units]=data;render();return true}
  catch(error){message('No se pudo actualizar el inventario: '+error.message,true);return false}
  finally{loading=false;el('sale-refresh').disabled=false;if(canWrite)el('sale-new').disabled=false}
 }
 el('sale-filters').onsubmit=e=>e.preventDefault();el('sale-filter-branch').onchange=render;el('sale-search').oninput=render;
 el('sale-refresh').onclick=load;
 if(canWrite)el('sale-new').onclick=async()=>{if(!await load())return;form.reset();el('sale-date').value=localDay();el('sale-code').value='SAL-'+crypto.randomUUID();el('sale-branch').value=el('sale-filter-branch').value;el('sale-error').textContent='';renderUnits();dialog.showModal()};
 el('sale-branch').onchange=renderUnits;
 el('sale-unit').onchange=()=>{const u=units.find(u=>u.id===el('sale-unit').value);el('sale-unit-info').textContent=u?`Cantidad completa: ${u.quantity} · Vencimiento: ${u.expiry_date}`:''};
 el('sale-cancel').onclick=()=>{if(!busy)dialog.close()};dialog.addEventListener('cancel',e=>{if(busy)e.preventDefault()});
 form.onsubmit=async event=>{
  event.preventDefault();if(busy||!canWrite)return;
  busy=true;el('sale-submit').disabled=true;el('sale-cancel').disabled=true;el('sale-error').textContent='';
  try{const v=id=>el(id).value;const payload=outputPayload({sale_code:v('sale-code'),sale_date:v('sale-date'),branch_id:v('sale-branch'),customer_id:v('sale-customer'),shift:v('sale-shift'),treating_doctor:v('sale-doctor'),request_number:v('sale-request'),patient_code:v('sale-patient'),notes:v('sale-notes')},units.find(u=>u.id===v('sale-unit')));await bloodData.createSale(payload.header,payload.lines);dialog.close();message('Entrega registrada. La unidad salió del inventario disponible.');await load()}
  catch(error){el('sale-error').textContent=error.message+' Si hubo un problema de conexión, actualice y busque el código antes de reintentar.'}
  finally{busy=false;el('sale-submit').disabled=false;el('sale-cancel').disabled=false}
 };
 await load();
}
