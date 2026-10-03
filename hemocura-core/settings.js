import {
  loadSettingsWorkspace,
  runSystemDiagnostics
} from './settings-data.js';
import { getSession } from './auth.js';

function esc(v='') {
  return String(v ?? '').replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

function boolPill(v) {
  return v
    ? '<span class="stock-pill stock-ok">Sí</span>'
    : '<span class="stock-pill stock-none">No</span>';
}

function modePill(mode='') {
  const m=String(mode).toUpperCase();
  const cls = m==='LIVE' ? 'stock-ok'
    : ['LIVE_LIMITED','SHADOW','PARALLEL'].includes(m) ? 'stock-warning'
    : m==='MAINTENANCE' ? 'stock-critical'
    : 'stock-none';
  return `<span class="stock-pill ${cls}">${esc(mode || 'N/D')}</span>`;
}

function profileRows(rows, branches) {
  const bm=Object.fromEntries(branches.map(b=>[b.id,b]));
  if(!rows.length) return `<tr><td colspan="5" class="muted">No hay perfiles visibles o RLS limita la consulta.</td></tr>`;
  return rows.map(p=>`
    <tr>
      <td>${esc(p.full_name || 'Sin nombre')}</td>
      <td><code>${esc(p.id)}</code></td>
      <td>${esc(bm[p.branch_id]?.name || (p.branch_id ? p.branch_id : 'Corporativo'))}</td>
      <td>${boolPill(p.active)}</td>
      <td>${esc(p.updated_at ? new Date(p.updated_at).toLocaleString('es-DO') : '')}</td>
    </tr>`).join('');
}

function roleRows(roles, userRoles, profiles, branches) {
  const rm=Object.fromEntries(roles.map(r=>[r.id,r]));
  const pm=Object.fromEntries(profiles.map(p=>[p.id,p]));
  const bm=Object.fromEntries(branches.map(b=>[b.id,b]));

  if(!userRoles.length) return `<tr><td colspan="4" class="muted">No hay asignaciones visibles o RLS limita la consulta.</td></tr>`;

  return userRoles.map(ur=>`
    <tr>
      <td>${esc(pm[ur.user_id]?.full_name || ur.user_id)}</td>
      <td>${esc(rm[ur.role_id]?.code || ur.role_id)}</td>
      <td>${esc(rm[ur.role_id]?.name || '')}</td>
      <td>${esc(bm[ur.branch_id]?.name || (ur.branch_id ? ur.branch_id : 'Global'))}</td>
    </tr>`).join('');
}

function branchRows(rows) {
  if(!rows.length) return `<tr><td colspan="4">Sin sucursales visibles.</td></tr>`;
  return rows.map(b=>`
    <tr>
      <td>${esc(b.code)}</td>
      <td><strong>${esc(b.name)}</strong></td>
      <td>${boolPill(b.active)}</td>
      <td>${esc(b.updated_at ? new Date(b.updated_at).toLocaleString('es-DO') : '')}</td>
    </tr>`).join('');
}

function productRows(rows) {
  if(!rows.length) return `<tr><td colspan="5">Sin productos visibles.</td></tr>`;
  return rows.map(p=>`
    <tr>
      <td>${esc(p.code)}</td>
      <td><strong>${esc(p.name)}</strong></td>
      <td>${esc(p.category || '—')}</td>
      <td>${esc(p.unit_of_measure || 'unidad')}</td>
      <td>${boolPill(p.active)}</td>
    </tr>`).join('');
}

function flagRows(result) {
  if(!result?.ok) {
    return `<tr><td colspan="5"><div class="status warn">Producción Caliente no disponible: ${esc(result?.error || 'No instalado')}</div></td></tr>`;
  }
  const rows=result.data || [];
  if(!rows.length) return `<tr><td colspan="5">Sin feature flags.</td></tr>`;
  return rows.map(f=>`
    <tr>
      <td><code>${esc(f.key)}</code></td>
      <td>${boolPill(f.enabled)}</td>
      <td>${modePill(f.mode)}</td>
      <td>${esc(f.description || '')}</td>
      <td>${esc(f.updated_at ? new Date(f.updated_at).toLocaleString('es-DO') : '')}</td>
    </tr>`).join('');
}

function releaseRows(result) {
  if(!result?.ok) return `<tr><td colspan="6">No disponible.</td></tr>`;
  const rows=result.data || [];
  if(!rows.length) return `<tr><td colspan="6">Sin releases registrados.</td></tr>`;
  return rows.map(r=>`
    <tr>
      <td>${esc(r.version)}</td><td>${esc(r.environment)}</td><td>${modePill(r.status)}</td>
      <td>${esc(r.deployed_at ? new Date(r.deployed_at).toLocaleString('es-DO') : '—')}</td>
      <td>${esc(r.notes || '')}</td>
      <td>${esc(r.created_at ? new Date(r.created_at).toLocaleString('es-DO') : '')}</td>
    </tr>`).join('');
}

function diagRows(rows) {
  return rows.map(r=>`
    <tr>
      <td><code>${esc(r.label)}</code></td>
      <td>${r.ok ? '<span class="stock-pill stock-ok">OK</span>' : '<span class="stock-pill stock-critical">ERROR</span>'}</td>
      <td>${r.ok ? 'Accesible' : esc(r.error)}</td>
    </tr>`).join('');
}

function healthHtml(result) {
  if(!result?.ok) {
    return `<div class="status warn">production_healthcheck() no está disponible: ${esc(result?.error || '')}</div>`;
  }
  return `<pre class="json-box">${esc(JSON.stringify(result.data,null,2))}</pre>`;
}

export async function mountSettings(root) {
  if(!root) return;

  root.innerHTML=`<section class="card"><h3>Configuración</h3><div class="status info">Cargando catálogos, permisos y diagnóstico…</div></section>`;

  try {
    const [ws, session] = await Promise.all([
      loadSettingsWorkspace(),
      getSession()
    ]);

    const production=ws.production || {};
    const operating=production.mode?.ok ? production.mode.data : null;

    root.innerHTML=`
      <div class="sales-toolbar">
        <div>
          <h2 class="section-heading">Configuración y diagnóstico</h2>
          <div class="muted">Auditoría de configuración. Administración de Auth se mantiene fuera del navegador.</div>
        </div>
        <button id="run-diagnostics" class="secondary">Ejecutar diagnóstico</button>
      </div>

      <div class="status info">
        <strong>Usuario:</strong> ${esc(session?.user?.email || session?.user?.id || '—')} ·
        Este módulo es deliberadamente de consulta. No utiliza <code>service_role</code>.
      </div>

      <div id="settings-errors">
        ${ws.errors.length ? `<div class="status warn">Carga parcial: ${esc(ws.errors.join(' · '))}</div>` : ''}
      </div>

      <section class="card">
        <h3>Modo operativo</h3>
        ${production.mode?.ok
          ? `<div class="grid sales-kpis">
               <section class="card"><div class="muted">Modo</div><div class="kpi small-kpi">${modePill(operating?.mode)}</div></section>
               <section class="card"><div class="muted">Excel paralelo</div><div class="kpi small-kpi">${boolPill(operating?.excel_parallel_required)}</div></section>
               <section class="card"><div class="muted">Despacho clínico/unidad</div><div class="kpi small-kpi">${boolPill(operating?.clinical_unit_dispatch_enabled)}</div></section>
               <section class="card"><div class="muted">Bloqueo térmico</div><div class="kpi small-kpi">${boolPill(operating?.temperature_blocking_enabled)}</div></section>
             </div>`
          : `<div class="status warn">El paquete Producción Caliente no está accesible o no está instalado: ${esc(production.mode?.error || '')}</div>`}
      </section>

      <section class="card">
        <div class="card-head"><h3>Feature flags</h3><span class="muted">LIVE / LIVE_LIMITED / SHADOW / OFF</span></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Clave</th><th>Activo</th><th>Modo</th><th>Descripción</th><th>Actualizado</th></tr></thead>
            <tbody>${flagRows(production.flags)}</tbody>
          </table>
        </div>
      </section>

      <section class="card">
        <h3>Healthcheck de producción</h3>
        ${healthHtml(production.health)}
      </section>

      <section class="card">
        <div class="card-head"><h3>Perfiles</h3><span class="muted">${ws.profiles.length} visible(s)</span></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Nombre</th><th>User ID</th><th>Sucursal</th><th>Activo</th><th>Actualizado</th></tr></thead>
            <tbody>${profileRows(ws.profiles,ws.branches)}</tbody>
          </table>
        </div>
      </section>

      <section class="card">
        <div class="card-head"><h3>Roles y alcance</h3><span class="muted">${ws.userRoles.length} asignación(es) visible(s)</span></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Usuario</th><th>Rol</th><th>Nombre</th><th>Sucursal / alcance</th></tr></thead>
            <tbody>${roleRows(ws.roles,ws.userRoles,ws.profiles,ws.branches)}</tbody>
          </table>
        </div>
      </section>

      <section class="card">
        <div class="card-head"><h3>Sucursales</h3><span class="muted">${ws.branches.length}</span></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Código</th><th>Nombre</th><th>Activa</th><th>Actualizada</th></tr></thead>
            <tbody>${branchRows(ws.branches)}</tbody>
          </table>
        </div>
      </section>

      <section class="card">
        <div class="card-head"><h3>Productos</h3><span class="muted">${ws.products.length}</span></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Código</th><th>Nombre</th><th>Categoría</th><th>Unidad</th><th>Activo</th></tr></thead>
            <tbody>${productRows(ws.products)}</tbody>
          </table>
        </div>
      </section>

      <section class="card">
        <div class="card-head"><h3>Últimos releases</h3><span class="muted">Producción Caliente</span></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Versión</th><th>Entorno</th><th>Estado</th><th>Desplegado</th><th>Notas</th><th>Creado</th></tr></thead>
            <tbody>${releaseRows(production.releases)}</tbody>
          </table>
        </div>
      </section>

      <section class="card hidden" id="diagnostics-card">
        <div class="card-head">
          <div><h3>Diagnóstico central</h3><div class="muted">Prueba de acceso a cada subsistema.</div></div>
          <button id="copy-diagnostics" class="secondary compact">Copiar diagnóstico</button>
        </div>
        <div id="diagnostics-status"></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Objeto</th><th>Estado</th><th>Detalle</th></tr></thead>
            <tbody id="diagnostics-body"></tbody>
          </table>
        </div>
      </section>

      <div class="debug-strip">[HEMOCURA_SETTINGS] OK · configuración en modo lectura</div>`;

    let lastDiagnostics=[];

    document.getElementById('run-diagnostics').addEventListener('click', async ()=>{
      const btn=document.getElementById('run-diagnostics');
      btn.disabled=true;
      btn.textContent='Diagnosticando…';

      const card=document.getElementById('diagnostics-card');
      card.classList.remove('hidden');
      document.getElementById('diagnostics-body').innerHTML=
        `<tr><td colspan="3">Ejecutando pruebas…</td></tr>`;

      try {
        lastDiagnostics=await runSystemDiagnostics();
        document.getElementById('diagnostics-body').innerHTML=diagRows(lastDiagnostics);

        const errors=lastDiagnostics.filter(x=>!x.ok).length;
        document.getElementById('diagnostics-status').innerHTML=
          errors
            ? `<div class="status warn">${errors} objeto(s) presentan error o no están accesibles.</div>`
            : `<div class="status ok">Todos los objetos comprobados son accesibles.</div>`;

        console.info('[HEMOCURA_DIAGNOSTICS] OK',lastDiagnostics);
      } catch(error) {
        document.getElementById('diagnostics-status').innerHTML=
          `<div class="status bad">${esc(error.message)}</div>`;
      } finally {
        btn.disabled=false;
        btn.textContent='Ejecutar diagnóstico';
      }
    });

    document.getElementById('copy-diagnostics').addEventListener('click', async ()=>{
      const report={
        timestamp:new Date().toISOString(),
        version:'0.11.0',
        user:session?.user?.email || session?.user?.id || null,
        operating_mode:operating || null,
        diagnostics:lastDiagnostics.map(x=>({
          object:x.label,
          ok:x.ok,
          error:x.error || null
        }))
      };

      try {
        await navigator.clipboard.writeText(JSON.stringify(report,null,2));
        document.getElementById('diagnostics-status').innerHTML=
          `<div class="status ok">Diagnóstico copiado al portapapeles.</div>`;
      } catch(error) {
        document.getElementById('diagnostics-status').innerHTML=
          `<div class="status warn">No se pudo copiar automáticamente. Use F12 → Console.</div>`;
        console.info('[HEMOCURA_DIAGNOSTICS_REPORT]',report);
      }
    });

    console.info('[HEMOCURA_SETTINGS] módulo OK');

  } catch(error) {
    console.error('[HEMOCURA_SETTINGS_ERROR]',error);
    root.innerHTML=`
      <section class="card">
        <h3>Configuración no disponible</h3>
        <div class="status bad">${esc(error.message)}</div>
        <p>Abra F12 → Console y busque <code>HEMOCURA_SETTINGS_ERROR</code>.</p>
      </section>`;
  }
}
