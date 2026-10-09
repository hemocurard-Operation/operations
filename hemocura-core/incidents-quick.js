import { getBranches } from './sales-data.js';
import { createIncident, getIncidents } from './quality-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);
const nowTime=()=>new Date().toTimeString().slice(0,5);
const stamp=()=>`INC-${new Date().toISOString().replace(/[-:TZ.]/g,'').slice(0,14)}`;

export async function mountIncidentsQuick(root){
  const branches=await getBranches();
  const branchMap=Object.fromEntries(branches.map(b=>[b.id,b.name]));
  let rows=[];

  root.innerHTML=`
    <div class="sales-toolbar"><div><h2 class="section-heading">Reportar incidencia</h2><div class="muted">Describe qué ocurrió. Calidad hará la clasificación y el seguimiento cuando corresponda.</div></div><button id="inc-new">Nueva incidencia</button></div>
    <div id="inc-msg"></div>
    <section class="card quick-capture"><div class="quick-capture-head"><div><div class="eyebrow">Captura rápida</div><h3>Qué ocurrió</h3></div></div><p class="muted">El reporte operativo evita pedir causa raíz, CAPA o clasificación ISO al usuario que detecta el evento.</p></section>
    <section class="card"><div class="card-head"><h3>Incidencias recientes</h3><span id="inc-count" class="muted"></span></div><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Código</th><th>Sucursal</th><th>Proceso</th><th>Descripción</th><th>Seguimiento</th></tr></thead><tbody id="inc-body"></tbody></table></div></section>

    <dialog id="inc-dialog" class="sales-dialog"><form id="inc-form"><h3>Nueva incidencia</h3>
      <label>¿Qué ocurrió?<textarea id="inc-description" required autofocus placeholder="Describe el hecho observado, sin analizar la causa."></textarea></label>
      <label>Sucursal<select id="inc-branch"><option value="">Corporativo / no aplica</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
      <label>Proceso o área<input id="inc-process" placeholder="Ej. Colecta, Tamizaje, Inventario"></label>
      <label>Acción inmediata tomada<textarea id="inc-action" placeholder="Ej. se aisló la unidad, se notificó al supervisor"></textarea></label>
      <details class="advanced-fields"><summary>Datos adicionales</summary>
        <label>Código<input id="inc-code"></label><div class="filter-grid"><label>Fecha<input id="inc-date" type="date"></label><label>Hora<input id="inc-time" type="time"></label></div>
        <label>Clasificación preliminar<input id="inc-classification" placeholder="Opcional; Calidad puede completar después"></label>
        <label>Severidad preliminar<select id="inc-severity"><option value="">Sin clasificar</option><option value="1">1</option><option value="2">2</option><option value="3">3</option><option value="4">4</option><option value="5">5</option></select></label>
        <label><input id="inc-affected" type="checkbox"> Paciente o donante potencialmente afectado</label>
        <label>Impacto observado<textarea id="inc-impact"></textarea></label>
        <label>Evidencia / referencia<input id="inc-evidence" placeholder="URL o referencia, si existe"></label>
      </details>
      <div id="inc-form-msg" role="status" aria-live="polite"></div>
      <div class="dialog-actions"><button type="button" id="inc-cancel" class="secondary">Cancelar</button><button type="submit">Reportar incidencia</button></div>
    </form></dialog>`;

  function defaults(){const f=document.getElementById('inc-form');f.reset();document.getElementById('inc-code').value=stamp();document.getElementById('inc-date').value=today();document.getElementById('inc-time').value=nowTime();if(branches.length===1)document.getElementById('inc-branch').value=branches[0].id;document.getElementById('inc-form-msg').textContent=''}
  function render(){document.getElementById('inc-count').textContent=`${rows.length} registro(s)`;document.getElementById('inc-body').innerHTML=rows.length?rows.map(r=>`<tr><td>${esc(r.incident_date)} ${esc(r.incident_time||'')}</td><td><code>${esc(r.incident_code||'—')}</code></td><td>${esc(branchMap[r.branch_id]||'Corporativo')}</td><td>${esc(r.process_name||'—')}</td><td>${esc(r.description)}</td><td>${r.requires_quality_followup?'<span class="status warn">Calidad</span>':'<span class="status ok">No requerido</span>'}</td></tr>`).join(''):'<tr><td colspan="6">Sin incidencias recientes.</td></tr>'}
  async function load(){try{rows=await getIncidents({});render()}catch(err){document.getElementById('inc-msg').innerHTML=`<div class="status warn">${esc(err.message)}</div>`}}

  document.getElementById('inc-new').onclick=()=>{defaults();document.getElementById('inc-dialog').showModal()};
  document.getElementById('inc-cancel').onclick=()=>document.getElementById('inc-dialog').close();
  document.getElementById('inc-form').onsubmit=async ev=>{ev.preventDefault();const btn=ev.submitter;if(btn.disabled)return;btn.disabled=true;btn.textContent='Reportando…';const msg=document.getElementById('inc-form-msg');try{await createIncident({incidentCode:document.getElementById('inc-code').value.trim()||stamp(),incidentDate:document.getElementById('inc-date').value||today(),incidentTime:document.getElementById('inc-time').value||null,branchId:document.getElementById('inc-branch').value||null,classification:document.getElementById('inc-classification').value.trim()||null,processName:document.getElementById('inc-process').value.trim()||null,severity:document.getElementById('inc-severity').value?Number(document.getElementById('inc-severity').value):null,description:document.getElementById('inc-description').value.trim(),patientOrDonorAffected:document.getElementById('inc-affected').checked,impactDetail:document.getElementById('inc-impact').value.trim()||null,immediateAction:document.getElementById('inc-action').value.trim()||null,evidenceUrl:document.getElementById('inc-evidence').value.trim()||null,requiresQualityFollowup:true});document.getElementById('inc-dialog').close();document.getElementById('inc-msg').innerHTML='<div class="status ok">Incidencia reportada y enviada a seguimiento de Calidad.</div>';await load()}catch(err){msg.innerHTML=`<div class="status bad">${esc(err.message)}. Los datos permanecen en el formulario.</div>`}finally{btn.disabled=false;btn.textContent='Reportar incidencia'}};
  await load();
}
