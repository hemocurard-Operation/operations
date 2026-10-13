import { loadAccess } from './access-control.js';
import { workflowData } from './workflow-data.js';
import { localDay,localDateTime } from './workflow-domain.js';
export const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
export const pill=(text,kind='info')=>`<span class="state-pill state-${kind}">${esc(text)}</span>`;
export const money=(n,currency='DOP')=>new Intl.NumberFormat('es-DO',{style:'currency',currency}).format(Number(n||0));
export const dt=t=>localDateTime(t).replace('T',' ');
export function table(head,rows){return `<div class="table-wrap"><table class="data-table"><thead><tr>${head.map(x=>`<th>${esc(x)}</th>`).join('')}</tr></thead><tbody>${rows.length?rows.map(row=>`<tr>${row.map(x=>`<td>${x??'—'}</td>`).join('')}</tr>`).join(''):`<tr><td colspan="${head.length}" class="muted">Sin registros para el contexto seleccionado.</td></tr>`}</tbody></table></div>`}
export function field(name,label,type='text',value='',options={}){const attrs=`name="${esc(name)}" ${options.required===false?'':'required'} ${type==='number'?'min="0" step="'+(options.step||'1')+'"':''}`;return `<label>${esc(label)}${type==='select'?`<select ${attrs}>${(options.items||[]).map(i=>{const pair=Array.isArray(i)?i:[i,i];return `<option value="${esc(pair[0])}" ${String(pair[0])===String(value)?'selected':''}>${esc(pair[1])}</option>`}).join('')}</select>`:type==='textarea'?`<textarea ${attrs} rows="3">${esc(value)}</textarea>`:`<input ${attrs} type="${type}" value="${esc(value)}">`}</label>`}
export function form(id,title,fields,button='Guardar'){return `<details class="card wf-form-section"><summary><strong>${esc(title)}</strong></summary><form id="${id}" class="wf-form"><div class="filter-grid">${fields}</div><div class="dialog-actions"><button type="submit">${esc(button)}</button></div></form></details>`}
export const options=items=>[['','Seleccionar…'],...items];
export async function screen(root,title,description,loader,draw){
 const [branches,access]=await Promise.all([workflowData.branches(),loadAccess()]);
 const preferred=access.context?.branch_id||access.context?.current_branch_id||access.context?.profile_branch_id;
 const state={branch:branches.find(b=>b.id===preferred)?.id||branches[0]?.id||'',date:localDay(),shift:'DIURNO',access,branches,userId:access.context?.user_id||access.context?.id,can:p=>access.permissions.has(p)};
 root.innerHTML=`<div class="sales-toolbar"><div><h2 class="section-heading">${esc(title)}</h2><p class="muted">${esc(description)}</p></div><button class="secondary" data-wf-refresh>Actualizar</button></div><div data-wf-msg role="status"></div><section class="card filter-grid wf-filters">${field('branch','Sucursal','select',state.branch,{items:options(branches.map(b=>[b.id,b.name]))})}${field('date','Fecha operativa','date',state.date)}${field('shift','Turno','select',state.shift,{items:['DIURNO','NOCTURNO']})}<p class="muted">America/Santo_Domingo · el turno se asigna explícitamente.</p></section><div data-wf-body></div>`;
 const body=root.querySelector('[data-wf-body]'),msg=root.querySelector('[data-wf-msg]');let generation=0;
 function message(text,bad=false){msg.innerHTML=`<div class="status ${bad?'bad':'ok'}">${esc(text)}</div>`}
 async function reload(){const ticket=++generation;if(!state.branch){body.innerHTML='<section class="card">Seleccione una sucursal.</section>';return}body.innerHTML='<section class="card">Cargando registros…</section>';try{const data=await loader({...state});if(ticket===generation)await draw(body,data,state,actions)}catch(e){if(ticket===generation){body.innerHTML='<section class="card">No se pudieron cargar los registros. Puede reintentar.</section>';message(e.message,true)}}}
 const actions={reload,message,mutate:async(button,fn)=>{if(button.disabled)return;button.disabled=true;try{await fn();message('Registro guardado.');await reload()}catch(e){message(e.message,true)}finally{if(button.isConnected)button.disabled=false}},bindForm:(id,fn)=>{const el=body.querySelector('#'+id);if(el)el.onsubmit=async e=>{e.preventDefault();if(!el.reportValidity())return;const data=Object.fromEntries(new FormData(el));await actions.mutate(el.querySelector('[type="submit"]'),()=>fn(data))}}};
 root.querySelectorAll('.wf-filters [name]').forEach(el=>el.onchange=()=>{state[el.name]=el.value;msg.innerHTML='';reload()});root.querySelector('[data-wf-refresh]').onclick=reload;
 await reload();return {state,actions};
}
export function downloadText(name,text){const url=URL.createObjectURL(new Blob([text],{type:'text/plain;charset=utf-8'}));const a=document.createElement('a');a.href=url;a.download=name;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000)}
