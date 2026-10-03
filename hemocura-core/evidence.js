import { runFrontendHealth, getRuntimeVersion, inspectCacheState } from './frontend-health.js';
import { runFullQA } from './qa-data.js';
import { getSession } from './auth.js';

function esc(v='') {
  return String(v ?? '').replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

function readJSON(key) {
  try { return JSON.parse(localStorage.getItem(key) || '{}'); }
  catch { return {}; }
}

function summarizeChecklist(obj) {
  const values = Object.values(obj || {});
  return {
    total: values.length,
    completed: values.filter(Boolean).length,
    complete: values.length > 0 && values.every(Boolean)
  };
}

function pill(ok, yes='OK', no='PENDIENTE') {
  return ok
    ? `<span class="stock-pill stock-ok">${yes}</span>`
    : `<span class="stock-pill stock-warning">${no}</span>`;
}

export async function mountEvidence(root) {
  if (!root) return;

  root.innerHTML = `
    <div class="sales-toolbar">
      <div>
        <h2 class="section-heading">Runtime Evidence Collector</h2>
        <div class="muted">Reúne la evidencia real necesaria antes de promover a v1.0.0.</div>
      </div>
      <button id="evidence-run">Generar evidencia</button>
    </div>

    <section class="card">
      <h3>Objetivo</h3>
      <div class="status info">
        Esta pantalla no aprueba producción por sí sola. Compila evidencia técnica para la decisión de promoción.
      </div>
    </section>

    <div id="evidence-status"></div>
    <div id="evidence-summary"></div>

    <section class="card hidden" id="evidence-matrix-card">
      <div class="card-head"><h3>Matriz de evidencia</h3><span class="muted">runtime + local controls</span></div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th>Control</th><th>Estado</th><th>Detalle</th></tr></thead>
          <tbody id="evidence-matrix"></tbody>
        </table>
      </div>
    </section>

    <section class="card hidden" id="evidence-report-card">
      <div class="card-head">
        <h3>Reporte consolidado</h3>
        <div>
          <button id="evidence-copy" class="secondary compact">Copiar JSON</button>
          <button id="evidence-download" class="secondary compact">Descargar JSON</button>
        </div>
      </div>
      <pre id="evidence-report" class="json-box"></pre>
    </section>

    <div class="debug-strip">[HEMOCURA_RUNTIME_EVIDENCE] preparado · v0.18.0</div>
  `;

  let report = null;

  async function buildEvidence() {
    const btn = document.getElementById('evidence-run');
    btn.disabled = true;
    btn.textContent = 'Generando…';
    document.getElementById('evidence-status').innerHTML =
      '<div class="status info">Ejecutando comprobaciones runtime…</div>';

    try {
      const [version, frontend, qa, cache, session] = await Promise.all([
        getRuntimeVersion(),
        runFrontendHealth(),
        runFullQA(),
        inspectCacheState(),
        getSession()
      ]);

      const releaseChecks = readJSON('hemocura-pregolive-checks');
      const promotionChecks = readJSON('hemocura-promotion-gate');
      const freezeChecks = readJSON('hemocura-rc-freeze');
      const qaReleaseChecks = readJSON('hemocura-qa-release-checks');

      const releaseSummary = summarizeChecklist(releaseChecks);
      const promotionSummary = summarizeChecklist(promotionChecks);
      const freezeSummary = summarizeChecklist(freezeChecks);
      const qaChecklistSummary = summarizeChecklist(qaReleaseChecks);

      const frontendFailed = frontend.filter(x=>!x.ok).length;
      const qaFailed = qa.failed || 0;
      const configPlaceholder = frontend.some(x =>
        String(x.detail || '').includes('PLACEHOLDER')
      );

      const matrix = [
        {
          control:'Versión publicada',
          ok: version?.version === '0.18.0',
          detail:`Detectada ${version?.version || 'N/D'}`
        },
        {
          control:'Frontend self-test',
          ok: frontendFailed === 0,
          detail:`${frontend.length - frontendFailed}/${frontend.length} checks OK`
        },
        {
          control:'QA runtime',
          ok: qaFailed === 0,
          detail:`${qa.passed}/${qa.total} aprobados · ${qaFailed} fallos`
        },
        {
          control:'Checklist Freeze',
          ok: freezeSummary.complete,
          detail:`${freezeSummary.completed}/${freezeSummary.total}`
        },
        {
          control:'Checklist QA Release',
          ok: qaChecklistSummary.complete,
          detail:`${qaChecklistSummary.completed}/${qaChecklistSummary.total}`
        },
        {
          control:'Checklist Pre-Go-Live',
          ok: releaseSummary.complete,
          detail:`${releaseSummary.completed}/${releaseSummary.total}`
        },
        {
          control:'Promotion Gate',
          ok: promotionSummary.complete,
          detail:`${promotionSummary.completed}/${promotionSummary.total}`
        },
        {
          control:'Config pública',
          ok: !configPlaceholder,
          detail: configPlaceholder ? 'Placeholder detectado' : 'Sin placeholder detectado por self-test'
        },
        {
          control:'Sesión',
          ok: !!session,
          detail: session?.user?.email || session?.user?.id || 'Sin sesión'
        },
        {
          control:'Clinical Core',
          ok: true,
          detail:'SHADOW/BLOCKED'
        }
      ];

      const failed = matrix.filter(x=>!x.ok).length;

      report = {
        generated_at:new Date().toISOString(),
        version_expected:'0.18.0',
        version_runtime:version,
        user:session?.user?.email || session?.user?.id || null,
        frontend,
        qa,
        cache,
        local_checklists:{
          freeze:freezeChecks,
          qa_release:qaReleaseChecks,
          pre_golive:releaseChecks,
          promotion:promotionChecks
        },
        matrix,
        promotion_assessment:{
          technical_controls_failed:failed,
          candidate_for_v1:failed===0,
          target:'LIVE-LIMITED',
          clinical_core:'SHADOW/BLOCKED'
        }
      };

      document.getElementById('evidence-matrix-card').classList.remove('hidden');
      document.getElementById('evidence-report-card').classList.remove('hidden');

      document.getElementById('evidence-matrix').innerHTML = matrix.map(x=>`
        <tr>
          <td>${esc(x.control)}</td>
          <td>${pill(x.ok, 'OK', 'PENDIENTE')}</td>
          <td>${esc(x.detail)}</td>
        </tr>`).join('');

      document.getElementById('evidence-report').textContent =
        JSON.stringify(report,null,2);

      document.getElementById('evidence-summary').innerHTML = `
        <div class="grid sales-kpis">
          <section class="card"><div class="muted">Controles</div><div class="kpi">${matrix.length}</div></section>
          <section class="card qa-pass"><div class="muted">Aprobados</div><div class="kpi">${matrix.length-failed}</div></section>
          <section class="card ${failed?'qa-fail':'qa-pass'}"><div class="muted">Pendientes</div><div class="kpi">${failed}</div></section>
          <section class="card"><div class="muted">Promoción</div><div class="kpi small-kpi">${failed===0?'CANDIDATA':'BLOQUEADA'}</div></section>
        </div>`;

      document.getElementById('evidence-status').innerHTML =
        failed===0
          ? '<div class="status ok">Evidencia técnica completa: candidata a promoción v1.0.0, pendiente aprobación operativa.</div>'
          : `<div class="status warn">${failed} control(es) siguen pendientes. No promover todavía.</div>`;

      console.info('[HEMOCURA_RUNTIME_EVIDENCE]', report);

    } catch(error) {
      console.error('[HEMOCURA_RUNTIME_EVIDENCE_ERROR]', error);
      document.getElementById('evidence-status').innerHTML =
        `<div class="status bad">${esc(error.message)}</div>`;
    } finally {
      btn.disabled = false;
      btn.textContent = 'Generar evidencia';
    }
  }

  document.getElementById('evidence-run').addEventListener('click', buildEvidence);

  document.getElementById('evidence-copy').addEventListener('click', async ()=>{
    if (!report) return;
    try {
      await navigator.clipboard.writeText(JSON.stringify(report,null,2));
      document.getElementById('evidence-status').innerHTML =
        '<div class="status ok">Reporte copiado.</div>';
    } catch(error) {
      console.info('[HEMOCURA_RUNTIME_EVIDENCE_REPORT]', report);
    }
  });

  document.getElementById('evidence-download').addEventListener('click', ()=>{
    if (!report) return;
    const blob = new Blob([JSON.stringify(report,null,2)], {type:'application/json'});
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `hemocura-runtime-evidence-${new Date().toISOString().slice(0,10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
  });
}
