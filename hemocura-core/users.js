import { loadUsersAdmin, inviteUser, createUser, addUserRole, removeUserRole, changeUserPassword } from './users-data.js';

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

function removeRoleButtons(state,user){
  return (user.roles||[]).map(role=>{
    const blocked=!state.caller_user_id||!role.role_id||user.id===state.caller_user_id||role.role_code===SUPER_ROLE||!role.branch_id;
    const label=`Retirar ${role.role_name||role.role_code} · ${role.branch_name||'Sin sucursal'}`;
    return `<button type="button" class="secondary compact" data-remove-role="${esc(role.role_id)}" data-remove-user="${esc(user.id)}" data-remove-branch="${esc(role.branch_id)}" data-remove-label="${esc(label)}" ${blocked?'disabled':''} title="${!state.caller_user_id?'Retiro no habilitado por el servidor':blocked?'El propio acceso y el Superusuario se conservan':esc(label)}">${esc(label)}</button>`;
  }).join(' ');
}

function filterUsers(state,filters){
  const query=filters.query.trim().toLocaleLowerCase('es');
  return (state.users||[]).filter(user=>{
    const text=[user.full_name,user.email,user.branch_name,...(user.roles||[]).map(role=>role.role_name||role.role_code)].filter(Boolean).join(' ').toLocaleLowerCase('es');
    return (!query||text.includes(query))&&
      (!filters.branch||user.branch_id===filters.branch||(user.roles||[]).some(role=>role.branch_id===filters.branch))&&
      (!filters.role||(user.roles||[]).some(role=>role.role_id===filters.role))&&
      (filters.active==='ALL'||(user.active!==false)===(filters.active==='ACTIVE'));
  });
}

