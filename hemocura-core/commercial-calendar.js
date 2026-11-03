import {loadCommercialCalendar,createLaunchProject,createSpecialistActivity,createVisit} from './commercial-calendar-data.js';
import {getBranches} from './sales-data.js';
import {esc,field,downloadText} from './workflow-ui.js';
import {rdTimestamp,localDay} from './workflow-domain.js';

const MONTHS=['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
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
  let state={branchId:branches[0]?.id||'',year:now.getFullYear(),month:now.getMonth()+1};
  let data={visits:[],customers:[],launches:[],referrers:[],activities:[]};

  function customerName(id){return data.customers.find(c=>c.id===id)?.name||'Cliente'}
  function referrerName(id){return data.referrers.find(r=>r.referrer_id===id)?.full_name||'Especialista'}

  function eventsByDay(){
    const total=daysInMonth(state.year,state.month);
    const byDay=Object.fromEntries(Array.from({length:total},(_,i)=>[i+1,[]]));
    data.visits.forEach(v=>{
      const d=new Date(v.scheduled_at);
      if(d.getFullYear()===state.year&&d.getMonth()+1===state.month)byDay[d.getDate()]?.push({kind:'visit',title:customerName(v.customer_id),time:d,ref:v});
    });
    data.launches.forEach(p=>{
      if(!p.target_date)return;
      const d=new Date(p.target_date+'T00:00:00');
      if(d.getFullYear()===state.year&&d.getMonth()+1===state.month)byDay[d.getDate()]?.push({kind:'launch',title:p.title,time:d,ref:p});
    });
    data.activities.forEach(a=>{
      const d=new Date(a.referral_date+'T00:00:00');
      if(d.getFullYear()===state.year&&d.getMonth()+1===state.month)byDay[d.getDate()]?.push({kind:'specialist',title:referrerName(a.referrer_id),time:d,ref:a});
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

  function listCsv(){
    const byDay=eventsByDay();
    const rows=['fecha,tipo,titulo'];
    Object.entries(byDay).forEach(([d,evs])=>evs.forEach(e=>rows.push(`${state.year}-${String(state.month).padStart(2,'0')}-${String(d).padStart(2,'0')},${KIND_LABEL[e.kind]},"${(e.title||'').replace(/"/g,'""')}"`)));
    return rows.join('\n');
  }

  function render(){
    root.innerHTML=`
      <div class="sales-toolbar"><div><h2 class="section-heading">Agenda Comercial</h2><div class="muted">Visitas a clientes, lanzamientos de producto y actividades con especialistas en un solo calendario.</div></div><div class="quick-links"><button id="cc-export" class="secondary">Exportar</button><button id="cc-new">+ Nueva actividad</button></div></div>
      <div id="cc-msg"></div>
      <form id="cc-filters" class="card filter-grid">
        <label>Sucursal<select id="cc-f-branch">${branches.map(b=>`<option value="${esc(b.id)}" ${state.branchId===b.id?'selected':''}>${esc(b.name)}</option>`).join('')}</select></label>
        <label>Mes<select id="cc-f-month">${MONTHS.map((m,i)=>`<option value="${i+1}" ${state.month===i+1?'selected':''}>${esc(m)}</option>`).join('')}</select></label>
        <label>Año<input id="cc-f-year" type="number" value="${state.year}" min="2024" max="2100"></label>
        <button type="submit">Actualizar</button>
      </form>
      <div class="cc-legend">
        <span><i class="cc-swatch cc-visit"></i>Visita a cliente</span>
        <span><i class="cc-swatch cc-launch"></i>Lanzamiento de producto</span>
        <span><i class="cc-swatch cc-specialist"></i>Actividad con especialista</span>
      </div>
      <section class="card">${calendarHtml()}</section>
      <dialog id="cc-new-dialog" class="sales-dialog"></dialog>
      <dialog id="cc-detail-dialog" class="sales-dialog"></dialog>
    `;
    document.getElementById('cc-filters').onsubmit=e=>{
      e.preventDefault();
      state={branchId:document.getElementById('cc-f-branch').value,month:Number(document.getElementById('cc-f-month').value),year:Number(document.getElementById('cc-f-year').value)};
      load();
    };
    document.getElementById('cc-export').onclick=()=>downloadText(`agenda-comercial-${state.year}-${String(state.month).padStart(2,'0')}.csv`,listCsv());
    document.getElementById('cc-new').onclick=openNewDialog;
    root.querySelectorAll('.cc-ev').forEach(btn=>btn.onclick=()=>openDetail(btn.dataset.kind,btn.dataset.id));
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
      data=await loadCommercialCalendar(state.branchId);
      render();
    }catch(e){
      root.innerHTML=`<section class="card"><div class="status bad">${esc(e.message)}</div></section>`;
    }
  }

  await load();
}
