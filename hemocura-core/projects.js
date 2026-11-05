import { bloodData } from './blood-operations-data.js';
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);
const STATUSES=['PLANIFICADO','EN_PROGRESO','COMPLETADO','SUSPENDIDO'];
const DOMAINS=['OPERACIONES','SGC','COMPLIANCE','TECNOLOGIA','CAPACITACION'];

export async function mountProjects(root){
  let allRows=[];let fStatus='';let fDomain='';

  root.innerHTML=`<div class="sales-toolbar"><div><h2 class="section-heading">Gestión de Proyectos</h2>
  <div class="muted">Portafolio de Operaciones, SGC, Compliance, Tecnología y Capacitación.</div></div>
  <button id="pm-new">Nuevo proyecto</button></div>
  <div id="pm-msg"></div><div class="grid sales-kpis" id="pm-kpis"></div>
  <div class="filter-grid" id="pm-filters">
    <label>Estado<select id="pm-f-status"><option value="">Todos</option>${STATUSES.map(s=>`<option value="${esc(s)}">${esc(s)}</option>`).join('')}</select></label>
    <label>Dominio<select id="pm-f-domain"><option value="">Todos</option>${DOMAINS.map(d=>`<option value="${esc(d)}">${esc(d)}</option>`).join('')}</select></label>
  </div>
  <section class="card"><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Código</th><th>Proyecto</th><th>Dominio</th><th>Prioridad</th><th>Estado</th><th>Avance</th><th>Meta</th><th>Tareas</th><th>Vencidas</th></tr></thead>
  <tbody id="pm-body"></tbody></table></div></section>

  <dialog id="pm-dialog" class="sales-dialog"><form id="pm-form"><h3>Nuevo proyecto</h3>
  <label>Código<input id="pm-code" required></label><label>Título<input id="pm-title" required></label>
  <label>Dominio<select id="pm-domain">${DOMAINS.map(d=>`<option>${d}</option>`).join('')}</select></label>
  <label>Prioridad<select id="pm-priority"><option>MEDIA</option><option>ALTA</option><option>CRITICA</option><option>BAJA</option></select></label>
  <label>Fecha inicio<input id="pm-start" type="date"></label><label>Fecha meta<input id="pm-target" type="date"></label>
  <label>Objetivo<textarea id="pm-objective"></textarea></label><label>Resultado esperado<textarea id="pm-result"></textarea></label>
  <div class="dialog-actions"><button type="button" id="pm-cancel" class="secondary">Cancelar</button><button>Guardar</button></div></form></dialog>

  <dialog id="pm-detail" class="sales-dialog"><form id="pm-detail-form"><h3 id="pm-detail-title">Detalle del proyecto</h3>
  <input type="hidden" id="pd-id">
  <label>Código<input id="pd-code" readonly></label><label>Título<input id="pd-title" required></label>
  <label>Dominio<select id="pd-domain">${DOMAINS.map(d=>`<option>${d}</option>`).join('')}</select></label>
  <label>Prioridad<select id="pd-priority"><option>MEDIA</option><option>ALTA</option><option>CRITICA</option><option>BAJA</option></select></label>
  <label>Estado<select id="pd-status">${STATUSES.map(s=>`<option>${s}</option>`).join('')}</select></label>
  <label>Avance %<input id="pd-progress" type="number" min="0" max="100"></label>
  <label>Fecha inicio<input id="pd-start" type="date"></label><label>Fecha meta<input id="pd-target" type="date"></label>
  <label>Objetivo<textarea id="pd-objective"></textarea></label><label>Resultado esperado<textarea id="pd-result"></textarea></label>
  <div class="dialog-actions"><button type="button" id="pd-cancel" class="secondary">Cancelar</button><button>Guardar cambios</button></div></form></dialog>`;

  function v(id){return document.getElementById(id).value.trim()}

  function renderTable(){
    const rows=allRows.filter(r=>{
      if(fStatus&&r.status!==fStatus)return false;
      if(fDomain&&r.domain!==fDomain)return false;
      return true;
    });
    const inProgress=rows.filter(r=>r.status==='EN_PROGRESO').length;
    const completed=rows.filter(r=>r.status==='COMPLETADO').length;
    const overdue=rows.filter(r=>r.target_date&&r.target_date<today()&&r.status!=='COMPLETADO').length;
    document.getElementById('pm-kpis').innerHTML=`
      <section class="card"><div class="muted">Proyectos</div><div class="kpi">${rows.length}</div></section>
      <section class="card"><div class="muted">En progreso</div><div class="kpi">${inProgress}</div></section>
      <section class="card"><div class="muted">Completados</div><div class="kpi">${completed}</div></section>
      <section class="card"><div class="muted">Vencidos</div><div class="kpi">${overdue}</div></section>`;
    document.getElementById('pm-body').innerHTML=rows.length?rows.map(r=>`<tr data-pid="${esc(r.id)}" style="cursor:pointer">
      <td><code>${esc(r.project_code)}</code></td><td>${esc(r.title)}</td><td>${esc(r.domain)}</td><td>${esc(r.priority)}</td>
      <td><span class="status ${r.status==='COMPLETADO'?'ok':r.status==='SUSPENDIDO'?'bad':'info'}">${esc(r.status)}</span></td>
      <td>${esc(r.progress_pct)}%</td><td>${r.target_date&&r.target_date<today()&&r.status!=='COMPLETADO'?`<span class="status bad">${esc(r.target_date)}</span>`:esc(r.target_date||'—')}</td>
      <td>${esc(r.tasks)}</td><td>${esc(r.overdue_tasks)}</td></tr>`).join(''):'<tr><td colspan="9">Sin proyectos.</td></tr>';
    document.querySelectorAll('[data-pid]').forEach(tr=>tr.onclick=()=>{
      const r=allRows.find(x=>x.id===tr.dataset.pid);if(!r)return;
      document.getElementById('pd-id').value=r.id;
      document.getElementById('pd-code').value=r.project_code||'';
      document.getElementById('pd-title').value=r.title||'';
      document.getElementById('pd-domain').value=r.domain||'OPERACIONES';
      document.getElementById('pd-priority').value=r.priority||'MEDIA';
      document.getElementById('pd-status').value=r.status||'PLANIFICADO';
      document.getElementById('pd-progress').value=r.progress_pct||0;
      document.getElementById('pd-start').value=r.start_date||'';
      document.getElementById('pd-target').value=r.target_date||'';
      document.getElementById('pd-objective').value=r.objective||'';
      document.getElementById('pd-result').value=r.expected_result||'';
      document.getElementById('pm-detail-title').textContent=r.project_code+' · '+r.title;
      document.getElementById('pm-detail').showModal();
    });
  }

  async function load(){
    try{allRows=await bloodData.projects();renderTable();document.getElementById('pm-msg').innerHTML=''}
    catch(e){document.getElementById('pm-msg').innerHTML=`<div class="status warn">${esc(e.message)} · Instale SQL v0.23.0.</div>`}
  }

  document.getElementById('pm-f-status').onchange=e=>{fStatus=e.target.value;renderTable()};
  document.getElementById('pm-f-domain').onchange=e=>{fDomain=e.target.value;renderTable()};
  document.getElementById('pm-new').onclick=()=>document.getElementById('pm-dialog').showModal();
  document.getElementById('pm-cancel').onclick=()=>document.getElementById('pm-dialog').close();
  document.getElementById('pd-cancel').onclick=()=>document.getElementById('pm-detail').close();

  document.getElementById('pm-form').onsubmit=async e=>{e.preventDefault();
    try{await bloodData.createProject({project_code:v('pm-code'),title:v('pm-title'),domain:v('pm-domain'),priority:v('pm-priority'),start_date:v('pm-start')||null,target_date:v('pm-target')||null,objective:v('pm-objective')||null,expected_result:v('pm-result')||null,status:'PLANIFICADO'});
    document.getElementById('pm-dialog').close();e.target.reset();await load()}
    catch(x){document.getElementById('pm-msg').innerHTML=`<div class="status bad">${esc(x.message)}</div>`}};

  document.getElementById('pm-detail-form').onsubmit=async e=>{e.preventDefault();
    try{await bloodData.updateProject(v('pd-id'),{title:v('pd-title'),domain:v('pd-domain'),priority:v('pd-priority'),status:v('pd-status'),progress_pct:Number(v('pd-progress'))||0,start_date:v('pd-start')||null,target_date:v('pd-target')||null,objective:v('pd-objective')||null,expected_result:v('pd-result')||null});
    document.getElementById('pm-detail').close();await load()}
    catch(x){document.getElementById('pm-msg').innerHTML=`<div class="status bad">${esc(x.message)}</div>`}};

  await load();
}
