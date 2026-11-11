import {cycleData} from './twelve-week-data.js';
import {localDay,localDateTime,rdTimestamp} from './workflow-domain.js';
import {confirmDiscardProgress} from './progress-protection.js';
import {TASK_STATES,activeTask,overdue} from './area-agenda-domain.js';

const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const priorities=['NORMAL','ALTA','CRITICA'];
const priorityName={NORMAL:'Normal',ALTA:'Alta',CRITICA:'Crítica'};
const styles=`
.tw-screen .tw-toolbar,.tw-screen .tw-actions{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap}
.tw-screen .tw-actions{justify-content:flex-start}.tw-screen .tw-context{margin:16px 0}.tw-screen .tw-weeks{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;margin-top:12px}
.tw-screen .tw-week{min-width:0;display:flex;flex-direction:column;gap:10px}.tw-screen .tw-week p{margin:0;overflow-wrap:anywhere}.tw-screen .tw-week-button{background:#edf2f8;color:#1a365d;border:2px solid transparent;text-align:left;width:100%;font-weight:700}
.tw-screen .tw-week-button[aria-pressed=true]{border-color:#1a365d;background:#dfe8f4}.tw-screen .tw-week-current{border-top:4px solid #1a365d}.tw-screen .tw-goal{font-weight:600}.tw-screen .tw-help{line-height:1.6;max-width:90ch}.tw-screen .tw-empty{padding:18px;border:1px dashed #9eaec4;border-radius:8px}
.tw-screen .tw-section{margin-top:16px}.tw-screen .tw-task-title{max-width:360px;min-width:160px;white-space:normal;overflow-wrap:anywhere}.tw-screen .tw-task-note{display:block;margin-top:4px;color:#667085}.tw-screen .tw-warning{color:#8b0000;font-weight:600}.tw-screen .tw-badge{display:inline-block;background:#edf2f8;color:#17304e;border-radius:12px;padding:3px 8px;margin:3px;font-size:12px}
.tw-screen dialog{width:min(760px,94vw);max-height:92vh;overflow:auto;background:#fff;color:#172131;border:1px solid #d9e0ea;border-radius:12px;padding:22px}.tw-screen dialog::backdrop{background:#142b47bd}.tw-screen dialog header{display:flex;align-items:center;justify-content:space-between;gap:14px}.tw-screen dialog h3{margin:0}.tw-screen dialog input,.tw-screen dialog select,.tw-screen dialog textarea{display:block;width:100%;padding:10px;border:1px solid #9eaec4;border-radius:7px;color:#17304e;background:#fff;font:inherit}.tw-screen dialog textarea{min-height:90px}.tw-screen dialog form{margin-top:16px}
.tw-screen button:focus-visible,.tw-screen a:focus-visible,.tw-screen input:focus-visible,.tw-screen select:focus-visible,.tw-screen textarea:focus-visible{outline:3px solid #9a6700;outline-offset:3px}.tw-screen button:disabled{opacity:.55;cursor:default}.tw-screen .tw-link{color:#1a365d;text-decoration:underline;font-weight:600}.tw-screen .tw-kpis{margin-bottom:16px}.tw-screen [data-tw-dialog-error]:empty{display:none}
@media(max-width:650px){.tw-screen .tw-weeks{grid-template-columns:1fr}.tw-screen dialog{padding:16px}.tw-screen .tw-toolbar>div{min-width:0}.tw-screen .tw-actions button{flex:1}.tw-screen .tw-task-title{min-width:140px}}
`;
function addDays(iso,days){
 if(!/^\d{4}-\d{2}-\d{2}$/.test(iso||''))throw Error('Seleccione una fecha válida.');
 const date=new Date(iso+'T12:00:00Z');
 if(!Number.isFinite(date.getTime())||date.toISOString().slice(0,10)!==iso)throw Error('Seleccione una fecha válida.');
 date.setUTCDate(date.getUTCDate()+days);return date.toISOString().slice(0,10);
}
function weekRange(cycle,week){const start=addDays(cycle.start_date,(week-1)*7);return {start,end:addDays(start,6)}}
function currentWeek(cycle){const day=localDay();if(day<cycle.start_date)return 0;if(day>cycle.end_date)return 13;return Math.floor((Date.parse(day+'T12:00:00Z')-Date.parse(cycle.start_date+'T12:00:00Z'))/(7*86400000))+1}
const options=(items,selected='')=>items.map(([value,label])=>`<option value="${esc(value)}" ${String(value)===String(selected)?'selected':''}>${esc(label)}</option>`).join('');
const input=(name,label,value='',type='text',extra='')=>`<label>${esc(label)}<input name="${name}" type="${type}" value="${esc(value)}" ${extra}></label>`;
const textarea=(name,label,value='',max=2000,required=false)=>`<label>${esc(label)}<textarea name="${name}" maxlength="${max}" ${required?'required':''}>${esc(value)}</textarea></label>`;

