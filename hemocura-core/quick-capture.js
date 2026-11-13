import { bloodData } from './blood-operations-data.js';
import { createRequisition } from './integrated-qms-data.js';
import { quickCaptureProducts, createDispatchDraft, createIncident } from './quick-capture-data.js';
import { showToast, enableDraftSave, restoreDraft, clearDraft, enableBlurValidation, mountProgressBar } from './form-ux.js';

const LEGACY_FORMS=[
  'https://forms.gle/mxXX6Y6d2vo5w5T17','https://forms.gle/HtnwoYbq5w6F4QiA8','https://forms.gle/96Vt4xs3Ub2dxNcu7','https://forms.gle/VUXv7PxKMs4J58mP8','https://forms.gle/7iVCkWW2Ssrcb3Ls5'
];
const TESTS=[['VIH 1/2','VIH'],['HTLV I/II','HTLV'],['CORE','CORE'],['HBsAg','HEP B'],['Anti-HCV','HEP C'],['Sífilis','SÍFILIS'],['Chagas','CHAGAS']];
const CTX_KEY='hemocura_quick_capture_context_v1';
const SCREEN_KEY='hemocura_quick_capture_screening_defaults_v2';
const today=()=>new Date().toISOString().slice(0,10);
const nowTime=()=>new Date().toTimeString().slice(0,5);
const esc=(v='')=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const val=id=>document.getElementById(id)?.value?.trim?.()||'';
const chk=id=>!!document.getElementById(id)?.checked;
function stamp(prefix){const d=new Date(),p=n=>String(n).padStart(2,'0');return `${prefix}-${d.getFullYear()}${p(d.getMonth()+1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`}
function loadJson(key){try{return JSON.parse(localStorage.getItem(key)||'{}')}catch{return {}}}
function saveJson(key,value){localStorage.setItem(key,JSON.stringify(value))}
function normalize(v=''){return String(v||'').trim().toLowerCase().replace(/\s+/g,' ')}
function duplicateValues(values=[]){const seen=new Set(),dups=new Set();for(const raw of values){const v=normalize(raw);if(!v)continue;if(seen.has(v))dups.add(v);seen.add(v)}return [...dups]}
function selectedScreeningRows(){
  return TESTS.map(([test,label],i)=>{
    const include=document.querySelector(`.qc-test-check[data-i="${i}"]`)?.checked;
    const result=document.querySelector(`.qc-test-result[data-i="${i}"]`)?.value||'';
    return {test,label,i,include,result};
  }).filter(x=>x.include);
}

/* ── Form helper: loading state on submit buttons ── */
function setFormBusy(form,busy){
  const btn=form.querySelector('.dialog-actions button[type="submit"],\n.dialog-actions button:not([type="button"])');
  if(!btn)return;
  if(busy){btn.setAttribute('aria-busy','true');btn.disabled=true}
  else{btn.removeAttribute('aria-busy');btn.disabled=false}
}

/* ── Form helper: clear field-level errors ── */
function clearFieldErrors(form){
  form.querySelectorAll('.qc-field-error').forEach(el=>el.classList.remove('qc-field-error'));
  form.querySelectorAll('.qc-field-error-msg').forEach(el=>el.remove());
}

/* ── Form helper: mark a field with inline error ── */
function markFieldError(fieldId,message){
  const el=document.getElementById(fieldId);
  if(!el)return;
  el.classList.add('qc-field-error');
  el.setAttribute('aria-invalid','true');
  const msg=document.createElement('span');
  msg.className='qc-field-error-msg';
  msg.id=fieldId+'-error';
  msg.textContent=message;
  el.setAttribute('aria-describedby',msg.id);
  el.parentElement?.appendChild(msg);
  el.focus({preventScroll:false});
}

/* ── Form helper: wrapped submit with loading + error handling ── */
function handleSubmit(form,handler,show){
  form.onsubmit=async e=>{
    e.preventDefault();
    clearFieldErrors(form);
    setFormBusy(form,true);
    try{
      await handler(e);
    }catch(x){
      show(x.message,'bad');
      // Try to focus the first invalid field if it was a validation error
      const firstInvalid=form.querySelector('[aria-invalid="true"]');
      if(firstInvalid)firstInvalid.focus({preventScroll:false});
    }finally{
      setFormBusy(form,false);
    }
  };
}

