import {loadCommercialCalendar,createLaunchProject,createSpecialistActivity,createVisit} from './commercial-calendar-data.js';
import {loadVisitRoute,logReferrerVisit} from './medical-network-data.js';
import {getBranches} from './sales-data.js';
import {esc,field,downloadText} from './workflow-ui.js';
import {rdTimestamp,localDay} from './workflow-domain.js';

const MONTHS=['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
const WEEKDAY_NAMES=['','Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
const KIND_LABEL={visit:'Visita a cliente',launch:'Lanzamiento de producto',specialist:'Actividad con especialista'};
const KIND_CLASS={visit:'cc-visit',launch:'cc-launch',specialist:'cc-specialist'};

function commercialCalendarStyles(){if(!document.querySelector('[data-cc-style]')){const l=document.createElement('link');l.rel='stylesheet';l.href=new URL('../css/commercial-calendar.css',import.meta.url).href;l.dataset.ccStyle='';document.head.append(l)}}
function daysInMonth(y,m){return new Date(y,m,0).getDate()}
function dayOf(iso){return new Date(iso).getDate()}
function today(){return new Date()}

export async function mountCommercialCalendar(root){
  commercialCalendarStyles();
  root.innerHTML='<section class="card"><div class="status info">Cargando agenda comercial…</div></section>';
  let branches;
  try{branches=await getBranches()}catch(e){root.innerHTML=`<section class="card"><div class="status bad">${esc(e.message)}</div></section>`;return}
  const now=today();
  const todayISO=now.toISOString().slice(0,10);
  let state={branchId:branches[0]?.id||'',year:now.getFullYear(),month:now.getMonth()+1,tab:'hoy',search:''};
  let data={visits:[],customers:[],launches:[],referrers:[],activities:[]};
  let route=[];

  function customerName(id){return data.customers.find(c=>c.id===id)?.name||'Cliente'}
  function referrerName(id){return data.referrers.find(r=>r.referrer_id===id)?.full_name||'Especialista'}
  function matchesSearch(text){return !state.search||(text||'').toLowerCase().includes(state.search.trim().toLowerCase())}

  function eventsByDay(){
    const total=daysInMonth(state.year,state.month);
    const byDay=Object.fromEntries(Array.from({length:total},(_,i)=>[i+1,[]]));
    data.visits.forEach(v=>{
      const d=new Date(v.scheduled_at);
      const title=customerName(v.customer_id);
      if(d.getFullYear()===state.year&&d.getMonth()+1===state.month&&matchesSearch(title))byDay[d.getDate()]?.push({kind:'visit',title,time:d,ref:v});
    });
    data.launches.forEach(p=>{
      if(!p.target_date||!matchesSearch(p.title))return;
      const d=new Date(p.target_date+'T00:00:00');
      if(d.getFullYear()===state.year&&d.getMonth()+1===state.month)byDay[d.getDate()]?.push({kind:'launch',title:p.title,time:d,ref:p});
    });
    data.activities.forEach(a=>{
      const title=referrerName(a.referrer_id);
      if(!matchesSearch(title))return;
      const d=new Date(a.referral_date+'T00:00:00');
      if(d.getFullYear()===state.year&&d.getMonth()+1===state.month)byDay[d.getDate()]?.push({kind:'specialist',title,time:d,ref:a});
    });
    return byDay;
  }

  function calendarHtml(){
    const total=daysInMonth(state.year,state.month);
    const firstWeekday=new Date(state.year,state.month-1,1).getDay();
    const byDay=eventsByDay();
    const weekdayHead=['Dom','Lun','Mar','Mié','Jue','Vie','Sáb'].map(w=>`<div class="cc-wd">${w}</div>`).join('');
    let cells='';
    for(let i=0;i<firstWeekday;i++)cells+='<div class="cc-day cc-other"></div>';
    for(let d=1;d<=total;d++){
      const evs=byDay[d]||[];
      const isToday=state.year===now.getFullYear()&&state.month===now.getMonth()+1&&d===now.getDate();
      cells+=`<div class="cc-day${isToday?' cc-today':''}"><div class="cc-num">${d}</div>${evs.map(e=>`<button type="button" class="cc-ev ${KIND_CLASS[e.kind]}" data-kind="${e.kind}" data-id="${esc(e.ref.id)}">${esc(e.title)}</button>`).join('')}</div>`;
    }
    return `<div class="cc-cal">${weekdayHead}${cells}</div>`;
  }

  function todayHtml(){
    const visitsToday=data.visits.filter(v=>new Date(v.scheduled_at).toISOString().slice(0,10)===todayISO)
      .map(v=>({kind:'visit',time:new Date(v.scheduled_at),title:customerName(v.customer_id),sub:v.purpose,ref:v,status:v.status}))
      .filter(e=>matchesSearch(e.title));
    const activitiesToday=data.activities.filter(a=>a.referral_date===todayISO)
      .map(a=>({kind:'specialist',time:null,title:referrerName(a.referrer_id),sub:a.notes||'Actividad con especialista',ref:a,status:a.status}))
      .filter(e=>matchesSearch(e.title));
    const launchesToday=data.launches.filter(p=>p.target_date===todayISO)
      .map(p=>({kind:'launch',time:null,title:p.title,sub:'Lanzamiento de producto',ref:p,status:p.status}))
      .filter(e=>matchesSearch(e.title));
    const visitedReferrerIdsToday=new Set(data.activities.filter(a=>a.referral_date===todayISO).map(a=>a.referrer_id));
    const dueReferrersToday=route.filter(r=>r.is_due&&r.receives_today&&!visitedReferrerIdsToday.has(r.id)&&matchesSearch(r.full_name));

    const timed=[...visitsToday].sort((a,b)=>a.time-b.time);
    const matutina=dueReferrersToday.filter(r=>r.reception_shift!=='VESPERTINA');
    const vespertina=dueReferrersToday.filter(r=>r.reception_shift==='VESPERTINA');
    const untimedOther=[...activitiesToday,...launchesToday];

    const overdueCount=dueReferrersToday.filter(r=>r.days_overdue>0).length;
    const totalToday=timed.length+dueReferrersToday.length+untimedOther.length;

    function timedRow(e){
      return `<div class="cc-route-card">
        <div class="cc-route-body">
          <strong>${esc(e.time?e.time.toLocaleTimeString('es-DO',{hour:'2-digit',minute:'2-digit'}):'')} · ${esc(e.title)}</strong>
          <div class="muted">${esc(e.sub||'')}</div>
          <div class="cc-route-tags"><span class="cc-tag cc-tag-info">${esc(KIND_LABEL[e.kind])}</span><span class="cc-tag cc-tag-ok">${esc(e.status)}</span></div>
        </div>
        <div class="cc-route-actions"><button class="minibtn" data-open="${e.kind}:${esc(e.ref.id)}">Ver</button></div>
      </div>`;
    }
    function dueRow(r){
      return `<div class="cc-route-card">
        <div class="cc-route-body">
          <strong>${esc(r.full_name)}</strong>
          <div class="muted">${esc(r.specialty||'')}${r.organization?' · '+esc(r.organization):''}</div>
          <div class="cc-route-tags">${r.days_overdue>0?`<span class="cc-tag cc-tag-due">Vencido ${esc(r.days_overdue)} día(s)</span>`:'<span class="cc-tag cc-tag-due">Vence hoy</span>'}${r.priority==='ALTA'?'<span class="cc-tag cc-tag-due">Prioridad alta</span>':''}</div>
        </div>
        <div class="cc-route-actions">
          <button class="minibtn primary" data-visit="${esc(r.id)}" data-outcome="VISITADO">Visitado</button>
          <button class="minibtn" data-visit="${esc(r.id)}" data-outcome="NO_DISPONIBLE">No disponible</button>
        </div>
      </div>`;
    }
    function infoRow(e){
      return `<div class="cc-route-card">
        <div class="cc-route-body">
          <strong>${esc(e.title)}</strong>
          <div class="muted">${esc(e.sub||'')}</div>
          <div class="cc-route-tags"><span class="cc-tag cc-tag-info">${esc(KIND_LABEL[e.kind])}</span></div>
        </div>
        <div class="cc-route-actions"><button class="minibtn" data-open="${e.kind}:${esc(e.ref.id)}">Ver</button></div>
      </div>`;
    }

    return `
      <div class="cc-kpis">
        <div class="cc-kpi"><div class="cc-kpi-v">${totalToday}</div><div class="cc-kpi-l">Total hoy</div></div>
        <div class="cc-kpi"><div class="cc-kpi-v">${overdueCount}</div><div class="cc-kpi-l">Vencidos</div></div>
        <div class="cc-kpi"><div class="cc-kpi-v">${timed.length}</div><div class="cc-kpi-l">Con hora fija</div></div>
      </div>
      ${timed.length?`<div class="cc-route-section"><h3>Con hora fija</h3>${timed.map(timedRow).join('')}</div>`:''}
      ${matutina.length?`<div class="cc-route-section"><h3>Tanda matutina (médicos vencidos)</h3>${matutina.map(dueRow).join('')}</div>`:''}
      ${vespertina.length?`<div class="cc-route-section"><h3>Tanda vespertina (médicos vencidos)</h3>${vespertina.map(dueRow).join('')}</div>`:''}
      ${untimedOther.length?`<div class="cc-route-section"><h3>Otras actividades de hoy</h3>${untimedOther.map(infoRow).join('')}</div>`:''}
      ${totalToday===0?`<p class="muted">${state.search?'Ningún resultado para "'+esc(state.search)+'" en el día de hoy.':'No hay nada agendado ni vencido para hoy. Revisa la Ruta del día para planificar.'}</p>`:''}
    `;
  }

  function routeHtml(){
    const pool=route.filter(r=>matchesSearch(r.full_name));
    const dueToday=pool.filter(r=>r.is_due&&r.receives_today).sort((a,b)=>(b.days_overdue||0)-(a.days_overdue||0));
    const dueOtherDays=pool.filter(r=>r.is_due&&!r.receives_today).sort((a,b)=>(b.days_overdue||0)-(a.days_overdue||0));
    const notYetDue=pool.filter(r=>!r.is_due).sort((a,b)=>(a.next_due_date||'').localeCompare(b.next_due_date||''));
    const noSchedule=pool.filter(r=>!r.visit_frequency_days||!r.last_visit_at);

    function row(r,projected){
      const overdue=r.days_overdue>0;
      return `<div class="cc-route-card">
        <div class="cc-route-body">
          <strong>${esc(r.full_name)}</strong>
          <div class="muted">${esc(r.specialty||'')}${r.organization?' · '+esc(r.organization):''}</div>
          <div class="cc-route-tags">
            ${overdue?`<span class="cc-tag cc-tag-due">Vencido ${esc(r.days_overdue)} día(s)</span>`:r.is_due?'<span class="cc-tag cc-tag-due">Vence hoy</span>':`<span class="cc-tag cc-tag-ok">Próxima: ${esc(r.next_due_date||'—')}</span>`}
            ${r.reception_shift?`<span class="cc-tag cc-tag-info">${esc(r.reception_shift)}</span>`:''}
            ${r.priority==='ALTA'?'<span class="cc-tag cc-tag-due">Prioridad alta</span>':''}
            ${(r.reception_days||[]).length?`<span class="cc-tag cc-tag-info">${r.reception_days.map(d=>WEEKDAY_NAMES[d]).join(', ')}</span>`:''}
          </div>
        </div>
        ${projected?`<div class="cc-route-actions">
          <button class="minibtn primary" data-visit="${esc(r.id)}" data-outcome="VISITADO">Visitado</button>
          <button class="minibtn" data-visit="${esc(r.id)}" data-outcome="NO_DISPONIBLE">No disponible</button>
        </div>`:''}
      </div>`;
    }

    return `
      <div class="cc-route-section">
        <h3>Ruta proyectada de hoy (${dueToday.length})</h3>
        <p class="muted">Médicos que reciben hoy y ya cumplieron su frecuencia de visita.</p>
        ${dueToday.map(r=>row(r,true)).join('')||'<p class="muted">Nadie vencido recibe hoy. Revisa "Vencidos otros días" si quieres adelantar alguna visita.</p>'}
      </div>
      <div class="cc-route-section">
        <h3>Vencidos, otro día de recepción (${dueOtherDays.length})</h3>
        ${dueOtherDays.map(r=>row(r,false)).join('')||'<p class="muted">Ninguno.</p>'}
      </div>
      <div class="cc-route-section">
        <h3>Próximos a vencer (${notYetDue.length})</h3>
        ${notYetDue.slice(0,10).map(r=>row(r,false)).join('')||'<p class="muted">Ninguno.</p>'}
      </div>
      ${noSchedule.length?`<div class="cc-route-section"><h3>Sin condiciones de recepción configuradas (${noSchedule.length})</h3><p class="muted">Agrega días, tanda y frecuencia desde Red Médica para que entren en la ruta predictiva.</p>${noSchedule.map(r=>`<div class="cc-route-card"><div class="cc-route-body"><strong>${esc(r.full_name)}</strong></div></div>`).join('')}</div>`:''}
    `;
  }

  function listCsv(){
    const byDay=eventsByDay();
    const rows=['fecha,tipo,titulo'];
    Object.entries(byDay).forEach(([d,evs])=>evs.forEach(e=>rows.push(`${state.year}-${String(state.month).padStart(2,'0')}-${String(d).padStart(2,'0')},${KIND_LABEL[e.kind]},"${(e.title||'').replace(/"/g,'""')}"`)));
    return rows.join('\n');
  }

  function render(){
    root.innerHTML=`
      <div class="sales-toolbar"><div><h2 class="section-heading">Agenda Comercial</h2><div class="muted">Visitas a clientes, lanzamientos de producto y actividades con especialistas en un solo calendario.</div></div><div class="quick-links">${state.tab==='calendario'?'<button id="cc-export" class="secondary">Exportar</button><button id="cc-new">+ Nueva actividad</button>':''}</div></div>
      <div id="cc-msg"></div>
      <nav class="cc-tabs">
        <button type="button" class="cc-tab${state.tab==='hoy'?' cc-tab-active':''}" data-tab="hoy">Mi Día</button>
        <button type="button" class="cc-tab${state.tab==='calendario'?' cc-tab-active':''}" data-tab="calendario">Calendario</button>
        <button type="button" class="cc-tab${state.tab==='ruta'?' cc-tab-active':''}" data-tab="ruta">Ruta del día (predictiva)</button>
      </nav>
      <form id="cc-filters" class="card filter-grid">
        <label>Sucursal<select id="cc-f-branch">${branches.map(b=>`<option value="${esc(b.id)}" ${state.branchId===b.id?'selected':''}>${esc(b.name)}</option>`).join('')}</select></label>
        <label>Buscar médico o cliente<input id="cc-f-search" type="search" placeholder="Nombre…" value="${esc(state.search)}"></label>
        ${state.tab==='calendario'?`<label>Mes<select id="cc-f-month">${MONTHS.map((m,i)=>`<option value="${i+1}" ${state.month===i+1?'selected':''}>${esc(m)}</option>`).join('')}</select></label>
        <label>Año<input id="cc-f-year" type="number" value="${state.year}" min="2024" max="2100"></label>`:''}
        <button type="submit">Actualizar</button>
      </form>
      ${state.tab==='hoy'?`<section class="card">${todayHtml()}</section>`:''}
      ${state.tab==='calendario'?`
        <div class="cc-legend">
          <span><i class="cc-swatch cc-visit"></i>Visita a cliente</span>
          <span><i class="cc-swatch cc-launch"></i>Lanzamiento de producto</span>
          <span><i class="cc-swatch cc-specialist"></i>Actividad con especialista</span>
        </div>
        <section class="card">${calendarHtml()}</section>
      `:''}
      ${state.tab==='ruta'?`<section class="card">${routeHtml()}</section>`:''}
      <dialog id="cc-new-dialog" class="sales-dialog"></dialog>
      <dialog id="cc-detail-dialog" class="sales-dialog"></dialog>
    `;
    document.getElementById('cc-filters').onsubmit=e=>{
      e.preventDefault();
      state={...state,branchId:document.getElementById('cc-f-branch').value,
        month:state.tab==='calendario'?Number(document.getElementById('cc-f-month').value):state.month,
        year:state.tab==='calendario'?Number(document.getElementById('cc-f-year').value):state.year};
      load();
    };
    document.getElementById('cc-f-search').oninput=e=>{
      const pos=e.target.selectionStart;
      state={...state,search:e.target.value};
      render();
      const input=document.getElementById('cc-f-search');
      input.focus();
      input.setSelectionRange(pos,pos);
    };
    root.querySelectorAll('.cc-tab').forEach(btn=>btn.onclick=()=>{state={...state,tab:btn.dataset.tab};load()});
    document.getElementById('cc-export')?.addEventListener('click',()=>downloadText(`agenda-comercial-${state.year}-${String(state.month).padStart(2,'0')}.csv`,listCsv()));
    document.getElementById('cc-new')?.addEventListener('click',openNewDialog);
    root.querySelectorAll('.cc-ev').forEach(btn=>btn.onclick=()=>openDetail(btn.dataset.kind,btn.dataset.id));
    root.querySelectorAll('[data-open]').forEach(btn=>{const [kind,id]=btn.dataset.open.split(':');btn.onclick=()=>openDetail(kind,id)});
    root.querySelectorAll('[data-visit]').forEach(btn=>btn.onclick=async()=>{
      const r=route.find(x=>x.id===btn.dataset.visit);
      try{
        await logReferrerVisit(r.id,{branchId:r.branch_id,outcome:btn.dataset.outcome,notes:btn.dataset.outcome==='VISITADO'?'Visita registrada desde Ruta del día':'Marcado no disponible desde Ruta del día'});
        await load();
      }catch(err){document.getElementById('cc-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
    });
  }

  function openDetail(kind,id){
    const dialog=document.getElementById('cc-detail-dialog');
    let html='';
    if(kind==='visit'){
      const v=data.visits.find(x=>x.id===id);
      html=`<h3>${esc(KIND_LABEL.visit)}</h3><p><strong>${esc(customerName(v.customer_id))}</strong></p><p class="muted">${esc(new Date(v.scheduled_at).toLocaleString('es-DO'))}</p><p>${esc(v.purpose)}</p><p>Estado: ${esc(v.status)}</p>${v.commitment?`<p>Compromiso: ${esc(v.commitment)}</p>`:''}`;
    }else if(kind==='launch'){
      const p=data.launches.find(x=>x.id===id);
      html=`<h3>${esc(KIND_LABEL.launch)}</h3><p><strong>${esc(p.title)}</strong></p><p class="muted">Meta: ${esc(p.target_date)}</p><p>Estado: ${esc(p.status)} · ${esc(p.progress_pct)}% avance</p><p>${esc(p.objective||'')}</p>`;
    }else{
      const a=data.activities.find(x=>x.id===id);
      html=`<h3>${esc(KIND_LABEL.specialist)}</h3><p><strong>${esc(referrerName(a.referrer_id))}</strong></p><p class="muted">${esc(a.referral_date)}</p><p>${esc(a.notes||'Sin notas adicionales.')}</p><p>Estado: ${esc(a.status)}</p>`;
    }
    dialog.innerHTML=`${html}<div class="dialog-actions"><button type="button" id="cc-detail-close" class="secondary">Cerrar</button></div>`;
    dialog.querySelector('#cc-detail-close').onclick=()=>dialog.close();
    dialog.showModal();
  }

  function openNewDialog(){
    const dialog=document.getElementById('cc-new-dialog');
    let kind='visit';
    const defaultDate=`${state.year}-${String(state.month).padStart(2,'0')}-01`;
    function fieldsFor(){
      if(kind==='visit')return `
        ${field('customer_id','Cliente','select','',{items:data.customers.map(c=>[c.id,c.name])})}
        ${field('scheduled_at','Fecha y hora','datetime-local',defaultDate+'T09:00')}
        ${field('purpose','Objetivo')}`;
      if(kind==='launch')return `
        ${field('project_code','Código','text','LANZ-'+Date.now().toString().slice(-6))}
        ${field('title','Producto / título')}
        ${field('target_date','Fecha de lanzamiento','date',defaultDate)}
        ${field('objective','Objetivo','textarea','',{required:false})}`;
      return `
        ${field('referrer_id','Especialista','select','',{items:data.referrers.map(r=>[r.referrer_id,r.full_name+(r.specialty?' · '+r.specialty:'')])})}
        ${field('customer_id','Cliente / cuenta (opcional)','select','',{required:false,items:[['','— Sin cliente —'],...data.customers.map(c=>[c.id,c.name])]})}
        ${field('referral_date','Fecha','date',defaultDate)}
        ${field('notes','Descripción de la actividad','textarea','',{required:false})}`;
    }
    function draw(){
      dialog.innerHTML=`
        <form id="cc-new-form">
          <h3>Nueva actividad</h3>
          <div class="cc-type-picker">
            ${Object.entries(KIND_LABEL).map(([k,label])=>`<button type="button" class="cc-type-opt${k===kind?' cc-type-active':''}" data-type="${k}">${esc(label)}</button>`).join('')}
          </div>
          <div class="filter-grid">${fieldsFor()}</div>
          <p data-dialog-error role="alert"></p>
          <div class="dialog-actions"><button type="button" id="cc-new-close" class="secondary">Cancelar</button><button type="submit">Guardar en la agenda</button></div>
        </form>`;
      dialog.querySelector('#cc-new-close').onclick=()=>dialog.close();
      dialog.querySelectorAll('[data-type]').forEach(b=>b.onclick=()=>{kind=b.dataset.type;draw()});
      dialog.querySelector('#cc-new-form').onsubmit=async ev=>{
        ev.preventDefault();
        const fd=Object.fromEntries(new FormData(ev.target));
        try{
          if(kind==='visit')await createVisit(state.branchId,{customer_id:fd.customer_id,scheduled_at:rdTimestamp(fd.scheduled_at),duration_minutes:30,purpose:fd.purpose,status:'PROPUESTA'});
          else if(kind==='launch')await createLaunchProject({project_code:fd.project_code,title:fd.title,target_date:fd.target_date,objective:fd.objective||null,status:'PLANIFICADO',priority:'MEDIA'});
          else await createSpecialistActivity({referrer_id:fd.referrer_id,branch_id:state.branchId,customer_id:fd.customer_id||null,referral_date:fd.referral_date,notes:fd.notes||null,status:'REFERIDO',estimated_units:0});
          dialog.close();
          await load();
        }catch(err){dialog.querySelector('[data-dialog-error]').textContent=err.message}
      };
    }
    draw();
    dialog.showModal();
  }

  async function load(){
    try{
      [data,route]=await Promise.all([loadCommercialCalendar(state.branchId),loadVisitRoute(state.branchId)]);
      render();
    }catch(e){
      root.innerHTML=`<section class="card"><div class="status bad">${esc(e.message)}</div></section>`;
    }
  }

  await load();
}