function userRows(state,users=[]){
  if(!users.length)return '<tr><td colspan="7" class="muted">No hay usuarios visibles.</td></tr>';
  return users.map(u=>`<tr>
    <td><strong>${esc(u.full_name||'Sin nombre')}</strong><br><span class="muted">${esc(u.email||'')}</span></td>
    <td>${esc(u.branch_name||'—')}</td>
    <td>${roleBadges(u.roles)}</td>
    <td>${u.active?'<span class="stock-pill stock-ok">Activo</span>':'<span class="stock-pill stock-none">Inactivo</span>'}</td>
    <td>${u.email_confirmed_at?'<span class="stock-pill stock-ok">Confirmado</span>':'<span class="stock-pill stock-warning">Pendiente</span>'}</td>
    <td>${fmtDate(u.last_sign_in_at)}</td>
    <td><button class="secondary compact" data-add-role="${esc(u.id)}" data-user-name="${esc(u.full_name||u.email)}" ${u.active?'':'disabled'}>+ Rol</button> <button class="secondary compact" data-password-user="${esc(u.id)}" data-user-name="${esc(u.full_name||u.email)}" ${u.active?'':'disabled'}>Cambiar clave</button> ${removeRoleButtons(state,u)}</td>
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
    const filters={query:'',branch:'',role:'',active:'ALL'};
    const render=()=>{
      const superUser=(state.users||[]).find(u=>(u.roles||[]).some(r=>r.role_code===SUPER_ROLE));
      root.innerHTML=`
        <div class="sales-toolbar"><div><h2 class="section-heading">Usuarios y roles</h2><div class="muted">Acceso controlado por rol y sucursal.</div></div><button id="users-refresh" class="secondary">Actualizar</button></div>
        <div class="status info"><strong>Administración exclusiva del Super Usuario:</strong> creación de cuentas, cambio de claves y asignación de roles. Laboratorio, Consulta y Encargada de Laboratorio se asignan por sucursal. Solo existe un Superusuario global.</div>
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
            <label id="temp-password-wrap" hidden>Contraseña temporal<input name="password" type="password" minlength="12" maxlength="128" autocomplete="new-password"></label>
            <div class="form-actions"><button type="submit">Crear usuario</button></div>
          </form>
          <div id="user-create-status"></div>
        </section>
        <section class="card">
          <div class="card-head"><h3>Usuarios existentes</h3><span class="muted">${state.users?.length||0} usuario(s)</span></div>
          <div class="form-grid">
            <label>Buscar usuario<input id="users-search" type="search" autocomplete="off" value="${esc(filters.query)}" placeholder="Nombre, correo o rol"></label>
            <label>Sucursal<select id="users-branch"><option value="">Todas</option>${options(state.branches)}</select></label>
            <label>Rol<select id="users-role"><option value="">Todos</option>${options(state.roles)}</select></label>
            <label>Estado<select id="users-active"><option value="ALL">Todos</option><option value="ACTIVE">Activos</option><option value="INACTIVE">Inactivos</option></select></label>
          </div>
          <p class="muted" id="users-count" aria-live="polite"></p>
          <div id="user-admin-status" aria-live="polite"></div>
          <div class="table-wrap"><table class="data-table"><thead><tr><th>Usuario</th><th>Sucursal principal</th><th>Roles / alcance</th><th>Estado</th><th>Correo</th><th>Último acceso</th><th>Acción</th></tr></thead><tbody id="users-body">${userRows(state,filterUsers(state,filters))}</tbody></table></div>
        </section>
        <section class="card hidden" id="password-card">
          <div class="card-head"><h3>Cambiar clave</h3><button type="button" class="secondary compact" id="password-close">Cerrar</button></div>
          <p id="password-user-label"></p>
          <form id="password-form" class="form-grid">
            <input type="hidden" name="user_id">
            <label>Nueva clave<input name="password" type="password" minlength="12" maxlength="128" required autocomplete="new-password"></label>
            <label>Confirmar clave<input name="confirmation" type="password" minlength="12" maxlength="128" required autocomplete="new-password"></label>
            <div class="form-actions"><button type="submit">Cambiar clave</button></div>
          </form><div id="password-status" role="status" aria-live="polite"></div>
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

      const bindUserActions=()=>{
      root.querySelectorAll('[data-password-user]').forEach(btn=>btn.onclick=()=>{
        const form=root.querySelector('#password-form');form.reset();form.elements.user_id.value=btn.dataset.passwordUser;
        root.querySelector('#password-user-label').textContent=`Usuario: ${btn.dataset.userName}`;
        root.querySelector('#password-status').textContent='';root.querySelector('#password-card').classList.remove('hidden');form.elements.password.focus();
      });
      root.querySelectorAll('[data-add-role]').forEach(btn=>btn.onclick=()=>{
        const card=root.querySelector('#add-role-card');card.classList.remove('hidden');
        root.querySelector('#add-role-user').textContent=`Usuario: ${btn.dataset.userName}`;
        root.querySelector('#add-role-form [name="user_id"]').value=btn.dataset.addRole;
        root.querySelector('#add-role-form [name="role_id"]').value='';
        root.querySelector('#add-role-form [name="role_id"]').dispatchEvent(new Event('change'));
        card.scrollIntoView({behavior:'smooth',block:'start'});
      });
        root.querySelectorAll('[data-remove-role]').forEach(btn=>btn.onclick=async()=>{
          if(btn.disabled||!window.confirm(`${btn.dataset.removeLabel}. ¿Continuar?`))return;
          const status=root.querySelector('#user-admin-status');btn.disabled=true;
          status.innerHTML='<div class="status info">Retirando asignación…</div>';
          try{
            const result=await removeUserRole({user_id:btn.dataset.removeUser,role_id:btn.dataset.removeRole,branch_ids:[btn.dataset.removeBranch]});
            state=await loadUsersAdmin();paintUsers();
            status.innerHTML=result.removed_assignments===0?'<div class="status ok">La asignación ya no estaba vigente. La lista se actualizó.</div>':'<div class="status ok">Asignación retirada. Las demás sucursales y roles se conservan.</div>';
          }catch(err){status.innerHTML=`<div class="status bad">${esc(err.message)}</div>`;btn.disabled=false}
        });
      };
      const paintUsers=()=>{
        const users=filterUsers(state,filters);
        root.querySelector('#users-body').innerHTML=userRows(state,users);
        root.querySelector('#users-count').textContent=`${users.length} de ${state.users?.length||0} usuario(s)`;
        bindUserActions();
      };
      for(const [selector,key] of [['#users-search','query'],['#users-branch','branch'],['#users-role','role'],['#users-active','active']]){
        const input=root.querySelector(selector);input.value=filters[key];
        input.addEventListener(selector==='#users-search'?'input':'change',()=>{filters[key]=input.value;paintUsers()});
      }
      paintUsers();
      root.querySelector('#password-close').onclick=()=>{root.querySelector('#password-form').reset();root.querySelector('#password-card').classList.add('hidden')};
      root.querySelector('#password-form').addEventListener('submit',async e=>{
        e.preventDefault();const form=e.currentTarget,status=root.querySelector('#password-status'),button=form.querySelector('button[type="submit"]');
        if(form.elements.password.value!==form.elements.confirmation.value){status.textContent='Las claves no coinciden.';return}
        button.disabled=true;status.textContent='Cambiando clave…';
        try{const result=await changeUserPassword({user_id:form.elements.user_id.value,password:form.elements.password.value});status.textContent=result.message||'Clave cambiada correctamente.'}
        catch(err){status.textContent=err.message}
        finally{form.elements.password.value='';form.elements.confirmation.value='';button.disabled=false}
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
