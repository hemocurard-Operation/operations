import { getBranches } from './sales-data.js';
import { listInspections, createInspection, listInspectionFindings, listActiveProfiles, inspectionFindingToNonconformity, inspectionFindingCreateCapa } from './integrated-qms-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);

// Checklist estándar de criterios recurrentes de inspección, para no empezar
// cada inspección desde cero (concepto adaptado de un prototipo externo).
// Son un punto de partida editable, no una lista normativa cerrada: cada fila
// sigue siendo texto libre y se pueden añadir o quitar criterios.
const STANDARD_CHECKLIST=[
  ['Infraestructura e Instalaciones','Señalización de áreas restringidas'],
  ['Infraestructura e Instalaciones','Condiciones de limpieza y orden'],
  ['Bioseguridad','Uso correcto de equipo de protección personal'],
  ['Bioseguridad','Manejo y disposición de desechos biológicos'],
  ['Cadena de frío','Registro diario de temperatura actualizado'],
  ['Cadena de frío','Dispositivos de alarma funcionando'],
  ['Documentación','Procedimientos vigentes disponibles en el área'],
  ['Documentación','Registros de capacitación del personal actualizados']
];

function findingRow(n,f={}){
  return `<div class="card" data-finding-row data-n="${n}"><div class="filter-grid">
    <label>Sección<input name="section_name" value="${esc(f.section_name||'Infraestructura e Instalaciones')}" required></label>
    <label>Criterio<input name="criterion" value="${esc(f.criterion||'')}" required></label>
    <label>Resultado<select name="result" data-result>
      <option value="" ${!f.result?'selected':''}>Pendiente de evaluar</option>
      <option value="C" ${f.result==='C'?'selected':''}>Cumple</option>
      <option value="NC" ${f.result==='NC'?'selected':''}>No cumple</option>
      <option value="NA" ${f.result==='NA'?'selected':''}>No aplica</option>
    </select></label>
    <label>Observación<textarea name="observation">${esc(f.observation||'')}</textarea></label>
  </div><button type="button" data-remove-finding>Quitar criterio</button></div>`;
}

function checklistProgressHtml(done,total){
  const pct=total?Math.round(100*done/total):0;
  return `<div data-checklist-progress style="margin-bottom:10px">
    <p class="muted" style="margin-bottom:4px">${done} de ${total} criterios evaluados (${pct}%)</p>
    <div style="height:6px;border-radius:999px;background:var(--surface-2,#eee);overflow:hidden">
      <div style="height:100%;width:${pct}%;background:var(--accent,#2b5fa8);transition:width .2s"></div>
    </div>
  </div>`;
}

