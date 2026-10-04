import { diagnosticData } from './diagnostic-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
function levelClass(d){
  if(d.code==='CONFIG_OK') return 'ok';
  if(d.severity==='CRITICAL'||d.severity==='ERROR') return 'bad';
  if(d.severity==='WARN') return 'warn';
  return 'info';
}
function card(title,d){
  return `<section class="card"><h3>${esc(title)}</h3>
    <div class="status ${levelClass(d)}"><strong>${esc(d.code)}</strong> · ${esc(d.message)}</div>
    <p><strong>Subsistema:</strong> ${esc(d.subsystem||'—')}</p>
    <p><strong>Acción:</strong> ${esc(d.action||'—')}</p>
    ${d.technical?`<details><summary>Detalle técnico</summary><pre class="debug-box">${esc(d.technical)}</pre></details>`:''}
  </section>`;
}

export async function mountDiagnostics(root){
  root.innerHTML=`<div class="sales-toolbar"><div><h2 class="section-heading">Diagnóstico Unificado</h2>
  <div class="muted">Identifica qué falló, dónde ocurrió y qué acción tomar.</div></div>
  <button id="diag-run">Ejecutar diagnóstico</button></div>
  <div id="diag-summary"></div>
  <div class="diag-grid" id="diag-results"></div>
  <section class="card"><h3>Configuración enmascarada</h3><div id="diag-config"></div></section>
  <section class="card"><h3>Migraciones</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Versión</th><th>Migración</th><th>Aplicada</th><th>Fecha</th></tr></thead><tbody id="diag-migrations"></tbody>
  </table></div></section>
  <section class="card"><h3>Objetos requeridos</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Tipo</th><th>Objeto</th><th>Existe</th></tr></thead><tbody id="diag-schema"></tbody>
  </table></div></section>
  <section class="card"><h3>Códigos frecuentes</h3>
  <div class="table-wrap"><table class="data-table"><thead><tr><th>Código</th><th>Significado</th><th>Acción</th></tr></thead><tbody>
  <tr><td><code>NETWORK_FAILED</code></td><td>No se pudo llegar a Supabase</td><td>Revise internet, URL, DNS/firewall.</td></tr>
  <tr><td><code>AUTH_INVALID_CREDENTIALS</code></td><td>Credenciales rechazadas</td><td>Revise correo/contraseña.</td></tr>
  <tr><td><code>PROFILE_MISSING</code></td><td>Auth existe pero no profile</td><td>Crear/recuperar profile.</td></tr>
  <tr><td><code>ROLE_MISSING</code></td><td>Sin rol asignado</td><td>Asignar user_roles.</td></tr>
  <tr><td><code>RLS_DENIED</code></td><td>RLS bloqueó la operación</td><td>Revisar rol, sucursal y policy.</td></tr>
  <tr><td><code>MIGRATION_MISSING</code></td><td>Schema incompleto</td><td>Ejecutar migraciones pendientes.</td></tr>
  </tbody></table></div></section>`;

  async function run(){
    const c=diagnosticData.config();
    document.getElementById('diag-config').innerHTML=`
      <p><strong>Host:</strong> ${esc(c.masked.host)}</p>
      <p><strong>Key:</strong> ${esc(c.masked.key)}</p>
      <p><strong>APP_BASE:</strong> ${esc(c.masked.appBase)}</p>
      ${c.problems.length?`<div class="status bad">${c.problems.map(esc).join(' · ')}</div>`:`<div class="status ok">CONFIG_OK</div>`}`;

    const configDiag=c.ok
      ? {code:'CONFIG_OK',severity:'INFO',subsystem:'CONFIG',message:'Configuración con formato válido.',action:'Continuar con conectividad.'}
      : {code:'CONFIG_ERROR',severity:'ERROR',subsystem:'CONFIG',message:c.problems.join(' · '),action:'Corregir js/config.js.'};

    let connection={code:'SKIPPED',severity:'WARN',subsystem:'SUPABASE',message:'No ejecutado.',action:'Corrija configuración primero.'};
    let session={code:'SKIPPED',severity:'WARN',subsystem:'AUTH',message:'No ejecutado.',action:'Corrija configuración primero.'};
    let health={code:'SKIPPED',severity:'WARN',subsystem:'ACCESS',message:'No ejecutado.',action:'Inicie sesión primero.'};
    let migrations={code:'SKIPPED',severity:'WARN',subsystem:'DATABASE',message:'No ejecutado.',action:'Inicie sesión primero.',rows:[]};
    let schema={code:'SKIPPED',severity:'WARN',subsystem:'DATABASE',message:'No ejecutado.',action:'Inicie sesión primero.',rows:[]};

    if(c.ok){
      connection=await diagnosticData.connection();
      session=await diagnosticData.session();
      if(session.code!=='SESSION_MISSING' && session.code!=='AUTH_FAILED'){
        [health,migrations,schema]=await Promise.all([
          diagnosticData.userHealth(),
          diagnosticData.migrations(),
          diagnosticData.schema()
        ]);
      }
    }

    const all=[configDiag,connection,session,health,migrations,schema];
    document.getElementById('diag-results').innerHTML=
      card('Configuración',configDiag)+card('Conectividad',connection)+card('Sesión',session)+
      card('Perfil / Roles / Permisos',health)+card('Migraciones',migrations)+card('Schema',schema);

    document.getElementById('diag-migrations').innerHTML=(migrations.rows||[]).length
      ? migrations.rows.map(r=>`<tr><td>${esc(r.version)}</td><td><code>${esc(r.migration_code)}</code></td><td>${r.applied?'Sí':'NO'}</td><td>${esc(r.applied_at||'—')}</td></tr>`).join('')
      : '<tr><td colspan="4">Sin datos.</td></tr>';

    document.getElementById('diag-schema').innerHTML=(schema.rows||[]).length
      ? schema.rows.map(r=>`<tr><td>${esc(r.object_type)}</td><td><code>${esc(r.object_name)}</code></td><td>${r.object_exists?'Sí':'NO'}</td></tr>`).join('')
      : '<tr><td colspan="3">Sin datos.</td></tr>';

    const errors=all.filter(d=>d.code!=='CONFIG_OK' && d.code!=='SKIPPED' && (d.severity==='ERROR'||d.severity==='CRITICAL')).length;
    const warns=all.filter(d=>d.code!=='CONFIG_OK' && d.severity==='WARN').length;
    document.getElementById('diag-summary').innerHTML=`<div class="status ${errors?'bad':warns?'warn':'ok'}">
      ${errors?`${errors} problema(s) crítico(s) detectado(s).`:warns?`${warns} advertencia(s).`:'DIAGNÓSTICO OK'}
    </div>`;

    for(const d of all){
      if(d.code && !['CONFIG_OK','SKIPPED'].includes(d.code)) diagnosticData.log(d);
    }
  }

  document.getElementById('diag-run').onclick=run;
  await run();
}
