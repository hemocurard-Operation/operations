import { getBranches } from './sales-data.js';
import { listRequisitions, createRequisition } from './integrated-qms-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);
const LS_BRANCH='hc:capture:last-branch';
const LS_DEPT='hc:capture:last-department';

function lineTemplate(i){return `<tr data-line-row><td><input data-field="item" placeholder="Artículo o insumo" required></td><td><input data-field="category" placeholder="Categoría"></td><td><input data-field="unit" placeholder="unidad, caja, kit"></td><td><input data-field="qty" type="number" min="0.01" step="0.01" required></td><td><button type="button" class="secondary compact" data-remove-line title="Eliminar línea">×</button></td></tr>`}

export async function mountRequisitions(root){
  const branches=await getBranches();
  root.innerHTML=`
    <div class="sales-toolbar">
      <div><h2 class="section-heading">Requisiciones de Insumos</h2><div class="muted">Solicitud → autorización → entrega → recepción. Una requisición puede contener varios insumos sin repetir el encabezado.</div></div>
      <button id="req-new">Nueva requisición</button>
    </div>
    <div id="req-status"></div>
    <section class="card"><div class="table-wrap"><table class="data-table">
      <thead><tr><th>Fecha</th><th>Código</th><th>Sucursal</th><th>Área</th><th>Prioridad</th><th>Estado</th></tr></thead>
      <tbody id="req-body"></tbody></table></div></section>
    <dialog id="req-dialog" class="sales-dialog">
      <form id="req-form">
        <h3>Requisición rápida</h3>
        <div class="status info">Registre el encabezado una sola vez y agregue todas las líneas necesarias. Se elimina el patrón de 1.º…10.º ítem del formulario ancho.</div>
        <div class="quick-form-grid">
          <label>Código<input id="req-code" required placeholder="REQ-2026-001" autocomplete="off"></label>
          <label>Fecha<input id="req-date" type="date" value="${today()}" required></label>
          <label>Sucursal<select id="req-branch" required><option value="">Seleccionar…</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
          <label>Área<input id="req-dept" list="req-depts" placeholder="Laboratorio, Colecta, Banco de sangre" autocomplete="off"><datalist id="req-depts"><option value="Laboratorio"><option value="Colecta"><option value="Banco de sangre"><option value="Administración"><option value="Calidad"></datalist></label>
          <label>Prioridad<select id="req-priority"><option>NORMAL</option><option>URGENTE</option></select></label>
          <label class="full">Justificación<textarea id="req-just"></textarea></label>
        </div>
        <div class="card-head" style="margin-top:14px"><div><h4>Insumos solicitados</h4><div class="muted">Añada solo las líneas que necesita.</div></div><button type="button" id="req-add-line" class="secondary compact">+ Agregar insumo</button></div>
        <div class="table-wrap"><table class="data-table"><thead><tr><th>Artículo</th><th>Categoría</th><th>Unidad</th><th>Cantidad</th><th></th></tr></thead><tbody id="req-lines"></tbody></table></div>
        <div class="dialog-actions"><button type="button" id="req-cancel" class="secondary">Cancelar</button><button type="submit">Guardar requisición</button></div>
      </form>
    </dialog>`;

  const branchMap=Object.fromEntries(branches.map(b=>[b.id,b.name]));
  function addLine(){const body=document.getElementById('req-lines');body.insertAdjacentHTML('beforeend',lineTemplate(body.children.length));bindRemove()}
  function bindRemove(){document.querySelectorAll('[data-remove-line]').forEach(btn=>btn.onclick=()=>{const rows=document.querySelectorAll('[data-line-row]');if(rows.length>1)btn.closest('tr').remove();else{btn.closest('tr').querySelectorAll('input').forEach(x=>x.value='')}})}
  function applyDefaults(){document.getElementById('req-date').value=today();const branch=localStorage.getItem(LS_BRANCH)||'';if(branch&&branches.some(b=>b.id===branch))document.getElementById('req-branch').value=branch;const dept=localStorage.getItem(LS_DEPT)||'';if(dept)document.getElementById('req-dept').value=dept}
  function resetForm(){document.getElementById('req-form').reset();document.getElementById('req-lines').innerHTML='';addLine();applyDefaults()}
  function collectLines(){return [...document.querySelectorAll('[data-line-row]')].map(row=>({
    item_name:row.querySelector('[data-field="item"]').value.trim(),
    category:row.querySelector('[data-field="category"]').value.trim()||null,
    unit:row.querySelector('[data-field="unit"]').value.trim()||null,
    requested_qty:Number(row.querySelector('[data-field="qty"]').value)
  })).filter(x=>x.item_name)}
  async function load(){
    try{
      const rows=await listRequisitions();
      document.getElementById('req-body').innerHTML=rows.length?rows.map(r=>`<tr>
        <td>${esc(r.request_date)}</td><td><code>${esc(r.requisition_code)}</code></td>
        <td>${esc(branchMap[r.requesting_branch_id]||r.requesting_branch_id)}</td><td>${esc(r.department||'—')}</td>
        <td>${esc(r.priority)}</td><td>${esc(r.status)}</td></tr>`).join(''):
        `<tr><td colspan="6" class="muted">No hay requisiciones registradas.</td></tr>`;
      document.getElementById('req-status').innerHTML='';
    }catch(e){
      document.getElementById('req-status').innerHTML=`<div class="status warn">${esc(e.message)} · Ejecute sql/22_OPERATIONS_QMS_COMPLIANCE_v0_22.sql si aún no está instalado.</div>`;
    }
  }

  document.getElementById('req-add-line').onclick=addLine;
  document.getElementById('req-new').onclick=()=>{resetForm();document.getElementById('req-dialog').showModal()};
  document.getElementById('req-cancel').onclick=()=>document.getElementById('req-dialog').close();
  document.getElementById('req-form').onsubmit=async(ev)=>{
    ev.preventDefault();
    try{
      const lines=collectLines();
      if(!lines.length) throw new Error('Agregue al menos un insumo.');
      if(lines.some(x=>!Number.isFinite(x.requested_qty)||x.requested_qty<=0)) throw new Error('Revise las cantidades solicitadas.');
      const branch=document.getElementById('req-branch').value;
      const dept=document.getElementById('req-dept').value.trim();
      localStorage.setItem(LS_BRANCH,branch);if(dept)localStorage.setItem(LS_DEPT,dept);
      await createRequisition({
        requisition_code:document.getElementById('req-code').value.trim(),
        request_date:document.getElementById('req-date').value,
        requesting_branch_id:branch,
        department:dept||null,
        priority:document.getElementById('req-priority').value,
        justification:document.getElementById('req-just').value.trim()||null,
        status:'PENDIENTE'
      },lines);
      document.getElementById('req-dialog').close(); resetForm(); await load();
      document.getElementById('req-status').innerHTML=`<div class="status ok">Requisición guardada con ${lines.length} línea(s).</div>`;
    }catch(e){document.getElementById('req-status').innerHTML=`<div class="status bad">${esc(e.message)}</div>`}
  };
  resetForm(); await load();
}
