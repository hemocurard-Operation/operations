import { getBranches } from './sales-data.js';
import { listRequisitions, createRequisition } from './integrated-qms-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);
const reqCode=()=>`REQ-${new Date().toISOString().replace(/[-:TZ.]/g,'').slice(0,14)}`;

export async function mountRequisitions(root){
  const branches=await getBranches();
  root.innerHTML=`
    <div class="sales-toolbar"><div><h2 class="section-heading">Requisiciones de Insumos</h2><div class="muted">Solicitud rápida: qué necesita, cuánto y desde dónde.</div></div><button id="req-new">Nueva requisición</button></div>
    <div id="req-status"></div>
    <section class="card"><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Código</th><th>Sucursal</th><th>Área</th><th>Prioridad</th><th>Estado</th></tr></thead><tbody id="req-body"></tbody></table></div></section>
    <dialog id="req-dialog" class="sales-dialog"><form id="req-form"><h3>Nueva requisición</h3><p class="muted">Completa primero los cuatro datos esenciales. El resto es opcional.</p><div id="req-form-status" role="status" aria-live="polite"></div>
      <label>Insumo<input id="req-item" required autofocus placeholder="Ej. Kit de tamizaje"></label><label>Cantidad<input id="req-qty" type="number" min="0.01" step="0.01" required></label><label>Sucursal solicitante<select id="req-branch" required><option value="">Seleccionar…</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label><label>Prioridad<select id="req-priority"><option>NORMAL</option><option>URGENTE</option></select></label>
      <details class="advanced-fields"><summary>Detalles opcionales</summary><label>Área<input id="req-dept" placeholder="Laboratorio, Colecta..."></label><label>Justificación<textarea id="req-just"></textarea></label><label>Categoría<input id="req-cat"></label><label>Unidad<input id="req-unit" placeholder="unidad, caja, kit"></label><label>Código<input id="req-code"></label><label>Fecha<input id="req-date" type="date"></label></details>
      <div class="dialog-actions"><button type="button" id="req-cancel" class="secondary">Cancelar</button><button type="submit">Enviar solicitud</button></div>
    </form></dialog>`;

  const branchMap=Object.fromEntries(branches.map(b=>[b.id,b.name]));
  async function load(){try{const rows=await listRequisitions();document.getElementById('req-body').innerHTML=rows.length?rows.map(r=>`<tr><td>${esc(r.request_date)}</td><td><code>${esc(r.requisition_code)}</code></td><td>${esc(branchMap[r.requesting_branch_id]||r.requesting_branch_id)}</td><td>${esc(r.department||'—')}</td><td>${esc(r.priority)}</td><td>${esc(r.status)}</td></tr>`).join(''):`<tr><td colspan="6" class="muted">No hay requisiciones registradas.</td></tr>`;document.getElementById('req-status').innerHTML=''}catch(e){document.getElementById('req-status').innerHTML=`<div class="status warn">${esc(e.message)} · Ejecute sql/22_OPERATIONS_QMS_COMPLIANCE_v0_22.sql si aún no está instalado.</div>`}}
  function openForm(){const f=document.getElementById('req-form');f.reset();document.getElementById('req-code').value=reqCode();document.getElementById('req-date').value=today();if(branches.length===1)document.getElementById('req-branch').value=branches[0].id;document.getElementById('req-form-status').textContent='';document.getElementById('req-dialog').showModal()}
  document.getElementById('req-new').onclick=openForm;document.getElementById('req-cancel').onclick=()=>document.getElementById('req-dialog').close();
  document.getElementById('req-form').onsubmit=async(ev)=>{ev.preventDefault();const button=ev.submitter;if(button.disabled)return;button.disabled=true;button.textContent='Guardando…';const status=document.getElementById('req-form-status');status.textContent='Guardando solicitud. No cierre esta ventana.';try{await createRequisition({requisition_code:document.getElementById('req-code').value.trim()||reqCode(),request_date:document.getElementById('req-date').value||today(),requesting_branch_id:document.getElementById('req-branch').value,department:document.getElementById('req-dept').value.trim()||null,priority:document.getElementById('req-priority').value,justification:document.getElementById('req-just').value.trim()||null,status:'PENDIENTE'},[{item_name:document.getElementById('req-item').value.trim(),category:document.getElementById('req-cat').value.trim()||null,unit:document.getElementById('req-unit').value.trim()||null,requested_qty:Number(document.getElementById('req-qty').value)}]);document.getElementById('req-dialog').close();document.getElementById('req-status').innerHTML='<div class="status ok">Requisición enviada.</div>';await load()}catch(e){status.innerHTML=`<div class="status bad">${esc(e.message)}. Los datos permanecen en el formulario. Si fallaron las líneas, revise la solicitud creada antes de volver a enviarla.</div>`}finally{button.disabled=false;button.textContent='Enviar solicitud'}};
  await load();
}
