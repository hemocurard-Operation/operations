import {loadCommercialCalendar,createLaunchProject,createSpecialistActivity,createVisit,updateVisitStatus} from './commercial-calendar-data.js';
import {loadVisitRoute,logReferrerVisit} from './medical-network-data.js';
import {getBranches} from './sales-data.js';
import {esc,field,downloadText} from './workflow-ui.js';
import {rdTimestamp,localDay,localDateTime} from './workflow-domain.js';
import {loadAccess} from './access-control.js';
import {confirmDiscardProgress} from './progress-protection.js';

const MONTHS=['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
const WEEKDAY_NAMES=['','Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
const KIND_LABEL={visit:'Visita a cliente',crmvisit:'Visita del mapa CRM',launch:'Lanzamiento corporativo',specialist:'Actividad con especialista'};
const KIND_CLASS={visit:'cc-visit',crmvisit:'cc-specialist',launch:'cc-launch',specialist:'cc-specialist'};
const ORIGIN={visit:'Agenda de clientes',crmvisit:'Mapa y plan semanal CRM',launch:'Proyecto comercial',specialist:'Red Médica'};
const LEGACY_KINDS=['visit','launch','specialist'];
const EMPTY=()=>({visits:[],customers:[],launches:[],referrers:[],activities:[],crmVisits:[],crmAgendaEnabled:null,crmAgendaError:'',warnings:[]});
function commercialCalendarStyles(){if(!document.querySelector('[data-cc-style]')){const link=document.createElement('link');link.rel='stylesheet';link.href=new URL('../css/commercial-calendar.css',import.meta.url).href;link.dataset.ccStyle='';document.head.append(link)}}
const pad=number=>String(number).padStart(2,'0');
function dateOnly(value){if(/^\d{4}-\d{2}-\d{2}$/.test(value||''))return value;return localDateTime(value).slice(0,10)}
function daysInMonth(year,month){return new Date(Date.UTC(year,month,0)).getUTCDate()}
const csvCell=value=>'"'+(/^\s*[=+\-@]|^[\t\r\n]/.test(String(value??''))?"'":'')+String(value??'').replaceAll('"','""')+'"';

export async function mountCommercialCalendar(root){
 commercialCalendarStyles();root.classList.add('cc-union');root.innerHTML='<section class="card"><div class="status info" role="status">Cargando agenda comercial…</div></section>';
 let branches,access;
 try{[branches,access]=await Promise.all([getBranches(),loadAccess()])}catch(error){root.innerHTML=`<section class="card"><div class="status bad" role="alert">${esc(error.message)}</div><button type="button" data-cc-retry>Reintentar</button></section>`;root.querySelector('[data-cc-retry]').onclick=()=>mountCommercialCalendar(root);return}
 if(!root.isConnected)return;
 if(!branches.length){root.innerHTML='<section class="card"><p>No hay sucursales autorizadas para consultar la agenda.</p></section>';return}
 const initialDay=localDay(),actor=access.context?.user_id||access.context?.id,permissions=access.permissions;
 const can=permission=>permissions.has(permission);
 const allowedKinds=()=>LEGACY_KINDS.filter(kind=>can(kind==='visit'?'COMMERCIAL_WRITE':kind==='launch'?'PROJECTS_WRITE':'MEDICAL_NETWORK_WRITE'));
 const canUpdateVisit=visit=>can('COMMERCIAL_WRITE')&&(visit.agent_id===actor||can('ACCESS_ADMIN'));
 let state={branchId:branches[0].id,year:Number(initialDay.slice(0,4)),month:Number(initialDay.slice(5,7)),tab:'hoy',search:''};
 let data=EMPTY(),route=[],routeError='',busy=false,generation=0,dialogDirty=false,searchTimer=null,notice={text:'',kind:'info'};
 const q=selector=>root.querySelector(selector),disabledBefore=new Map();
 function message(text,kind='info'){notice={text,kind};const node=q('#cc-msg');if(node){node.className=text?'status '+kind:'';node.textContent=text;node.setAttribute('role',kind==='bad'?'alert':'status')}}
 function setBusy(value){busy=value;root.setAttribute('aria-busy',String(value));if(value){for(const control of root.querySelectorAll('button,input,select,textarea')){if(!disabledBefore.has(control))disabledBefore.set(control,control.disabled);control.disabled=true}}else{for(const [control,disabled] of disabledBefore){if(control.isConnected)control.disabled=disabled}disabledBefore.clear()}}
 function allowDiscard(){
  if(busy){message('Hay una operación en curso. Espere su resultado.','warn');return false}
  const dialog=q('#cc-new-dialog');
  if(dialog?.open&&dialogDirty){if(!confirm('Hay cambios sin guardar. ¿Desea descartarlos?'))return false;dialog.querySelector('form')?.reset();dialogDirty=false}
  return confirmDiscardProgress();
 }
 const customerName=id=>data.customers.find(customer=>customer.id===id)?.name||'Cliente no disponible';
 const referrerName=id=>data.referrers.find(referrer=>referrer.referrer_id===id||referrer.id===id)?.full_name||'Especialista no disponible';
 const matchesSearch=text=>!state.search||String(text||'').toLocaleLowerCase('es').includes(state.search.trim().toLocaleLowerCase('es'));
 function allEvents(){
  const timed=(kind,record,title,sub)=>{const local=localDateTime(record.scheduled_at);return {kind,title,sub,date:local.slice(0,10),time:local.slice(11,16),ref:record,status:record.status,owner:record.owner_name||(record.agent_id===actor?'Mi cuenta':'Responsable asignado'),center:kind==='crmvisit'?record.center||'':'',specialty:kind==='crmvisit'?record.specialty||'':''}};
  const events=[
   ...data.visits.map(visit=>timed('visit',visit,customerName(visit.customer_id),visit.purpose)),
   ...data.crmVisits.map(visit=>timed('crmvisit',visit,visit.full_name||'Ficha CRM no disponible',visit.objective)),
   ...data.launches.map(project=>({kind:'launch',title:project.title,sub:project.objective,date:dateOnly(project.target_date),time:'',ref:project,status:project.status,owner:'',center:'',specialty:''})),
   ...data.activities.map(activity=>({kind:'specialist',title:referrerName(activity.referrer_id),sub:activity.notes,date:dateOnly(activity.referral_date),time:'',ref:activity,status:activity.status,owner:'',center:'',specialty:''}))
  ];
  return events.filter(event=>event.date&&matchesSearch([event.title,event.center,event.specialty,event.owner,event.sub].join(' '))).sort((a,b)=>(a.date+'T'+(a.time||'23:59')).localeCompare(b.date+'T'+(b.time||'23:59'))||a.kind.localeCompare(b.kind)||String(a.ref.id).localeCompare(String(b.ref.id)));
 }
 function eventsByDay(){const byDay=Object.fromEntries(Array.from({length:daysInMonth(state.year,state.month)},(_,index)=>[index+1,[]])),prefix=state.year+'-'+pad(state.month);for(const event of allEvents()){if(event.date.slice(0,7)===prefix)byDay[Number(event.date.slice(8,10))]?.push(event)}return byDay}
 function eventCellHtml(event){
  const quick=event.kind==='visit'&&event.status==='PROPUESTA'&&canUpdateVisit(event.ref)?`<span class="cc-ev-quick"><button type="button" class="cc-ev-qbtn cc-ev-qok" title="Confirmar visita a cliente" data-quick="confirm:${esc(event.ref.id)}">✓</button><button type="button" class="cc-ev-qbtn cc-ev-qno" title="Cancelar visita a cliente" data-quick="cancel:${esc(event.ref.id)}">✕</button></span>`:'';
  const label=[event.time,event.kind==='crmvisit'?'Mapa CRM · '+event.title:event.title].filter(Boolean).join(' · ');
  return `<div class="cc-ev-wrap" data-cc-event-key="${esc(event.kind+':'+event.ref.id)}"><button type="button" class="cc-ev ${KIND_CLASS[event.kind]}" data-kind="${event.kind}" data-id="${esc(event.ref.id)}" title="${esc([KIND_LABEL[event.kind],event.title,event.time,event.status,event.owner].filter(Boolean).join(' · '))}">${esc(label)}</button>${quick}</div>`;
 }
 function calendarHtml(){
  const byDay=eventsByDay(),total=daysInMonth(state.year,state.month),firstWeekday=new Date(Date.UTC(state.year,state.month-1,1)).getUTCDay(),today=localDay();
  let cells=Array.from({length:firstWeekday},()=>'<div class="cc-day cc-other"></div>').join('');
  for(let day=1;day<=total;day++){const date=state.year+'-'+pad(state.month)+'-'+pad(day);cells+=`<div class="cc-day${date===today?' cc-today':''}" data-cc-date="${date}"><div class="cc-num">${day}</div>${byDay[day].map(eventCellHtml).join('')}</div>`}
  return `<div class="table-wrap"><div class="cc-cal">${['Dom','Lun','Mar','Mié','Jue','Vie','Sáb'].map(day=>`<div class="cc-wd">${day}</div>`).join('')}${cells}</div></div>`;
 }
 function todayHtml(){
  const today=localDay(),events=allEvents().filter(event=>event.date===today),timed=events.filter(event=>event.time),other=events.filter(event=>!event.time);
  const visited=new Set(data.activities.filter(activity=>dateOnly(activity.referral_date)===today).map(activity=>activity.referrer_id));
  const due=route.filter(referrer=>referrer.is_due&&referrer.receives_today&&!visited.has(referrer.id)&&matchesSearch(referrer.full_name)),morning=due.filter(r=>r.reception_shift!=='VESPERTINA'),afternoon=due.filter(r=>r.reception_shift==='VESPERTINA');
  const total=events.length+due.length,pendingTimed=timed.filter(event=>['PROPUESTA','CONFIRMADA','PLANIFICADA'].includes(event.status)).length,incomplete=data.warnings.length>0||!!routeError;
  const eventRow=event=>`<article class="cc-route-card" data-cc-event-key="${esc(event.kind+':'+event.ref.id)}"><div class="cc-route-body"><strong>${esc([event.time,event.title].filter(Boolean).join(' · '))}</strong><div class="muted">${esc(event.sub||'')}</div>${event.center||event.specialty?`<p>${esc([event.center,event.specialty].filter(Boolean).join(' · '))}</p>`:''}${event.owner?`<p>Responsable: ${esc(event.owner)}</p>`:''}<div class="cc-route-tags"><span class="cc-tag cc-tag-info">${esc(KIND_LABEL[event.kind])}</span><span class="cc-tag cc-tag-info">Origen: ${esc(ORIGIN[event.kind])}</span>${event.status?`<span class="cc-tag cc-tag-info">${esc(event.status)}</span>`:''}</div></div><div class="cc-route-actions">${event.kind==='visit'&&event.status==='PROPUESTA'&&canUpdateVisit(event.ref)?`<button type="button" class="minibtn primary" data-quick="confirm:${esc(event.ref.id)}">Confirmar</button><button type="button" class="minibtn" data-quick="cancel:${esc(event.ref.id)}">Cancelar</button>`:''}<button type="button" class="minibtn" data-open="${event.kind}:${esc(event.ref.id)}">Ver</button></div></article>`;
  const dueRow=referrer=>`<div class="cc-route-card"><div class="cc-route-body"><strong>${esc(referrer.full_name)}</strong><div class="muted">${esc([referrer.specialty,referrer.organization].filter(Boolean).join(' · '))}</div><div class="cc-route-tags"><span class="cc-tag cc-tag-due">${referrer.days_overdue>0?'Vencido '+esc(referrer.days_overdue)+' día(s)':'Vence hoy'}</span>${referrer.priority==='ALTA'?'<span class="cc-tag cc-tag-due">Prioridad alta</span>':''}</div></div>${can('MEDICAL_NETWORK_WRITE')?`<div class="cc-route-actions"><button type="button" class="minibtn primary" data-visit="${esc(referrer.id)}" data-outcome="VISITADO">Visitado</button><button type="button" class="minibtn" data-visit="${esc(referrer.id)}" data-outcome="NO_DISPONIBLE">No disponible</button></div>`:''}</div>`;
  return `<p class="muted">${esc(today)} · America/Santo_Domingo</p><div class="cc-kpis"><div class="cc-kpi"><div class="cc-kpi-v">${events.length}</div><div class="cc-kpi-l">${incomplete?'Registros cargados hoy (incluye historial)':'Registros de hoy (incluye historial)'}</div></div><div class="cc-kpi"><div class="cc-kpi-v">${due.length}</div><div class="cc-kpi-l">Recomendaciones por frecuencia</div></div><div class="cc-kpi"><div class="cc-kpi-v">${pendingTimed}</div><div class="cc-kpi-l">Visitas pendientes con hora</div></div></div>${timed.length?`<section class="cc-route-section"><h3>Con hora fija</h3>${timed.map(eventRow).join('')}</section>`:''}${morning.length?`<section class="cc-route-section"><h3>Tanda matutina (médicos vencidos)</h3>${morning.map(dueRow).join('')}</section>`:''}${afternoon.length?`<section class="cc-route-section"><h3>Tanda vespertina (médicos vencidos)</h3>${afternoon.map(dueRow).join('')}</section>`:''}${other.length?`<section class="cc-route-section"><h3>Otras actividades de hoy</h3>${other.map(eventRow).join('')}</section>`:''}${!total?`<p class="muted">${incomplete?'La agenda está incompleta; no se puede confirmar ausencia de actividad.':state.search?'No hay coincidencias cargadas para esta búsqueda hoy.':'No hay registros cargados para hoy. Consulte el calendario o la ruta.'}</p>`:''}`;
 }
 function routeHtml(){
  const pool=route.filter(referrer=>matchesSearch(referrer.full_name)),dueToday=pool.filter(r=>r.is_due&&r.receives_today).sort((a,b)=>(b.days_overdue||0)-(a.days_overdue||0)),dueOther=pool.filter(r=>r.is_due&&!r.receives_today).sort((a,b)=>(b.days_overdue||0)-(a.days_overdue||0)),future=pool.filter(r=>!r.is_due).sort((a,b)=>(a.next_due_date||'').localeCompare(b.next_due_date||'')),unscheduled=pool.filter(r=>!r.visit_frequency_days||!r.last_visit_at);
  function row(referrer,projected){return `<div class="cc-route-card"><div class="cc-route-body"><strong>${esc(referrer.full_name)}</strong><div class="muted">${esc([referrer.specialty,referrer.organization].filter(Boolean).join(' · '))}</div><div class="cc-route-tags">${referrer.days_overdue>0?`<span class="cc-tag cc-tag-due">Vencido ${esc(referrer.days_overdue)} día(s)</span>`:referrer.is_due?'<span class="cc-tag cc-tag-due">Vence hoy</span>':`<span class="cc-tag cc-tag-ok">Próxima: ${esc(referrer.next_due_date||'—')}</span>`}${referrer.reception_shift?`<span class="cc-tag cc-tag-info">${esc(referrer.reception_shift)}</span>`:''}${referrer.priority==='ALTA'?'<span class="cc-tag cc-tag-due">Prioridad alta</span>':''}${referrer.reception_days?.length?`<span class="cc-tag cc-tag-info">${esc(referrer.reception_days.map(day=>WEEKDAY_NAMES[day]).join(', '))}</span>`:''}</div></div>${projected&&can('MEDICAL_NETWORK_WRITE')?`<div class="cc-route-actions"><button type="button" class="minibtn primary" data-visit="${esc(referrer.id)}" data-outcome="VISITADO">Visitado</button><button type="button" class="minibtn" data-visit="${esc(referrer.id)}" data-outcome="NO_DISPONIBLE">No disponible</button></div>`:''}</div>`}
  function grouped(rows,projected,empty){if(!rows.length)return `<p class="muted">${empty}</p>`;const zones=new Map();for(const referrer of rows){const zone=referrer.city||'Sin zona asignada';if(!zones.has(zone))zones.set(zone,[]);zones.get(zone).push(referrer)}return [...zones].sort(([a],[b])=>a.localeCompare(b)).map(([zone,people])=>`<div class="cc-zone-group"><h4 class="cc-zone-head">${esc(zone)} (${people.length})</h4>${people.map(person=>row(person,projected)).join('')}</div>`).join('')}
  return `<section class="cc-route-section"><h3>Ruta proyectada de hoy (${dueToday.length})</h3><p class="muted">Médicos con frecuencia cumplida y recepción hoy, agrupados por zona. Esta proyección no confirma una cita del mapa CRM.</p>${grouped(dueToday,true,'Ningún registro cargado cumple estas condiciones.')}</section><section class="cc-route-section"><h3>Vencidos, otro día de recepción (${dueOther.length})</h3>${grouped(dueOther,false,'Ninguno cargado.')}</section><section class="cc-route-section"><h3>Próximos a vencer (${future.length})</h3>${future.slice(0,10).map(person=>row(person,false)).join('')||'<p class="muted">Ninguno cargado.</p>'}</section>${unscheduled.length?`<section class="cc-route-section"><h3>Sin condiciones de recepción configuradas (${unscheduled.length})</h3><p class="muted">Revise días, tanda y frecuencia en Red Médica. Las reglas de las visitas del mapa se mantienen en su ficha CRM de origen.</p>${unscheduled.map(person=>`<div class="cc-route-card"><strong>${esc(person.full_name)}</strong></div>`).join('')}</section>`:''}`;
 }
 function listCsv(){const rows=[['fecha','tipo','titulo','hora_RD','id_original','centro','especialidad','responsable','estado','origen']];for(const events of Object.values(eventsByDay()))for(const event of events)rows.push([event.date,KIND_LABEL[event.kind],event.title,event.time,event.ref.id,event.center,event.specialty,event.owner,event.status,ORIGIN[event.kind]]);return '\uFEFF'+rows.map(row=>row.map(csvCell).join(',')).join('\r\n')}
 function render(){
  if(!root.isConnected)return;disabledBefore.clear();
  const warnings=[...data.warnings,...(routeError?[routeError]:[])];
  root.innerHTML=`<style>.cc-union .cc-route-body{min-width:0;overflow-wrap:anywhere}.cc-union .cc-route-actions{flex-wrap:wrap}.cc-union .cc-tab.cc-tab-active{background:#1a365d;border-color:#1a365d}.cc-union .cc-cal{min-width:300px}.cc-union .cc-ev{color:#17304e}.cc-union button:focus-visible,.cc-union a:focus-visible{outline:3px solid #9a6700;outline-offset:3px}@media(max-width:650px){.cc-union .cc-route-card{flex-wrap:wrap}.cc-union .cc-tabs{flex-wrap:wrap}.cc-union .cc-route-actions{flex-shrink:1}}</style><div class="sales-toolbar"><div><h2 class="section-heading">Agenda Comercial</h2><div class="muted">Visitas de clientes y del mapa CRM, lanzamientos y especialistas, con su origen y hora de Santo Domingo. Los lanzamientos corporativos pueden aparecer en todas las sucursales.</div></div><div class="quick-links">${state.tab==='calendario'?`<button type="button" id="cc-export" class="secondary">Exportar</button>${allowedKinds().length?'<button type="button" id="cc-new">+ Nueva actividad</button>':''}`:''}</div></div><div id="cc-msg" role="status" aria-live="polite"></div>${warnings.length?`<section class="status warn" role="status" data-cc-source-warnings><strong>Agenda incompleta</strong><ul>${warnings.map(warning=>`<li>${esc(warning)}</li>`).join('')}</ul><p>Se muestran solo los orígenes cargados; un origen fallido no equivale a cero visitas.</p></section>`:''}${data.crmAgendaEnabled===false?'<p class="status info" data-cc-map-off>Las visitas del mapa CRM todavía no están agregadas a este calendario. Puede consultarlas en <a href="#commercial">Gestión comercial</a>.</p>':''}<nav class="cc-tabs" aria-label="Vistas de la agenda"><button type="button" class="cc-tab${state.tab==='hoy'?' cc-tab-active':''}" data-tab="hoy" aria-pressed="${state.tab==='hoy'}">Mi Día</button><button type="button" class="cc-tab${state.tab==='calendario'?' cc-tab-active':''}" data-tab="calendario" aria-pressed="${state.tab==='calendario'}">Calendario</button><button type="button" class="cc-tab${state.tab==='ruta'?' cc-tab-active':''}" data-tab="ruta" aria-pressed="${state.tab==='ruta'}">Ruta del día (predictiva)</button></nav><form id="cc-filters" class="card filter-grid" data-progress-ignore><label>Sucursal<select id="cc-f-branch">${branches.map(branch=>`<option value="${esc(branch.id)}" ${state.branchId===branch.id?'selected':''}>${esc(branch.name)}</option>`).join('')}</select></label><label>Buscar médico, centro o cliente<input id="cc-f-search" type="search" placeholder="Nombre, centro, especialidad…" value="${esc(state.search)}"></label>${state.tab==='calendario'?`<label>Mes<select id="cc-f-month">${MONTHS.map((month,index)=>`<option value="${index+1}" ${state.month===index+1?'selected':''}>${esc(month)}</option>`).join('')}</select></label><label>Año<input id="cc-f-year" type="number" value="${state.year}" min="2024" max="2100"></label>`:''}<button type="submit" data-cc-refresh>Actualizar</button></form>${busy?'<p class="status info" data-cc-loading role="status">Cargando agenda…</p>':''}${state.tab==='hoy'&&!busy?`<section class="card">${todayHtml()}</section>`:''}${state.tab==='calendario'&&!busy?`<div class="cc-legend"><span><i class="cc-swatch cc-visit"></i>Visita a cliente</span>${data.crmAgendaEnabled===true?'<span><i class="cc-swatch cc-specialist"></i>Visita del mapa CRM · origen independiente</span>':''}<span><i class="cc-swatch cc-launch"></i>Lanzamiento corporativo</span><span><i class="cc-swatch cc-specialist"></i>Actividad con especialista</span></div><section class="card">${calendarHtml()}</section>`:''}${state.tab==='ruta'&&!busy?`<section class="card">${routeHtml()}</section>`:''}<dialog id="cc-new-dialog" class="sales-dialog"></dialog><dialog id="cc-detail-dialog" class="sales-dialog"></dialog>`;
  message(notice.text,notice.kind);
  q('#cc-filters').onsubmit=event=>{event.preventDefault();applyFilters(true)};
  q('#cc-f-branch').onchange=()=>applyFilters(false);q('#cc-f-month')?.addEventListener('change',()=>applyFilters(false));q('#cc-f-year')?.addEventListener('change',()=>applyFilters(false));
  q('#cc-f-search').oninput=()=>{clearTimeout(searchTimer);searchTimer=setTimeout(()=>applyFilters(false,true),220)};
  root.querySelectorAll('.cc-tab').forEach(button=>button.onclick=()=>{if(!allowDiscard())return;clearTimeout(searchTimer);state={...state,search:q('#cc-f-search').value,tab:button.dataset.tab};render()});
  q('#cc-export')?.addEventListener('click',()=>downloadText(`agenda-comercial-${state.year}-${pad(state.month)}.csv`,listCsv()));q('#cc-new')?.addEventListener('click',openNewDialog);
  root.querySelectorAll('.cc-ev').forEach(button=>button.onclick=()=>openDetail(button.dataset.kind,button.dataset.id));root.querySelectorAll('[data-open]').forEach(button=>button.onclick=()=>{const [kind,id]=button.dataset.open.split(':');openDetail(kind,id)});
  root.querySelectorAll('[data-quick]').forEach(button=>button.onclick=event=>{event.stopPropagation();const [action,id]=button.dataset.quick.split(':'),visit=data.visits.find(item=>item.id===id);if(!visit||!canUpdateVisit(visit))return;mutate(button,()=>updateVisitStatus(state.branchId,visit,action==='confirm'?'CONFIRMADA':'CANCELADA'))});
  root.querySelectorAll('[data-visit]').forEach(button=>button.onclick=()=>{if(!can('MEDICAL_NETWORK_WRITE'))return;const referrer=route.find(item=>item.id===button.dataset.visit);if(!referrer)return;mutate(button,()=>logReferrerVisit(referrer.id,{branchId:referrer.branch_id,outcome:button.dataset.outcome,notes:button.dataset.outcome==='VISITADO'?'Visita registrada desde Ruta del día':'Marcado no disponible desde Ruta del día'}))});setBusy(busy);
 }
 async function applyFilters(refresh=false,keepSearchFocus=false){
  if(!root.isConnected)return;const form=q('#cc-filters');if(!form)return;if(!allowDiscard()){q('#cc-f-branch').value=state.branchId;if(q('#cc-f-month'))q('#cc-f-month').value=state.month;if(q('#cc-f-year'))q('#cc-f-year').value=state.year;return}
  const input=q('#cc-f-search'),position=input.selectionStart,next={...state,branchId:q('#cc-f-branch').value,search:input.value,month:q('#cc-f-month')?Number(q('#cc-f-month').value):state.month,year:q('#cc-f-year')?Number(q('#cc-f-year').value):state.year};
  if(!Number.isInteger(next.month)||next.month<1||next.month>12||!Number.isInteger(next.year)||next.year<2024||next.year>2100){message('Seleccione un mes y un año válidos.','bad');return}
  const changedBranch=next.branchId!==state.branchId;state=next;clearTimeout(searchTimer);if(refresh||changedBranch)await load();else render();
  if(keepSearchFocus&&root.isConnected){const search=q('#cc-f-search');search.focus();search.setSelectionRange(position,position)}
 }
 async function mutate(button,operation){
  if(busy)return;setBusy(true);const label=button.textContent;button.textContent='Guardando…';
  try{await operation();setBusy(false);message('Cambio guardado.','ok');await load()}catch(error){message(error.message+' No se confirmó el guardado; revise el registro antes de repetir.','bad')}
  finally{setBusy(false);if(button.isConnected)button.textContent=label}
 }
 function openDetail(kind,id){
  clearTimeout(searchTimer);const event=allEvents().find(item=>item.kind===kind&&String(item.ref.id)===id);if(!event)return;const dialog=q('#cc-detail-dialog'),record=event.ref;
  let html=`<h3>${esc(KIND_LABEL[kind])}</h3><p><strong>${esc(event.title)}</strong></p><p class="muted">${esc(event.date)}${event.time?' · '+esc(event.time):''} · Santo Domingo</p><p>Origen: ${esc(ORIGIN[kind])}</p><p>Estado: ${esc(event.status||'No indicado')}</p><p>${esc(event.sub||'Sin notas adicionales.')}</p>`;
  if(kind==='crmvisit')html+=`<p>Centro: ${esc(event.center||'Por completar')} · Especialidad: ${esc(event.specialty||'Por completar')}</p><p>Responsable: ${esc(event.owner)}</p><p>Referencia original: ${esc(record.id)}</p><p>Sucursal de la visita: ${esc(branches.find(branch=>branch.id===state.branchId)?.name||'Sucursal seleccionada')}</p><p>Este calendario consulta la visita original; no la duplica ni registra su realización. Para modificarla o cancelarla, abra su mapa de origen y seleccione esta sucursal.</p><a href="#commercial" data-cc-map-origin>Abrir mapa / planificador (seleccione la misma sucursal) →</a>`;
  else if(kind==='visit'&&record.commitment)html+=`<p>Compromiso: ${esc(record.commitment)}</p>`;
  else if(kind==='launch')html+=`<p>Avance declarado: ${esc(record.progress_pct??'Sin indicar')}%</p>`;
  dialog.innerHTML=html+'<div class="dialog-actions"><button type="button" data-cc-detail-close class="secondary">Cerrar</button></div>';dialog.querySelector('[data-cc-detail-close]').onclick=()=>dialog.close();dialog.showModal();
 }
 function openNewDialog(){
  if(busy||!allowedKinds().length)return;clearTimeout(searchTimer);const dialog=q('#cc-new-dialog');let kind=allowedKinds()[0];const monthPrefix=state.year+'-'+pad(state.month),today=localDay(),defaultDate=today.startsWith(monthPrefix)?today:monthPrefix+'-01';
  function fieldsFor(){
   if(kind==='visit')return field('customer_id','Cliente','select','',{items:data.customers.map(customer=>[customer.id,customer.name])})+field('scheduled_at','Fecha y hora · Santo Domingo','datetime-local',defaultDate+'T09:00')+field('purpose','Objetivo');
   if(kind==='launch')return field('project_code','Código','text','LANZ-'+Date.now().toString().slice(-6))+field('title','Producto / título')+field('target_date','Fecha de lanzamiento','date',defaultDate)+field('objective','Objetivo','textarea','',{required:false});
   return field('referrer_id','Especialista','select','',{items:data.referrers.map(referrer=>[referrer.referrer_id||referrer.id,referrer.full_name+(referrer.specialty?' · '+referrer.specialty:'')])})+field('customer_id','Cliente / cuenta (opcional)','select','',{required:false,items:[['','— Sin cliente —'],...data.customers.map(customer=>[customer.id,customer.name])]})+field('referral_date','Fecha','date',defaultDate)+field('notes','Descripción de la actividad','textarea','',{required:false});
  }
  function close(){if(!allowDiscard())return;dialog.close();dialogDirty=false}
  function draw(){
   dialogDirty=false;dialog.innerHTML=`<form id="cc-new-form"><h3>Nueva actividad</h3><div class="cc-type-picker">${allowedKinds().map(type=>`<button type="button" class="cc-type-opt${type===kind?' cc-type-active':''}" data-type="${type}">${esc(KIND_LABEL[type])}</button>`).join('')}</div><div class="filter-grid">${fieldsFor()}</div><p data-dialog-error role="alert"></p><div class="dialog-actions"><button type="button" id="cc-new-close" class="secondary">Cancelar</button><button type="submit">Guardar en la agenda</button></div></form>`;
   const form=dialog.querySelector('form');form.oninput=()=>{dialogDirty=true};form.onchange=()=>{dialogDirty=true};dialog.querySelector('#cc-new-close').onclick=close;dialog.oncancel=event=>{event.preventDefault();close()};
   dialog.querySelectorAll('[data-type]').forEach(button=>button.onclick=()=>{if(!allowDiscard())return;kind=button.dataset.type;draw()});
   form.onsubmit=async event=>{
    event.preventDefault();if(busy||!form.reportValidity()||!allowedKinds().includes(kind))return;const fields=Object.fromEntries(new FormData(form)),button=form.querySelector('[type=submit]');setBusy(true);button.textContent='Guardando…';
    try{
     if(kind==='visit')await createVisit(state.branchId,{customer_id:fields.customer_id,scheduled_at:rdTimestamp(fields.scheduled_at),duration_minutes:30,purpose:fields.purpose,status:'PROPUESTA'});
     else if(kind==='launch')await createLaunchProject({project_code:fields.project_code,title:fields.title,target_date:fields.target_date,objective:fields.objective||null,status:'PLANIFICADO',priority:'MEDIA'});
     else await createSpecialistActivity({referrer_id:fields.referrer_id,branch_id:state.branchId,customer_id:fields.customer_id||null,referral_date:fields.referral_date,notes:fields.notes||null,status:'REFERIDO',estimated_units:0});
     form.reset();dialogDirty=false;dialog.close();setBusy(false);message('Actividad guardada en su origen.','ok');await load();
    }catch(error){dialog.querySelector('[data-dialog-error]').textContent=error.message+' El formulario se conserva. Revise los registros antes de repetir un guardado no confirmado.'}
    finally{setBusy(false);if(button.isConnected)button.textContent='Guardar en la agenda'}
   };
  }
  draw();dialog.showModal();
 }
 async function load(){
  const ticket=++generation,branch=state.branchId;setBusy(true);data=EMPTY();route=[];routeError='';render();
  try{
   const [calendarResult,routeResult]=await Promise.allSettled([loadCommercialCalendar(branch),loadVisitRoute(branch)]);
   if(ticket!==generation||!root.isConnected||state.branchId!==branch)return;
   if(calendarResult.status==='fulfilled')data=calendarResult.value;
   else data={...EMPTY(),warnings:['No se pudo cargar la agenda. '+(calendarResult.reason?.message||'Error de conexión.')]};
   if(routeResult.status==='fulfilled')route=routeResult.value;else routeError='No se pudo cargar la ruta de recepción. '+(routeResult.reason?.message||'Error de conexión.');
  }finally{if(ticket===generation&&root.isConnected){setBusy(false);render()}}
 }
 await load();
}
