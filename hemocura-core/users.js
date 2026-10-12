import { loadUsersAdmin, inviteUser, createUser, addUserRole } from './users-data.js';

const BRANCH_SCOPED_ROLES=new Set(['LABORATORIO','CONSULTA','ENCARGADA_LABORATORIO']);
const SUPER_ROLE='SUPER_USUARIO';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
function fmtDate(v){return v?new Date(v).toLocaleString('es-DO'):'—'}
function options(rows=[],label='name'){return rows.map(x=>`<option value="${esc(x.id)}">${esc(x[label]||x.code||x.id)}</option>`).join('')}
function roleById(state,id){return (state.roles||[]).find(r=>r.id===id)||null}
function activeBranches(state){return (state.branches||[]).filter(b=>b.active)}

function roleBadges(roles=[]){
  if(!roles.length)return '<span class="muted">Sin rol</span>';
  const grouped=new Map();
  for(const r of roles){
    const key=r.role_code||r.role_id;
    const g=grouped.get(key)||{name:r.role_name||r.role_code,code:r.role_code,branches:[]};
    if(r.branch_name&&!g.branches.includes(r.branch_name))g.branches.push(r.branch_name);
    grouped.set(key,g);
  }
  return [...grouped.values()].map(g=>{
    const scope=g.code===SUPER_ROLE?'Todas las sucursales':(g.branches.join(', ')||'Sin sucursal');
    return `<span class="role-chip">${esc(g.name)} · ${esc(scope)}</span>`;
  }).join(' ');
}

function userRows(users=[]){
  if(!users.length)return '<tr><td colspan="7" class="muted">No hay usuarios visibles.</td></tr>';
  return users.map(u=>`<tr>
    <td><strong>${esc(u.full_name||'Sin nombre')}</strong><br><span class="muted">${esc(u.email||'')}</span></td>
    <td>${esc(u.branch_name||'—')}</td>
    <td>${roleBadges(u.roles)}</td>
    <td>${u.active?'<span class="stock-pill stock-ok">Activo</span>':'<span class="stock-pill stock-none">Inactivo</span>'}</td>
    <td>${u.email_confirmed_at?'<span class="stock-pill stock-ok">Confirmado</span>':'<span class="stock-pill stock-warning">Pendiente</span>'}</td>
    <td>${fmtDate(u.last_sign_in_at)}</td>
    <td><button class="secondary compact" data-add-role="${esc(u.id)}" data-user-name="${esc(u.full_name||u.email)}">+ Rol</button></td>
  </tr>`).join('');
}

function branchAccessMarkup(state,roleId,prefix){
  const role=roleById(state,roleId);
  const branches=activeBranches(state);
  if(!role)return '<div class="status info">Seleccione un rol para definir el alcance por sucursal.</div>';
  if(role.code===SUPER_ROLE){
    return `<div class="status ok"><strong>Acceso global:</strong> ${branches.map(b=>esc(b.name)).join(' · ')}. HemoCura permite un solo Superusuario.</div>`;
  }
  if(BRANCH_SCOPED_ROLES.has(role.code)){
    return `<label>Sucursal operativa<select name="branch_id" required><option value="">Seleccionar…</option>${options(branches)}</select><small class="muted">${esc(role.name)} opera en una sucursal por asignación.</small></label>`;
  }
  return `<fieldset class="card" style="padding:12px"><legend><strong>Acceso a sucursales</strong></legend><div class="quick-links">${branches.map((b,i)=>`<label class="inline-check"><input type="checkbox" name="branch_ids" value="${esc(b.id)}" ${i===0?'checked':''}> ${esc(b.name)}</label>`).join('')}</div><small class="muted">Marque una o varias sucursales permitidas para este rol.</small></fieldset>`;
}

function payloadFromForm(form){
  const fd=new FormData(form);
  const payload=Object.fromEntries(fd.entries());
  payload.branch_ids=fd.getAll('branch_ids').map(String);
  return payload;
}

function bindBranchAccess(root,state,formSelector,containerSelector){
  const form=root.querySelector(formSelector);
  const role=form.querySelector('[name="role_id"]');
  const container=root.querySelector(containerSelector);
  const paint=()=>{container.innerHTML=branchAccessMarkup(state,role.value,containerSelector)};
  role.addEventListener('change',paint);paint();
}

