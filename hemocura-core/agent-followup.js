import {areaAgendaData as api} from './area-agenda-data.js';
import {getSupabase} from './supabase.js';
import {loadAccess,filterRoutes} from './access-control.js';
import {routeList} from './router.js';
import {localDateTime} from './workflow-domain.js';
import {agentSourceReference,agentFollowupPayload} from './agent-followup-domain.js';
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const options=rows=>'<option value="">Seleccionar…</option>'+rows.map(([id,name])=>`<option value="${esc(id)}">${esc(name)}</option>`).join('');
export async function canPrepareAgentFollowup(){const [a,routes]=await Promise.all([loadAccess(),filterRoutes(routeList())]);return a.permissions.has('WORK_AGENDA_VIEW')&&a.permissions.has('WORK_AGENDA_WRITE')&&routes.some(([key])=>key==='areaagenda')}
export async function openAgentFollowup(root,finding,{onSaved}={}){
 const reference=agentSourceReference(finding);if(!root.isConnected)return;
 root.querySelector('[data-agent-task-dialog]')?.remove();const dialog=document.createElement('dialog');dialog.className='sales-dialog';dialog.dataset.agentTaskDialog='';dialog.setAttribute('aria-labelledby','agent-task-title');dialog.innerHTML='<h3 id="agent-task-title">Preparar seguimiento del hallazgo</h3><div data-task-status role="status" aria-live="polite">Consultando áreas y responsables autorizados…</div><div data-task-content></div><button type="button" class="secondary" data-task-close>Cerrar</button>';root.append(dialog);dialog.showModal();
 const status=dialog.querySelector('[data-task-status]'),content=dialog.querySelector('[data-task-content]'),close=dialog.querySelector('[data-task-close]');let saving=false,frozen=null,peopleGeneration=0,existing=[];
 close.onclick=()=>dialog.close();dialog.oncancel=e=>{if(saving)e.preventDefault()};dialog.addEventListener('close',()=>dialog.remove(),{once:true});
 try{
  if(!await canPrepareAgentFollowup())throw Error('Se requiere Agenda por área habilitada y permiso para crear tareas.');if(!dialog.isConnected)return;
  const [branches,areas]=await Promise.all([api.branches(),api.areas()]);if(!dialog.isConnected)return;
  const openAgenda=async(branch,id)=>{try{const routes=await filterRoutes(routeList());if(routes.some(([key])=>key==='areaagenda')){dialog.close();location.hash='#areaagenda?branch='+encodeURIComponent(branch)+'&task='+encodeURIComponent(id)}else status.textContent='La Agenda por área ya no está habilitada.'}catch{status.textContent='No se pudo verificar el acceso a la agenda.'}};
  const scoped=branches.filter(b=>!finding.branch_id||b.id===finding.branch_id);if(!scoped.length||!areas.length)throw Error('No hay sucursal o área de agenda habilitada para dar seguimiento a este hallazgo.');
  status.textContent='Revise el resultado esperado, el responsable y el vencimiento antes de guardar. La tarea requiere revisión independiente.';
  content.innerHTML=`<p class="muted">Use referencias operativas; evite nombres y datos clínicos de pacientes.</p><p><strong>${esc(finding.title||'Hallazgo para revisión')}</strong></p><p>${esc(finding.description||'')}</p><details><summary>Origen del seguimiento</summary><p>${esc(reference)}</p></details><div data-task-existing></div><form data-agent-task-form><div class="filter-grid"><label>${finding.branch_id?'Sucursal del hallazgo':'Sucursal responsable del seguimiento (señal global)'}<select name="branch_id" required>${!finding.branch_id?'<option value="">Seleccionar…</option>':''}${scoped.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label><label>Área<select name="area_code" required>${options(areas.map(a=>[a.code,a.name]))}</select></label><label>Responsable habilitado<select name="owner_id" required>${options([])}</select></label></div><label>Título de la tarea<input name="title" maxlength="250" required value="${esc(String(finding.title||'Revisar hallazgo del agente').slice(0,250))}"></label><label>Resultado esperado / instrucciones<textarea name="description" maxlength="6000">${esc(finding.recommended_action||'Revisar la evidencia y documentar las medidas de seguimiento.')}</textarea></label><div class="filter-grid"><label>Vencimiento del seguimiento (hora RD)<input name="due_at" type="datetime-local" required value="${esc(localDateTime(new Date(Date.now()+86400000).toISOString()))}"></label><label>Prioridad<select name="priority"><option>NORMAL</option><option>ALTA</option><option>CRITICA</option></select></label></div><label data-task-duplicate-check hidden><input type="checkbox" name="another"> Revisé los seguimientos existentes y necesito crear otro.</label><p data-task-form-error role="alert"></p><button type="submit" disabled>Guardar seguimiento</button></form>`;
  const form=content.querySelector('form'),submit=form.querySelector('[type=submit]'),existingHost=content.querySelector('[data-task-existing]');
  form.elements.branch_id.disabled=!!finding.branch_id;form.elements.area_code.value=areas[0].code;form.elements.priority.value=['ALTA','CRITICA'].includes(finding.priority)?finding.priority:'NORMAL';
  async function people(){
   const ticket=++peopleGeneration;submit.disabled=true;form.elements.owner_id.innerHTML=options([]);form.querySelector('[data-task-form-error]').textContent='Consultando responsables y seguimientos…';existingHost.replaceChildren();
   try{
    const branch=form.elements.branch_id.value,area=form.elements.area_code.value;
    if(!branch||!area){existing=[];form.querySelector('[data-task-form-error]').textContent='Seleccione la sucursal responsable y el área.';return}
    const [persons,result]=await Promise.all([api.people(branch,area),getSupabase().from('work_tasks').select('id,title,owner_name,due_at,status').eq('branch_id',branch).eq('source_route','orchestration').eq('source_reference',reference).order('created_at',{ascending:false}).order('id').limit(20)]);
    if(ticket!==peopleGeneration||!dialog.isConnected)return;if(result.error)throw result.error;
    form.elements.owner_id.innerHTML=options((persons||[]).map(p=>[p.id,p.full_name]));existing=result.data||[];
    existingHost.innerHTML=existing.length?`<div class="status info"><strong>Ya hay ${existing.length} seguimiento(s) visible(s) para este hallazgo.</strong><p>Se muestran hasta 20 registros recientes.</p><ul>${existing.map(t=>`<li>${esc(t.title)} · ${esc(t.owner_name)} · ${esc(t.status)} · ${esc(localDateTime(t.due_at).replace('T',' '))} <button type="button" class="secondary compact" data-existing-task="${esc(t.id)}">Ver tarea</button></li>`).join('')}</ul></div>`:'';
    existingHost.querySelectorAll('[data-existing-task]').forEach(button=>button.onclick=()=>openAgenda(branch,button.dataset.existingTask));
    form.querySelector('[data-task-duplicate-check]').hidden=!existing.length;form.elements.another.checked=false;form.querySelector('[data-task-form-error]').textContent=persons?.length?'':'No hay responsables elegibles para esta área y sucursal.';submit.disabled=!persons?.length;
   }catch{if(ticket===peopleGeneration&&dialog.isConnected){existing=[];form.querySelector('[data-task-form-error]').textContent='No se pudieron verificar responsables o tareas existentes. Cambie el área o cierre y vuelva a intentar.'}}
  }
  form.elements.branch_id.onchange=people;form.elements.area_code.onchange=people;
  const requestId=crypto.randomUUID();
  form.onsubmit=async e=>{
   e.preventDefault();if(saving||submit.disabled||!form.reportValidity())return;const error=form.querySelector('[data-task-form-error]');error.textContent='';
   if(existing.length&&!form.elements.another.checked){error.textContent='Revise los seguimientos existentes y confirme si necesita otro.';return}
   saving=true;submit.disabled=true;close.disabled=true;
   try{
    if(!await canPrepareAgentFollowup())throw Error('El permiso para crear seguimientos ya no está disponible.');
    if(!frozen){const fields=Object.fromEntries(new FormData(form));fields.branch_id=form.elements.branch_id.value;frozen=agentFollowupPayload(finding,fields,requestId)}
    saving=true;submit.disabled=true;close.disabled=true;form.querySelectorAll('input,select,textarea').forEach(el=>el.disabled=true);status.textContent='Guardando seguimiento revisado…';
    const result=await api.action('CREATE',frozen);if(!result?.ids?.length)throw Error('El servidor no confirmó la tarea.');if(!dialog.isConnected)return;
    content.innerHTML='<div class="status ok">Seguimiento registrado con responsable, vencimiento, referencia al hallazgo y revisión independiente.</div><button type="button" class="secondary" data-task-agenda>Revisar en Agenda por área</button>';status.textContent=result.already_created?'La solicitud ya estaba registrada; no se duplicó.':'Tarea guardada.';
    content.querySelector('[data-task-agenda]').onclick=()=>openAgenda(frozen.branch_id,result.ids[0]);
    try{onSaved?.(result)}catch{/* The task is already saved; a display callback cannot change that result. */}
   }catch(err){if(dialog.isConnected){error.textContent=err.message;status.textContent=frozen?'No se confirmó el resultado. Reintentar conserva los mismos datos y la misma solicitud para evitar duplicados.':'No se pudo preparar el seguimiento.';submit.disabled=false}}
   finally{saving=false;if(dialog.isConnected)close.disabled=false}
  };
  await people();
 }catch(err){if(dialog.isConnected){content.replaceChildren();status.textContent=err.message}}
}
