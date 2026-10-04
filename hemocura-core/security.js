import { accessData } from './access-data.js';
import { loadAccess, resetAccessCache } from './access-control.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}

export async function mountSecurity(root){
  root.innerHTML=`
    <div class="sales-toolbar">
      <div><h2 class="section-heading">Seguridad y Acceso</h2>
      <div class="muted">Auth, perfil, sucursal, roles, permisos y eventos de acceso.</div></div>
      <button id="sec-refresh" class="secondary">Actualizar</button>
    </div>
    <div id="sec-msg"></div>
    <div class="grid sales-kpis" id="sec-kpis"></div>
    <section class="card"><h3>Mi contexto</h3><div id="sec-context"></div></section>
    <section class="card"><h3>Permisos efectivos</h3>
      <div class="table-wrap"><table class="data-table">
      <thead><tr><th>Módulo</th><th>Permiso</th><th>Riesgo</th><th>Rol</th><th>Sucursal rol</th></tr></thead>
      <tbody id="sec-permissions"></tbody></table></div>
    </section>
    <section class="card"><h3>Eventos recientes de acceso</h3>
      <div class="table-wrap"><table class="data-table">
      <thead><tr><th>Fecha</th><th>Ruta</th><th>Permiso</th><th>Permitido</th><th>Razón</th></tr></thead>
      <tbody id="sec-events"></tbody></table></div>
    </section>`;

  async function load(){
    try{
      resetAccessCache();
      const [a,ready,events]=await Promise.all([
        loadAccess(),
        accessData.readiness(),
        accessData.accessEvents()
      ]);

      const c=a.context||{};
      document.getElementById('sec-context').innerHTML=`
        <p><strong>Usuario:</strong> ${esc(c.email||'—')}</p>
        <p><strong>Nombre:</strong> ${esc(c.full_name||'—')}</p>
        <p><strong>Sucursal:</strong> ${esc(c.branch_code||'—')} · ${esc(c.branch_name||'—')}</p>
        <p><strong>Roles:</strong> ${esc(JSON.stringify(c.roles||[]))}</p>`;

      document.getElementById('sec-permissions').innerHTML=a.rows.length?a.rows.map(r=>`
        <tr><td>${esc(r.module)}</td><td><code>${esc(r.permission_code)}</code></td>
        <td>${esc(r.risk_level)}</td><td>${esc(r.role_code)}</td><td>${esc(r.role_branch_id||'—')}</td></tr>
      `).join(''):`<tr><td colspan="5">Sin permisos efectivos.</td></tr>`;

      document.getElementById('sec-events').innerHTML=events.length?events.map(e=>`
        <tr><td>${esc(new Date(e.event_time).toLocaleString('es-DO'))}</td>
        <td>${esc(e.route||'—')}</td><td>${esc(e.permission_code||'—')}</td>
        <td>${e.allowed?'Sí':'NO'}</td><td>${esc(e.reason||'—')}</td></tr>
      `).join(''):`<tr><td colspan="5">Sin eventos.</td></tr>`;

      document.getElementById('sec-kpis').innerHTML=`
        <section class="card"><div class="muted">Permisos</div><div class="kpi">${ready.permissions_count}</div></section>
        <section class="card"><div class="muted">Roles</div><div class="kpi">${ready.roles_count}</div></section>
        <section class="card"><div class="muted">Usuarios</div><div class="kpi">${ready.profiles_count}</div></section>
        <section class="card"><div class="muted">Roles→usuarios</div><div class="kpi">${ready.user_role_links}</div></section>`;

      document.getElementById('sec-msg').innerHTML=`
        <div class="status ${ready.user_roles_have_profiles?'ok':'warn'}">
          ${ready.user_roles_have_profiles?'Perfiles y asignaciones consistentes.':'Hay asignaciones de rol sin perfil.'}
        </div>`;
    }catch(e){
      document.getElementById('sec-msg').innerHTML=
        `<div class="status warn">${esc(e.message)} · Ejecute sql/29_ACCESS_GOVERNANCE_v0_29.sql.</div>`;
    }
  }
  document.getElementById('sec-refresh').onclick=load;
  await load();
}