export async function mountTwelveWeekPlan(root){
 root.classList.add('tw-screen');
 let context=null,branch='',area='',cycleId='',week=0,status='',priority='',busy=false,generation=0,dialogDirty=false,lastRequest=null,people=[],peopleLoaded=false;
 let data={enabled:true,can_manage:false,cycles:[],goals:[],tasks:[]};
 let notice={text:'',kind:'info'};const disabledBefore=new Map();
 const query=selector=>root.querySelector(selector);
 const availableAreas=()=>context.areas.filter(a=>!Array.isArray(a.branch_ids)||a.branch_ids.includes(branch));
 const selectedCycle=()=>data.cycles.find(c=>c.id===cycleId);
 const canManage=()=>context?.enabled===true&&data.enabled===true&&data.can_manage===true;
 const setNotice=(text,kind='info')=>{notice={text,kind};const node=query('[data-tw-message]');if(node){node.className=text?'status '+kind:'';node.textContent=text;node.setAttribute('role',kind==='bad'?'alert':'status')}};
 function setBusy(value){busy=value;root.setAttribute('aria-busy',String(value));if(value){for(const control of root.querySelectorAll('button,input,select,textarea')){if(!disabledBefore.has(control))disabledBefore.set(control,control.disabled);control.disabled=true}}else{for(const [control,disabled] of disabledBefore){if(control.isConnected)control.disabled=disabled}disabledBefore.clear()}}
 function allowDiscard(){
  if(busy){setNotice('Hay una operación en curso. Espere su resultado antes de cambiar de contexto.','warn');return false}
  const dialog=query('[data-tw-dialog]');
  if(dialog?.open&&dialogDirty){if(!confirm('Hay cambios sin guardar. ¿Desea descartarlos?'))return false;dialog.querySelector('form')?.reset();dialogDirty=false}
  return confirmDiscardProgress();
 }
 function closeDialog(){if(!allowDiscard())return;query('[data-tw-dialog]')?.close();dialogDirty=false}
 async function loadView(preferredCycle=''){
  if(!branch||!area){data={enabled:true,can_manage:false,cycles:[],goals:[],tasks:[]};setNotice('No hay un área autorizada para esta sucursal. Seleccione otra sucursal.','warn');render();return}
  const ticket=++generation;people=[];peopleLoaded=false;data={enabled:true,can_manage:false,cycles:[],goals:[],tasks:[]};setBusy(true);render();
  try{
   const result=await cycleData.load(branch,area);
   if(ticket!==generation||!root.isConnected)return;
   if(!result||!Array.isArray(result.cycles)||!Array.isArray(result.goals)||!Array.isArray(result.tasks))throw Error('El módulo devolvió datos incompletos.');
   data={...result,enabled:result.enabled===true};
   cycleId=data.cycles.find(c=>c.id===(preferredCycle||cycleId))?.id||data.cycles.find(c=>c.status==='ACTIVO')?.id||data.cycles[0]?.id||'';
  }catch(error){if(ticket===generation)setNotice((notice.kind==='ok'?notice.text+' ':'')+'No se pudo actualizar el plan. '+error.message,'bad')}
  finally{if(ticket===generation&&root.isConnected){setBusy(false);render()}}
 }
 async function save(type,payload){
  if(busy||!canManage())return;
  const signature=JSON.stringify({branch,area,type,payload});if(lastRequest?.signature!==signature)lastRequest={signature,id:crypto.randomUUID()};
  const form=query('[data-tw-form]'),errorNode=query('[data-tw-dialog-error]'),button=form?.querySelector('[type=submit]');setBusy(true);if(button)button.textContent='Guardando…';
  try{
   const result=await cycleData.action(branch,area,type,payload,lastRequest.id);lastRequest=null;
   if(!root.isConnected)return;
   form?.reset();dialogDirty=false;query('[data-tw-dialog]')?.close();setBusy(false);
   setNotice(type==='TASK_CREATE'?'Tarea creada en la Agenda por área, con responsable, vencimiento y revisión.':'Cambio guardado y registrado.','ok');
   await loadView(type==='CYCLE_SAVE'?(result?.id||result?.cycle?.id||cycleId):cycleId);
  }catch(error){if(errorNode?.isConnected){errorNode.className='status bad';errorNode.textContent=error.message+' Se conserva el formulario. Con los mismos datos, el reintento reutiliza la solicitud para evitar duplicados.'}setNotice('No se confirmó el guardado. Revise el mensaje y reintente desde el formulario.','bad')}
  finally{if(root.isConnected){setBusy(false);if(button?.isConnected)button.textContent='Reintentar guardar'}}
 }
 function modal(title,body,onSubmit){
  if(busy||!canManage())return;
  const dialog=query('[data-tw-dialog]');dialog.querySelector('[data-tw-dialog-title]').textContent=title;
  dialog.querySelector('[data-tw-form]').innerHTML=body+'<div data-tw-dialog-error role="alert"></div><div class="tw-actions"><button type="submit" data-tw-submit>Guardar</button></div>';
  const form=dialog.querySelector('form');dialogDirty=false;
  form.oninput=()=>{dialogDirty=true};form.onchange=()=>{dialogDirty=true};
  form.onsubmit=async event=>{event.preventDefault();if(busy||!form.reportValidity())return;try{await onSubmit(new FormData(form))}catch(error){const node=query('[data-tw-dialog-error]');node.className='status bad';node.textContent=error.message}};
  dialog.showModal();return form;
 }
 function cycleEditor(existing=null){
  if(existing?.status==='CERRADO')return;
  const allowed=existing?.status==='ACTIVO'?['ACTIVO','CERRADO']:['BORRADOR','ACTIVO'];const start=existing?.start_date||localDay();
  const form=modal(existing?'Editar ciclo de 12 semanas':'Nuevo ciclo de 12 semanas',`<p class="tw-help">Ciclo de 84 días calendario. El cierre es definitivo: después no se editan metas ni se crean tareas.</p><div class="filter-grid">${input('title','Nombre del ciclo',existing?.title||'','text','required maxlength="200"')}${input('start_date','Inicio del ciclo',start,'date','required'+(existing?' readonly':''))}<label>Estado<select name="status" required>${options(allowed.map(s=>[s,s]),existing?.status||'BORRADOR')}</select></label><div><strong>Final del ciclo</strong><p data-tw-end-date>${esc(addDays(start,83))}</p></div></div>${textarea('objective','Objetivo del ciclo',existing?.objective||'',2000,true)}`,fd=>save('CYCLE_SAVE',{...(existing?{id:existing.id,revision:existing.revision}:{}),title:String(fd.get('title')).trim(),start_date:String(fd.get('start_date')),objective:String(fd.get('objective')).trim(),status:String(fd.get('status'))}));
  if(form)form.elements.start_date.addEventListener('input',()=>{try{form.querySelector('[data-tw-end-date]').textContent=addDays(form.elements.start_date.value,83)}catch{form.querySelector('[data-tw-end-date]').textContent='Seleccione una fecha válida.'}});
 }
 function goalEditor(weekNumber){
  const cycle=selectedCycle();if(!cycle||cycle.status==='CERRADO'||!canManage())return;
  const existing=data.goals.find(g=>g.cycle_id===cycle.id&&Number(g.week_number)===weekNumber),range=weekRange(cycle,weekNumber);
  modal('Meta de la semana '+weekNumber,`<p class="tw-help">${esc(range.start)} al ${esc(range.end)}. La meta expresa un objetivo planificado; el módulo no calcula ni inventa resultados.</p>${input('week_number','Semana',weekNumber,'number','readonly min="1" max="12"')}<div class="filter-grid">${input('target_metric','Indicador / unidad de medida',existing?.target_metric||'','text','maxlength="200"')}${input('target_value','Valor objetivo (opcional)',existing?.target_value??'','number','step="any"')}</div>${textarea('goal','Meta semanal',existing?.goal||'',2000,true)}`,fd=>{const value=String(fd.get('target_value')).trim(),number=value===''?null:Number(value);if(number!==null&&!Number.isFinite(number))throw Error('El valor objetivo debe ser un número válido.');return save('GOAL_SAVE',{...(existing?{id:existing.id,revision:existing.revision}:{}),cycle_id:cycle.id,week_number:weekNumber,goal:String(fd.get('goal')).trim(),target_metric:String(fd.get('target_metric')).trim()||null,target_value:number})});
 }
 async function taskEditor(){
  const cycle=selectedCycle();if(!cycle||cycle.status!=='ACTIVO'||!canManage()||busy)return;
  const activeWeek=week||Math.min(12,Math.max(1,currentWeek(cycle))),range=weekRange(cycle,activeWeek);setBusy(true);setNotice('Consultando responsables autorizados de esta sucursal y área…');
  try{
   if(!peopleLoaded){people=await cycleData.people(branch,area);if(!Array.isArray(people))throw Error('Lista de responsables incompleta.');peopleLoaded=true}
  }catch(error){setNotice('No se pudo consultar a los responsables. '+error.message,'bad');return}
  finally{setBusy(false)}
  if(!root.isConnected)return;if(!people.length){setNotice('No hay responsables autorizados en esta sucursal y área. No se puede crear una tarea.','warn');return}
  setNotice('');const today=localDay(),date=today>=range.start&&today<=range.end?today:range.start;
  modal('Nueva tarea · semana '+activeWeek,`<p class="tw-help">Esta será una tarea real de la Agenda por área, con revisión. El vencimiento debe estar entre ${esc(range.start)} y ${esc(range.end)}, hora de Santo Domingo.</p>${input('week_number','Semana del ciclo',activeWeek,'number','readonly min="1" max="12"')}<div class="filter-grid">${input('title','Título de la tarea','','text','required maxlength="250"')}<label>Responsable<select name="owner_id" required><option value="">Seleccionar responsable…</option>${options(people.map(p=>[p.id,p.full_name]))}</select></label>${input('due_at','Vencimiento · Santo Domingo',date+'T17:00','datetime-local',`required min="${range.start}T00:00" max="${range.end}T23:59"`)}<label>Prioridad<select name="priority" required>${options(priorities.map(p=>[p,priorityName[p]]),'NORMAL')}</select></label></div>${textarea('description','Resultado esperado / instrucciones','',4000)}<p class="muted">Use referencias de trabajo; no escriba datos clínicos de pacientes. Ejecutar, aportar evidencia y validar se realiza en la Agenda por área.</p>`,fd=>{const due=String(fd.get('due_at')),date=due.slice(0,10);if(date<range.start||date>range.end)throw Error('El vencimiento debe pertenecer a la semana seleccionada.');const owner=String(fd.get('owner_id'));if(!people.some(p=>p.id===owner))throw Error('Seleccione un responsable autorizado.');return save('TASK_CREATE',{cycle_id:cycle.id,week_number:activeWeek,title:String(fd.get('title')).trim(),description:String(fd.get('description')).trim(),owner_id:owner,due_at:rdTimestamp(due),priority:String(fd.get('priority'))})});
 }
 function taskRows(tasks){return tasks.map(task=>`<tr><td>${esc(task.week_number)}</td><td class="tw-task-title"><strong>${esc(task.title||'Tarea')}</strong>${task.description?`<span class="tw-task-note">${esc(task.description)}</span>`:''}</td><td>${esc(task.owner_name||people.find(p=>p.id===task.owner_id)?.full_name||(task.owner_id===context.actorId?'Mi cuenta':'Responsable asignado'))}</td><td>${esc(localDateTime(task.due_at).replace('T',' ')||'Sin fecha')} ${overdue(task)?'<span class="tw-warning">Vencida</span>':''}</td><td>${esc(priorityName[task.priority]||task.priority)}</td><td>${esc(TASK_STATES[task.status]||task.status)}${task.requires_review?'<span class="tw-task-note">Revisión requerida</span>':''}</td><td><a class="tw-link" data-tw-task-agenda href="#areaagenda">Abrir Agenda por área</a></td></tr>`).join('')}
 function render(){
  if(!root.isConnected||!context)return;disabledBefore.clear();const cycle=selectedCycle(),tasks=data.tasks.filter(t=>t.cycle_id===cycleId),goals=data.goals.filter(g=>g.cycle_id===cycleId),current=cycle?currentWeek(cycle):0;
  const list=tasks.filter(t=>(!week||Number(t.week_number)===week)&&(!status||status==='VENCIDAS'&&overdue(t)||t.status===status)&&(!priority||t.priority===priority)).sort((a,b)=>Number(overdue(b))-Number(overdue(a))||priorities.indexOf(b.priority)-priorities.indexOf(a.priority)||String(a.due_at).localeCompare(String(b.due_at))||String(a.id).localeCompare(String(b.id)));
  const manager=canManage(),disabled=!data.enabled;
  root.innerHTML=`<style>${styles}</style><header class="tw-toolbar"><div><h2 class="section-heading">Plan de 12 Semanas</h2><p class="muted">Metas por sucursal y área, vinculadas a tareas reales con responsables y revisión.</p></div><div class="tw-actions"><a class="tw-link" data-tw-open-agenda href="#areaagenda">Agenda por área</a><button type="button" class="secondary" data-tw-refresh>Actualizar</button>${manager?'<button type="button" data-tw-new-cycle>Nuevo ciclo</button>':''}</div></header><div data-tw-message role="status" aria-live="polite"></div><section class="card filter-grid tw-context"><label>Sucursal<select data-tw-branch>${options(context.branches.map(b=>[b.id,b.name]),branch)}</select></label><label>Área<select data-tw-area ${availableAreas().length?'':'disabled'}>${options(availableAreas().map(a=>[a.code,a.name]),area)}</select></label><label>Ciclo<select data-tw-cycle ${data.cycles.length?'':'disabled'}>${data.cycles.length?options(data.cycles.map(c=>[c.id,c.title+' · '+c.status]),cycleId):'<option value="">Sin ciclos</option>'}</select></label><p class="muted">Hora local: Santo Domingo. ${manager?'Puede gestionar los ciclos de este ámbito.':'Vista de lectura de su ámbito autorizado.'}</p></section>${busy?'<p class="status info" data-tw-loading role="status">Cargando información…</p>':''}${disabled?'<section class="card"><p>El Plan de 12 Semanas no está activado para este ámbito. No se realizan cambios.</p></section>':cycle?`<section class="card"><div class="tw-toolbar"><h3>${esc(cycle.title)}</h3><div class="tw-actions">${manager&&cycle.status!=='CERRADO'?'<button type="button" class="secondary" data-tw-edit-cycle>Editar ciclo</button><button type="button" class="secondary" data-tw-new-goal>Definir meta semanal</button>':''}${manager&&cycle.status==='ACTIVO'?'<button type="button" data-tw-new-task>Nueva tarea</button>':''}</div></div><p>${esc(cycle.objective)}</p><p><strong>${esc(cycle.start_date)} → ${esc(cycle.end_date)}</strong><span class="tw-badge">${esc(cycle.status)}</span></p>${cycle.status==='CERRADO'?'<p class="muted">Ciclo cerrado: las metas y nuevas tareas están bloqueadas. Consulte la evidencia en la Agenda por área.</p>':cycle.status==='BORRADOR'?'<p class="muted">Ciclo en borrador: defina sus metas y actívelo antes de crear tareas.</p>':''}</section><div class="grid sales-kpis tw-kpis"><section class="card"><div>Completadas</div><div class="kpi">${tasks.filter(t=>t.status==='COMPLETADA').length}</div></section><section class="card"><div>Tareas activas</div><div class="kpi">${tasks.filter(activeTask).length}</div></section><section class="card"><div>Por revisar</div><div class="kpi">${tasks.filter(t=>t.status==='EN_REVISION').length}</div></section><section class="card"><div>Vencidas</div><div class="kpi">${tasks.filter(t=>overdue(t)).length}</div></section></div><section class="card tw-section"><h3>Semanas y metas</h3><p class="muted">Seleccione una semana para filtrar las tareas. Las cifras reflejan el estado real de las tareas, no el cumplimiento de la meta.</p><div class="tw-weeks">${Array.from({length:12},(_,i)=>{const w=i+1,range=weekRange(cycle,w),weekTasks=tasks.filter(t=>Number(t.week_number)===w),goal=goals.find(g=>Number(g.week_number)===w);return `<article class="card tw-week ${w===current?'tw-week-current':''}"><button type="button" data-tw-week="${w}" class="tw-week-button" aria-pressed="${week===w}">Semana ${w}${w===current?' · Actual':''}</button><p class="muted">${esc(range.start)} al ${esc(range.end)}</p><p class="tw-goal">${esc(goal?.goal||'Meta por definir')}</p>${goal?.target_metric||goal?.target_value!==null&&goal?.target_value!==undefined?`<p>${esc(goal.target_metric||'Valor objetivo')}: ${esc(goal.target_value??'Sin valor')}</p>`:''}<p>${weekTasks.filter(t=>t.status==='COMPLETADA').length} completadas · ${weekTasks.filter(activeTask).length} activas · ${weekTasks.filter(t=>t.status==='CANCELADA').length} canceladas</p>${manager&&cycle.status!=='CERRADO'?`<button type="button" class="secondary" data-tw-edit-goal="${w}">${goal?'Editar meta':'Definir meta'}</button>`:''}</article>`}).join('')}</div></section><section class="card tw-section"><div class="tw-toolbar"><h3>Tareas del ciclo${week?' · Semana '+week:''}</h3>${week?'<button type="button" class="secondary" data-tw-clear-week>Ver todas las semanas</button>':''}</div><div class="filter-grid"><label>Estado<select data-tw-status>${options([['','Todos'],['VENCIDAS','Vencidas'],...Object.entries(TASK_STATES)],status)}</select></label><label>Prioridad<select data-tw-priority>${options([['','Todas'],...priorities.map(p=>[p,priorityName[p]])],priority)}</select></label></div><p class="tw-help">Para iniciar, aportar evidencia, enviar a revisión o validar una tarea, ábrala en la Agenda por área. No se marca como completada desde esta pantalla.</p><div class="table-wrap"><table class="data-table"><caption>Tareas del ciclo seleccionado · ${esc(context.areas.find(a=>a.code===area)?.name||area)} · hora de Santo Domingo</caption><thead><tr>${['Semana','Tarea','Responsable','Vencimiento','Prioridad','Estado','Ejecución y revisión'].map(h=>`<th scope="col">${h}</th>`).join('')}</tr></thead><tbody>${list.length?taskRows(list):'<tr><td colspan="7">Sin tareas para estos filtros. Las nuevas tareas requieren un ciclo activo y un responsable autorizado.</td></tr>'}</tbody></table></div></section>`:!busy?'<section class="card tw-empty"><h3>No hay ciclos en este ámbito</h3><p>Seleccione otra sucursal o área autorizada.'+(manager?' También puede crear un ciclo de 12 semanas.':' Un gerente autorizado debe crear el ciclo y sus metas.')+'</p></section>':''}<dialog data-tw-dialog aria-labelledby="tw-dialog-heading"><header><h3 id="tw-dialog-heading" data-tw-dialog-title></h3><button type="button" class="secondary" data-tw-close>Cerrar</button></header><form data-tw-form></form></dialog>`;
  setNotice(notice.text,notice.kind);
  query('[data-tw-branch]').onchange=async event=>{const value=event.target.value;if(!allowDiscard()){event.target.value=branch;return}branch=value;if(!availableAreas().some(a=>a.code===area))area=availableAreas()[0]?.code||'';cycleId='';week=0;setNotice('');await loadView()};
  query('[data-tw-area]').onchange=async event=>{const value=event.target.value;if(!allowDiscard()){event.target.value=area;return}area=value;cycleId='';week=0;setNotice('');await loadView()};
  query('[data-tw-cycle]').onchange=event=>{if(!allowDiscard()){event.target.value=cycleId;return}cycleId=event.target.value;week=0;render()};
  query('[data-tw-refresh]').onclick=async()=>{if(allowDiscard())await loadView()};
  query('[data-tw-new-cycle]')?.addEventListener('click',()=>cycleEditor());query('[data-tw-edit-cycle]')?.addEventListener('click',()=>cycleEditor(selectedCycle()));query('[data-tw-new-goal]')?.addEventListener('click',()=>goalEditor(week||Math.min(12,Math.max(1,currentWeek(selectedCycle())))));query('[data-tw-new-task]')?.addEventListener('click',taskEditor);
  query('[data-tw-close]').onclick=closeDialog;query('[data-tw-dialog]').oncancel=event=>{event.preventDefault();closeDialog()};
  root.querySelectorAll('[data-tw-week]').forEach(button=>button.onclick=()=>{if(!allowDiscard())return;const value=Number(button.dataset.twWeek);week=week===value?0:value;render()});root.querySelectorAll('[data-tw-edit-goal]').forEach(button=>button.onclick=()=>goalEditor(Number(button.dataset.twEditGoal)));
  query('[data-tw-status]')?.addEventListener('change',event=>{const value=event.target.value;if(!allowDiscard()){event.target.value=status;return}status=value;render()});query('[data-tw-priority]')?.addEventListener('change',event=>{const value=event.target.value;if(!allowDiscard()){event.target.value=priority;return}priority=value;render()});query('[data-tw-clear-week]')?.addEventListener('click',()=>{if(allowDiscard()){week=0;render()}});setBusy(busy);
 }
 root.innerHTML='<p class="status info" role="status">Consultando acceso al Plan de 12 Semanas…</p>';root.setAttribute('aria-busy','true');
 try{
  context=await cycleData.context();if(!root.isConnected)return;
  if(context?.enabled!==true){root.innerHTML='<section class="card"><h2>Plan de 12 Semanas</h2><p>El nuevo flujo todavía no está activado. No se cargaron ni modificaron ciclos o tareas.</p></section>';root.setAttribute('aria-busy','false');return}
  if(!Array.isArray(context.branches)||!Array.isArray(context.areas))throw Error('El contexto de acceso está incompleto.');
  if(!context.branches.length||!context.areas.length){root.innerHTML='<section class="card"><h2>Plan de 12 Semanas</h2><p>No tiene una sucursal y un área habilitadas para consultar este módulo. Solicite revisión de sus permisos.</p></section>';root.setAttribute('aria-busy','false');return}
  branch=(context.branches.find(b=>context.areas.some(a=>!Array.isArray(a.branch_ids)||a.branch_ids.includes(b.id)))||context.branches[0]).id;area=availableAreas()[0]?.code||'';await loadView();
 }catch(error){root.setAttribute('aria-busy','false');root.innerHTML=`<section class="card"><h2>Plan de 12 Semanas</h2><p class="status bad" role="alert">No se pudo cargar el módulo. ${esc(error.message)}</p><button type="button" data-tw-retry>Reintentar</button></section>`;query('[data-tw-retry]').onclick=()=>mountTwelveWeekPlan(root)}
}
