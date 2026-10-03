import { runFullQA } from './qa-data.js';

function esc(v='') {
  return String(v ?? '').replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

function resultPill(ok) {
  return ok
    ? '<span class="stock-pill stock-ok">OK</span>'
    : '<span class="stock-pill stock-critical">ERROR</span>';
}

function moduleRows(rows) {
  return rows.map(r=>`
    <tr>
      <td>${esc(r.label)}</td>
      <td>${resultPill(r.ok)}</td>
      <td class="num">${esc(r.ms)} ms</td>
      <td>${esc(r.error || 'Accesible')}</td>
    </tr>`).join('');
}

function rlsRows(rows) {
  return rows.map(r=>`
    <tr>
      <td>${esc(r.label)}</td>
      <td>${resultPill(r.ok)}</td>
      <td class="num">${esc(r.ms)} ms</td>
      <td>${esc(r.error || 'Consulta permitida')}</td>
    </tr>`).join('');
}

function routeRows(rows) {
  return rows.map(r=>`
    <tr>
      <td><code>${esc(r.route)}</code></td>
      <td>${resultPill(r.ok)}</td>
      <td>${esc(r.note || '')}</td>
    </tr>`).join('');
}

function scoreClass(report) {
  if (report.failed === 0) return 'qa-pass';
  if (report.failed <= 3) return 'qa-warn';
  return 'qa-fail';
}

export async function mountQA(root) {
  if (!root) return;

  root.innerHTML = `
    <section class="card">
      <h3>QA integral</h3>
      <div class="status info">Preparando validación v0.12.0…</div>
    </section>`;

  root.innerHTML = `
    <div class="sales-toolbar">
      <div>
        <h2 class="section-heading">QA integral · Release Candidate</h2>
        <div class="muted">Validación técnica antes de LIVE-LIMITED.</div>
      </div>
      <button id="qa-run">Ejecutar QA completo</button>
    </div>

    <section class="card">
      <h3>Alcance de liberación</h3>
      <div class="grid sales-kpis">
        <section class="card"><div class="muted">Operaciones</div><div class="kpi small-kpi">LIVE-LIMITED</div></section>
        <section class="card"><div class="muted">Forecast</div><div class="kpi small-kpi">SHADOW</div></section>
        <section class="card"><div class="muted">FEFO clínico</div><div class="kpi small-kpi">BLOCKED</div></section>
        <section class="card"><div class="muted">Versión</div><div class="kpi small-kpi">0.12.0 RC</div></section>
      </div>
    </section>

    <div id="qa-status"></div>
    <div id="qa-summary"></div>

    <section class="card hidden" id="qa-modules-card">
      <div class="card-head"><h3>Matriz de salud por módulo</h3><span class="muted">Lectura real Supabase</span></div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th>Módulo</th><th>Estado</th><th>Tiempo</th><th>Detalle</th></tr></thead>
          <tbody id="qa-modules-body"></tbody>
        </table>
      </div>
    </section>

    <section class="card hidden" id="qa-rls-card">
      <div class="card-head"><h3>Pruebas RLS / permisos</h3><span class="muted">Acceso efectivo del usuario actual</span></div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th>Objeto</th><th>Estado</th><th>Tiempo</th><th>Detalle</th></tr></thead>
          <tbody id="qa-rls-body"></tbody>
        </table>
      </div>
    </section>

    <section class="card hidden" id="qa-routes-card">
      <div class="card-head"><h3>Rutas</h3><span class="muted">Navegación registrada</span></div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th>Ruta</th><th>Estado</th><th>Nota</th></tr></thead>
          <tbody id="qa-routes-body"></tbody>
        </table>
      </div>
    </section>

    <section class="card">
      <h3>Checklist de liberación</h3>
      <div class="release-checklist">
        <label><input type="checkbox" data-qa-check="auth"> Login, logout y persistencia validados</label>
        <label><input type="checkbox" data-qa-check="dashboard"> Dashboard sin errores críticos</label>
        <label><input type="checkbox" data-qa-check="sales"> Ventas y ajustes validados</label>
        <label><input type="checkbox" data-qa-check="dispatch"> Despachos y conciliación validados</label>
        <label><input type="checkbox" data-qa-check="inventory"> Inventario y conteo físico validados</label>
        <label><input type="checkbox" data-qa-check="costs"> Costos y recálculo validados</label>
        <label><input type="checkbox" data-qa-check="quality"> Calidad/NC/CAPA validados</label>
        <label><input type="checkbox" data-qa-check="planning"> Planificación y forecast SHADOW validados</label>
        <label><input type="checkbox" data-qa-check="rls"> RLS revisado por rol/sucursal</label>
        <label><input type="checkbox" data-qa-check="backup"> Respaldo previo a producción confirmado</label>
      </div>
      <div id="release-progress" class="status info">0/10 controles confirmados.</div>
    </section>

    <section class="card hidden" id="qa-export-card">
      <div class="card-head">
        <h3>Reporte QA</h3>
        <button id="qa-copy" class="secondary compact">Copiar JSON</button>
      </div>
      <pre id="qa-json" class="json-box"></pre>
    </section>

    <div class="debug-strip">[HEMOCURA_QA] preparado · v0.12.0 RC</div>`;

  let lastReport = null;

  async function executeQA() {
    const btn = document.getElementById('qa-run');
    btn.disabled = true;
    btn.textContent = 'Ejecutando QA…';
    document.getElementById('qa-status').innerHTML =
      `<div class="status info">Ejecutando pruebas contra Supabase…</div>`;

    try {
      lastReport = await runFullQA();

      document.getElementById('qa-modules-card').classList.remove('hidden');
      document.getElementById('qa-rls-card').classList.remove('hidden');
      document.getElementById('qa-routes-card').classList.remove('hidden');
      document.getElementById('qa-export-card').classList.remove('hidden');

      document.getElementById('qa-modules-body').innerHTML = moduleRows(lastReport.modules);
      document.getElementById('qa-rls-body').innerHTML = rlsRows(lastReport.rls);
      document.getElementById('qa-routes-body').innerHTML = routeRows(lastReport.routes);
      document.getElementById('qa-json').textContent = JSON.stringify(lastReport,null,2);

      const cls = scoreClass(lastReport);
      document.getElementById('qa-summary').innerHTML = `
        <div class="grid sales-kpis">
          <section class="card ${cls}"><div class="muted">Pruebas</div><div class="kpi">${lastReport.total}</div></section>
          <section class="card qa-pass"><div class="muted">Aprobadas</div><div class="kpi">${lastReport.passed}</div></section>
          <section class="card ${lastReport.failed ? 'qa-fail':'qa-pass'}"><div class="muted">Fallidas</div><div class="kpi">${lastReport.failed}</div></section>
          <section class="card"><div class="muted">Resultado</div><div class="kpi small-kpi">${lastReport.failed===0?'RC APTO':'REVISAR'}</div></section>
        </div>`;

      document.getElementById('qa-status').innerHTML =
        lastReport.failed === 0
          ? `<div class="status ok">QA técnico sin errores detectados en los checks ejecutados.</div>`
          : `<div class="status warn">${lastReport.failed} prueba(s) requieren revisión antes de liberar.</div>`;

      console.info('[HEMOCURA_QA_RELEASE]', lastReport);

    } catch(error) {
      console.error('[HEMOCURA_QA_ERROR]', error);
      document.getElementById('qa-status').innerHTML =
        `<div class="status bad">${esc(error.message)}</div>`;
    } finally {
      btn.disabled = false;
      btn.textContent = 'Ejecutar QA completo';
    }
  }

  document.getElementById('qa-run').addEventListener('click', executeQA);

  document.getElementById('qa-copy')?.addEventListener('click', async ()=>{
    if (!lastReport) return;
    try {
      await navigator.clipboard.writeText(JSON.stringify(lastReport,null,2));
      document.getElementById('qa-status').innerHTML =
        `<div class="status ok">Reporte QA copiado.</div>`;
    } catch(error) {
      console.info('[HEMOCURA_QA_REPORT]', lastReport);
      document.getElementById('qa-status').innerHTML =
        `<div class="status warn">No se pudo copiar. El reporte fue enviado a Console.</div>`;
    }
  });

  const checks = [...document.querySelectorAll('[data-qa-check]')];
  const saved = JSON.parse(localStorage.getItem('hemocura-qa-release-checks') || '{}');

  for (const c of checks) {
    c.checked = !!saved[c.dataset.qaCheck];
    c.addEventListener('change', ()=>{
      saved[c.dataset.qaCheck] = c.checked;
      localStorage.setItem('hemocura-qa-release-checks', JSON.stringify(saved));
      updateProgress();
    });
  }

  function updateProgress() {
    const done = checks.filter(c=>c.checked).length;
    const box = document.getElementById('release-progress');
    box.textContent = `${done}/${checks.length} controles confirmados.`;
    box.className = `status ${done===checks.length ? 'ok' : 'info'}`;
  }

  updateProgress();
}
