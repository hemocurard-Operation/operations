import { getSession } from './auth.js';
import { runFullQA } from './qa-data.js';

function esc(v='') {
  return String(v ?? '').replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

function pill(text, cls='stock-none') {
  return `<span class="stock-pill ${cls}">${esc(text)}</span>`;
}

function modeStatus(report) {
  if (!report) return pill('PENDIENTE','stock-none');
  if (report.failed === 0) return pill('APTO TÉCNICO','stock-ok');
  if (report.failed <= 3) return pill('REVISAR','stock-warning');
  return pill('NO-GO','stock-critical');
}

function getChecklist() {
  return JSON.parse(localStorage.getItem('hemocura-pregolive-checks') || '{}');
}

function saveChecklist(data) {
  localStorage.setItem('hemocura-pregolive-checks', JSON.stringify(data));
}

function buildReleaseReport(report, checklist, session) {
  const completed = Object.values(checklist).filter(Boolean).length;
  const total = 12;
  return {
    generated_at: new Date().toISOString(),
    version: '0.13.0',
    target: 'LIVE-LIMITED',
    user: session?.user?.email || session?.user?.id || null,
    qa: report ? {
      total: report.total,
      passed: report.passed,
      failed: report.failed
    } : null,
    checklist: {
      completed,
      total,
      items: checklist
    },
    clinical_guardrails: {
      forecast: 'SHADOW',
      fefo_per_unit: 'BLOCKED',
      cold_chain_blocking: 'BLOCKED',
      donor_recipient_traceability: 'SHADOW/BLOCKED'
    }
  };
}

export async function mountRelease(root) {
  if (!root) return;

  const session = await getSession();
  let qaReport = null;
  let checklist = getChecklist();

  root.innerHTML = `
    <div class="sales-toolbar">
      <div>
        <h2 class="section-heading">Pre-Go-Live · v0.13.0 RC</h2>
        <div class="muted">Preparación de despliegue, rollback y respuesta a incidentes.</div>
      </div>
      <span id="release-status">${pill('RC','stock-warning')}</span>
    </div>

    <section class="card">
      <h3>Guardrails de liberación</h3>
      <div class="grid sales-kpis">
        <section class="card"><div class="muted">Objetivo</div><div class="kpi small-kpi">LIVE-LIMITED</div></section>
        <section class="card"><div class="muted">Forecast</div><div class="kpi small-kpi">SHADOW</div></section>
        <section class="card"><div class="muted">FEFO clínico</div><div class="kpi small-kpi">BLOCKED</div></section>
        <section class="card"><div class="muted">Cold chain blocking</div><div class="kpi small-kpi">BLOCKED</div></section>
      </div>
    </section>

    <section class="card">
      <div class="card-head">
        <div>
          <h3>Preflight técnico</h3>
          <div class="muted">Ejecuta el QA integral antes de evaluar Go/No-Go.</div>
        </div>
        <button id="release-run-qa">Ejecutar preflight</button>
      </div>
      <div id="release-qa-status" class="status info">QA no ejecutado en esta sesión.</div>
    </section>

    <section class="card">
      <h3>Checklist Pre-Go-Live</h3>
      <div class="release-checklist" id="pregolive-checklist">
        <label><input type="checkbox" data-release-check="qa"> QA ejecutado y errores críticos resueltos</label>
        <label><input type="checkbox" data-release-check="backup"> Backup de Supabase confirmado</label>
        <label><input type="checkbox" data-release-check="export"> Export/backup de datos operativos críticos confirmado</label>
        <label><input type="checkbox" data-release-check="github"> Commit/tag de versión identificado</label>
        <label><input type="checkbox" data-release-check="config"> js/config.js validado</label>
        <label><input type="checkbox" data-release-check="rls"> RLS revisado por rol y sucursal</label>
        <label><input type="checkbox" data-release-check="auth"> Login/logout/persistencia validados</label>
        <label><input type="checkbox" data-release-check="smoke"> Smoke test post-deploy preparado</label>
        <label><input type="checkbox" data-release-check="rollback"> Punto de rollback identificado</label>
        <label><input type="checkbox" data-release-check="owners"> Responsables de incidente identificados</label>
        <label><input type="checkbox" data-release-check="clinical"> Clinical Core confirmado SHADOW/BLOCKED</label>
        <label><input type="checkbox" data-release-check="parallel"> Operación paralela/Excel definida si aplica</label>
      </div>
      <div id="pregolive-progress" class="status info"></div>
    </section>

    <section class="card">
      <h3>Go / No-Go</h3>
      <div id="go-no-go" class="status warn">
        Pendiente. Ejecute QA y complete el checklist.
      </div>
    </section>

    <section class="card">
      <h3>Rollback rápido</h3>
      <ol class="runbook-steps">
        <li>Detener nuevas escrituras operativas si el incidente afecta integridad de datos.</li>
        <li>Identificar último commit/tag estable en GitHub.</li>
        <li>Restaurar archivos de la versión estable.</li>
        <li>Limpiar caché del navegador/Service Worker si sirve archivos antiguos.</li>
        <li>Validar login, Dashboard y módulo afectado.</li>
        <li>Documentar el incidente antes de reanudar operación.</li>
      </ol>
      <div class="status warn">Rollback de frontend no revierte cambios de datos en Supabase. Las restauraciones de base requieren procedimiento separado.</div>
    </section>

    <section class="card">
      <div class="card-head">
        <h3>Reporte de liberación</h3>
        <button id="release-copy" class="secondary compact">Copiar reporte</button>
      </div>
      <pre id="release-report" class="json-box"></pre>
    </section>

    <div class="debug-strip">[HEMOCURA_RELEASE] preparado · v0.13.0 RC</div>
  `;

  const checks = [...document.querySelectorAll('[data-release-check]')];

  for (const c of checks) {
    c.checked = !!checklist[c.dataset.releaseCheck];
    c.addEventListener('change', () => {
      checklist[c.dataset.releaseCheck] = c.checked;
      saveChecklist(checklist);
      update();
    });
  }

  function update() {
    const done = checks.filter(c=>c.checked).length;
    const total = checks.length;
    const box = document.getElementById('pregolive-progress');
    box.textContent = `${done}/${total} controles confirmados.`;
    box.className = `status ${done===total ? 'ok':'info'}`;

    const qaReady = qaReport && qaReport.failed === 0;
    const checklistReady = done === total;
    const gonogo = document.getElementById('go-no-go');

    if (qaReady && checklistReady) {
      gonogo.className = 'status ok';
      gonogo.textContent = 'GO TÉCNICO PARA LIVE-LIMITED. Aún requiere aprobación operativa y respaldo confirmado.';
      document.getElementById('release-status').innerHTML = pill('GO TÉCNICO','stock-ok');
    } else {
      gonogo.className = 'status warn';
      gonogo.textContent = 'NO-GO / PENDIENTE: falta QA sin fallos o checklist completo.';
      document.getElementById('release-status').innerHTML = qaReport ? modeStatus(qaReport) : pill('RC','stock-warning');
    }

    document.getElementById('release-report').textContent =
      JSON.stringify(buildReleaseReport(qaReport, checklist, session), null, 2);
  }

  document.getElementById('release-run-qa').addEventListener('click', async ()=>{
    const btn=document.getElementById('release-run-qa');
    btn.disabled=true;
    btn.textContent='Ejecutando…';
    document.getElementById('release-qa-status').className='status info';
    document.getElementById('release-qa-status').textContent='Ejecutando QA integral…';

    try {
      qaReport = await runFullQA();
      const box=document.getElementById('release-qa-status');
      if (qaReport.failed === 0) {
        box.className='status ok';
        box.textContent=`QA aprobado: ${qaReport.passed}/${qaReport.total} checks.`;
      } else {
        box.className='status warn';
        box.textContent=`QA con ${qaReport.failed} fallo(s). Revise #qa antes de liberar.`;
      }
      console.info('[HEMOCURA_PREFLIGHT]', qaReport);
    } catch(error) {
      console.error('[HEMOCURA_RELEASE_ERROR]',error);
      document.getElementById('release-qa-status').className='status bad';
      document.getElementById('release-qa-status').textContent=error.message;
    } finally {
      btn.disabled=false;
      btn.textContent='Ejecutar preflight';
      update();
    }
  });

  document.getElementById('release-copy').addEventListener('click', async ()=>{
    const report=buildReleaseReport(qaReport, checklist, session);
    try {
      await navigator.clipboard.writeText(JSON.stringify(report,null,2));
    } catch(error) {
      console.info('[HEMOCURA_RELEASE_REPORT]', report);
    }
  });

  update();
}