export async function mountQuickCapture(root){
  const [branches,products]=await Promise.all([bloodData.branches(),quickCaptureProducts()]);
  const saved=loadJson(CTX_KEY),screenSaved=loadJson(SCREEN_KEY);
  const productByName=new Map(products.map(p=>[normalize(p.name),p]));
  const branchOptions=branches.map(b=>`<option value="${esc(b.id)}" ${saved.branchId===b.id?'selected':''}>${esc(b.name)}</option>`).join('');
  const productOptions=products.map(p=>`<option value="${esc(p.name)}">${esc(p.code||'')} · ${esc(p.unit_of_measure||'unidad')}</option>`).join('');

  root.innerHTML=`
  <div class="sales-toolbar"><div><h2 class="section-heading">Captura rápida</h2><div class="muted">Registra lo esencial primero. El contexto se reutiliza y los datos clínicos sensibles exigen selección explícita.</div></div><span class="role-chip">v0.45.9</span></div>
  <div id="qc-msg" role="status" aria-live="polite" aria-atomic="true"></div>

  <section class="card">
    <div class="card-head"><div><h3>Contexto de trabajo</h3><div class="muted">Fecha, sucursal y turno se reutilizan en todos los formularios de esta pantalla.</div></div><span id="qc-context-state" class="state-pill state-info">Contexto local</span></div>
    <div class="quick-form-grid">
      <label>Fecha<input id="qc-date" type="date" value="${esc(saved.date||today())}" aria-required="true"></label>
      <label data-required>Sucursal<select id="qc-branch" required aria-required="true"><option value="">Seleccionar…</option>${branchOptions}</select></label>
      <label>Turno<select id="qc-shift"><option ${saved.shift==='Día'?'selected':''}>Día</option><option ${saved.shift==='Noche'?'selected':''}>Noche</option><option ${saved.shift==='Mixto'?'selected':''}>Mixto</option></select></label>
    </div>
    <small class="muted">El contexto se guarda automáticamente en este navegador. No contiene resultados clínicos.</small>
  </section>

  <details class="card" open>
    <summary><strong>Donante</strong> · captura mínima</summary>
    <form id="qc-donor-form" class="quick-capture-form" novalidate>
      <div class="status info">El estado inicia en PENDIENTE. Aceptación o diferimiento corresponde a revisión humana autorizada.</div>
      <div class="quick-form-grid">
        <label data-required>Código<input id="qc-donor-code" required aria-required="true" value="${stamp('DON')}" autocomplete="off"></label>
        <label>Tipo<select id="qc-donor-type"><option>VOLUNTARIO</option><option>REPOSICION</option><option>DIRIGIDO</option></select></label>
        <label>Estado revisión<select id="qc-donor-status"><option selected>PENDIENTE</option><option>ACEPTADO</option><option>DIFERIDO</option></select></label>
        <label><input id="qc-donor-effective" type="checkbox"> Donación efectiva confirmada</label>
      </div>
      <details>
        <summary>Agregar datos opcionales</summary>
        <div class="quick-form-grid">
          <label>ABO<select id="qc-donor-abo"><option value="">Pendiente</option><option>A</option><option>B</option><option>AB</option><option>O</option></select></label>
          <label>Rh<select id="qc-donor-rh"><option value="">Pendiente</option><option>POSITIVO</option><option>NEGATIVO</option></select></label>
          <label>Motivo diferimiento<input id="qc-donor-reason" list="qc-deferrals" autocomplete="off"><datalist id="qc-deferrals"><option value="Hemoglobina fuera de criterio"><option value="Presión arterial fuera de criterio"><option value="Medicamento / tratamiento"><option value="Procedimiento reciente"><option value="Otro motivo documentado"></datalist></label>
          <label class="full">Observaciones<textarea id="qc-donor-notes" rows="2"></textarea></label>
        </div>
      </details>
      <div class="dialog-actions"><button type="submit">Guardar y preparar otro</button></div>
    </form>
  </details>

  <details class="card" open>
    <summary><strong>Tamizaje por unidad</strong> · selección explícita de cada resultado</summary>
    <form id="qc-screen-form" class="quick-capture-form" novalidate>
      <div class="status warn"><strong>Sin resultados precargados.</strong> Seleccione la prueba y luego su resultado. El sistema no asume "NO_REACTIVO".</div>
      <div class="quick-form-grid">
        <label data-required>Unidad<input id="qc-screen-unit" required aria-required="true" placeholder="Código de unidad" autocomplete="off"></label>
        <label>Estado<select id="qc-screen-status"><option selected>PENDIENTE</option><option>VALIDADO</option><option>REPETIR</option><option>CERRADO</option></select></label>
        <label>Reactivo / plataforma<input id="qc-screen-reagent" value="${esc(screenSaved.reagent||'')}" placeholder="Opcional" autocomplete="off"></label>
        <label>Lote<input id="qc-screen-lot" value="${esc(screenSaved.lot||'')}" placeholder="Opcional" autocomplete="off"></label>
        <label>Responsable<input id="qc-screen-resp" value="${esc(screenSaved.responsible||'')}" placeholder="Opcional" autocomplete="off"></label>
        <label><input id="qc-screen-remember" type="checkbox" ${screenSaved.remember===false?'':'checked'}> Recordar reactivo, lote y responsable</label>
      </div>
      <div class="card-head"><div><strong>Panel de pruebas</strong><div id="qc-screen-count" class="muted" aria-live="polite">0 seleccionadas</div></div><div><button type="button" id="qc-screen-all" class="secondary compact">Seleccionar panel</button> <button type="button" id="qc-screen-clear" class="secondary compact">Limpiar</button></div></div>
      <div class="table-wrap"><table class="data-table" role="grid" aria-label="Panel de pruebas de tamizaje"><thead><tr><th scope="col">Incluir</th><th scope="col">Prueba</th><th scope="col">Resultado</th></tr></thead><tbody>${TESTS.map(([test,label],i)=>`<tr><td><input class="qc-test-check" data-i="${i}" type="checkbox" aria-label="Incluir ${esc(label)}"></td><td>${esc(label)}</td><td><select class="qc-test-result" data-i="${i}" disabled aria-label="Resultado ${esc(label)}"><option value="" selected>Seleccionar resultado…</option><option value="NO_REACTIVO">NO REACTIVO</option><option value="REACTIVO">REACTIVO</option><option value="INDETERMINADO">INDETERMINADO</option></select></td></tr>`).join('')}</tbody></table></div>
      <div class="dialog-actions"><button type="submit">Guardar resultados explícitos</button></div>
    </form>
  </details>

  <details class="card">
    <summary><strong>Requisición</strong> · líneas dinámicas</summary>
    <form id="qc-req-form" class="quick-capture-form" novalidate>
      <div class="quick-form-grid">
        <label data-required>Código<input id="qc-req-code" required aria-required="true" value="${stamp('REQ')}" autocomplete="off"></label>
        <label>Área<select id="qc-req-dept"><option>Laboratorio</option><option>Banco de sangre</option><option>Colecta</option><option>Calidad</option><option>Administración</option><option>Otro</option></select></label>
        <label>Prioridad<select id="qc-req-priority"><option>NORMAL</option><option>URGENTE</option></select></label>
        <label class="full">Justificación<textarea id="qc-req-just" rows="2"></textarea></label>
      </div>
      <datalist id="qc-product-list">${productOptions}</datalist>
      <div class="card-head"><div><h4>Artículos</h4><div class="muted">Un artículo una sola vez; ajuste la cantidad en su misma línea.</div></div><button type="button" id="qc-add-req" class="secondary compact">+ Agregar</button></div>
      <div id="qc-req-lines" role="list" aria-label="Líneas de requisición"></div>
      <div class="dialog-actions"><button type="submit">Guardar requisición</button></div>
    </form>
  </details>

  <details class="card">
    <summary><strong>Despacho</strong> · líneas dinámicas</summary>
    <form id="qc-dispatch-form" class="quick-capture-form" novalidate>
      <div class="quick-form-grid"><label>Tipo<select id="qc-dispatch-type"><option value="venta">Venta</option><option value="traslado">Traslado</option><option value="otro">Otro</option></select></label><label class="full">Notas<textarea id="qc-dispatch-notes" rows="2"></textarea></label></div>
      <div class="status info">Se crea únicamente como BORRADOR. No confirma, libera ni determina compatibilidad transfusional.</div>
      <div class="card-head"><div><h4>Productos / componentes</h4><div class="muted">No se permiten productos duplicados en el mismo borrador.</div></div><button type="button" id="qc-add-dispatch" class="secondary compact">+ Agregar</button></div>
      <div id="qc-dispatch-lines" role="list" aria-label="Líneas de despacho"></div>
      <div class="dialog-actions"><button type="submit">Guardar borrador</button></div>
    </form>
  </details>

  <details class="card">
    <summary><strong>Incidencia</strong> · reporte breve</summary>
    <form id="qc-inc-form" class="quick-capture-form" novalidate>
      <div class="quick-form-grid">
        <label>Clasificación<select id="qc-inc-class"><option>OPERACIONAL</option><option>BIOSEGURIDAD</option><option>EQUIPO</option><option>REACTIVO</option><option>CALIDAD</option><option>TECNOLOGIA</option><option>OTRO</option></select></label>
        <label data-required>Área / proceso<input id="qc-inc-process" list="qc-processes" required aria-required="true" autocomplete="off"><datalist id="qc-processes"><option value="Colecta"><option value="Tamizaje"><option value="Producción"><option value="Inventario"><option value="Despacho"><option value="Calidad"><option value="Cadena de frío"></datalist></label>
        <label>Severidad<select id="qc-inc-severity"><option value="1">1 · Leve</option><option value="2">2 · Menor</option><option value="3" selected>3 · Moderada</option><option value="4">4 · Alta</option><option value="5">5 · Crítica</option></select></label>
        <label class="full" data-required>Descripción<textarea id="qc-inc-description" required aria-required="true" rows="3"></textarea></label>
        <label><input id="qc-inc-affected" type="checkbox"> Afectó paciente/donante</label>
        <label><input id="qc-inc-followup" type="checkbox"> Requiere seguimiento de Calidad</label>
      </div>
      <details><summary>Detalle adicional</summary><div class="quick-form-grid"><label class="full">Detalle de afectación<textarea id="qc-inc-impact" rows="2"></textarea></label><label class="full">Acción inmediata<textarea id="qc-inc-action" rows="2"></textarea></label><label class="full">Evidencia<input id="qc-inc-evidence" type="url" inputmode="url" placeholder="https://…"></label></div></details>
      <div class="dialog-actions"><button type="submit">Guardar incidencia</button></div>
    </form>
  </details>

  <section class="card"><h3>Formularios Google históricos</h3><div class="muted">Se conservan como contingencia. Los enlaces cortos suministrados no permitieron identificar con certeza qué proceso corresponde a cada URL, por lo que no se inventa esa asociación.</div><div class="grid">${LEGACY_FORMS.map((u,i)=>`<a class="secondary" target="_blank" rel="noopener noreferrer" href="${u}">Formulario histórico ${i+1}</a>`).join('')}</div></section>`;

  const context=()=>({date:val('qc-date')||today(),branchId:val('qc-branch'),shift:val('qc-shift')||'Día'});
  const requireContext=()=>{
    const c=context();
    if(!c.branchId){markFieldError('qc-branch','Seleccione una sucursal.');throw new Error('Seleccione una sucursal.')}
    return c;
  };
  const show=(m,t='ok')=>{
    const el=document.getElementById('qc-msg');
    el.innerHTML=`<div class="status ${t}" role="${t==='bad'?'alert':'status'}">${esc(m)}</div>`;
    el.scrollIntoView({behavior:'smooth',block:'nearest'});
    showToast(m,t);
    if(t==='ok'){
      // Flash the success card
      const card=el.closest('.card')||el.previousElementSibling;
      if(card){card.classList.add('qc-success-flash');setTimeout(()=>card.classList.remove('qc-success-flash'),600)}
    }
  };
  const productFor=name=>productByName.get(normalize(name))||null;
  const persistContext=()=>{saveJson(CTX_KEY,context());const s=document.getElementById('qc-context-state');if(s){s.textContent='Contexto guardado';setTimeout(()=>{s.textContent='Contexto local'},1200)}};
  ['qc-date','qc-branch','qc-shift'].forEach(id=>document.getElementById(id)?.addEventListener('change',persistContext));

  // Clear field errors on input
  root.addEventListener('input',e=>{
    if(e.target.classList.contains('qc-field-error')){
      e.target.classList.remove('qc-field-error');
      e.target.removeAttribute('aria-invalid');
      e.target.removeAttribute('aria-describedby');
      const errMsg=e.target.parentElement?.querySelector('.qc-field-error-msg');
      if(errMsg)errMsg.remove();
    }
  });

  function addReqLine(){
    const w=document.getElementById('qc-req-lines'),r=document.createElement('div');r.className='quick-form-grid qc-req-line';r.setAttribute('role','listitem');
    r.innerHTML=`<label data-required>Artículo<input class="qc-item" list="qc-product-list" required aria-required="true" autocomplete="off"></label><label data-required>Cantidad<input class="qc-qty" type="number" min="0.01" step="0.01" value="1" inputmode="decimal" required aria-required="true"></label><label>Unidad<input class="qc-unit" placeholder="unidad" autocomplete="off"></label><label><span>&nbsp;</span><button type="button" class="secondary qc-remove" aria-label="Quitar línea">Quitar</button></label>`;
    r.querySelector('.qc-item').onchange=e=>{const p=productFor(e.target.value);if(p)r.querySelector('.qc-unit').value=p.unit_of_measure||''};
    r.querySelector('.qc-remove').onclick=()=>w.children.length>1&&r.remove();w.appendChild(r)
  }
  function addDispatchLine(){
    const w=document.getElementById('qc-dispatch-lines'),r=document.createElement('div');r.className='quick-form-grid qc-dispatch-line';r.setAttribute('role','listitem');
    r.innerHTML=`<label data-required>Producto<input class="qc-dsp-item" list="qc-product-list" required aria-required="true" autocomplete="off"></label><label data-required>Unidades<input class="qc-dsp-qty" type="number" min="0.01" step="0.01" value="1" inputmode="decimal" required aria-required="true"></label><label><input class="qc-dsp-sale" type="checkbox" checked> Es venta</label><label><span>&nbsp;</span><button type="button" class="secondary qc-remove" aria-label="Quitar línea">Quitar</button></label>`;
    r.querySelector('.qc-remove').onclick=()=>w.children.length>1&&r.remove();w.appendChild(r)
  }
  addReqLine();addDispatchLine();
  document.getElementById('qc-add-req').onclick=addReqLine;
  document.getElementById('qc-add-dispatch').onclick=addDispatchLine;

  const updateScreeningCount=()=>{const n=selectedScreeningRows().length;document.getElementById('qc-screen-count').textContent=`${n} seleccionada${n===1?'':'s'}`};
  document.querySelectorAll('.qc-test-check').forEach(box=>box.addEventListener('change',()=>{
    const result=document.querySelector(`.qc-test-result[data-i="${box.dataset.i}"]`);
    if(result){result.disabled=!box.checked;if(!box.checked)result.value=''}
    updateScreeningCount();
  }));
  document.getElementById('qc-screen-all').onclick=()=>{document.querySelectorAll('.qc-test-check').forEach(box=>{box.checked=true;const result=document.querySelector(`.qc-test-result[data-i="${box.dataset.i}"]`);if(result)result.disabled=false});updateScreeningCount()};
  document.getElementById('qc-screen-clear').onclick=()=>{document.querySelectorAll('.qc-test-check').forEach(box=>{box.checked=false;const result=document.querySelector(`.qc-test-result[data-i="${box.dataset.i}"]`);if(result){result.value='';result.disabled=true}});updateScreeningCount()};

  /* ── Donor form ── */
  handleSubmit(document.getElementById('qc-donor-form'),async(e)=>{
    const c=requireContext();persistContext();
    const status=val('qc-donor-status');
    if(status==='DIFERIDO'&&!val('qc-donor-reason')){
      markFieldError('qc-donor-reason','Indique el motivo de diferimiento.');
      throw new Error('Indique el motivo de diferimiento antes de guardar.');
    }
    await bloodData.createDonor({donor_code:val('qc-donor-code'),branch_id:c.branchId,donor_type:val('qc-donor-type'),abo:val('qc-donor-abo')||null,rh:val('qc-donor-rh')||null,status,deferral_reason:val('qc-donor-reason')||null,effective_donation:chk('qc-donor-effective'),observations:val('qc-donor-notes')||null,registration_date:c.date});
    e.target.reset();document.getElementById('qc-donor-code').value=stamp('DON');document.getElementById('qc-donor-status').value='PENDIENTE';
    show('Donante guardado. Nuevo registro preparado con revisión PENDIENTE.');
  },show);

  /* ── Screening form ── */
  handleSubmit(document.getElementById('qc-screen-form'),async(e)=>{
    const c=requireContext(),selected=selectedScreeningRows();
    if(!selected.length)throw new Error('Seleccione al menos una prueba.');
    const missing=selected.filter(x=>!x.result);
    if(missing.length)throw new Error(`Seleccione resultado explícito para: ${missing.map(x=>x.label).join(', ')}.`);
    const unit=val('qc-screen-unit');
    if(!unit){markFieldError('qc-screen-unit','Indique el código de unidad.');throw new Error('Indique el código de unidad.')}
    const reagent=val('qc-screen-reagent'),lot=val('qc-screen-lot'),responsible=val('qc-screen-resp');
    const base=stamp('TAM'),rows=selected.map((x,n)=>({screening_code:`${base}-${String(n+1).padStart(2,'0')}`,source_unit_code:unit,branch_id:c.branchId,screening_date:c.date,test_type:x.test,result:x.result,reagent:reagent||null,reagent_lot:lot||null,responsible:responsible||null,status:val('qc-screen-status'),observations:'Captura rápida v0.45.9 · resultado explícito'}));
    if(chk('qc-screen-remember'))saveJson(SCREEN_KEY,{reagent,lot,responsible,remember:true});else saveJson(SCREEN_KEY,{remember:false});
    await bloodData.createScreenings(rows);
    document.getElementById('qc-screen-unit').value='';
    document.getElementById('qc-screen-status').value='PENDIENTE';
    if(!chk('qc-screen-remember')){document.getElementById('qc-screen-reagent').value='';document.getElementById('qc-screen-lot').value='';document.getElementById('qc-screen-resp').value=''}
    document.getElementById('qc-screen-clear').click();
    show(`${rows.length} prueba(s) guardada(s). Ningún resultado fue inferido automáticamente.`);
  },show);

  /* ── Requisition form ── */
  handleSubmit(document.getElementById('qc-req-form'),async(e)=>{
    const c=requireContext(),raw=[...document.querySelectorAll('.qc-req-line')].map(r=>{const name=r.querySelector('.qc-item').value.trim(),p=productFor(name);return {item_name:name,category:p?.category||null,unit:r.querySelector('.qc-unit').value.trim()||p?.unit_of_measure||null,requested_qty:Number(r.querySelector('.qc-qty').value)}});
    const lines=raw.filter(x=>x.item_name&&x.requested_qty>0);
    if(!lines.length)throw new Error('Agregue al menos un artículo.');
    const dups=duplicateValues(lines.map(x=>x.item_name));if(dups.length)throw new Error('Hay artículos duplicados. Mantenga cada artículo en una sola línea y ajuste su cantidad.');
    await createRequisition({requisition_code:val('qc-req-code'),request_date:c.date,requesting_branch_id:c.branchId,department:val('qc-req-dept')||null,priority:val('qc-req-priority'),justification:val('qc-req-just')||null,status:'PENDIENTE'},lines);
    e.target.reset();document.getElementById('qc-req-code').value=stamp('REQ');document.getElementById('qc-req-lines').innerHTML='';addReqLine();
    show(`Requisición guardada con ${lines.length} línea(s), sin artículos duplicados.`);
  },show);

  /* ── Dispatch form ── */
  handleSubmit(document.getElementById('qc-dispatch-form'),async(e)=>{
    const c=requireContext(),raw=[...document.querySelectorAll('.qc-dispatch-line')].map(r=>{const p=productFor(r.querySelector('.qc-dsp-item').value);return p?{product_id:p.id,product_name:p.name,units:Number(r.querySelector('.qc-dsp-qty').value),is_sale:r.querySelector('.qc-dsp-sale').checked}:null}).filter(Boolean);
    const lines=raw.filter(x=>x.units>0);
    if(!lines.length)throw new Error('Seleccione un producto válido del catálogo.');
    const dups=duplicateValues(lines.map(x=>x.product_id));if(dups.length)throw new Error('Hay productos duplicados. Mantenga cada producto en una sola línea y ajuste sus unidades.');
    await createDispatchDraft({dispatch_date:c.date,branch_id:c.branchId,shift:c.shift,dispatch_type:val('qc-dispatch-type'),notes:val('qc-dispatch-notes')||null},lines);
    e.target.reset();document.getElementById('qc-dispatch-lines').innerHTML='';addDispatchLine();
    show(`Despacho guardado como BORRADOR con ${lines.length} línea(s). Requiere revisión posterior.`);
  },show);

  /* ── Incident form ── */
  handleSubmit(document.getElementById('qc-inc-form'),async(e)=>{
    const c=requireContext();
    if(!val('qc-inc-description')){markFieldError('qc-inc-description','Describa la incidencia.');throw new Error('Describa la incidencia.')}
    await createIncident({incidentCode:stamp('INC'),incidentDate:c.date,incidentTime:nowTime(),branchId:c.branchId,classification:val('qc-inc-class'),processName:val('qc-inc-process'),severity:Number(val('qc-inc-severity')),description:val('qc-inc-description'),patientOrDonorAffected:chk('qc-inc-affected'),impactDetail:val('qc-inc-impact')||null,immediateAction:val('qc-inc-action')||null,evidenceUrl:val('qc-inc-evidence')||null,requiresQualityFollowup:chk('qc-inc-followup')});
    e.target.reset();document.getElementById('qc-inc-severity').value='3';show('Incidencia guardada.');
  },show);

  updateScreeningCount();

  /* ── Phase 2 UX: toast, draft save, blur validation, progress bar ── */

  // Enable blur validation on all forms
  root.querySelectorAll('.quick-capture-form').forEach(f=>enableBlurValidation(f));

  // Draft auto-save for donor form (most commonly interrupted).
  // §15 del prompt maestro v11 prohíbe almacenar datos clínicos sensibles
  // en localStorage como fuente principal. Excluimos ABO, Rh, motivo de
  // diferimiento, notas y efectividad — todos ellos derivan del juicio
  // clínico o revelan estado de salud del donante. Solo se persisten
  // campos administrativos de borrador (código, tipo de visita, estado
  // del flujo) para que el captador no pierda su progreso.
  const donorDraftFields=['qc-donor-code','qc-donor-type','qc-donor-status'];
  const donorDraft=enableDraftSave('qc-donor-form',donorDraftFields);
  if(restoreDraft('qc-donor-form',donorDraftFields)){
    showToast('Borrador de donante restaurado','ok',2500);
  }

  // Draft auto-save for incident form (long form, easy to lose).
  // §15: la descripción, afectados e impacto pueden contener datos
  // clínicos de un paciente o donante involucrado en la incidencia.
  // Persistimos solo metadatos de clasificación; el texto libre se
  // vuelve a capturar si el navegador cierra.
  const incDraftFields=['qc-inc-class','qc-inc-process','qc-inc-severity'];
  const incDraft=enableDraftSave('qc-inc-form',incDraftFields);
  restoreDraft('qc-inc-form',incDraftFields);

  // Progress bar for the main capture area
  mountProgressBar('qc-donor-form',['.quick-form-grid']);

  // Clear drafts on successful save — wrap existing handlers
  const donorForm=document.getElementById('qc-donor-form');
  const origDonorSubmit=donorForm.onsubmit;
  donorForm.onsubmit=async e=>{
    await origDonorSubmit(e);
    clearDraft('qc-donor-form');
  };
  const incForm=document.getElementById('qc-inc-form');
  const origIncSubmit=incForm.onsubmit;
  incForm.onsubmit=async e=>{
    await origIncSubmit(e);
    clearDraft('qc-inc-form');
  };
}
