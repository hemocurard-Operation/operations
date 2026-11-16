import {operationsNavigation} from './operations-modules.js';
import {loadOperationsStyle} from './operations-shell.js';
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
// Presentation only: every destination must come from the caller's freshly
// authorized route entries. No synthetic metrics, extra grants or data reads.
export function operationsOverview(entries){
 loadOperationsStyle();const {modules}=operationsNavigation(entries);
 if(!modules.length)return '';
 return `<section class="operations-overview" aria-label="Módulos de Operaciones"><h2>Operaciones</h2><p>${modules.length===7?'Siete módulos, una misma forma de trabajar.':'Tus áreas autorizadas y sus pantallas de trabajo.'}</p><div class="operations-module-grid">${modules.map(m=>{const links=m.entries.map(([key,meta])=>`<a href="#${esc(key)}">${esc(meta.title)}</a>`);return `<article class="operations-module-card" data-operations-card="${esc(m.id)}"><div class="operations-module-head"><span class="operations-module-number" aria-hidden="true">${esc(['inventario','logistica','calidad','compliance','donantes','comercial','finanzas'].indexOf(m.id)+1)}</span><div><h3>${esc(m.title)}</h3><p>${esc(m.description)}</p></div></div><nav class="operations-module-links" aria-label="Pantallas de ${esc(m.title)}">${links.slice(0,3).join('')}${links.length>3?`<details><summary>Más pantallas (${links.length-3})</summary><div>${links.slice(3).join('')}</div></details>`:''}</nav></article>`}).join('')}</div></section>`;
}
