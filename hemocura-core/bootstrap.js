import { getSession } from './auth.js';
import { mountLayout } from './layout.js';
import { classifyError } from './diagnostic-engine.js';

async function currentVersion(){
  try{
    const r=await fetch('./VERSION.json',{cache:'no-store'});
    if(!r.ok) return 'desconocida';
    const v=await r.json();
    return v.version || 'desconocida';
  }catch{
    return 'desconocida';
  }
}

function renderBootError(app,error){
  const d=error?.diagnostic || classifyError(error,{subsystem:'BOOT',route:'bootstrap'});
  const msg=String(d.message||error?.message||error);
  const action=d.action || 'Abra F12 → Console y Network para revisar el detalle.';
  app.innerHTML=`
    <main class="boot">
      <h1>HemoCura Operations</h1>
      <div class="status bad">
        <strong>[${d.code||'BOOT_ERROR'}]</strong><br>
        ${msg}
      </div>
      <p><strong>Subsistema:</strong> ${d.subsystem||'BOOT'}</p>
      <p><strong>Acción sugerida:</strong> ${action}</p>
      <details>
        <summary>Diagnóstico técnico</summary>
        <pre class="debug-box">${String(d.technical||error?.stack||'Sin detalle adicional').replace(/</g,'&lt;')}</pre>
      </details>
      <p>
        Si el mensaje menciona <code>vw_my_security_context</code>,
        <code>vw_my_access</code> o <code>role_permissions</code>,
        ejecute primero la migración <code>29_ACCESS_GOVERNANCE_v0_29.sql</code>.
      </p>
      <p>
        Si menciona <code>relation ... does not exist</code>,
        falta una migración de Supabase.
      </p>
      <p>
        Si menciona <code>row-level security</code> o <code>permission denied</code>,
        revise perfil, rol, sucursal y RLS.
      </p>
      <p><a href="./deployment-check.html">Abrir Deployment Check</a></p>
      <p><a href="./login.html">Ir al login</a></p>
    </main>`;
}

export async function initApp(){
  const version=await currentVersion();
  console.info(`[HEMOCURA_BOOT] iniciando v${version}`);

  const app=document.getElementById('app');
  if(!app) throw new Error('No existe #app');

  const bootText=app.querySelector('[data-boot-status]');
  if(bootText) bootText.textContent=`Inicializando v${version}…`;

  try{
    const session=await getSession();

    if(!session){
      console.info('[HEMOCURA_AUTH] sin sesión → login');
      location.replace('./login.html');
      return;
    }

    // CRÍTICO: mountLayout es async. Debe esperarse para que
    // cualquier error de perfil/roles/RLS/schema llegue a este catch.
    await mountLayout(session);

    console.info(`[HEMOCURA_BOOT] OK v${version}`);
  }catch(error){
    console.error('[HEMOCURA_BOOT_ERROR]',error);
    renderBootError(app,error);
  }
}
