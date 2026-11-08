import {getSupabase} from './supabase.js';
import {loadUsersAdmin} from './users-data.js';
import {workspacePreview} from './workspace-preview-model.js';
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
async function rows(table,columns,orders){
 const result=[];
 for(let offset=0;;offset+=500){let q=getSupabase().from(table).select(columns);for(const key of orders)q=q.order(key);const {data,error}=await q.range(offset,offset+499);if(error)throw Error('No se pudo consultar la configuración de áreas. Actualice e inténtelo de nuevo.');if(!Array.isArray(data))throw Error('Configuración de áreas no disponible.');result.push(...data);if(data.length<500)return result}
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
   // The existing admin endpoint rechecks active SUPER_USUARIO + ACCESS_ADMIN server-side.
   const state=await loadUsersAdmin();
   if(current!==generation||!dialog.isConnected)return;
   const caller=state.users?.find(u=>u.id===state.caller_user_id);
   if(caller?.active!==true||!caller.roles?.some(r=>r.role_code==='SUPER_USUARIO'))throw Error('Esta vista está disponible únicamente para el Súper Usuario activo.');
   const [catalog,settings,permissions,rolePermissions]=await Promise.all([
    rows('app_module_catalog','route_key,title,group_name,permission_code,active',['route_key']),
    rows('role_module_access','role_id,route_key,enabled',['role_id','route_key']),
    rows('app_permissions','permission_code,active',['permission_code']),
    rows('role_permissions','role_id,permission_code',['role_id','permission_code'])
   ]);
   if(current!==generation||!dialog.isConnected)return;
   const metadata={catalog,settings,permissions,rolePermissions};
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
    status.textContent=`${model.routes.length} áreas disponibles · Configuración consultada a las ${new Date().toLocaleTimeString('es-DO')}`;
    body.innerHTML=`<div class="status info">Está revisando la vista de <strong>${esc(user.full_name||user.username||user.email)}</strong>. Su sesión de Súper Usuario continúa activa. Esta vista muestra accesos y tareas; los registros, formularios y decisiones se consultan con la cuenta propia del usuario.</div><div class="workspace-preview-shell"><aside class="workspace-preview-nav"><strong>HemoCura</strong><p>${esc(roleNames.join(' / ')||'Sin roles')}</p><button type="button" data-preview-home>Mi trabajo · Vista previa</button>${groups.map(group=>`<section><h3>${esc(group)}</h3>${model.routes.filter(([,m])=>m.group===group).map(([key,m])=>`<button type="button" data-preview-route="${esc(key)}">${esc(m.title)}</button>`).join('')}</section>`).join('')}</aside><main class="workspace-preview-main"><div class="workspace-preview-identity"><strong>${esc(user.full_name||user.username||'Usuario')}</strong><span>${esc(scope)}</span><small>Sucursales de sus roles. Los alcances adicionales y las reglas de cada registro se validan al operar.</small></div><div data-preview-content></div></main></div>`;
    const content=body.querySelector('[data-preview-content]');
    function showHome(){
     body.querySelectorAll('[data-preview-route]').forEach(b=>b.removeAttribute('aria-current'));
     content.innerHTML=`<h2>Mi trabajo</h2><p>Así se priorizan sus accesos y tareas de inicio.</p>${!model.active?'<div class="status warn">Perfil inactivo: no tiene áreas de trabajo habilitadas.</div>':!model.routes.length?'<div class="status warn">No hay áreas habilitadas que cuenten con permisos de datos activos.</div>':''}<div class="work-grid">${model.tasks.slice(0,4).map((task,i)=>`<button type="button" class="work-card ${i===0?'primary-work':''}" data-preview-task="${esc(task.key)}"><span class="work-kicker">${i===0?'Siguiente acción':'Tarea disponible'}</span><strong>${esc(task.label)}</strong><small>${esc(task.hint)}</small><span>Revisar área →</span></button>`).join('')}</div>${model.tasks.length>4?`<h3>También puedes continuar con</h3><div class="quick-links">${model.tasks.slice(4).map(task=>`<button type="button" class="secondary" data-preview-task="${esc(task.key)}">${esc(task.label)}</button>`).join('')}</div>`:''}<p class="muted">La agenda personal, los pendientes y las cifras de operación dependen de los registros autorizados de cada cuenta.</p>`;
     content.querySelectorAll('[data-preview-task]').forEach(b=>b.onclick=()=>showRoute(b.dataset.previewTask));
    }
    function showRoute(key){
     const entry=model.routes.find(([k])=>k===key);if(!entry)return;const [,meta]=entry;
     body.querySelectorAll('[data-preview-route]').forEach(b=>{if(b.dataset.previewRoute===key)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current')});
     content.innerHTML=`<p class="muted">${esc(meta.group)}</p><h2>${esc(meta.title)}</h2><p>${esc(meta.subtitle)}</p><div class="status ok">Área visible en el menú de este usuario.</div><section class="card"><h3>Acceso del área</h3><p>Permiso de entrada: <strong>${esc(catalog.find(m=>m.route_key===key)?.permission_code)}</strong></p><p>Los botones y registros disponibles se ajustan a sus permisos, sucursales y estado de cada operación.</p></section><details><summary>Permisos de datos activos del usuario (${model.permissions.size})</summary><ul>${[...model.permissions].sort().map(p=>`<li>${esc(p)}</li>`).join('')}</ul></details><button type="button" class="secondary" data-preview-back>Volver a Mi trabajo</button>`;
     content.querySelector('[data-preview-back]').onclick=showHome;
    }
    body.querySelector('[data-preview-home]').onclick=showHome;body.querySelectorAll('[data-preview-route]').forEach(b=>b.onclick=()=>showRoute(b.dataset.previewRoute));showHome();
   }
   select.onchange=()=>{selected=select.value;draw()};controls.querySelector('[data-preview-refresh]').onclick=refresh;draw();
  }catch(error){if(current===generation&&dialog.isConnected){body.replaceChildren();controls.innerHTML='<button type="button" class="secondary" data-preview-retry>Volver a intentar</button>';controls.querySelector('button').onclick=refresh;status.textContent=error.message}}
 }
 await refresh();
}
