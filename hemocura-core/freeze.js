import {
  runFrontendHealth,
  getRuntimeVersion,
  inspectCacheState,
  clearAppCaches
} from './frontend-health.js';

function esc(v='') {
  return String(v ?? '').replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

function pill(ok) {
  return ok
    ? '<span class="stock-pill stock-ok">OK</span>'
    : '<span class="stock-pill stock-critical">ERROR</span>';
}

function rows(items) {
  return items.map(i=>`
    <tr>
      <td>${esc(i.label)}</td>
      <td>${pill(i.ok)}</td>
      <td class="num">${esc(i.ms)} ms</td>
      <td>${esc(i.detail)}</td>
    </tr>`).join('');
}

export async function mountFreeze(root) {
  if (!root) return;

  root.innerHTML = `
    <div class="sales-toolbar">
      <div>
        <h2 class="section-heading">RC Freeze · Integridad del frontend</h2>
        <div class="muted">Comprueba versión, archivos y caché antes de cualquier promoción a v1.0.0.</div>
      </div>
      <span class="shadow-badge">0.14.0 RC-FREEZE</span>
    </div>

    <section class="card">
      <h3>Versión publicada</h3>
      <div id="freeze-version" class="status info">Consultando VERSION.json…</div>
    </section>

    <section class="card">
      <div class="card-head">
        <h3>Autodiagnóstico de frontend</h3>
        <button id="freeze-run">Ejecutar self-test</button>
      </div>
      <div id="freeze-status"></div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th>Archivo / control</th><th>Estado</th><th>Tiempo</th><th>Detalle</th></tr></thead>
          <tbody id="freeze-body"></tbody>
        </table>
      </div>
    </section>

    <section class="card">
      <div class="card-head">
        <h3>Diagnóstico de caché</h3>
        <button id="freeze-cache" class="secondary">Revisar caché</button>
      </div>
      <pre id="freeze-cache-output" class="json-box">Pendiente.</pre>
      <button id="freeze-clear-cache" class="secondary">Limpiar caché local y Service Workers</button>
      <div class="status warn">
        Use esta acción solamente si GitHub Pages está sirviendo una versión anterior después de un despliegue.
      </div>
    </section>

    <section class="card">
      <h3>Criterio de congelación</h3>
      <div class="release-checklist">
        <label><input type="checkbox" data-freeze="qa"> QA técnico ejecutado</label>
        <label><input type="checkbox" data-freeze="frontend"> Self-test frontend sin errores</label>
        <label><input type="checkbox" data-freeze="version"> VERSION.json coincide con despliegue esperado</label>
        <label><input type="checkbox" data-freeze="cache"> Caché revisada</label>
        <label><input type="checkbox" data-freeze="manifest"> RELEASE_MANIFEST.json presente</label>
        <label><input type="checkbox" data-freeze="backup"> Backup confirmado</label>
      </div>
      <div id="freeze-progress" class="status info"></div>
    </section>

    <div class="debug-strip">[HEMOCURA_RC_FREEZE] preparado</div>
  `;

  try {
    const v = await getRuntimeVersion();
    document.getElementById('freeze-version').className='status ok';
    document.getElementById('freeze-version').textContent =
      `Versión publicada: ${v.version} · ${v.release_channel}`;
  } catch(error) {
    document.getElementById('freeze-version').className='status bad';
    document.getElementById('freeze-version').textContent=error.message;
  }

  document.getElementById('freeze-run').addEventListener('click', async ()=>{
    const btn=document.getElementById('freeze-run');
    btn.disabled=true; btn.textContent='Ejecutando…';
    document.getElementById('freeze-status').innerHTML='<div class="status info">Comprobando archivos…</div>';

    try {
      const result=await runFrontendHealth();
      document.getElementById('freeze-body').innerHTML=rows(result);
      const failed=result.filter(x=>!x.ok).length;
      document.getElementById('freeze-status').innerHTML =
        failed===0
          ? '<div class="status ok">Frontend íntegro según los checks ejecutados.</div>'
          : `<div class="status warn">${failed} comprobación(es) fallaron.</div>`;
    } catch(error) {
      document.getElementById('freeze-status').innerHTML =
        `<div class="status bad">${esc(error.message)}</div>`;
    } finally {
      btn.disabled=false; btn.textContent='Ejecutar self-test';
    }
  });

  document.getElementById('freeze-cache').addEventListener('click', async ()=>{
    const data=await inspectCacheState();
    document.getElementById('freeze-cache-output').textContent=JSON.stringify(data,null,2);
  });

  document.getElementById('freeze-clear-cache').addEventListener('click', async ()=>{
    await clearAppCaches();
    document.getElementById('freeze-cache-output').textContent =
      'Caché local y Service Workers eliminados. Recargue la página.';
  });

  const checks=[...document.querySelectorAll('[data-freeze]')];
  const saved=JSON.parse(localStorage.getItem('hemocura-rc-freeze')||'{}');

  for(const c of checks){
    c.checked=!!saved[c.dataset.freeze];
    c.addEventListener('change',()=>{
      saved[c.dataset.freeze]=c.checked;
      localStorage.setItem('hemocura-rc-freeze',JSON.stringify(saved));
      update();
    });
  }

  function update(){
    const done=checks.filter(c=>c.checked).length;
    const box=document.getElementById('freeze-progress');
    box.textContent=`${done}/${checks.length} controles de congelación confirmados.`;
    box.className=`status ${done===checks.length?'ok':'info'}`;
  }
  update();
}
