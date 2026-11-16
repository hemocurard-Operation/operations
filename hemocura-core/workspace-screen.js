import {configureWorkspaceScreen} from './workspace-screen-data.js';
const host=document.querySelector('[data-screen-root]'),notice=document.querySelector('[data-screen-status]');
const parentOrigin=new URL(document.baseURI).origin;
let started=false;
window.addEventListener('message',async event=>{
 if(started||event.source!==parent||event.origin!==parentOrigin||event.data?.type!=='hc-workspace-screen')return;
 started=true;const c=event.data.configuration;
 try{
  if(!c||!c.routes?.includes(c.route)||!Array.isArray(c.permissions))throw Error('Área no habilitada para el usuario seleccionado.');
  configureWorkspaceScreen(c);notice.textContent=`Vista de ${c.name}. Formularios reales con sus permisos; sin registros reales y sin posibilidad de guardar.`;
  const blocked=['users','security','settings','userworkspaces','diagnostics','qa','releasegate','release1'];
  if(blocked.includes(c.route))throw Error('La administración de cuentas y configuración se consulta desde la pantalla original, con sus propios permisos.');
  const {MOUNTS}=await import('./route-mounts.js');if(typeof MOUNTS[c.route]!=='function')throw Error('Pantalla no disponible.');
  await MOUNTS[c.route](host);
 }catch(e){host.replaceChildren();const p=document.createElement('p');p.setAttribute('role','status');p.textContent=e.message;host.append(p);}
});
// Block navigation and writes at the document boundary as well as in the adapter.
document.addEventListener('click',event=>{if(event.target.closest('a')){event.preventDefault();event.stopImmediatePropagation();}},true);
document.addEventListener('submit',event=>{event.preventDefault();event.stopImmediatePropagation();},true);
const disableSaves=()=>document.querySelectorAll('[type=submit]').forEach(b=>{b.disabled=true;b.title='La vista previa no permite guardar.';});
new MutationObserver(disableSaves).observe(host,{subtree:true,childList:true});
parent.postMessage({type:'hc-workspace-screen-ready'},parentOrigin);
