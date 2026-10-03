const CHECKS = [
  ['status.html', './status.html'],
  ['VERSION.json', './VERSION.json'],
  ['RELEASE_MANIFEST.json', './RELEASE_MANIFEST.json'],
  ['index.html', './index.html'],
  ['login.html', './login.html'],
  ['css/app.css', './css/app.css'],
  ['js/app.js', './js/app.js'],
  ['js/login.js', './js/login.js'],
  ['hemocura-core/bootstrap.js', './hemocura-core/bootstrap.js'],
  ['hemocura-core/layout.js', './hemocura-core/layout.js'],
  ['hemocura-core/router.js', './hemocura-core/router.js'],
  ['hemocura-core/supabase.js', './hemocura-core/supabase.js']
];

let lastReport = null;

async function inspectConfig() {
  try {
    const response = await fetch(`./js/config.js?_hc=${Date.now()}`, {cache:'no-store'});
    if (!response.ok) return {ok:false, detail:`HTTP ${response.status}`};
    const text = await response.text();
    const placeholder = text.includes('TU-PROYECTO') || text.includes('TU_CLAVE_PUBLICABLE');
    return {
      ok: !placeholder,
      detail: placeholder ? 'CONFIG PLACEHOLDER DETECTADO' : 'Configuración personalizada detectada'
    };
  } catch(error) {
    return {ok:false, detail:error.message};
  }
}


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

async function testResource(label, url) {
  const started = performance.now();
  try {
    const response = await fetch(`${url}?_hc=${Date.now()}`, {cache:'no-store'});
    const ms = Math.round(performance.now() - started);
    const text = await response.text();

    return {
      label,
      url,
      ok: response.ok,
      status: response.status,
      ms,
      bytes: text.length,
      contentType: response.headers.get('content-type') || '',
      detail: response.ok ? `${text.length} bytes` : `HTTP ${response.status}`
    };
  } catch(error) {
    return {
      label,
      url,
      ok:false,
      status:null,
      ms:Math.round(performance.now()-started),
      bytes:0,
      contentType:'',
      detail:error.message
    };
  }
}

async function readVersion() {
  const response = await fetch(`./VERSION.json?_hc=${Date.now()}`, {cache:'no-store'});
  if (!response.ok) throw new Error(`VERSION.json HTTP ${response.status}`);
  return response.json();
}

async function run() {
  const button = document.getElementById('status-run');
  const body = document.getElementById('status-body');
  const summary = document.getElementById('status-summary');

  button.disabled = true;
  button.textContent = 'Ejecutando…';
  summary.className = 'status info';
  summary.textContent = 'Comprobando archivos publicados…';
  body.innerHTML = '<tr><td colspan="5">Ejecutando…</td></tr>';

  try {
    const results = [];
    for (const [label,url] of CHECKS) {
      results.push(await testResource(label,url));
    }

    let version = null;
    let versionError = null;
    try {
      version = await readVersion();
      document.getElementById('version-output').textContent =
        JSON.stringify(version,null,2);
    } catch(error) {
      versionError = error.message;
      document.getElementById('version-output').textContent = error.message;
    }

    const configCheck = await inspectConfig();
    results.push({
      label:'js/config.js',
      url:'./js/config.js',
      ok:configCheck.ok,
      status:configCheck.ok ? 200 : null,
      ms:0,
      bytes:0,
      contentType:'application/javascript',
      detail:configCheck.detail
    });
    body.innerHTML = results.map(r => `
      <tr>
        <td><code>${esc(r.label)}</code></td>
        <td>${pill(r.ok)}</td>
        <td>${esc(r.status ?? '—')}</td>
        <td class="num">${r.ms} ms</td>
        <td>${esc(r.detail)}</td>
      </tr>`).join('');

    const failed = results.filter(r=>!r.ok).length + (versionError ? 1 : 0);

    lastReport = {
      generated_at:new Date().toISOString(),
      page:location.href,
      user_agent:navigator.userAgent,
      online:navigator.onLine,
      expected_version:'0.15.0',
      runtime_version:version?.version || null,
      release_channel:version?.release_channel || null,
      version_error:versionError,
      failed,
      checks:results
    };

    document.getElementById('status-report').textContent =
      JSON.stringify(lastReport,null,2);

    if (failed === 0 && version?.version === '0.15.0') {
      summary.className='status ok';
      summary.textContent='Despliegue estático OK · v0.15.0 detectada.';
    } else if (failed === 0) {
      summary.className='status warn';
      summary.textContent=`Archivos accesibles, pero versión detectada: ${version?.version || 'desconocida'}.`;
    } else {
      summary.className='status bad';
      summary.textContent=`${failed} comprobación(es) fallaron.`;
    }

    console.info('[HEMOCURA_DEPLOYMENT_VERIFIER]', lastReport);

  } finally {
    button.disabled=false;
    button.textContent='Ejecutar diagnóstico';
  }
}

document.getElementById('status-run').addEventListener('click', run);

document.getElementById('status-copy').addEventListener('click', async ()=>{
  if (!lastReport) {
    await run();
  }
  try {
    await navigator.clipboard.writeText(JSON.stringify(lastReport,null,2));
    document.getElementById('status-summary').className='status ok';
    document.getElementById('status-summary').textContent='Reporte copiado.';
  } catch(error) {
    console.info('[HEMOCURA_DEPLOYMENT_REPORT]', lastReport);
    document.getElementById('status-summary').className='status warn';
    document.getElementById('status-summary').textContent='No se pudo copiar automáticamente; reporte disponible en Console.';
  }
});

run();
