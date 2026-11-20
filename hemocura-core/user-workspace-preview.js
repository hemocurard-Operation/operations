import {getSupabase} from './supabase.js';
import {workspacePreview} from './workspace-preview-model.js';
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
export async function loadWorkspaceDirectory(target=null,search='',offset=0){
 const {data,error}=await getSupabase().rpc('admin_workspace_preview',{p_target:target,p_search:search,p_offset:offset});
 if(error)throw Error('No se pudo consultar las áreas. Verifique su permiso de administrador y vuelva a intentar.');
 return data;
}
export async function mountUserWorkspaces(root){
 root.innerHTML='<section class="card"><h2>Pantallas por usuario</h2><p>Consulte los menús y tareas asignados a cada usuario. El entrenamiento reproduce la aplicación con los permisos y sucursal de cada usuario; usa datos de práctica.</p><form data-directory-search><label>Buscar por nombre <input name="search" maxlength="100" autocomplete="off"></label><button>Buscar</button></form><div data-directory-status role="status"></div><div data-directory-list></div><button type="button" data-directory-prev>Anterior</button><button type="button" data-directory-next>Siguiente</button></section>';
 let offset=0,search='',generation=0;
 const status=root.querySelector('[data-directory-status]'),list=root.querySelector('[data-directory-list]'),prev=root.querySelector('[data-directory-prev]'),next=root.querySelector('[data-directory-next]');
 async function load(){const current=++generation;list.replaceChildren();prev.disabled=next.disabled=true;status.textContent='Consultando usuarios…';try{const state=await loadWorkspaceDirectory(null,search,offset);if(current!==generation||!root.isConnected)return;status.textContent=state.users.length?'Seleccione un usuario para revisar sus áreas.':'Sin resultados.';list.innerHTML=state.users.map(u=>`<p><strong>${esc(u.full_name||'Sin nombre')}</strong> · ${u.active?'Activo':'Inactivo'} <button type="button" class="secondary" data-directory-user="${esc(u.id)}">Ver áreas de trabajo</button></p>`).join('');prev.disabled=offset===0;next.disabled=!state.has_more;list.querySelectorAll('[data-directory-user]').forEach(b=>b.onclick=()=>openWorkspacePreview(root,b.dataset.directoryUser));}catch(e){if(current===generation){status.textContent=e.message;prev.disabled=offset===0;}}}
 root.querySelector('form').onsubmit=e=>{e.preventDefault();search=new FormData(e.target).get('search').trim();offset=0;load()};prev.onclick=()=>{offset=Math.max(0,offset-50);load()};next.onclick=()=>{offset+=50;load()};await load();
}
export async function openWorkspacePreview(root,userId){
 root.querySelector('[data-workspace-dialog]')?.remove();
 if(!document.querySelector('[data-workspace-preview-style]')){const link=document.createElement('link');link.rel='stylesheet';link.href=new URL('../css/workspace-preview.css',import.meta.url).href;link.dataset.workspacePreviewStyle='';document.head.append(link)}
 const dialog=document.createElement('dialog');dialog.dataset.workspaceDialog='';dialog.className='workspace-preview-dialog';dialog.setAttribute('aria-labelledby','workspace-preview-title');
 dialog.innerHTML='<header class="workspace-preview-header"><div><h2 id="workspace-preview-title">Áreas de trabajo por usuario</h2><p>Entrenamiento con la interfaz real · Sin guardar datos</p></div><button type="button" data-preview-close class="secondary">Cerrar vista previa</button></header><div data-preview-controls></div><p data-preview-status role="status" aria-live="polite">Consultando accesos actuales…</p><div data-preview-body></div>';
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
    const scope=model.superUser?'Todas las sucursales':Object.hasOwn(user,'branch_id')?(user.branch_name||'Sin sucursal asignada'):branchNames.join(' · ')||'Sin sucursal asignada';
    status.textContent=`${model.routes.length} pantallas habilitadas · Accesos consultados a las ${verifiedAt}`;
    if(!model.active||!model.routes.length){body.innerHTML=`<p role="status">${!model.active?'Perfil inactivo: sin pantallas habilitadas.':'Sin áreas habilitadas para este usuario.'}</p>`;return}
    body.innerHTML=`<p class="status info">Entrenamiento de <strong>${esc(user.full_name||'Usuario')}</strong> · ${esc(scope)}. La sesión de administrador continúa activa. Se usa la misma aplicación con datos de práctica y guardado bloqueado.</p><div data-preview-frame></div>`;
    const holder=body.querySelector('[data-preview-frame]'),frame=document.createElement('iframe');frame.title='Aplicación de '+(user.full_name||'Usuario')+' · Entrenamiento sin datos reales';frame.className='workspace-screen-frame';frame.setAttribute('sandbox','allow-scripts');frame.src=new URL('../workspace-screen.html',import.meta.url).href;
    const roleBranches=[...new Map((user.roles||[]).filter(r=>r.branch_id).map(r=>[r.branch_id,{id:r.branch_id,name:r.branch_name||'Sucursal asignada',active:true}])).values()];
    const profileBranch=user.branch_id?{id:user.branch_id,name:user.branch_name||roleBranches.find(b=>b.id===user.branch_id)?.name||'Sucursal asignada',active:true}:Object.hasOwn(user,'branch_id')?null:roleBranches[0];
    const branches=model.superUser?(state.branches||roleBranches):profileBranch?[profileBranch]:[];
    const routes=model.routes.map(([key])=>key),route=routes.includes('mywork')?'mywork':routes.find(k=>!['users','security','settings','userworkspaces','diagnostics','qa','releasegate','release1'].includes(k));
    if(!route){holder.textContent='Las pantallas administrativas se consultan en la sesión original.';return}
    const configuration={route,routes,permissions:[...model.permissions],roles:(user.roles||[]).map(r=>r.role_code),name:user.full_name||'Usuario',branches,context:{user_id:user.id,id:user.id,branch_id:profileBranch?.id||null,profile_branch_id:profileBranch?.id||null,roles:(user.roles||[]).map(r=>r.role_code)}};
    const controller=new AbortController();window.addEventListener('message',event=>{if(event.source!==frame.contentWindow||event.origin!=='null'||event.data?.type!=='hc-workspace-screen-ready')return;frame.contentWindow.postMessage({type:'hc-workspace-screen',configuration},'*');controller.abort();},{signal:controller.signal});dialog.addEventListener('close',()=>controller.abort(),{once:true});holder.append(frame);
   }
   select.onchange=()=>{selected=select.value;draw()};controls.querySelector('[data-preview-refresh]').onclick=refresh;draw();
  }catch(error){if(current===generation&&dialog.isConnected){body.replaceChildren();controls.innerHTML='<button type="button" class="secondary" data-preview-retry>Volver a intentar</button>';controls.querySelector('button').onclick=refresh;status.textContent=error.message}}
 }
 await refresh();
}