export async function mountInspections(root){
  const [branches,profiles]=await Promise.all([getBranches(),listActiveProfiles()]);
  const branchMap=Object.fromEntries(branches.map(b=>[b.id,b.name]));
  root.innerHTML=`
    <div class="sales-toolbar"><div><h2 class="section-heading">Inspecciones de Sucursal</h2>
    <div class="muted">Inspección → hallazgo → seguimiento SGC.</div></div><button id="insp-new">Nueva inspección</button></div>
    <div id="insp-status"></div>
    <section class="card"><div class="table-wrap"><table class="data-table">
      <thead><tr><th>Fecha</th><th>Código</th><th>Sucursal</th><th>Tipo</th><th>Cumplimiento</th><th>NC</th><th>Convertidas a NC</th><th>Estado</th><th></th></tr></thead>
      <tbody id="insp-body"></tbody></table></div></section>
    <section class="card" id="insp-detail"></section>
    <dialog id="insp-dialog" class="sales-dialog"><form id="insp-form">
      <h3>Nueva inspección</h3>
      <div class="filter-grid">
      <label>Código<input id="insp-code" required placeholder="INS-2026-001"></label>
      <label>Fecha<input id="insp-date" type="date" value="${today()}" required></label>
      <label>Sucursal<select id="insp-branch" required><option value="">Seleccionar…</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
      <label>Tipo<select id="insp-type"><option>RUTINA</option><option>SEGUIMIENTO</option><option>APERTURA</option><option>EXTRAORDINARIA</option></select></label>
      <label>Responsable en sitio<input id="insp-responsible"></label>
      </div>
      <h4>Criterios / hallazgos</h4>
      <div id="insp-checklist-progress"></div>
      <div id="insp-findings">${STANDARD_CHECKLIST.map((c,i)=>findingRow(i+1,{section_name:c[0],criterion:c[1]})).join('')}</div>
      <button type="button" id="insp-add-finding">Añadir criterio</button>
      <div class="dialog-actions"><button type="button" id="insp-cancel" class="secondary">Cancelar</button><button type="submit">Guardar</button></div>
    </form></dialog>
    <dialog id="insp-nc-dialog" class="sales-dialog"><form id="insp-nc-form">
      <h3 id="insp-nc-title">Convertir hallazgo</h3>
      <div class="filter-grid" id="insp-nc-fields"></div>
      <div class="dialog-actions"><button type="button" id="insp-nc-cancel" class="secondary">Cancelar</button><button type="submit">Guardar</button></div>
    </form></dialog>`;

  let findingCount=STANDARD_CHECKLIST.length;
  const findingsHolder=document.getElementById('insp-findings');
  function updateProgress(){
    const rows=[...findingsHolder.querySelectorAll('[data-finding-row]')];
    const done=rows.filter(r=>r.querySelector('[data-result]').value).length;
    document.getElementById('insp-checklist-progress').innerHTML=checklistProgressHtml(done,rows.length);
  }
  function bindRemovals(){
    findingsHolder.querySelectorAll('[data-remove-finding]').forEach(b=>b.onclick=()=>{
      if(findingsHolder.querySelectorAll('[data-finding-row]').length>1){b.closest('[data-finding-row]').remove();updateProgress()}
    });
  }
  bindRemovals();
  findingsHolder.addEventListener('change',e=>{if(e.target.matches('[data-result]'))updateProgress()});
  updateProgress();
  document.getElementById('insp-add-finding').onclick=()=>{
    findingCount++;
    findingsHolder.insertAdjacentHTML('beforeend',findingRow(findingCount));
    bindRemovals();
    updateProgress();
  };

  async function load(){
    try{
      const rows=await listInspections();
      document.getElementById('insp-body').innerHTML=rows.length?rows.map(r=>`<tr>
        <td>${esc(r.inspection_date)}</td><td><code>${esc(r.inspection_code)}</code></td>
        <td>${esc(branchMap[r.branch_id]||r.branch_id)}</td><td>${esc(r.inspection_type)}</td>
        <td>${r.compliance_pct==null?'—':esc(r.compliance_pct)+'%'}</td><td>${esc(r.nc_findings||0)}</td>
        <td>${esc(r.converted_to_nc||0)}/${esc(r.nc_findings||0)}</td><td>${esc(r.status)}</td>
        <td><button type="button" data-detail="${esc(r.id)}" data-code="${esc(r.inspection_code)}">Ver hallazgos</button></td>
      </tr>`).join(''):`<tr><td colspan="9" class="muted">No hay inspecciones registradas.</td></tr>`;
      document.getElementById('insp-status').innerHTML='';
      document.getElementById('insp-body').querySelectorAll('[data-detail]').forEach(b=>b.onclick=()=>openDetail(b.dataset.detail,b.dataset.code));
    }catch(e){document.getElementById('insp-status').innerHTML=`<div class="status warn">${esc(e.message)} · Ejecute la migración v0.22.0 si falta.</div>`}
  }

  function profileOptions(){return `<option value="">Seleccionar…</option>${profiles.map(p=>`<option value="${esc(p.id)}">${esc(p.full_name)}</option>`).join('')}`}

  async function openDetail(inspectionId,code){
    const detail=document.getElementById('insp-detail');
    detail.innerHTML='<p>Cargando hallazgos…</p>';
    try{
      const findings=await listInspectionFindings(inspectionId);
      detail.innerHTML=`<h3>Hallazgos · ${esc(code)}</h3>${findings.length?`<div class="table-wrap"><table class="data-table">
        <thead><tr><th>Sección</th><th>Criterio</th><th>Resultado</th><th>Observación</th><th>NC</th><th>CAPA</th><th></th></tr></thead>
        <tbody>${findings.map(f=>`<tr>
          <td>${esc(f.section_name)}</td><td>${esc(f.criterion)}</td><td>${esc(f.result)}</td><td>${esc(f.observation||'—')}</td>
          <td>${f.nonconformity_id?'Vinculada':'—'}</td><td>${f.capa_id?'Vinculada':'—'}</td>
          <td>${f.result==='NC'&&!f.nonconformity_id?`<button type="button" data-nc="${esc(f.id)}">Convertir a NC</button>`:''}${f.nonconformity_id&&!f.capa_id?`<button type="button" data-capa="${esc(f.id)}">Crear CAPA</button>`:''}</td>
        </tr>`).join('')}</tbody></table></div>`:'<p class="muted">Sin hallazgos registrados.</p>'}`;
      detail.querySelectorAll('[data-nc]').forEach(b=>b.onclick=()=>openNcDialog(b.dataset.nc,inspectionId,code));
      detail.querySelectorAll('[data-capa]').forEach(b=>b.onclick=()=>openCapaDialog(b.dataset.capa,inspectionId,code));
    }catch(e){detail.innerHTML=`<div class="status bad">${esc(e.message)}</div>`}
  }

  function openNcDialog(findingId,inspectionId,code){
    const dialog=document.getElementById('insp-nc-dialog');
    document.getElementById('insp-nc-title').textContent=`Convertir hallazgo a No Conformidad · ${code}`;
    document.getElementById('insp-nc-fields').innerHTML=`
      <label>Responsable<select name="owner" required>${profileOptions()}</select></label>
      <label>Fecha límite<input name="due" type="date"></label>`;
    const form=document.getElementById('insp-nc-form');
    form.onsubmit=async ev=>{
      ev.preventDefault();
      const fd=new FormData(form);
      try{
        await inspectionFindingToNonconformity(findingId,fd.get('owner'),fd.get('due')||null);
        dialog.close();
        await openDetail(inspectionId,code);
      }catch(e){document.getElementById('insp-status').innerHTML=`<div class="status bad">${esc(e.message)}</div>`}
    };
    dialog.showModal();
  }

  function openCapaDialog(findingId,inspectionId,code){
    const dialog=document.getElementById('insp-nc-dialog');
    document.getElementById('insp-nc-title').textContent=`Crear CAPA · ${code}`;
    document.getElementById('insp-nc-fields').innerHTML=`
      <label>Plan de acción<textarea name="plan" required></textarea></label>
      <label>Responsable<select name="owner" required>${profileOptions()}</select></label>
      <label>Fecha límite<input name="due" type="date"></label>`;
    const form=document.getElementById('insp-nc-form');
    form.onsubmit=async ev=>{
      ev.preventDefault();
      const fd=new FormData(form);
      try{
        await inspectionFindingCreateCapa(findingId,fd.get('plan'),fd.get('owner'),fd.get('due')||null);
        dialog.close();
        await openDetail(inspectionId,code);
      }catch(e){document.getElementById('insp-status').innerHTML=`<div class="status bad">${esc(e.message)}</div>`}
    };
    dialog.showModal();
  }

  document.getElementById('insp-new').onclick=()=>document.getElementById('insp-dialog').showModal();
  document.getElementById('insp-cancel').onclick=()=>document.getElementById('insp-dialog').close();
  document.getElementById('insp-nc-cancel').onclick=()=>document.getElementById('insp-nc-dialog').close();
  document.getElementById('insp-form').onsubmit=async(ev)=>{
    ev.preventDefault();
    const pending=[...findingsHolder.querySelectorAll('[data-finding-row]')].filter(r=>!r.querySelector('[data-result]').value);
    if(pending.length){document.getElementById('insp-status').innerHTML=`<div class="status warn">Faltan ${pending.length} criterio(s) por evaluar.</div>`;pending[0].scrollIntoView({block:'center'});return}
    const rows=[...findingsHolder.querySelectorAll('[data-finding-row]')].map(row=>({
      section_name:row.querySelector('[name=section_name]').value.trim(),
      criterion_no:row.dataset.n,
      criterion:row.querySelector('[name=criterion]').value.trim(),
      result:row.querySelector('[name=result]').value,
      observation:row.querySelector('[name=observation]').value.trim()||null,
      severity:row.querySelector('[name=result]').value==='NC'?3:null
    }));
    const compliant=rows.filter(r=>r.result==='C').length;
    const nonconforming=rows.filter(r=>r.result==='NC').length;
    const notApplicable=rows.filter(r=>r.result==='NA').length;
    const rated=rows.filter(r=>r.result!=='NA').length;
    try{
      await createInspection({
        inspection_code:document.getElementById('insp-code').value.trim(),
        inspection_date:document.getElementById('insp-date').value,
        branch_id:document.getElementById('insp-branch').value,
        inspection_type:document.getElementById('insp-type').value,
        site_responsible:document.getElementById('insp-responsible').value.trim()||null,
        status:'FINALIZADA',
        compliant_count:compliant,
        nonconforming_count:nonconforming,
        not_applicable_count:notApplicable,
        compliance_pct:rated?Math.round((compliant/rated)*100):null,
        overall_rating:nonconforming>0?'CON_OBSERVACIONES':'SATISFACTORIO'
      },rows);
      document.getElementById('insp-dialog').close();
      ev.target.reset();
      findingsHolder.innerHTML=STANDARD_CHECKLIST.map((c,i)=>findingRow(i+1,{section_name:c[0],criterion:c[1]})).join('');
      findingCount=STANDARD_CHECKLIST.length;
      bindRemovals();
      updateProgress();
      await load();
    }catch(e){document.getElementById('insp-status').innerHTML=`<div class="status bad">${esc(e.message)}</div>`}
  };
  await load();
}
