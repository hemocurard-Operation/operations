import { bloodData } from './blood-operations-data.js';
import { getProductsForDispatch, createDispatchDraft } from './dispatch-data.js';
import { createRequisition } from './integrated-qms-data.js';
import { createIncident } from './quality-data.js';

const LEGACY_FORMS=[
  'https://forms.gle/mxXX6Y6d2vo5w5T17',
  'https://forms.gle/HtnwoYbq5w6F4QiA8',
  'https://forms.gle/96Vt4xs3Ub2dxNcu7',
  'https://forms.gle/VUXv7PxKMs4J58mP8',
  'https://forms.gle/7iVCkWW2Ssrcb3Ls5'
];
const SCREENING_TESTS=[
  ['VIH 1/2','VIH'],['HTLV I/II','HTLV'],['CORE','CORE'],['HBsAg','HEP B'],['Anti-HCV','HEP C'],['Sífilis','SÍFILIS'],['Chagas','CHAGAS']
];
const STORAGE_KEY='hemocura_quick_capture_context_v1';
const today=()=>new Date().toISOString().slice(0,10);
const nowTime=()=>new Date().toTimeString().slice(0,5);
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
function stamp(prefix){const d=new Date(),p=n=>String(n).padStart(2,'0');return `${prefix}-${d.getFullYear()}${p(d.getMonth()+1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`}
function savedContext(){try{return JSON.parse(localStorage.getItem(STORAGE_KEY)||'{}')}catch{return {}}}
function saveContext(ctx){localStorage.setItem(STORAGE_KEY,JSON.stringify(ctx))}
function value(id){return document.getElementById(id)?.value?.trim?.()||''}
function checked(id){return !!document.getElementById(id)?.checked}

