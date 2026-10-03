function esc(v='') {
  return String(v ?? '').replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

const BRANCHES = ['Santiago','Puerto Plata','Tenares'];
const MODULES = [
  'Login y sesión',
  'Dashboard',
  'Ventas',
  'Despachos',
  'Inventario',
  'Costos',
  'Calidad',
  'Planificación',
  'Configuración',
  'QA / Release'
];

function readState() {
  try {
    return JSON.parse(localStorage.getItem('hemocura-operational-acceptance') || '{}');
  } catch {
    return {};
  }
}

function saveState(state) {
  localStorage.setItem('hemocura-operational-acceptance', JSON.stringify(state));
}

function calcSummary(state) {
  let total=0, approved=0, rejected=0, pending=0;

  for (const branch of BRANCHES) {
    for (const module of MODULES) {
      total++;
      const value = state?.branches?.[branch]?.modules?.[module]?.status || 'PENDIENTE';
      if (value === 'APROBADO') approved++;
      else if (value === 'RECHAZADO') rejected++;
      else pending++;
    }
  }

  return {total,approved,rejected,pending};
}

function branchCard(branch, state) {
  const b = state?.branches?.[branch] || {};
  const moduleState = b.modules || {};

  const rows = MODULES.map(module => {
    const item = moduleState[module] || {};
    return `
      <tr>
        <td>${esc(module)}</td>
        <td>
          <select data-branch="${esc(branch)}" data-module="${esc(module)}" class="accept-status">
            <option value="PENDIENTE" ${item.status==='PENDIENTE'||!item.status?'selected':''}>PENDIENTE</option>
            <option value="APROBADO" ${item.status==='APROBADO'?'selected':''}>APROBADO</option>
            <option value="RECHAZADO" ${item.status==='RECHAZADO'?'selected':''}>RECHAZADO</option>
          </select>
        </td>
        <td>
          <input data-notes-branch="${esc(branch)}" data-notes-module="${esc(module)}"
            value="${esc(item.notes || '')}" placeholder="Observaciones">
        </td>
      </tr>`;
  }).join('');

  return `
    <section class="card acceptance-branch">
      <div class="card-head">
        <div>
          <h3>${esc(branch)}</h3>
          <div class="muted">Validación operativa por módulo.</div>
        </div>
      </div>

      <div class="filter-grid">
        <label>Responsable
          <input data-owner="${esc(branch)}" value="${esc(b.owner || '')}" placeholder="Nombre">
        </label>
        <label>Fecha
          <input data-date="${esc(branch)}" type="date" value="${esc(b.date || '')}">
        </label>
        <label>Turno
          <input data-shift="${esc(branch)}" value="${esc(b.shift || '')}" placeholder="Ej. 8:00–17:00">
        </label>
      </div>

      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th>Módulo</th><th>Estado</th><th>Observación</th></tr></thead>
          <tbody>${rows}</tbody>
        </table>
      </div>
    </section>`;
}

export async function mountAcceptance(root) {
  if (!root) return;

  let state = readState();
  state.branches = state.branches || {};

  root.innerHTML = `
    <div class="sales-toolbar">
      <div>
        <h2 class="section-heading">Aceptación operativa y Sign-off</h2>
        <div class="muted">Validación final por sucursal antes de v1.0.0.</div>
      </div>
      <span class="shadow-badge">0.19.0 RC</span>
    </div>

    <section class="card">
      <h3>Regla de promoción</h3>
      <div class="status info">
        v1.0.0 requiere evidencia técnica + aceptación operativa.
        Esta pantalla no modifica datos de Supabase.
      </div>
    </section>

    <div id="acceptance-summary"></div>

    <div id="acceptance-branches">
      ${BRANCHES.map(b=>branchCard(b,state)).join('')}
    </div>

    <section class="card">
      <h3>Primer día de operación</h3>
      <div class="release-checklist">
        <label><input type="checkbox" data-day1="opening"> Apertura del día validada</label>
        <label><input type="checkbox" data-day1="firstsale"> Primera venta validada</label>
        <label><input type="checkbox" data-day1="firstdispatch"> Primer despacho validado</label>
        <label><input type="checkbox" data-day1="inventory"> Inventario conciliado</label>
        <label><input type="checkbox" data-day1="alerts"> Alertas revisadas</label>
        <label><input type="checkbox" data-day1="quality"> Incidencias/Calidad revisadas</label>
        <label><input type="checkbox" data-day1="closing"> Cierre del día validado</label>
        <label><input type="checkbox" data-day1="backup"> Backup/copia de seguridad confirmada</label>
      </div>
      <div id="day1-progress" class="status info"></div>
    </section>

    <section class="card">
      <div class="card-head">
        <h3>Sign-off final</h3>
        <button id="acceptance-copy" class="secondary compact">Copiar reporte</button>
      </div>

      <div class="filter-grid">
        <label>Gerencia Operativa
          <input id="signoff-operations" value="${esc(state.signoff?.operations || '')}" placeholder="Nombre">
        </label>
        <label>Calidad
          <input id="signoff-quality" value="${esc(state.signoff?.quality || '')}" placeholder="Nombre">
        </label>
        <label>Fecha de aceptación
          <input id="signoff-date" type="date" value="${esc(state.signoff?.date || '')}">
        </label>
      </div>

      <label>Observaciones finales
        <textarea id="signoff-notes">${esc(state.signoff?.notes || '')}</textarea>
      </label>

      <div id="acceptance-result" class="status warn">Pendiente de aceptación.</div>
      <pre id="acceptance-report" class="json-box"></pre>
    </section>

    <div class="debug-strip">[HEMOCURA_OPERATIONAL_ACCEPTANCE] preparado</div>
  `;

  const day1 = state.day1 || {};
  document.querySelectorAll('[data-day1]').forEach(c=>{
    c.checked=!!day1[c.dataset.day1];
  });

  function persist() {
    state.branches = state.branches || {};

    document.querySelectorAll('.accept-status').forEach(el=>{
      const branch=el.dataset.branch;
      const module=el.dataset.module;
      state.branches[branch] = state.branches[branch] || {modules:{}};
      state.branches[branch].modules = state.branches[branch].modules || {};
      state.branches[branch].modules[module] = state.branches[branch].modules[module] || {};
      state.branches[branch].modules[module].status = el.value;
    });

    document.querySelectorAll('[data-notes-branch]').forEach(el=>{
      const branch=el.dataset.notesBranch;
      const module=el.dataset.notesModule;
      state.branches[branch] = state.branches[branch] || {modules:{}};
      state.branches[branch].modules = state.branches[branch].modules || {};
      state.branches[branch].modules[module] = state.branches[branch].modules[module] || {};
      state.branches[branch].modules[module].notes = el.value.trim();
    });

    for(const branch of BRANCHES) {
      state.branches[branch] = state.branches[branch] || {modules:{}};
      state.branches[branch].owner =
        document.querySelector(`[data-owner="${branch}"]`)?.value.trim() || '';
      state.branches[branch].date =
        document.querySelector(`[data-date="${branch}"]`)?.value || '';
      state.branches[branch].shift =
        document.querySelector(`[data-shift="${branch}"]`)?.value.trim() || '';
    }

    state.day1 = {};
    document.querySelectorAll('[data-day1]').forEach(c=>{
      state.day1[c.dataset.day1]=c.checked;
    });

    state.signoff = {
      operations:document.getElementById('signoff-operations').value.trim(),
      quality:document.getElementById('signoff-quality').value.trim(),
      date:document.getElementById('signoff-date').value,
      notes:document.getElementById('signoff-notes').value.trim()
    };

    saveState(state);
    renderSummary();
  }

  function renderSummary() {
    const summary=calcSummary(state);
    const day1Values=Object.values(state.day1 || {});
    const day1Total=8;
    const day1Done=day1Values.filter(Boolean).length;

    document.getElementById('acceptance-summary').innerHTML=`
      <div class="grid sales-kpis">
        <section class="card"><div class="muted">Controles sucursal/módulo</div><div class="kpi">${summary.total}</div></section>
        <section class="card qa-pass"><div class="muted">Aprobados</div><div class="kpi">${summary.approved}</div></section>
        <section class="card ${summary.rejected?'qa-fail':''}"><div class="muted">Rechazados</div><div class="kpi">${summary.rejected}</div></section>
        <section class="card"><div class="muted">Pendientes</div><div class="kpi">${summary.pending}</div></section>
      </div>`;

    const progress=document.getElementById('day1-progress');
    progress.textContent=`${day1Done}/${day1Total} controles del primer día confirmados.`;
    progress.className=`status ${day1Done===day1Total?'ok':'info'}`;

    const signoff=state.signoff || {};
    const signoffComplete=!!(signoff.operations && signoff.quality && signoff.date);
    const operationalReady =
      summary.rejected===0 &&
      summary.pending===0 &&
      day1Done===day1Total &&
      signoffComplete;

    const result=document.getElementById('acceptance-result');
    if(operationalReady){
      result.className='status ok';
      result.textContent='ACEPTACIÓN OPERATIVA COMPLETA · candidata a promoción v1.0.0.';
    }else{
      result.className='status warn';
      result.textContent='Aceptación incompleta · no promover todavía.';
    }

    const report={
      generated_at:new Date().toISOString(),
      version:'0.19.0',
      target:'LIVE-LIMITED',
      branches:state.branches,
      day1:state.day1,
      signoff:state.signoff,
      summary:{
        ...summary,
        day1_completed:day1Done,
        day1_total:day1Total,
        signoff_complete:signoffComplete,
        operational_acceptance_complete:operationalReady
      },
      guardrails:{
        forecast:'SHADOW',
        fefo_per_unit:'BLOCKED',
        cold_chain_blocking:'BLOCKED',
        donor_recipient_traceability:'SHADOW/BLOCKED'
      }
    };

    document.getElementById('acceptance-report').textContent=
      JSON.stringify(report,null,2);
  }

  document.querySelectorAll('input,select,textarea').forEach(el=>{
    el.addEventListener('change',persist);
    if(el.tagName==='INPUT' || el.tagName==='TEXTAREA') {
      el.addEventListener('input',persist);
    }
  });

  document.getElementById('acceptance-copy').addEventListener('click',async()=>{
    persist();
    const text=document.getElementById('acceptance-report').textContent;
    try{
      await navigator.clipboard.writeText(text);
      document.getElementById('acceptance-result').className='status ok';
      document.getElementById('acceptance-result').textContent='Reporte de aceptación copiado.';
    }catch(error){
      console.info('[HEMOCURA_OPERATIONAL_ACCEPTANCE_REPORT]', JSON.parse(text));
    }
  });

  renderSummary();
}
