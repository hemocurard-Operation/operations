import { releaseData } from './release-data.js';

function esc(v=''){
  return String(v??'').replace(/[&<>"']/g,c=>({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

async function fetchJsonNoCache(path){
  const r=await fetch(path,{cache:'no-store'});
  if(!r.ok) throw new Error(`${path}: HTTP ${r.status}`);
  return r.json();
}

async function fetchTextNoCache(path){
  const r=await fetch(path,{cache:'no-store'});
  if(!r.ok) throw new Error(`${path}: HTTP ${r.status}`);
  return r.text();
}

export async function mountReleaseGate(root){
  root.innerHTML=`
    <div class="sales-toolbar">
      <div>
        <h2 class="section-heading">Release Gate</h2>
        <div class="muted">Configuración, frontend, Supabase y migraciones antes de promover una versión.</div>
      </div>
      <button id="rel-run">Ejecutar validación</button>
    </div>
    <div id="rel-msg"></div>
    <div class="grid sales-kpis" id="rel-kpis"></div>

    <section class="card">
      <h3>Configuración protegida</h3>
      <div id="config-result"></div>
    </section>

    <section class="card">
      <h3>Archivos frontend</h3>
      <div class="table-wrap"><table class="data-table">
        <thead><tr><th>Archivo</th><th>Estado</th><th>Detalle</th></tr></thead>
        <tbody id="frontend-body"></tbody>
      </table></div>
    </section>

    <section class="card">
      <h3>Objetos Supabase</h3>
      <div class="table-wrap"><table class="data-table">
        <thead><tr><th>Tipo</th><th>Objeto</th><th>Existe</th></tr></thead>
        <tbody id="schema-body"></tbody>
      </table></div>
    </section>

    <section class="card">
      <h3>Migraciones</h3>
      <div class="table-wrap"><table class="data-table">
        <thead><tr><th>Migración</th><th>Versión</th><th>Aplicada</th><th>Fecha</th></tr></thead>
        <tbody id="migration-body"></tbody>
      </table></div>
    </section>

    <section class="card">
      <h3>Historial de releases</h3>
      <div class="table-wrap"><table class="data-table">
        <thead><tr><th>Versión</th><th>Canal</th><th>Estado</th><th>Creado</th><th>Notas</th></tr></thead>
        <tbody id="releases-body"></tbody>
      </table></div>
    </section>

    <section class="card">
      <div class="status warn">
        <strong>Archivo protegido:</strong> <code>js/config.js</code> no forma parte de los paquetes de actualización.
        La plantilla es <code>js/config.example.js</code>.
      </div>
    </section>`;

  async function run(){
    const checks=[];
    const config=releaseData.configCheck();

    document.getElementById('config-result').innerHTML=`
      <div class="status ${config.ok?'ok':'bad'}">
        ${config.ok?'Configuración válida':'Configuración con problemas'}
      </div>
      <p><strong>Host:</strong> ${esc(config.host||'—')}</p>
      <p><strong>APP_BASE:</strong> ${esc(config.appBase||'—')}</p>
      <p><strong>Publishable key:</strong> ${esc(config.keyPreview)}</p>
      ${config.problems.length?`<ul>${config.problems.map(x=>`<li>${esc(x)}</li>`).join('')}</ul>`:''}`;

    const files=[
      './VERSION.json',
      './index.html',
      './login.html',
      './js/app.js',
      './js/config.js',
      './hemocura-core/bootstrap.js',
      './hemocura-core/layout.js'
    ];

    const fileResults=[];
    for(const path of files){
      try{
        const text=await fetchTextNoCache(path);
        let detail=`${text.length} bytes`;
        if(path.endsWith('config.js') && (text.includes('TU-PROYECTO')||text.includes('TU_CLAVE'))){
          throw new Error('Contiene placeholders');
        }
        fileResults.push({path,ok:true,detail});
      }catch(e){
        fileResults.push({path,ok:false,detail:e.message});
      }
    }

    document.getElementById('frontend-body').innerHTML=fileResults.map(x=>`
      <tr><td><code>${esc(x.path)}</code></td><td>${x.ok?'OK':'ERROR'}</td><td>${esc(x.detail)}</td></tr>
    `).join('');

    let schema=[],migrations=[],ready=null,releases=[],version=null;
    try{
      [schema,migrations,ready,releases,version]=await Promise.all([
        releaseData.schema(),
        releaseData.migrations(),
        releaseData.readiness(),
        releaseData.releases(),
        fetchJsonNoCache('./VERSION.json')
      ]);

      document.getElementById('schema-body').innerHTML=schema.map(x=>`
        <tr><td>${esc(x.object_type)}</td><td><code>${esc(x.object_name)}</code></td><td>${x.object_exists?'Sí':'NO'}</td></tr>
      `).join('');

      document.getElementById('migration-body').innerHTML=migrations.map(x=>`
        <tr><td><code>${esc(x.migration_code)}</code></td><td>${esc(x.version)}</td><td>${x.applied?'Sí':'NO'}</td><td>${esc(x.applied_at||'—')}</td></tr>
      `).join('');

      document.getElementById('releases-body').innerHTML=releases.length?releases.map(x=>`
        <tr><td>${esc(x.version)}</td><td>${esc(x.release_channel)}</td><td>${esc(x.status)}</td><td>${esc(x.created_at)}</td><td>${esc(x.validation_notes||'')}</td></tr>
      `).join(''):`<tr><td colspan="5">Sin releases registrados.</td></tr>`;

      const frontendOk=fileResults.every(x=>x.ok);
      const schemaOk=schema.every(x=>x.object_exists);
      const migrationsOk=migrations.every(x=>x.applied);
      const allOk=config.ok && frontendOk && schemaOk && migrationsOk && ready?.backend_ready;

      document.getElementById('rel-kpis').innerHTML=`
        <section class="card"><div class="muted">Config</div><div class="kpi">${config.ok?'OK':'ERROR'}</div></section>
        <section class="card"><div class="muted">Frontend</div><div class="kpi">${frontendOk?'OK':'ERROR'}</div></section>
        <section class="card"><div class="muted">Schema</div><div class="kpi">${schema.filter(x=>x.object_exists).length}/${schema.length}</div></section>
        <section class="card"><div class="muted">Migraciones</div><div class="kpi">${migrations.filter(x=>x.applied).length}/${migrations.length}</div></section>`;

      document.getElementById('rel-msg').innerHTML=`
        <div class="status ${allOk?'ok':'warn'}">
          ${allOk
            ? `READY: ${esc(version?.version||'versión actual')} cumple el Release Gate.`
            : 'NOT READY: corrija los elementos pendientes antes de promover esta versión.'}
        </div>`;

      if(allOk && version?.version){
        try{
          await releaseData.registerRelease({
            version:version.version,
            release_channel:version.release_channel||'RC',
            status:'VALIDACION',
            validation_notes:'Release Gate automático: configuración, frontend, schema y migraciones OK'
          });
        }catch(e){
          console.warn('[HEMOCURA_RELEASE_GATE] No se pudo registrar release',e);
        }
      }
    }catch(e){
      document.getElementById('rel-msg').innerHTML=`<div class="status bad">${esc(e.message)} · Ejecute la migración v0.28.0.</div>`;
    }
  }

  document.getElementById('rel-run').onclick=run;
  await run();
}
