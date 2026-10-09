import { mountQmsActionBoard } from './qms-action-board.js';
import {
  loadQualityWorkspace,
  createIncident,
  createNonconformity,
  createCapa
} from './quality-data.js';
import { getBranches } from './sales-data.js';

const num = new Intl.NumberFormat('es-DO', { maximumFractionDigits:2 });
const LS_BRANCH='hc:capture:last-branch';

function esc(v='') {
  return String(v ?? '').replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

function todayISO(){ return new Date().toISOString().slice(0,10); }
function nowHHMM(){ return new Date().toTimeString().slice(0,5); }
function daysAgoISO(days=30){
  const d=new Date(); d.setDate(d.getDate()-days);
  return d.toISOString().slice(0,10);
}

function statusPill(status='') {
  const s=String(status).toUpperCase();
  const cls = ['CERRADA','CERRADO','EFECTIVA','COMPLETADA'].includes(s) ? 'stock-ok'
    : ['ABIERTA','ABIERTO','PENDIENTE'].includes(s) ? 'stock-warning'
    : 'stock-none';
  return `<span class="stock-pill ${cls}">${esc(status)}</span>`;
}

function severityPill(severity) {
  const n=Number(severity||0);
  const cls = n >= 5 ? 'sev-critical' : n >= 4 ? 'sev-high' : n >= 3 ? 'sev-medium' : 'sev-low';
  return `<span class="severity ${cls}">S${esc(n || '—')}</span>`;
}

function measurementRows(rows, branchMap) {
  if(!rows.length) return `<tr><td colspan="7" class="muted">No hay mediciones visibles para el filtro.</td></tr>`;
  return rows.map(r=>`
    <tr>
      <td>${esc(r.measurement_date)}</td>
      <td>${esc(branchMap[r.branch_id]?.name || (r.branch_id || 'Corporativo'))}</td>
      <td>${esc(r.process_code)} · ${esc(r.process_name)}</td>
      <td>${esc(r.indicator_code)}</td>
      <td><strong>${esc(r.indicator_name)}</strong></td>
      <td class="num">${num.format(Number(r.value||0))}</td>
      <td>${statusPill(r.status)}</td>
    </tr>`).join('');
}

function incidentRows(rows, branchMap) {
  if(!rows.length) return `<tr><td colspan="8" class="muted">No hay incidencias visibles.</td></tr>`;
  return rows.map(r=>`
    <tr>
      <td>${esc(r.incident_date)} ${esc(r.incident_time || '')}</td>
      <td>${esc(r.incident_code || '—')}</td>
      <td>${esc(branchMap[r.branch_id]?.name || 'Corporativo')}</td>
      <td>${esc(r.classification || '—')}</td>
      <td>${severityPill(r.severity)}</td>
      <td>${esc(r.process_name || '—')}</td>
      <td>${esc(r.description)}</td>
      <td>${r.requires_quality_followup ? '<span class="status warn">Seguimiento</span>' : '<span class="status ok">No requerido</span>'}</td>
    </tr>`).join('');
}

function ncRows(rows, branchMap) {
  if(!rows.length) return `<tr><td colspan="7" class="muted">No hay no conformidades visibles.</td></tr>`;
  return rows.map(r=>`
    <tr>
      <td>${esc(r.code)}</td>
      <td>${esc(r.detected_at ? new Date(r.detected_at).toLocaleString('es-DO') : '')}</td>
      <td>${esc(branchMap[r.branch_id]?.name || 'Corporativo')}</td>
      <td>${esc(r.description)}</td>
      <td>${esc(r.root_cause || 'Pendiente')}</td>
      <td>${statusPill(r.status)}</td>
      <td>${esc(r.due_date || '—')}</td>
    </tr>`).join('');
}

function capaRows(rows) {
  if(!rows.length) return `<tr><td colspan="8" class="muted">No hay acciones CAPA visibles.</td></tr>`;
  return rows.map(r=>`
    <tr>
      <td>${esc(r.code)}</td>
      <td>${esc(r.problem)}</td>
      <td>${esc(r.root_cause || 'Pendiente')}</td>
      <td>${esc(r.action_plan)}</td>
      <td>${esc(r.due_date || '—')}</td>
      <td>${statusPill(r.status)}</td>
      <td>${statusPill(r.effectiveness_status)}</td>
      <td>${esc(r.effectiveness_notes || '')}</td>
    </tr>`).join('');
}

function alertRows(rows) {
  if(!rows.length) return `<div class="status ok">No hay alertas abiertas visibles.</div>`;
  return rows.map(a=>`
    <article class="alert-row">
      <div>
        <span class="severity ${String(a.severity).toUpperCase()==='CRITICA'?'sev-critical':'sev-medium'}">${esc(a.severity)}</span>
        <strong>${esc(a.title)}</strong>
        <div class="muted">${esc(a.branch || 'Corporativo')} · ${esc(a.category)}</div>
      </div>
      <p>${esc(a.description || '')}</p>
    </article>`).join('');
}

function summarize(ws) {
  const openNc = ws.nonconformities.filter(x=>!['CERRADA','CERRADO'].includes(String(x.status).toUpperCase())).length;
  const openCapa = ws.capa.filter(x=>!['CERRADA','CERRADO','COMPLETADA'].includes(String(x.status).toUpperCase())).length;
  const overdueCapa = ws.capa.filter(x=>{
    if(!x.due_date) return false;
    const open=!['CERRADA','CERRADO','COMPLETADA'].includes(String(x.status).toUpperCase());
    return open && x.due_date < todayISO();
  }).length;
  const followup = ws.incidents.filter(x=>x.requires_quality_followup).length;
  return {openNc,openCapa,overdueCapa,followup};
}

export async function mountQuality(root) {
  if(!root) return;

  root.innerHTML=`<section class="card"><h3>Calidad</h3><div class="status info">Cargando SGC operativo…</div></section>`;

  try {
    const branches=await getBranches();
    const branchMap=Object.fromEntries(branches.map(b=>[b.id,b]));
    const state={workspace:null};

    root.innerHTML=`
      <div class="sales-toolbar">
        <div>
          <h2 class="section-heading">Sistema de Gestión de Calidad</h2>
          <div class="muted">Indicadores, incidencias, no conformidades, CAPA y alertas.</div>
        </div>
        <button id="quality-refresh" class="secondary">Actualizar</button>
      </div>

      <section class="card filters-card">
        <div class="filter-grid">
          <label>Desde<input id="quality-from" type="date" value="${daysAgoISO(30)}"></label>
          <label>Hasta<input id="quality-to" type="date" value="${todayISO()}"></label>
          <label>Sucursal<select id="quality-branch"><option value="">Todas las autorizadas</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
          <label>Medición del día<input id="quality-date" type="date" value="${todayISO()}"></label>
        </div>
        <button id="quality-search">Aplicar filtros</button>
      </section>

      <div id="quality-errors"></div>
      <div id="quality-summary"></div>

      <section class="card">
        <div class="card-head"><h3>Indicadores de calidad</h3><span class="muted">vw_quality_today</span></div>
        <div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Sucursal</th><th>Proceso</th><th>Código</th><th>Indicador</th><th>Valor</th><th>Estado</th></tr></thead><tbody id="quality-measurements"></tbody></table></div>
      </section>

      <section class="card">
        <div class="card-head"><div><h3>Incidencias</h3><span class="muted" id="incident-count"></span></div><button id="new-incident" class="secondary compact">Nueva incidencia</button></div>
        <div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Código</th><th>Sucursal</th><th>Clasificación</th><th>Severidad</th><th>Proceso</th><th>Descripción</th><th>Calidad</th></tr></thead><tbody id="incident-body"></tbody></table></div>
      </section>

      <section class="card">
        <div class="card-head"><h3>No conformidades</h3><button id="new-nc" class="secondary compact">Nueva NC</button></div>
        <div class="table-wrap"><table class="data-table"><thead><tr><th>Código</th><th>Detectada</th><th>Sucursal</th><th>Descripción</th><th>Causa raíz</th><th>Estado</th><th>Vence</th></tr></thead><tbody id="nc-body"></tbody></table></div>
      </section>

      <section class="card">
        <div class="card-head"><h3>CAPA</h3><button id="new-capa" class="secondary compact">Nueva CAPA</button></div>
        <div class="table-wrap"><table class="data-table"><thead><tr><th>Código</th><th>Problema</th><th>Causa raíz</th><th>Plan</th><th>Vence</th><th>Estado</th><th>Efectividad</th><th>Notas</th></tr></thead><tbody id="capa-body"></tbody></table></div>
      </section>

      <section class="card"><div class="card-head"><h3>Alertas abiertas</h3><span class="muted">Gestión</span></div><div id="quality-alerts" class="alerts-list"></div></section>

      <section class="card"><h3>Riesgos</h3><div class="status warn">El esquema v7.2 no contiene todavía una tabla específica de registro de riesgos. Este módulo queda reservado para una migración posterior; no se inventa estructura desde el frontend.</div></section>

      <dialog id="incident-dialog" class="sales-dialog">
        <form id="incident-form">
          <h3>Reporte rápido de incidencia</h3>
          <div class="status info">Fecha, hora y sucursal se precargan. El seguimiento de Calidad se selecciona de forma explícita; no se decide automáticamente por severidad.</div>
          <div class="quick-form-grid">
            <label>Código<input id="incident-code" required placeholder="INC-2026-001" autocomplete="off"></label>
            <label>Fecha<input id="incident-date" type="date" value="${todayISO()}" required></label>
            <label>Hora<input id="incident-time" type="time" value="${nowHHMM()}"></label>
            <label>Sucursal<select id="incident-branch" required><option value="">Seleccionar…</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
            <label>Clasificación<select id="incident-classification"><option>OPERATIVA</option><option>CALIDAD</option><option>SEGURIDAD</option><option>EQUIPO</option><option>REACTIVO</option><option>CADENA_FRIO</option><option>OTRA</option></select></label>
            <label>Área / proceso<input id="incident-process" list="incident-processes" autocomplete="off"><datalist id="incident-processes"><option value="Colecta"><option value="Tamizaje"><option value="Producción"><option value="Inventario"><option value="Despacho"><option value="Cadena de frío"><option value="Administración"></datalist></label>
            <label>Severidad<select id="incident-severity"><option value="1">1 · Leve</option><option value="2">2 · Menor</option><option value="3">3 · Moderada</option><option value="4">4 · Alta</option><option value="5">5 · Crítica</option></select></label>
            <label class="full">Descripción<textarea id="incident-description" required></textarea></label>
            <label class="full"><input id="incident-affected" type="checkbox"> Hubo afectación a paciente o donante</label>
            <label class="full">Detalle de afectación<textarea id="incident-impact" disabled></textarea></label>
            <label class="full">Acción inmediata<textarea id="incident-action"></textarea></label>
            <label class="full">Evidencia / URL<input id="incident-evidence" type="url" placeholder="https://…"></label>
            <label class="full"><input id="incident-followup" type="checkbox"> Requiere seguimiento por Calidad</label>
          </div>
          <div id="incident-status"></div>
          <div class="dialog-actions"><button type="button" id="incident-cancel" class="secondary">Cancelar</button><button type="submit">Guardar incidencia</button></div>
        </form>
      </dialog>

      <dialog id="nc-dialog" class="sales-dialog">
        <form id="nc-form" method="dialog">
          <h3>Nueva no conformidad</h3>
          <label>Código<input id="nc-code" required placeholder="NC-2026-001"></label>
          <label>Sucursal<select id="nc-branch"><option value="">Corporativo</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
          <label>Descripción<textarea id="nc-description" required></textarea></label>
          <label>Causa raíz<textarea id="nc-root"></textarea></label>
          <label>Fecha límite<input id="nc-due" type="date"></label>
          <div id="nc-status"></div>
          <div class="dialog-actions"><button type="button" id="nc-cancel" class="secondary">Cancelar</button><button type="submit">Guardar</button></div>
        </form>
      </dialog>

      <dialog id="capa-dialog" class="sales-dialog">
        <form id="capa-form" method="dialog">
          <h3>Nueva CAPA</h3>
          <label>Código<input id="capa-code" required placeholder="CAPA-2026-001"></label>
          <label>Problema<textarea id="capa-problem" required></textarea></label>
          <label>Causa raíz<textarea id="capa-root"></textarea></label>
          <label>Plan de acción<textarea id="capa-plan" required></textarea></label>
          <label>Fecha límite<input id="capa-due" type="date"></label>
          <div id="capa-status"></div>
          <div class="dialog-actions"><button type="button" id="capa-cancel" class="secondary">Cancelar</button><button type="submit">Guardar</button></div>
        </form>
      </dialog>

      <div id="qms-open-actions"></div>
      <div class="debug-strip">[HEMOCURA_QUALITY] listo</div>`;

    function applyIncidentDefaults(){
      document.getElementById('incident-date').value=todayISO();
      document.getElementById('incident-time').value=nowHHMM();
      const branch=localStorage.getItem(LS_BRANCH)||'';
      if(branch&&branches.some(b=>b.id===branch))document.getElementById('incident-branch').value=branch;
      document.getElementById('incident-impact').disabled=!document.getElementById('incident-affected').checked;
    }

    async function load() {
      const filters={from:document.getElementById('quality-from').value,to:document.getElementById('quality-to').value,branchId:document.getElementById('quality-branch').value,date:document.getElementById('quality-date').value};
      const ws=await loadQualityWorkspace(filters);state.workspace=ws;
      document.getElementById('quality-measurements').innerHTML=measurementRows(ws.measurements,branchMap);
      document.getElementById('incident-body').innerHTML=incidentRows(ws.incidents,branchMap);
      document.getElementById('nc-body').innerHTML=ncRows(ws.nonconformities,branchMap);
      document.getElementById('capa-body').innerHTML=capaRows(ws.capa);
      document.getElementById('quality-alerts').innerHTML=alertRows(ws.alerts);
      document.getElementById('incident-count').textContent=`${ws.incidents.length} incidencia(s)`;
      const s=summarize(ws);
      document.getElementById('quality-summary').innerHTML=`<div class="grid sales-kpis"><section class="card"><div class="muted">Incidencias con seguimiento</div><div class="kpi">${num.format(s.followup)}</div></section><section class="card"><div class="muted">NC abiertas</div><div class="kpi">${num.format(s.openNc)}</div></section><section class="card"><div class="muted">CAPA abiertas</div><div class="kpi">${num.format(s.openCapa)}</div></section><section class="card"><div class="muted">CAPA vencidas</div><div class="kpi">${num.format(s.overdueCapa)}</div></section></div>`;
      document.getElementById('quality-errors').innerHTML=ws.errors.length?`<div class="status warn">Carga parcial: ${esc(ws.errors.join(' · '))}</div>`:'';
      console.info('[HEMOCURA_QUALITY] módulo OK');
    }

    document.getElementById('quality-search').addEventListener('click',()=>load().catch(showError));
    document.getElementById('quality-refresh').addEventListener('click',()=>load().catch(showError));

    document.getElementById('new-incident').addEventListener('click',()=>{document.getElementById('incident-status').innerHTML='';document.getElementById('incident-form').reset();applyIncidentDefaults();document.getElementById('incident-dialog').showModal()});
    document.getElementById('incident-cancel').addEventListener('click',()=>document.getElementById('incident-dialog').close());
    document.getElementById('incident-affected').addEventListener('change',e=>{document.getElementById('incident-impact').disabled=!e.target.checked;if(!e.target.checked)document.getElementById('incident-impact').value=''});
    document.getElementById('incident-form').addEventListener('submit',async e=>{
      e.preventDefault();const box=document.getElementById('incident-status');box.innerHTML='<div class="status info">Guardando…</div>';
      try{
        const branch=document.getElementById('incident-branch').value;localStorage.setItem(LS_BRANCH,branch);
        await createIncident({incidentCode:document.getElementById('incident-code').value.trim(),incidentDate:document.getElementById('incident-date').value,incidentTime:document.getElementById('incident-time').value,branchId:branch,classification:document.getElementById('incident-classification').value,processName:document.getElementById('incident-process').value.trim(),severity:document.getElementById('incident-severity').value,description:document.getElementById('incident-description').value.trim(),patientOrDonorAffected:document.getElementById('incident-affected').checked,impactDetail:document.getElementById('incident-impact').value.trim(),immediateAction:document.getElementById('incident-action').value.trim(),evidenceUrl:document.getElementById('incident-evidence').value.trim(),requiresQualityFollowup:document.getElementById('incident-followup').checked});
        box.innerHTML='<div class="status ok">Incidencia registrada.</div>';await load();setTimeout(()=>document.getElementById('incident-dialog').close(),400);
      }catch(error){box.innerHTML=`<div class="status bad">${esc(error.message)}</div>`}
    });

    document.getElementById('new-nc').addEventListener('click',()=>{document.getElementById('nc-status').innerHTML='';document.getElementById('nc-form').reset();document.getElementById('nc-dialog').showModal()});
    document.getElementById('new-capa').addEventListener('click',()=>{document.getElementById('capa-status').innerHTML='';document.getElementById('capa-form').reset();document.getElementById('capa-dialog').showModal()});
    document.getElementById('nc-cancel').addEventListener('click',()=>document.getElementById('nc-dialog').close());
    document.getElementById('capa-cancel').addEventListener('click',()=>document.getElementById('capa-dialog').close());

    document.getElementById('nc-form').addEventListener('submit',async e=>{
      e.preventDefault();const box=document.getElementById('nc-status');box.innerHTML=`<div class="status info">Guardando…</div>`;
      try {await createNonconformity({code:document.getElementById('nc-code').value.trim(),branchId:document.getElementById('nc-branch').value,description:document.getElementById('nc-description').value.trim(),rootCause:document.getElementById('nc-root').value.trim(),dueDate:document.getElementById('nc-due').value});box.innerHTML=`<div class="status ok">No conformidad creada.</div>`;await load();setTimeout(()=>document.getElementById('nc-dialog').close(),400)} catch(error) {box.innerHTML=`<div class="status bad">${esc(error.message)}</div>`}
    });

    document.getElementById('capa-form').addEventListener('submit',async e=>{
      e.preventDefault();const box=document.getElementById('capa-status');box.innerHTML=`<div class="status info">Guardando…</div>`;
      try {await createCapa({code:document.getElementById('capa-code').value.trim(),problem:document.getElementById('capa-problem').value.trim(),rootCause:document.getElementById('capa-root').value.trim(),actionPlan:document.getElementById('capa-plan').value.trim(),dueDate:document.getElementById('capa-due').value});box.innerHTML=`<div class="status ok">CAPA creada.</div>`;await load();setTimeout(()=>document.getElementById('capa-dialog').close(),400)} catch(error) {box.innerHTML=`<div class="status bad">${esc(error.message)}</div>`}
    });

    function showError(error) {console.error('[HEMOCURA_QUALITY_ERROR]',error);document.getElementById('quality-errors').innerHTML=`<div class="status bad">${esc(error.message)}</div>`}

    await load();
    await mountQmsActionBoard(document.getElementById('qms-open-actions'));

  } catch(error) {
    console.error('[HEMOCURA_QUALITY_ERROR]',error);
    root.innerHTML=`<section class="card"><h3>Calidad no disponible</h3><div class="status bad">${esc(error.message)}</div><p>Abra F12 → Console y busque <code>HEMOCURA_QUALITY_ERROR</code>.</p></section>`;
  }
}
