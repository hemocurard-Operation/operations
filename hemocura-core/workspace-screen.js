import {configureWorkspaceScreen} from './workspace-screen-data.js';
const host=document.querySelector('[data-screen-root]'),notice=document.querySelector('[data-screen-status]');
const parentOrigin=new URL(document.baseURI).origin;
let started=false,configuration;
const blocked=new Set(['users','security','settings','userworkspaces','diagnostics','qa','releasegate','release1']);
window.addEventListener('message',async event=>{
 if(started||event.source!==parent||event.origin!==parentOrigin||event.data?.type!=='hc-workspace-screen')return;
 started=true;const c=event.data.configuration;configuration=c;
 try{
  if(!c||!c.routes?.includes(c.route)||!Array.isArray(c.permissions))throw Error('Área no habilitada para el usuario seleccionado.');
  configureWorkspaceScreen(c);notice.textContent=`Entrenamiento: ${c.name} · Misma interfaz y formularios · Datos de práctica, sin registros reales ni guardado.`;
  if(blocked.has(c.route))throw Error('La administración se consulta desde la sesión original.');
  location.hash=c.route;
  const {mountLayout}=await import('./layout.js');
  await mountLayout({user:{id:c.context.user_id,email:c.name,user_metadata:{full_name:c.name}}});
 }catch(e){host.replaceChildren();const p=document.createElement('p');p.setAttribute('role','status');p.textContent=e.message;host.append(p);}
});
window.addEventListener('hashchange',event=>{const route=location.hash.slice(1);if(blocked.has(route)){event.stopImmediatePropagation();const view=document.getElementById('view');if(view)view.textContent='La administración se consulta desde la sesión original.';}},true);
document.addEventListener('click',event=>{const a=event.target.closest('a');if(!a)return;event.preventDefault();event.stopImmediatePropagation();const key=a.getAttribute('href')?.replace(/^#/, '');if(a.getAttribute('href')?.startsWith('#')&&configuration?.routes.includes(key))location.hash=key;},true);
document.addEventListener('submit',event=>{event.preventDefault();event.stopImmediatePropagation();},true);
const disableSaves=()=>{document.querySelectorAll('[type=submit],#logout-btn').forEach(b=>{b.disabled=true;b.title='El entrenamiento no modifica datos ni cierra la sesión.';});};
new MutationObserver(disableSaves).observe(host,{subtree:true,childList:true});
parent.postMessage({type:'hc-workspace-screen-ready'},parentOrigin);
