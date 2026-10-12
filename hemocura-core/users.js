import { loadUsersAdmin, inviteUser, createUser, addUserRole, removeUserRole, setUserActive } from './users-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot',"'":'&#039;'}[c]))}
function fmtDate(v){return v?new Date(v).toLocaleString('es-DO'):'—'}
function options(rows=[],label='name'){return rows.map(x=>`<option value="${esc(x.id)}">${esc(x[label]||x.code||x.id)}</option>`).join('')}
function roleBadges(user){
  const roles=user.roles||[];
  if(!roles.length)return '<span class="muted">Sin rol</span>';
  return roles.map(r=>`<span class="role-chip">${esc(r.role_name||r.role_code)} · ${esc(r.branch_name||'Global')} <button type="button" class="link-btn" data-remove-role="1" data-user-id="${esc(user.id)}" data-role-id="${esc(r.role_id)}" data-branch-id="${esc(r.branch_id)}" title="Retirar este rol">×</button></span>`).join(' ');
}
function matchesFilters(u,filters){
  const text=`${u.full_name||''} ${u.email||''}`.toLowerCase();
  if(filters.q&&!text.includes(filters.q))return false;
  if(filters.branch&&u.branch_id!==filters.branch&&!(u.roles||[]).some(r=>r.branch_id===filters.branch))return false;
  if(filters.role&&!(u.roles||[]).some(r=>r.role_id===filters.role))return false;
  if(filters.status==='active'&&!u.active)return false;
  if(filters.status==='inactive'&&u.active)return false;
  return true;
}
function userRows(users=[]){
  if(!users.length) return '<tr><td colspan="7" class="muted">No hay usuarios con los filtros seleccionados.</td></tr>';
  return users.map(u=>`<tr>
    <td><strong>${esc(u.full_name||'Sin nombre')}</strong><br><span class="muted">${esc(u.email||'')}</span></td>
    <td>${esc(u.branch_name||'—')}</td>
    <td>${roleBadges(u)}</td>
    <td>${u.active?'<span class="stock-pill stock-ok">Activo</span>':'<span class="stock-pill stock-none">Inactivo</span>'}</td>
    <td>${u.email_confirmed_at?'<span class="stock-pill stock-ok">Confirmado</span>':'<span class="stock-pill stock-warning">Pendiente</span>'}</td>
    <td>${fmtDate(u.last_sign_in_at)}</td>
    <td><div class="quick-links"><button class="secondary compact" data-add-role="${esc(u.id)}" data-user-name="${esc(u.full_name||u.email)}">+ Rol</button><button class="secondary compact" data-toggle-active="${esc(u.id)}" data-next-active="${u.active?'0':'1'}" ${u.id===u.caller_user_id?'disabled':''}>${u.active?'Desactivar':'Reactivar'}</button></div></td>
  </tr>`).join('');
}