export async function mountUsers(root){
  if(!root)return;
  root.innerHTML='<section class="card"><h3>Usuarios y roles</h3><div class="status info">Cargando administración segura…</div></section>';
  try{
    let state=await loadUsersAdmin();
    const render=()=>{
      const superUser=(state.users||[]).find(u=>(u.roles||[]).some(r=>r.role_code===SUPER_ROLE));
      root.innerHTML=`
        <div class="sales-toolbar"><div><h2 class="section-heading">Usuarios y roles</h2><div class="muted">Acceso controlado por rol y sucursal.</div></div><button id="users-refresh" class="secondary">Actualizar</button></div>
        <div class="status info"><strong>Modelo de acceso:</strong> Laboratorio, Consulta y Encargada de Laboratorio se asignan por sucursal. Los demás roles pueden acceder a varias sucursales. Solo existe un Superusuario global.</div>
        <section class="card"><div class="card-head"><div><h3>Superusuario global</h3><div class="muted">Única cuenta con alcance administrativo en todas las sucursales.</div></div></div>
          ${superUser?`<div class="status ok"><strong>${esc(superUser.full_name||superUser.email)}</strong> · ${esc(superUser.email)} · Todas las sucursales activas</div>`:'<div class="status warn">No existe Superusuario asignado.</div>'}
        </section>
        <section class="card">
          <div class="card-head"><div><h3>Crear usuario</h3><div class="muted">Recomendado: enviar invitación para que la persona defina su acceso.</div></div></div>
          <form id="user-create-form" class="form-grid">
            <label>Nombre completo<input name="full_name" required autocomplete="name"></label>
            <label>Correo<input name="email" type="email" required autocomplete="email"></label>
            <label>Rol<select name="role_id" required><option value="">Seleccionar…</option>${options(state.roles)}</select></label>
            <div id="user-create-branches"></div>
            <label>Modo<select name="mode"><option value="invite">Enviar invitación</option><option value="create">Crear con contraseña temporal</option></select></label>
            <label id="temp-password-wrap" hidden>Contraseña temporal<input name="password" type="password" minlength="8" autocomplete="new-password"></label>
            <div class="form-actions"><button type="submit">Crear usuario</button></div>
          </form>
          <div id="user-create-status"></div>
        </section>
        <section class="card">
          <div class="card-head"><h3>Usuarios existentes</h3><span class="muted">${state.users?.length||0} usuario(s)</span></div>
          <div class="table-wrap"><table class="data-table"><thead><tr><th>Usuario</th><th>Sucursal principal</th><th>Roles / alcance</th><th>Estado</th><th>Correo</th><th>Último acceso</th><th>Acción</th></tr></thead><tbody>${userRows(state.users)}</tbody></table></div>
        </section>
        <section class="card hidden" id="add-role-card">
          <div class="card-head"><div><h3>Agregar rol</h3><div class="muted" id="add-role-user"></div></div><button type="button" class="secondary compact" id="add-role-close">Cerrar</button></div>
          <form id="add-role-form" class="form-grid">
            <input type="hidden" name="user_id">
            <label>Rol<select name="role_id" required><option value="">Seleccionar…</option>${options(state.roles)}</select></label>
            <div id="add-role-branches"></div>
            <div class="form-actions"><button type="submit">Asignar rol</button></div>
          </form><div id="add-role-status"></div>
        </section>`;

      bindBranchAccess(root,state,'#user-create-form','#user-create-branches');
      bindBranchAccess(root,state,'#add-role-form','#add-role-branches');

      const mode=root.querySelector('[name="mode"]');
      const pwWrap=root.querySelector('#temp-password-wrap');
      const pw=root.querySelector('[name="password"]');
      mode.addEventListener('change',()=>{const show=mode.value==='create';pwWrap.hidden=!show;pw.required=show;if(!show)pw.value=''});
      root.querySelector('#users-refresh').onclick=async()=>{state=await loadUsersAdmin();render()};

      root.querySelector('#user-create-form').addEventListener('submit',async e=>{
        e.preventDefault();const form=e.currentTarget;const btn=form.querySelector('button[type="submit"]');const status=root.querySelector('#user-create-status');
        btn.disabled=true;status.innerHTML='<div class="status info">Procesando…</div>';
        const payload=payloadFromForm(form);
        try{
          if(payload.mode==='invite')await inviteUser(payload);else await createUser(payload);
          state=await loadUsersAdmin();render();
        }catch(err){status.innerHTML=`<div class="status bad">${esc(err.message)}</div>`;btn.disabled=false}
      });

      root.querySelectorAll('[data-add-role]').forEach(btn=>btn.onclick=()=>{
        const card=root.querySelector('#add-role-card');card.classList.remove('hidden');
        root.querySelector('#add-role-user').textContent=`Usuario: ${btn.dataset.userName}`;
        root.querySelector('#add-role-form [name="user_id"]').value=btn.dataset.addRole;
        root.querySelector('#add-role-form [name="role_id"]').value='';
        root.querySelector('#add-role-form [name="role_id"]').dispatchEvent(new Event('change'));
        card.scrollIntoView({behavior:'smooth',block:'start'});
      });
      root.querySelector('#add-role-close').onclick=()=>root.querySelector('#add-role-card').classList.add('hidden');
      root.querySelector('#add-role-form').addEventListener('submit',async e=>{
        e.preventDefault();const payload=payloadFromForm(e.currentTarget);const status=root.querySelector('#add-role-status');
        status.innerHTML='<div class="status info">Asignando…</div>';
        try{await addUserRole(payload);state=await loadUsersAdmin();render()}catch(err){status.innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
      });
    };
    render();
  }catch(error){
    console.error('[HEMOCURA_USERS_ERROR]',error);
    root.innerHTML=`<section class="card"><h3>Usuarios y roles</h3><div class="status bad">${esc(error.message)}</div><p class="muted">Se requiere permiso <code>ACCESS_ADMIN</code>.</p></section>`;
  }
}