export async function mountQuickCapture(root){
  const [branches,products]=await Promise.all([bloodData.branches(),getProductsForDispatch()]);
  const saved=savedContext();
  const productByName=new Map(products.map(p=>[String(p.name||'').trim().toLowerCase(),p]));
  const branchOptions=branches.map(b=>`<option value="${esc(b.id)}" ${saved.branchId===b.id?'selected':''}>${esc(b.name)}</option>`).join('');
  const productOptions=products.filter(p=>p.active!==false).map(p=>`<option value="${esc(p.name)}">${esc(p.code||'')} ${esc(p.unit_of_measure||'')}</option>`).join('');

  root.innerHTML=`
  <div class="sales-toolbar"><div><h2 class="section-heading">Captura rápida</h2><div class="muted">Un solo punto de entrada, menos campos repetidos y formularios progresivos.</div></div><span class="role-chip">v0.45.1</span></div>
  <div id="qc-msg"></div>

  <section class="card">
    <div class="card-head"><div><h3>Contexto de trabajo</h3><div class="muted">Se reutiliza automáticamente en los formularios de esta pantalla.</div></div><button id="qc-context-save" class="secondary">Guardar contexto</button></div>
    <div class="quick-form-grid">
      <label>Fecha<input id="qc-date" type="date" value="${esc(saved.date||today())}"></label>
      <label>Sucursal<select id="qc-branch"><option value="">Seleccionar…</option>${branchOptions}</select></label>
      <label>Turno<select id="qc-shift"><option ${saved.shift==='Día'?'selected':''}>Día</option><option ${saved.shift==='Noche'?'selected':''}>Noche</option><option ${saved.shift==='Mixto'?'selected':''}>Mixto</option></select></label>
    </div>
  </section>

  <details class="card" open>
    <summary><strong>1. Donante</strong> · datos esenciales primero</summary>
    <form id="qc-donor-form" style="margin-top:1rem">
      <div class="quick-form-grid">
        <label>Código<input id="qc-donor-code" required value="${stamp('DON')}" autocomplete="off"></label>
        <label>Tipo<select id="qc-donor-type"><option>VOLUNTARIO</option><option>REPOSICION</option><option>DIRIGIDO</option></select></label>
        <label>Estado de revisión humana<select id="qc-donor-status"><option>PENDIENTE</option><option>ACEPTADO</option><option>DIFERIDO</option></select></label>
        <label><input id="qc-donor-effective" type="checkbox"> Donación efectiva confirmada</label>
      </div>
      <details><summary>Datos opcionales</summary><div class="quick-form-grid" style="margin-top:.75rem">
        <label>ABO<select id="qc-donor-abo"><option value="">Pendiente</option><option>A</option><option>B</option><option>AB</option><option>O</option></select></label>
        <label>Rh<select id="qc-donor-rh"><option value="">Pendiente</option><option>POSITIVO</option><option>NEGATIVO</option></select></label>
        <label>Motivo diferimiento<input id="qc-donor-reason" list="qc-deferral-list" autocomplete="off"><datalist id="qc-deferral-list"><option value="Hemoglobina fuera de criterio"><option value="Presión arterial fuera de criterio"><option value="Medicamento / tratamiento"><option value="Procedimiento reciente"><option value="Otro motivo documentado"></datalist></label>
        <label class="full">Observaciones<textarea id="qc-donor-notes"></textarea></label>
      </div></details>
      <div class="dialog-actions"><button type="submit">Guardar donante</button></div>
    </form>
  </details>

  <details class="card" open>
    <summary><strong>2. Tamizaje por unidad</strong> · varias pruebas en un solo envío</summary>
    <form id="qc-screening-form" style="margin-top:1rem">
      <div class="quick-form-grid">
        <label>Código de unidad<input id="qc-screen-unit" required placeholder="U-2026-00123" autocomplete="off"></label>
        <label>Estado<select id="qc-screen-status"><option>PENDIENTE</option><option>VALIDADO</option><option>REPETIR</option><option>CERRADO</option></select></label>
        <label>Reactivo / plataforma<input id="qc-screen-reagent" placeholder="Opcional" autocomplete="off"></label>
        <label>Lote<input id="qc-screen-lot" placeholder="Opcional" autocomplete="off"></label>
        <label>Responsable<input id="qc-screen-resp" placeholder="Opcional" autocomplete="off"></label>
      </div>
      <div class="table-wrap"><table class="data-table"><thead><tr><th>Incluir</th><th>Prueba</th><th>Resultado</th></tr></thead><tbody>${SCREENING_TESTS.map(([value,label],i)=>`<tr><td><input class="qc-test-check" data-index="${i}" type="checkbox" ${i<6?'checked':''}></td><td>${esc(label)}</td><td><select class="qc-test-result" data-index="${i}"><option>NO_REACTIVO</option><option>REACTIVO</option><option>INDETERMINADO</option></select></td></tr>`).join('')}</tbody></table></div>
      <div class="dialog-actions"><button type="submit">Guardar pruebas seleccionadas</button></div>
    </form>
  </details>

  <details class="card">
    <summary><strong>3. Requisición de insumos</strong> · líneas dinámicas, no 10–15 pares de columnas</summary>
    <form id="qc-req-form" style="margin-top:1rem">
      <div class="quick-form-grid">
        <label>Código<input id="qc-req-code" required value="${stamp('REQ')}" autocomplete="off"></label>
        <label>Área<select id="qc-req-dept"><option>Laboratorio</option><option>Banco de sangre</option><option>Colecta</option><option>Calidad</option><option>Administración</option><option>Otro</option></select></label>
        <label>Prioridad<select id="qc-req-priority"><option>NORMAL</option><option>URGENTE</option></select></label>
        <label class="full">Justificación<textarea id="qc-req-just"></textarea></label>
      </div>
      <datalist id="qc-product-list">${productOptions}</datalist>
      <div class="card-head"><h4>Insumos solicitados</h4><button type="button" id="qc-req-add" class="secondary compact">+ Agregar insumo</button></div>
      <div id="qc-req-lines"></div>
      <div class="dialog-actions"><button type="submit">Guardar requisición</button></div>
    </form>
  </details>

  <details class="card">
    <summary><strong>4. Despacho</strong> · cantidades por línea, sin una columna fija por componente</summary>
    <form id="qc-dispatch-form" style="margin-top:1rem">
      <div class="quick-form-grid">
        <label>Tipo<select id="qc-dispatch-type"><option value="venta">Venta</option><option value="traslado">Traslado</option><option value="otro">Otro</option></select></label>
        <label class="full">Notas<textarea id="qc-dispatch-notes"></textarea></label>
      </div>
      <div class="status info">Se guarda como <strong>BORRADOR</strong>. La confirmación/liberación posterior sigue siendo una acción controlada.</div>
      <div class="card-head"><h4>Productos / componentes</h4><button type="button" id="qc-dispatch-add" class="secondary compact">+ Agregar línea</button></div>
      <div id="qc-dispatch-lines"></div>
      <div class="dialog-actions"><button type="submit">Guardar despacho en borrador</button></div>
    </form>
  </details>

  <details class="card">
    <summary><strong>5. Incidencia</strong> · reporte corto con ampliación opcional</summary>
    <form id="qc-incident-form" style="margin-top:1rem">
      <div class="quick-form-grid">
        <label>Clasificación<select id="qc-inc-class"><option>OPERACIONAL</option><option>BIOSEGURIDAD</option><option>EQUIPO</option><option>REACTIVO</option><option>CALIDAD</option><option>TECNOLOGIA</option><option>OTRO</option></select></label>
        <label>Área / proceso<input id="qc-inc-process" list="qc-process-list" required autocomplete="off"><datalist id="qc-process-list"><option value="Colecta"><option value="Tamizaje"><option value="Producción"><option value="Inventario"><option value="Despacho"><option value="Calidad"><option value="Cadena de frío"></datalist></label>
        <label>Severidad<select id="qc-inc-severity"><option value="1">1 · Leve</option><option value="2">2 · Menor</option><option value="3" selected>3 · Moderada</option><option value="4">4 · Alta</option><option value="5">5 · Crítica</option></select></label>
        <label class="full">Descripción<textarea id="qc-inc-description" required></textarea></label>
        <label><input id="qc-inc-affected" type="checkbox"> Afectó paciente/donante</label>
        <label><input id="qc-inc-followup" type="checkbox"> Requiere seguimiento de Calidad</label>
      </div>
      <details><summary>Detalle adicional</summary><div class="quick-form-grid" style="margin-top:.75rem">
        <label class="full">Detalle de afectación<textarea id="qc-inc-impact"></textarea></label>
        <label class="full">Acción inmediata<textarea id="qc-inc-action"></textarea></label>
        <label class="full">URL de evidencia<input id="qc-inc-evidence" type="url" placeholder="https://…"></label>
      </div></details>
      <div class="dialog-actions"><button type="submit">Guardar incidencia</button></div>
    </form>
  </details>

  <section class="card"><h3>Formularios Google históricos</h3><div class="muted">Se conservan como contingencia durante la transición. Los enlaces cortos no exponen suficiente metadata para asignar automáticamente cada URL a un proceso sin riesgo de etiquetarlo mal.</div><div class="grid" style="margin-top:1rem">${LEGACY_FORMS.map((u,i)=>`<a class="secondary" target="_blank" rel="noopener noreferrer" href="${u}">Abrir formulario histórico ${i+1}</a>`).join('')}</div></section>`;

  function context(){return {date:value('qc-date')||today(),branchId:value('qc-branch'),shift:value('qc-shift')||'Día'}}
  function requireContext(){const c=context();if(!c.branchId)throw new Error('Seleccione una sucursal en Contexto de trabajo.');return c}
  function show(message,type='ok'){document.getElementById('qc-msg').innerHTML=`<div class="status ${type}">${esc(message)}</div>`;document.getElementById('qc-msg').scrollIntoView({behavior:'smooth',block:'nearest'})}
  function productFor(name){return productByName.get(String(name||'').trim().toLowerCase())||null}

  function addReqLine(name='',qty='1'){
    const wrap=document.getElementById('qc-req-lines');
    const row=document.createElement('div');row.className='quick-form-grid qc-req-line';row.style.marginBottom='.5rem';
    row.innerHTML=`<label>Artículo<input class="qc-line-item" list="qc-product-list" required value="${esc(name)}" autocomplete="off"></label><label>Cantidad<input class="qc-line-qty" type="number" min="0.01" step="0.01" required value="${esc(qty)}"></label><label>Unidad<input class="qc-line-unit" placeholder="unidad"></label><label><span>&nbsp;</span><button type="button" class="secondary qc-line-remove">Quitar</button></label>`;
    row.querySelector('.qc-line-item').addEventListener('change',e=>{const p=productFor(e.target.value);if(p)row.querySelector('.qc-line-unit').value=p.unit_of_measure||''});
    row.querySelector('.qc-line-remove').onclick=()=>{if(wrap.children.length>1)row.remove()};wrap.appendChild(row);
  }
  function addDispatchLine(name='',qty='1'){
    const wrap=document.getElementById('qc-dispatch-lines');
    const row=document.createElement('div');row.className='quick-form-grid qc-dispatch-line';row.style.marginBottom='.5rem';
    row.innerHTML=`<label>Producto<input class="qc-dsp-item" list="qc-product-list" required value="${esc(name)}" autocomplete="off"></label><label>Unidades<input class="qc-dsp-qty" type="number" min="0.01" step="0.01" required value="${esc(qty)}"></label><label><input class="qc-dsp-sale" type="checkbox" checked> Es venta</label><label><span>&nbsp;</span><button type="button" class="secondary qc-dsp-remove">Quitar</button></label>`;
    row.querySelector('.qc-dsp-remove').onclick=()=>{if(wrap.children.length>1)row.remove()};wrap.appendChild(row);
  }

  document.getElementById('qc-context-save').onclick=()=>{const c=context();saveContext(c);show('Contexto guardado. Fecha, sucursal y turno se reutilizarán en esta pantalla.')};
  document.getElementById('qc-req-add').onclick=()=>addReqLine();
  document.getElementById('qc-dispatch-add').onclick=()=>addDispatchLine();
  addReqLine();addDispatchLine();

  document.getElementById('qc-donor-form').onsubmit=async e=>{e.preventDefault();try{const c=requireContext();saveContext(c);await bloodData.createDonor({donor_code:value('qc-donor-code'),branch_id:c.branchId,donor_type:value('qc-donor-type'),abo:value('qc-donor-abo')||null,rh:value('qc-donor-rh')||null,status:value('qc-donor-status'),deferral_reason:value('qc-donor-reason')||null,effective_donation:checked('qc-donor-effective'),observations:value('qc-donor-notes')||null,registration_date:c.date});e.target.reset();document.getElementById('qc-donor-code').value=stamp('DON');show('Donante guardado. La elegibilidad clínica continúa sujeta a revisión humana.')}catch(x){show(x.message,'bad')}};

  document.getElementById('qc-screening-form').onsubmit=async e=>{e.preventDefault();try{const c=requireContext();saveContext(c);const selected=SCREENING_TESTS.map(([test],i)=>({test,i})).filter(x=>document.querySelector(`.qc-test-check[data-index="${x.i}"]`)?.checked);if(!selected.length)throw new Error('Seleccione al menos una prueba.');const base=stamp('TAM');const rows=selected.map((x,n)=>({screening_code:`${base}-${String(n+1).padStart(2,'0')}`,source_unit_code:value('qc-screen-unit'),branch_id:c.branchId,screening_date:c.date,test_type:x.test,result:document.querySelector(`.qc-test-result[data-index="${x.i}"]`).value,reagent:value('qc-screen-reagent')||null,reagent_lot:value('qc-screen-lot')||null,responsible:value('qc-screen-resp')||null,status:value('qc-screen-status'),observations:'Captura rápida v0.45.1'}));await bloodData.createScreenings(rows);e.target.reset();document.querySelectorAll('.qc-test-check').forEach((el,i)=>el.checked=i<6);show(`${rows.length} pruebas de tamizaje guardadas en un solo envío.`)}catch(x){show(x.message,'bad')}};

  document.getElementById('qc-req-form').onsubmit=async e=>{e.preventDefault();try{const c=requireContext();saveContext(c);const lines=[...document.querySelectorAll('.qc-req-line')].map(row=>{const item=row.querySelector('.qc-line-item').value.trim(),p=productFor(item);return {item_name:item,category:p?.category||null,unit:row.querySelector('.qc-line-unit').value.trim()||p?.unit_of_measure||null,requested_qty:Number(row.querySelector('.qc-line-qty').value)}}).filter(x=>x.item_name&&x.requested_qty>0);if(!lines.length)throw new Error('Agregue al menos un insumo.');await createRequisition({requisition_code:value('qc-req-code'),request_date:c.date,requesting_branch_id:c.branchId,department:value('qc-req-dept')||null,priority:value('qc-req-priority'),justification:value('qc-req-just')||null,status:'PENDIENTE'},lines);e.target.reset();document.getElementById('qc-req-code').value=stamp('REQ');document.getElementById('qc-req-lines').innerHTML='';addReqLine();show(`Requisición guardada con ${lines.length} línea(s), sin columnas repetidas.`)}catch(x){show(x.message,'bad')}};

  document.getElementById('qc-dispatch-form').onsubmit=async e=>{e.preventDefault();try{const c=requireContext();saveContext(c);const lines=[...document.querySelectorAll('.qc-dispatch-line')].map(row=>{const p=productFor(row.querySelector('.qc-dsp-item').value);return p?{product_id:p.id,units:Number(row.querySelector('.qc-dsp-qty').value),is_sale:row.querySelector('.qc-dsp-sale').checked}:null}).filter(Boolean).filter(x=>x.units>0);if(!lines.length)throw new Error('Seleccione al menos un producto válido del catálogo.');await createDispatchDraft({dispatch_date:c.date,branch_id:c.branchId,shift:c.shift,dispatch_type:value('qc-dispatch-type'),notes:value('qc-dispatch-notes')||null,status:'BORRADOR'},lines);e.target.reset();document.getElementById('qc-dispatch-lines').innerHTML='';addDispatchLine();show(`Despacho guardado en BORRADOR con ${lines.length} línea(s). No se confirmó automáticamente.`)}catch(x){show(x.message,'bad')}};

  document.getElementById('qc-incident-form').onsubmit=async e=>{e.preventDefault();try{const c=requireContext();saveContext(c);await createIncident({incidentCode:stamp('INC'),incidentDate:c.date,incidentTime:nowTime(),branchId:c.branchId,classification:value('qc-inc-class'),processName:value('qc-inc-process'),severity:Number(value('qc-inc-severity')),description:value('qc-inc-description'),patientOrDonorAffected:checked('qc-inc-affected'),impactDetail:value('qc-inc-impact')||null,immediateAction:value('qc-inc-action')||null,evidenceUrl:value('qc-inc-evidence')||null,requiresQualityFollowup:checked('qc-inc-followup')});e.target.reset();document.getElementById('qc-inc-severity').value='3';show('Incidencia guardada. El usuario autenticado queda asociado como reportante cuando está disponible.')}catch(x){show(x.message,'bad')}};
}
