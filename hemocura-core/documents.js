import {filterRoutes} from './access-control.js';
import {routeList} from './router.js';
import { listDocumentRegister, listActiveProfiles, createDocument, updateDocument, listDocumentChanges, createDocumentChange, updateDocumentChange } from './integrated-qms-data.js';

const RESOURCES=[
['HC-SGC-IMP-001','Guía de implementación por etapas','./docs/recursos/HC-SGC-IMP-001_Guia_Implementacion_SGC.html','BORRADOR PARA APROBACIÓN'],
['HC-SGC-MC-01','Documento Maestro: adaptación v3','./docs/recursos/HC-SGC-MC-01_Documento_Maestro_v3_Borrador.html','BORRADOR · v2 CONSERVADO COMO ANTECEDENTE'],
['HC-SGC-ARQ','Arquitectura documental conectada v2','./docs/recursos/HC-SGC-ARQ_Arquitectura_v2_Borrador.html','BORRADOR'],
['HC-TRN-SUITE-001','Programa de Capacitación: correspondencia con el proyecto','./docs/recursos/HC-SGC-IMP-001_Guia_Implementacion_SGC.html#capacitacion','CONSULTAR VERSIÓN Y ESTADO EN REGISTRO'],
['HC-CMP-AUD-001','Auditoría Penal + SGC: antecedente y anexo','./docs/recursos/HC-CMP-Auditoria-Penal-SGC-V2.html','REQUIERE VALIDACIÓN JURÍDICA'],
['HC-CMP-MC-001','Manual de Compliance Penal','./docs/recursos/HC-CMP-MC-001_Manual_Compliance_Penal.md','BORRADOR · REQUIERE VALIDACIÓN JURÍDICA']
];

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);

const STATUS_COLORS={BORRADOR:'#6b7280',EN_REVISION:'#f59e0b',APROBADO:'#3b82f6',VIGENTE:'#10b981',OBSOLETO:'#ef4444',DEROGADO:'#ef4444'};
function statusBadge(s){const bg=STATUS_COLORS[s]||'#6b7280';return `<span style="display:inline-block;padding:2px 8px;border-radius:999px;font-size:0.8em;color:#fff;background:${bg}">${esc(s)}</span>`}

const DOC_TYPES=['PROCEDIMIENTO','MANUAL','INSTRUCTIVO','FORMATO','REGISTRO','PLAN','POLITICA'];

