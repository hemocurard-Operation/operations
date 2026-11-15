import {getSupabase} from './supabase.js';
import {workspacePreview} from './workspace-preview-model.js';
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
export async function loadWorkspaceDirectory(target=null,search='',offset=0){
 const {data,error}=await getSupabase().rpc('admin_workspace_preview',{p_target:target,p_search:search,p_offset:offset});
 if(error)throw Error('No se pudo consultar las áreas. Verifique su permiso de administrador y vuelva a intentar.');
 return data;
}
export async function mountUserWorkspaces(root){
 root.innerHTML='<section class="card"><h2>Pantallas por usuario</h2><p>Consulte los menús y tareas asignados a cada usuario. Las pantallas operativas se abren con sus propios permisos de administrador.</p><form data-directory-search><label>Buscar por nombre <input name="search" maxlength="100" autocomplete="off"></label><button>Buscar</button></form><div data-directory-status role="status"></div><div data-directory-list></div><button type="button" data-directory-prev>Anterior</button><button type="button" data-directory-next>Siguiente</button></section>';
 let offset=0,search='',generation=0;
 const status=root.querySelector('[data-directory-status]'),list=root.querySelector('[data-directory-list]'),prev=root.querySelector('[data-directory-prev]'),next=root.querySelector('[data-directory-next]');
 async function load(){const current=++generation;list.replaceChildren();prev.disabled=next.disabled=true;status.textContent='Consultando usuarios…';try{const state=await loadWorkspaceDirectory(null,search,offset);if(current!==generation||!root.isConnected)return;status.textContent=state.users.length?'Seleccione un usuario para revisar sus áreas.':'Sin resultados.';list.innerHTML=state.users.map(u=>`<p><strong>${esc(u.full_name||'Sin nombre')}</strong> · ${u.active?'Activo':'Inactivo'} <button type="button" class="secondary" data-directory-user="${esc(u.id)}">Ver áreas de trabajo</button></p>`).join('');prev.disabled=offset===0;next.disabled=!state.has_more;list.querySelectorAll('[data-directory-user]').forEach(b=>b.onclick=()=>openWorkspacePreview(root,b.dataset.directoryUser));}catch(e){if(current===generation){status.textContent=e.message;prev.disabled=offset===0;}}}
 root.querySelector('form').onsubmit=e=>{e.preventDefault();search=new FormData(e.target).get('search').trim();offset=0;load()};prev.onclick=()=>{offset=Math.max(0,offset-50);load()};next.onclick=()=>{offset+=50;load()};await load();
}
export async function openWorkspacePreview(root,userId){
 root.querySelector('[data-workspace-dialog]')?.remove();
 if(!document.querySelector('[data-workspace-preview-style]')){const link=document.createElement('link');link.rel='stylesheet';link.href=new URL('../css/workspace-preview.css',import.meta.url).href;link.dataset.workspacePreviewStyle='';document.head.append(link)}
 const dialog=document.createElement('dialog');dialog.dataset.workspaceDialog='';dialog.className='workspace-preview-dialog';dialog.setAttribute('aria-labelledby','workspace-preview-title');
 dialog.innerHTML='<header class="workspace-preview-header"><div><h2 id="workspace-preview-title">Áreas de trabajo por usuario</h2><p>Vista previa de menús y tareas · Solo consulta</p></div><button type="button" data-preview-close class="secondary">Cerrar vista previa</button></header><div data-preview-controls></div><p data-preview-status role="status" aria-live="polite">Consultando accesos actuales…</p><div data-preview-body></div>';
 root.append(dialog);dialog.showModal();dialog.querySelector('[data-preview-close]').onclick=()=>dialog.close();dialog.addEventListener('close',()=>dialog.remove(),{once:true});
 const body=dialog.querySelector('[data-preview-body]'),status=dialog.querySelector('[data-preview-status]'),controls=dialog.querySelector('[data-preview-controls]');let selected=userId,generation=0;
 async function refresh(){
  const current=++generation;body.replaceChildren();controls.replaceChildren();status.textContent='Consultando accesos actuales…';
  try{
   const state=await loadWorkspaceDirectory(selected);
   const {catalog,settings,permissions,rolePermissions}=state;
   if(current!==generation||!dialog.isConnected)return;
   const metadata={catalog,settings,permissions,rolePermissions},verifiedAt=new Date().toLocaleTimeString('es-DO');
   controls.innerHTML=`<label>Ver como usuario<select data-preview-user aria-label="Usuario de la vista previa">${state.users.map(u=>`<option value="${esc(u.id)}">${esc(u.full_name||u.username||u.email||'Sin nombre')}${u.active===true?'':' · Perfil inactivo'}</option>`).join('')}</select></label><button type="button" class="secondary" data-preview-refresh>Actualizar accesos</button>`;
   const select=controls.querySelector('[data-preview-user]');
   function draw(){
    const user=state.users.find(u=>u.id===selected);body.replaceChildren();
    if(!user){status.textContent='El usuario ya no está disponible. Cierre la vista y actualice la lista.';return}
    select.value=selected;const model=workspacePreview(user,metadata);
    const roleNames=[...new Set((user.roles||[]).map(r=>r.role_name||r.role_code))];
    const branchNames=[...new Set((user.roles||[]).map(r=>r.branch_name).filter(Boolean))];
    const scope=model.superUser?'Todas las sucursales':branchNames.join(' · ')||'Sin sucursales asignadas a sus roles';
    const groups=[...new Set(model.routes.map(([,m])=>m.group))];
    status.textContent=`${model.routes.length} áreas disponibles · Configuración consultada a las ${verifiedAt}`;
    body.innerHTML=`<div class="status info">Está revisando la vista de <strong>${esc(user.full_name||user.username||user.email)}</strong>. Su sesión de administrador continúa activa. Esta vista muestra accesos y tareas; las pantallas operativas se consultan con sus propios permisos de administrador, sin asumir la identidad del usuario.</div><div class="workspace-preview-shell"><aside class="workspace-preview-nav"><strong>HemoCura</strong><p>${esc(roleNames.join(' / ')||'Sin roles')}</p><button type="button" data-preview-home>Mi trabajo · Vista previa</button>${groups.map(group=>`<section><h3>${esc(group)}</h3>${model.routes.filter(([,m])=>m.group===group).map(([key,m])=>`<button type="button" data-preview-route="${esc(key)}">${esc(m.title)}</button>`).join('')}</section>`).join('')}</aside><main class="workspace-preview-main"><div class="workspace-preview-identity"><strong>${esc(user.full_name||user.username||'Usuario')}</strong><span>${esc(scope)}</span><small>Sucursales de sus roles. Los alcances adicionales y las reglas de cada registro se validan al operar.</small></div><div data-preview-content></div></main></div>`;
    const content=body.querySelector('[data-preview-content]');
    function showHome(){
     body.querySelectorAll('[data-preview-route]').forEach(b=>b.removeAttribute('aria-current'));
     content.innerHTML=`<h2>Mi trabajo</h2><p>Así se priorizan sus accesos y tareas de inicio.</p>${!model.active?'<div class="status warn">Perfil inactivo: no tiene áreas de trabajo habilitadas.</div>':!model.routes.length?'<div class="status warn">No hay áreas habilitadas que cuenten con permisos de datos activos.</div>':''}<div class="work-grid">${model.tasks.slice(0,4).map((task,i)=>`<button type="button" class="work-card ${i===0?'primary-work':''}" data-preview-task="${esc(task.key)}"><span class="work-kicker">${i===0?'Siguiente acción':'Tarea disponible'}</span><strong>${esc(task.label)}</strong><small>${esc(task.hint)}</small><span>Revisar área →</span></button>`).join('')}</div>${model.tasks.length>4?`<h3>También puedes continuar con</h3><div class="quick-links">${model.tasks.slice(4).map(task=>`<button type="button" class="secondary" data-preview-task="${esc(task.key)}">${esc(task.label)}</button>`).join('')}</div>`:''}<p class="muted">La agenda personal, los pendientes y las cifras de operación dependen de los registros autorizados de cada cuenta.</p>`;
     content.querySelectorAll('[data-preview-task]').forEach(b=>b.onclick=()=>showRoute(b.dataset.previewTask));
    }
    function showRoute(key){
     const entry=model.routes.find(([k])=>k===key);if(!entry)return;const [,meta]=entry;
     body.querySelectorAll('[data-preview-route]').forEach(b=>{if(b.dataset.previewRoute===key)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current')});
     content.innerHTML=`<p class="muted">${esc(meta.group)}</p><h2>${esc(meta.title)}</h2><p>${esc(meta.subtitle)}</p><div class="status ok">Área visible en el menú de este usuario.</div><section class="card"><h3>Acceso del área</h3><p>Permiso de entrada: <strong>${esc(catalog.find(m=>m.route_key===key)?.permission_code)}</strong></p><p>Los botones y registros disponibles se ajustan a sus permisos, sucursales y estado de cada operación.</p></section><details><summary>Permisos de datos activos del usuario (${model.permissions.size})</summary><ul>${[...model.permissions].sort().map(p=>`<li>${esc(p)}</li>`).join('')}</ul></details><button type="button" class="secondary" data-preview-open>Abrir pantalla con mis permisos</button><button type="button" class="secondary" data-preview-back>Volver a Mi trabajo</button>`;
     content.querySelector('[data-preview-back]').onclick=showHome;
     content.querySelector('[data-preview-open]').onclick=()=>{dialog.close();location.hash=key};
    }
    body.querySelector('[data-preview-home]').onclick=showHome;body.querySelectorAll('[data-preview-route]').forEach(b=>b.onclick=()=>showRoute(b.dataset.previewRoute));showHome();
   }
   select.onchange=()=>{selected=select.value;draw()};controls.querySelector('[data-preview-refresh]').onclick=refresh;draw();
  }catch(error){if(current===generation&&dialog.isConnected){body.replaceChildren();controls.innerHTML='<button type="button" class="secondary" data-preview-retry>Volver a intentar</button>';controls.querySelector('button').onclick=refresh;status.textContent=error.message}}
 }
 await refresh();
}
