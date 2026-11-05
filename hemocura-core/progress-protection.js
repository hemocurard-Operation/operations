// In-memory navigation protection only. Never stores clinical fields in browser storage.
let installed=false;
let discard=()=>true;
export const confirmDiscardProgress=()=>discard();
export function installProgressProtection(){
 if(installed)return;installed=true;
 const dirty=new Set();let acceptedHash=location.hash;
 const prune=()=>{for(const form of dirty){if(!form.isConnected||(form.closest('dialog')&&!form.closest('dialog').open))dirty.delete(form)}};
 const changed=e=>{const form=e.target.closest?.('#view form');if(form&&!form.hasAttribute('data-progress-ignore'))dirty.add(form)};
 document.addEventListener('input',changed,true);document.addEventListener('change',changed,true);
 document.addEventListener('reset',e=>dirty.delete(e.target),true);
 const allow=()=>{prune();if(!dirty.size)return true;
  if([...dirty].some(f=>f.querySelector('button[type=submit]:disabled,button:not([type]):disabled'))){alert('Hay un guardado en curso. Espere su resultado antes de salir.');return false}
  if(!confirm('Hay cambios sin guardar. ¿Desea descartarlos y salir de esta pantalla?'))return false;
  dirty.clear();return true;
 };
 discard=allow;
 window.addEventListener('beforeunload',e=>{prune();if(dirty.size){e.preventDefault();e.returnValue=''}});
 window.addEventListener('hashchange',e=>{if(location.hash===acceptedHash)return;if(!allow()){history.replaceState(null,'',location.pathname+location.search+acceptedHash);e.stopImmediatePropagation()}else acceptedHash=location.hash},true);
 document.addEventListener('click',e=>{const target=e.target.closest?.('#logout-btn,a[href]');if(!target||target.hasAttribute('download')||target.target==='_blank')return;
  if(target.matches('a')){const url=new URL(target.href,location.href);if(url.origin===location.origin&&url.pathname===location.pathname&&url.search===location.search)return}
  if(!allow()){e.preventDefault();e.stopImmediatePropagation()}
 },true);
}