export async function mountDocuments(root){
  const [profiles]=await Promise.all([listActiveProfiles()]);
  const profileMap=Object.fromEntries(profiles.map(p=>[p.id,p.full_name]));
  let implementationAllowed=false;try{implementationAllowed=(await filterRoutes(routeList())).some(([key])=>key==='sgcimplementation')}catch{}

  function profileOptions(selected){return `<option value="">Seleccionar…</option>${profiles.map(p=>`<option value="${esc(p.id)}" ${p.id===selected?'selected':''}>${esc(p.full_name)}</option>`).join('')}`}

  root.innerHTML=`
    <div class="sales-toolbar"><div><h2 class="section-heading">Control Documental</h2>
    <div class="muted">Ciclo de vida completo: crear, revisar, aprobar, versionar y obsolescer documentos ISO 9001 / 15189.</div></div>
    <button id="doc-new">Nuevo documento</button></div>
    <div id="doc-status"></div>
    <div class="grid sales-kpis" id="doc-kpis"></div>

    <section class="card"><h3>Lista Maestra de Documentos</h3>
    <div class="filter-grid" style="margin-bottom:12px">
      <label>Estado <select id="doc-filter-status"><option value="">Todos</option>${Object.keys(STATUS_COLORS).map(s=>`<option>${s}</option>`).join('')}</select></label>
      <label>Tipo <select id="doc-filter-type"><option value="">Todos</option>${DOC_TYPES.map(t=>`<option>${t}</option>`).join('')}</select></label>
    </div>
    <div class="table-wrap"><table class="data-table">
    <thead><tr><th>Código</th><th>Título</th><th>Área</th><th>Tipo</th><th>Versión</th><th>Estado</th><th>Responsable</th><th>Vigencia</th><th>Revisión</th><th></th></tr></thead>
    <tbody id="doc-body"></tbody></table></div></section>

    <section class="card" id="doc-detail" style="display:none"></section>

    ${implementationAllowed?'<section class="card"><h3>Proyecto de implementación del SGC</h3><p>Organice alcance, responsables, entregables y evidencia siguiendo seis fases y doce puertas.</p><a href="#sgcimplementation">Abrir proyecto guiado →</a></section>':''}

    <section class="card"><h3>Recursos integrados</h3><div class="table-wrap"><table class="data-table">
    <thead><tr><th>Código</th><th>Documento</th><th>Estado</th><th></th></tr></thead><tbody>
    ${RESOURCES.map(x=>`<tr><td><code>${esc(x[0])}</code></td><td>${esc(x[1])}</td><td>${esc(x[3])}</td><td><a class="secondary compact" href="${x[2]}" target="_blank" rel="noopener">Abrir</a></td></tr>`).join('')}
    </tbody></table></div></section>

    <dialog id="doc-dialog" class="sales-dialog"><form id="doc-form">
      <h3 id="doc-dialog-title">Nuevo documento</h3>
      <div class="filter-grid">
        <label>Código<input id="df-code" required placeholder="HC-SGC-XXX-001"></label>
        <label>Título<input id="df-title" required></label>
        <label>Área<input id="df-area" required placeholder="Laboratorio, Calidad, etc."></label>
        <label>Tipo<select id="df-type">${DOC_TYPES.map(t=>`<option>${t}</option>`).join('')}</select></label>
        <label>Versión<input id="df-version" value="01" required></label>
        <label>Responsable<select id="df-owner">${profileOptions()}</select></label>
        <label>Fecha de revisión<input id="df-review" type="date"></label>
        <label>Copia controlada<select id="df-controlled"><option value="true">Sí</option><option value="false">No</option></select></label>
      </div>
      <label>Notas<textarea id="df-notes" rows="2"></textarea></label>
      <div class="dialog-actions"><button type="button" id="doc-cancel" class="secondary">Cancelar</button><button type="submit">Guardar</button></div>
    </form></dialog>

    <dialog id="doc-change-dialog" class="sales-dialog"><form id="doc-change-form">
      <h3>Solicitud de cambio</h3>
      <input type="hidden" id="dc-doc-id">
      <div class="filter-grid">
        <label>Razón del cambio<textarea id="dc-reason" required rows="2"></textarea></label>
        <label>Evaluación de impacto<textarea id="dc-impact" rows="2"></textarea></label>
      </div>
      <div class="dialog-actions"><button type="button" id="dc-cancel" class="secondary">Cancelar</button><button type="submit">Solicitar</button></div>
    </form></dialog>

    <dialog id="doc-version-dialog" class="sales-dialog"><form id="doc-version-form">
      <h3>Nueva versión</h3>
      <input type="hidden" id="dv-doc-id">
      <div class="filter-grid">
        <label>Nueva versión<input id="dv-version" required></label>
      </div>
      <div class="dialog-actions"><button type="button" id="dv-cancel" class="secondary">Cancelar</button><button type="submit">Crear versión</button></div>
    </form></dialog>`;

  let allDocs=[];

  function msg(html){document.getElementById('doc-status').innerHTML=html}

  async function load(){
    try{
      allDocs=await listDocumentRegister();
      renderTable();
      renderKpis();
      msg('');
    }catch(e){msg(`<div class="status warn">${esc(e.message)}</div>`)}
  }

  function renderKpis(){
    const total=allDocs.length;
    const vigentes=allDocs.filter(d=>d.status==='VIGENTE').length;
    const enRevision=allDocs.filter(d=>d.status==='EN_REVISION').length;
    const overdue=allDocs.filter(d=>d.review_date&&d.review_date<today()&&d.status==='VIGENTE').length;
    document.getElementById('doc-kpis').innerHTML=`
      <section class="card"><div class="muted">Total documentos</div><div class="kpi">${total}</div></section>
      <section class="card"><div class="muted">Vigentes</div><div class="kpi">${vigentes}</div></section>
      <section class="card"><div class="muted">En revisión</div><div class="kpi">${enRevision}</div></section>
      <section class="card"><div class="muted">Revisión vencida</div><div class="kpi" style="${overdue?'color:#ef4444':''}">${overdue}</div></section>`;
  }

  function renderTable(){
    const fs=document.getElementById('doc-filter-status').value;
    const ft=document.getElementById('doc-filter-type').value;
    let rows=allDocs;
    if(fs) rows=rows.filter(d=>d.status===fs);
    if(ft) rows=rows.filter(d=>d.document_type===ft);
    document.getElementById('doc-body').innerHTML=rows.length?rows.map(d=>`<tr>
      <td><code>${esc(d.document_code)}</code></td>
      <td>${esc(d.title)}</td><td>${esc(d.area)}</td><td>${esc(d.document_type)}</td>
      <td>${esc(d.version)}</td><td>${statusBadge(d.status)}</td>
      <td>${esc(profileMap[d.owner_user_id]||'—')}</td>
      <td>${esc(d.effective_date||'—')}</td>
      <td>${esc(d.review_date||'—')}</td>
      <td style="white-space:nowrap">
        ${d.status==='BORRADOR'?`<button type="button" data-submit="${esc(d.id)}" class="compact">Enviar a revisión</button>`:''}
        ${d.status==='EN_REVISION'?`<button type="button" data-approve="${esc(d.id)}" class="compact">Aprobar</button><button type="button" data-reject="${esc(d.id)}" class="compact secondary">Rechazar</button>`:''}
        ${d.status==='APROBADO'?`<button type="button" data-publish="${esc(d.id)}" class="compact">Publicar</button>`:''}
        ${d.status==='VIGENTE'?`<button type="button" data-newver="${esc(d.id)}" data-code="${esc(d.document_code)}" data-ver="${esc(d.version)}" class="compact">Nueva versión</button><button type="button" data-obsolete="${esc(d.id)}" class="compact secondary">Obsolescer</button>`:''}
        <button type="button" data-detail="${esc(d.id)}" data-code="${esc(d.document_code)}" class="compact secondary">Cambios</button>
      </td>
    </tr>`).join(''):'<tr><td colspan="10" class="muted">Sin documentos registrados.</td></tr>';
    bindTableActions();
  }

  function bindTableActions(){
    document.querySelectorAll('[data-submit]').forEach(b=>b.onclick=async()=>{
      try{await updateDocument(b.dataset.submit,{status:'EN_REVISION'});await load()}catch(e){msg(`<div class="status bad">${esc(e.message)}</div>`)}
    });
    document.querySelectorAll('[data-approve]').forEach(b=>b.onclick=async()=>{
      try{await updateDocument(b.dataset.approve,{status:'APROBADO',approved_at:new Date().toISOString()});await load()}catch(e){msg(`<div class="status bad">${esc(e.message)}</div>`)}
    });
    document.querySelectorAll('[data-reject]').forEach(b=>b.onclick=async()=>{
      try{await updateDocument(b.dataset.reject,{status:'BORRADOR',approver_user_id:null,approved_at:null});await load()}catch(e){msg(`<div class="status bad">${esc(e.message)}</div>`)}
    });
    document.querySelectorAll('[data-publish]').forEach(b=>b.onclick=async()=>{
      try{await updateDocument(b.dataset.publish,{status:'VIGENTE',effective_date:today()});await load()}catch(e){msg(`<div class="status bad">${esc(e.message)}</div>`)}
    });
    document.querySelectorAll('[data-obsolete]').forEach(b=>b.onclick=async()=>{
      try{await updateDocument(b.dataset.obsolete,{status:'OBSOLETO'});await load()}catch(e){msg(`<div class="status bad">${esc(e.message)}</div>`)}
    });
    document.querySelectorAll('[data-newver]').forEach(b=>b.onclick=()=>{
      document.getElementById('dv-doc-id').value=b.dataset.newver;
      const cur=parseInt(b.dataset.ver,10)||1;
      document.getElementById('dv-version').value=String(cur+1).padStart(2,'0');
      document.getElementById('doc-version-dialog').showModal();
    });
    document.querySelectorAll('[data-detail]').forEach(b=>b.onclick=()=>openDetail(b.dataset.detail,b.dataset.code));
  }

  async function openDetail(docId,code){
    const detail=document.getElementById('doc-detail');
    detail.style.display='';
    detail.innerHTML='<p>Cargando cambios…</p>';
    try{
      const changes=await listDocumentChanges(docId);
      detail.innerHTML=`<h3>Historial de cambios · ${esc(code)}</h3>
        <button type="button" id="doc-req-change" data-doc="${esc(docId)}" style="margin-bottom:10px">Solicitar cambio</button>
        ${changes.length?`<div class="table-wrap"><table class="data-table">
        <thead><tr><th>Fecha</th><th>Solicitante</th><th>Razón</th><th>Impacto</th><th>Versión ant.</th><th>Versión nueva</th><th>Estado</th><th></th></tr></thead>
        <tbody>${changes.map(c=>`<tr>
          <td>${esc(new Date(c.change_date).toLocaleDateString('es-DO'))}</td>
          <td>${esc(profileMap[c.requested_by]||'—')}</td>
          <td>${esc(c.change_reason)}</td><td>${esc(c.impact_assessment||'—')}</td>
          <td>${esc(c.previous_version||'—')}</td><td>${esc(c.new_version||'—')}</td>
          <td>${statusBadge(c.status)}</td>
          <td>${c.status==='PENDIENTE'?`<button type="button" data-approve-change="${esc(c.id)}" class="compact">Aprobar</button><button type="button" data-reject-change="${esc(c.id)}" class="compact secondary">Rechazar</button>`:''}</td>
        </tr>`).join('')}</tbody></table></div>`:'<p class="muted">Sin cambios registrados.</p>'}`;
      document.getElementById('doc-req-change').onclick=()=>{
        document.getElementById('dc-doc-id').value=docId;
        document.getElementById('doc-change-dialog').showModal();
      };
      detail.querySelectorAll('[data-approve-change]').forEach(b=>b.onclick=async()=>{
        try{await updateDocumentChange(b.dataset.approveChange,{status:'APROBADO',approved_at:new Date().toISOString()});await openDetail(docId,code)}catch(e){msg(`<div class="status bad">${esc(e.message)}</div>`)}
      });
      detail.querySelectorAll('[data-reject-change]').forEach(b=>b.onclick=async()=>{
        try{await updateDocumentChange(b.dataset.rejectChange,{status:'RECHAZADO'});await openDetail(docId,code)}catch(e){msg(`<div class="status bad">${esc(e.message)}</div>`)}
      });
    }catch(e){detail.innerHTML=`<div class="status bad">${esc(e.message)}</div>`}
  }

  document.getElementById('doc-filter-status').onchange=renderTable;
  document.getElementById('doc-filter-type').onchange=renderTable;

  document.getElementById('doc-new').onclick=()=>{
    document.getElementById('doc-dialog-title').textContent='Nuevo documento';
    document.getElementById('doc-form').reset();
    document.getElementById('df-version').value='01';
    document.getElementById('doc-dialog').showModal();
  };
  document.getElementById('doc-cancel').onclick=()=>document.getElementById('doc-dialog').close();
  document.getElementById('dc-cancel').onclick=()=>document.getElementById('doc-change-dialog').close();
  document.getElementById('dv-cancel').onclick=()=>document.getElementById('doc-version-dialog').close();

  document.getElementById('doc-form').onsubmit=async e=>{
    e.preventDefault();
    try{
      await createDocument({
        document_code:document.getElementById('df-code').value.trim(),
        title:document.getElementById('df-title').value.trim(),
        area:document.getElementById('df-area').value.trim(),
        document_type:document.getElementById('df-type').value,
        version:document.getElementById('df-version').value.trim(),
        owner_user_id:document.getElementById('df-owner').value||null,
        review_date:document.getElementById('df-review').value||null,
        controlled_copy:document.getElementById('df-controlled').value==='true',
        notes:document.getElementById('df-notes').value.trim()||null,
        status:'BORRADOR'
      });
      document.getElementById('doc-dialog').close();
      await load();
    }catch(err){msg(`<div class="status bad">${esc(err.message)}</div>`)}
  };

  document.getElementById('doc-change-form').onsubmit=async e=>{
    e.preventDefault();
    const docId=document.getElementById('dc-doc-id').value;
    const doc=allDocs.find(d=>d.id===docId);
    try{
      await createDocumentChange({
        document_id:docId,
        change_reason:document.getElementById('dc-reason').value.trim(),
        impact_assessment:document.getElementById('dc-impact').value.trim()||null,
        previous_version:doc?.version||null,
        status:'PENDIENTE'
      });
      document.getElementById('doc-change-dialog').close();
      e.target.reset();
      await openDetail(docId,doc?.document_code||'');
    }catch(err){msg(`<div class="status bad">${esc(err.message)}</div>`)}
  };

  document.getElementById('doc-version-form').onsubmit=async e=>{
    e.preventDefault();
    const oldId=document.getElementById('dv-doc-id').value;
    const doc=allDocs.find(d=>d.id===oldId);
    const newVer=document.getElementById('dv-version').value.trim();
    try{
      await updateDocument(oldId,{status:'OBSOLETO'});
      // document_code is UNIQUE — append version to distinguish
      const newCode=doc.document_code.replace(/-v\d+$/,'')+'-v'+newVer;
      await createDocument({
        document_code:newCode,
        title:doc.title,
        area:doc.area,
        document_type:doc.document_type,
        version:newVer,
        owner_user_id:doc.owner_user_id,
        review_date:doc.review_date,
        controlled_copy:doc.controlled_copy,
        supersedes_code:doc.document_code,
        notes:doc.notes,
        status:'BORRADOR'
      });
      document.getElementById('doc-version-dialog').close();
      await load();
    }catch(err){msg(`<div class="status bad">${esc(err.message)}</div>`)}
  };

  await load();
}