export async function mountUsers(root){
  if(!root) return;
  root.innerHTML='<section class="card"><h3>Usuarios y roles</h3><div class="status info">Cargando administración segura…</div></section>';
  try{
    let state=await loadUsersAdmin();
    let filters={q:'',branch:'',role:'',status:'all'};
    const render=()=>{
      const normalized=(state.users||[]).map(u=>({...u,caller_user_id:state.caller_user_id}));
      const visible=normalized.filter(u=>matchesFilters(u,filters));
      root.innerHTML=`
        <div class="sales-toolbar"><div><h2 class="section-heading">Usuarios y roles</h2><div class="muted">Alta, acceso por sucursal y administración de roles con auditoría.</div></div><button id="users-refresh" class="secondary">Actualizar</button></div>
        <div class="status info"><strong>Seguridad:</strong> Auth administrativo y <code>service_role</code> permanecen en Supabase. El navegador sólo invoca acciones autorizadas con JWT.</div>
        <section class="card">
          <div class="card-head"><div><h3>Crear usuario</h3><div class="muted">Recomendado: enviar invitación para que la persona defina su acceso.</div></div></div>
          <form id="user-create-form" class="form-grid">
            <label>Nombre completo<input name="full_name" required autocomplete="name"></label>
            <label>Correo<input name="email" type="email" required autocomplete="email"></label>
            <label>Rol<select name="role_id" required><option value="">Seleccionar…</option>${options(state.roles)}</select></label>
            <label>Sucursal<select name="branch_id" required><option value="">Seleccionar…</option>${options((state.branches||[]).filter(b=>b.active))}</select></label>
            <label>Modo<select name="mode"><option value="invite">Enviar invitación</option><option value="create">Crear con contraseña temporal</option></select></label>
            <label id="temp-password-wrap" hidden>Contraseña temporal<input name="password" type="password" minlength="8" autocomplete="new-password"></label>
            <div class="form-actions"><button type="submit">Crear usuario</button></div>
          </form><div id="user-create-status"></div>
        </section>
        <section class="card">
          <div class="card-head"><div><h3>Usuarios existentes</h3><div class="muted">${visible.length} de ${state.users?.length||0} usuario(s)</div></div></div>
          <div class="form-grid">
            <label>Buscar<input id="users-q" type="search" value="${esc(filters.q)}" placeholder="Nombre o correo"></label>
            <label>Sucursal<select id="users-branch"><option value="">Todas</option>${options((state.branches||[]).filter(b=>b.active))}</select></label>
            <label>Rol<select id="users-role"><option value="">Todos</option>${options(state.roles)}</select></label>
            <label>Estado<select id="users-status"><option value="all">Todos</option><option value="active">Activos</option><option value="inactive">Inactivos</option></select></label>
          </div>
          <div class="table-wrap"><table class="data-table"><thead><tr><th>Usuario</th><th>Sucursal</th><th>Roles</th><th>Estado</th><th>Correo</th><th>Último acceso</th><th>Acción</th></tr></thead><tbody>${userRows(visible)}</tbody></table></div>
        </section>
        <section class="card hidden" id="add-role-card"><div class="card-head"><div><h3>Agregar rol</h3><div class="muted" id="add-role-user"></div></div><button type="button" class="secondary compact" id="add-role-close">Cerrar</button></div><form id="add-role-form" class="form-grid"><input type="hidden" name="user_id"><label>Rol<select name="role_id" required><option value="">Seleccionar…</option>${options(state.roles)}</select></label><label>Sucursal<select name="branch_id" required><option value="">Seleccionar…</option>${options((state.branches||[]).filter(b=>b.active))}</select></label><div class="form-actions"><button type="submit">Asignar rol</button></div></form><div id="add-role-status"></div></section>`;

      const mode=root.querySelector('[name="mode"]'),pwWrap=root.querySelector('#temp-password-wrap'),pw=root.querySelector('[name="password"]');
      mode.addEventListener('change',()=>{const show=mode.value==='create';pwWrap.hidden=!show;pw.required=show;if(!show)pw.value=''});
      root.querySelector('#users-branch').value=filters.branch;root.querySelector('#users-role').value=filters.role;root.querySelector('#users-status').value=filters.status;
      const refilter=()=>{filters={q:root.querySelector('#users-q').value.trim().toLowerCase(),branch:root.querySelector('#users-branch').value,role:root.querySelector('#users-role').value,status:root.querySelector('#users-status').value};render()};
      root.querySelector('#users-q').addEventListener('input',refilter);root.querySelector('#users-branch').addEventListener('change',refilter);root.querySelector('#users-role').addEventListener('change',refilter);root.querySelector('#users-status').addEventListener('change',refilter);
      root.querySelector('#users-refresh').onclick=async()=>{state=await loadUsersAdmin();render()};

      root.querySelector('#user-create-form').addEventListener('submit',async e=>{e.preventDefault();const form=e.currentTarget,btn=form.querySelector('button[type="submit"]'),status=root.querySelector('#user-create-status');btn.disabled=true;status.innerHTML='<div class="status info">Procesando…</div>';const payload=Object.fromEntries(new FormData(form).entries());try{if(payload.mode==='invite')await inviteUser(payload);else await createUser(payload);state=await loadUsersAdmin();render()}catch(err){status.innerHTML=`<div class="status bad">${esc(err.message)}</div>`;btn.disabled=false}});

      root.querySelectorAll('[data-add-role]').forEach(btn=>btn.onclick=()=>{const card=root.querySelector('#add-role-card');card.classList.remove('hidden');root.querySelector('#add-role-user').textContent=`Usuario: ${btn.dataset.userName}`;root.querySelector('#add-role-form [name="user_id"]').value=btn.dataset.addRole;card.scrollIntoView({behavior:'smooth',block:'start'})});
      root.querySelector('#add-role-close').onclick=()=>root.querySelector('#add-role-card').classList.add('hidden');
      root.querySelector('#add-role-form').addEventListener('submit',async e=>{e.preventDefault();const payload=Object.fromEntries(new FormData(e.currentTarget).entries()),status=root.querySelector('#add-role-status');status.innerHTML='<div class="status info">Asignando…</div>';try{await addUserRole(payload);state=await loadUsersAdmin();render()}catch(err){status.innerHTML=`<div class="status bad">${esc(err.message)}</div>`}});

      root.querySelectorAll('[data-remove-role]').forEach(btn=>btn.onclick=async()=>{if(!confirm('¿Retirar este rol del usuario?'))return;try{await removeUserRole({user_id:btn.dataset.userId,role_id:btn.dataset.roleId,branch_id:btn.dataset.branchId});state=await loadUsersAdmin();render()}catch(err){alert(err.message)}});
      root.querySelectorAll('[data-toggle-active]').forEach(btn=>btn.onclick=async()=>{const active=btn.dataset.nextActive==='1';if(!confirm(active?'¿Reactivar este usuario?':'¿Desactivar este usuario? El acceso quedará bloqueado.'))return;try{await setUserActive({user_id:btn.dataset.toggleActive,active});state=await loadUsersAdmin();render()}catch(err){alert(err.message)}});
    };
    render();
  }catch(error){console.error('[HEMOCURA_USERS_ERROR]',error);root.innerHTML=`<section class="card"><h3>Usuarios y roles</h3><div class="status bad">${esc(error.message)}</div><p class="muted">Se requiere permiso <code>ACCESS_ADMIN</code>.</p></section>`}
}
