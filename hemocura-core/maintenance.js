import { resourcesData } from './resources-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);
const TYPE_LABEL={MANTENIMIENTO_PREVENTIVO:'Mant. preventivo',MANTENIMIENTO_CORRECTIVO:'Mant. correctivo',CALIBRACION:'Calibración',CALIFICACION:'Calificación',VERIFICACION:'Verificación'};
const STATUS_LABEL={PROGRAMADO:'Programado',EN_CURSO:'En curso',COMPLETADO:'Completado',VENCIDO:'Vencido',CANCELADO:'Cancelado'};
const RESULT_LABEL={CONFORME:'Conforme',NO_CONFORME:'No conforme',PENDIENTE:'Pendiente',NO_APLICA:'N/A'};

function calendarGrid(year,month,events){
  const first=new Date(year,month,1);
  const last=new Date(year,month+1,0);
  const startDay=first.getDay();
  const daysInMonth=last.getDate();
  const todayStr=today();
  const soon=new Date();soon.setDate(soon.getDate()+7);
  const soonStr=soon.toISOString().slice(0,10);

  const byDay={};
  for(const ev of events){
    const d=ev.scheduled_date;
    if(!d)continue;
    const [y,m]=d.split('-').map(Number);
    if(y===year&&m-1===month){
      const day=+d.split('-')[2];
      (byDay[day]??=[]).push(ev);
    }
  }

  const DAYS=['Dom','Lun','Mar','Mié','Jue','Vie','Sáb'];
  let html=`<div class="maint-cal"><div class="maint-cal-head">${DAYS.map(d=>`<div class="maint-cal-hd">${d}</div>`).join('')}</div><div class="maint-cal-body">`;
  for(let i=0;i<startDay;i++) html+=`<div class="maint-cal-cell maint-cal-empty"></div>`;
  for(let d=1;d<=daysInMonth;d++){
    const dateStr=`${year}-${String(month+1).padStart(2,'0')}-${String(d).padStart(2,'0')}`;
    const dayEvents=byDay[d]||[];
    const isToday=dateStr===todayStr;
    let dots='';
    for(const ev of dayEvents.slice(0,3)){
      let color='var(--accent,#2b5fa8)';
      if(ev.status==='VENCIDO'||ev.scheduled_date<todayStr&&ev.status==='PROGRAMADO') color='var(--danger,#c0392b)';
      else if(ev.scheduled_date<=soonStr) color='var(--warning,#e67e22)';
      dots+=`<span class="maint-dot" style="background:${color}" title="${esc(TYPE_LABEL[ev.event_type]||ev.event_type)}"></span>`;
    }
    if(dayEvents.length>3) dots+=`<span class="maint-dot-more">+${dayEvents.length-3}</span>`;
    html+=`<div class="maint-cal-cell${isToday?' maint-cal-today':''}" data-cal-date="${dateStr}"><span class="maint-cal-num">${d}</span><div class="maint-dots">${dots}</div></div>`;
  }
  html+=`</div></div>`;
  return html;
}

export async function mountMaintenance(root){
  const [equipment,branches]=await Promise.all([resourcesData.equipment(),resourcesData.branches()]);
  const bm=Object.fromEntries(branches.map(b=>[b.id,b.name]));
  const eqMap=Object.fromEntries(equipment.map(e=>[e.id,e]));

  let calYear=new Date().getFullYear(), calMonth=new Date().getMonth();
  const MONTHS=['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];

  root.innerHTML=`
  <div class="sales-toolbar"><div><h2 class="section-heading">Mantenimiento de Equipos</h2>
  <div class="muted">Órdenes de trabajo, calendario preventivo y calibraciones · ISO 15189</div></div>
  <button id="maint-new">Nueva orden de trabajo</button></div>
  <div id="maint-msg"></div>
  <div class="grid sales-kpis" id="maint-kpis"></div>

  <section class="card"><h3>Calendario de mantenimiento</h3>
  <div style="display:flex;align-items:center;gap:12px;margin-bottom:12px">
    <button type="button" id="maint-prev" class="secondary compact">◀</button>
    <strong id="maint-cal-title"></strong>
    <button type="button" id="maint-next" class="secondary compact">▶</button>
    <button type="button" id="maint-today" class="secondary compact">Hoy</button>
  </div>
  <div id="maint-calendar"></div>
  <div id="maint-day-detail"></div>
  </section>

  <section class="card"><h3>Órdenes de trabajo</h3>
  <div class="filter-grid" style="margin-bottom:10px">
    <label>Estado<select id="maint-filter-status"><option value="">Todos</option><option value="PROGRAMADO">Programado</option><option value="EN_CURSO">En curso</option><option value="COMPLETADO">Completado</option><option value="VENCIDO">Vencido</option><option value="CANCELADO">Cancelado</option></select></label>
    <label>Tipo<select id="maint-filter-type"><option value="">Todos</option>${Object.entries(TYPE_LABEL).map(([k,v])=>`<option value="${k}">${esc(v)}</option>`).join('')}</select></label>
  </div>
  <div class="table-wrap"><table class="data-table">
  <thead><tr><th>Código</th><th>Equipo</th><th>Sucursal</th><th>Tipo</th><th>Programado</th><th>Realizado</th><th>Estado</th><th>Resultado</th><th>Proveedor</th><th></th></tr></thead>
  <tbody id="maint-body"></tbody></table></div></section>

  <dialog id="maint-dialog" class="sales-dialog"><form id="maint-form">
  <h3 id="maint-dialog-title">Nueva orden de trabajo</h3>
  <div class="filter-grid">
    <label>Código<input id="maint-code" required placeholder="SRV-2026-001"></label>
    <label>Equipo<select id="maint-equip" required><option value="">Seleccionar…</option>${equipment.filter(e=>e.status==='ACTIVO').map(e=>`<option value="${esc(e.id)}">${esc(e.equipment_code)} · ${esc(e.equipment_type)}</option>`).join('')}</select></label>
    <label>Tipo<select id="maint-type">${Object.entries(TYPE_LABEL).map(([k,v])=>`<option value="${k}">${esc(v)}</option>`).join('')}</select></label>
    <label>Fecha programada<input id="maint-sched" type="date" value="${today()}" required></label>
    <label>Proveedor<input id="maint-provider"></label>
    <label>Responsable<input id="maint-responsible"></label>
  </div>
  <div class="dialog-actions"><button type="button" id="maint-cancel" class="secondary">Cancelar</button><button type="submit">Crear</button></div>
  </form></dialog>

  <dialog id="maint-complete-dialog" class="sales-dialog"><form id="maint-complete-form">
  <h3>Completar orden de trabajo</h3>
  <div class="filter-grid">
    <label>Fecha realizada<input id="mc-date" type="date" value="${today()}" required></label>
    <label>Resultado<select id="mc-result" required><option value="CONFORME">Conforme</option><option value="NO_CONFORME">No conforme</option><option value="PENDIENTE">Pendiente</option><option value="NO_APLICA">N/A</option></select></label>
    <label>Referencia certificado<input id="mc-cert"></label>
    <label>URL evidencia<input id="mc-evidence" type="url"></label>
    <label>Próxima fecha<input id="mc-next" type="date"></label>
    <label>Hallazgos<textarea id="mc-findings"></textarea></label>
  </div>
  <div class="dialog-actions"><button type="button" id="mc-cancel" class="secondary">Cancelar</button><button type="submit">Completar</button></div>
  </form></dialog>

  <style>
  .maint-cal{border:1px solid var(--border,#ddd);border-radius:6px;overflow:hidden}
  .maint-cal-head{display:grid;grid-template-columns:repeat(7,1fr);background:var(--surface-2,#f5f5f5);font-weight:600;font-size:.85em}
  .maint-cal-hd{padding:6px;text-align:center}
  .maint-cal-body{display:grid;grid-template-columns:repeat(7,1fr)}
  .maint-cal-cell{min-height:60px;padding:4px 6px;border:1px solid var(--border,#eee);cursor:pointer;position:relative}
  .maint-cal-cell:hover{background:var(--surface-2,#f9f9f9)}
  .maint-cal-cell.maint-cal-today{background:color-mix(in srgb,var(--accent,#2b5fa8) 8%,transparent)}
  .maint-cal-cell.maint-cal-selected{outline:2px solid var(--accent,#2b5fa8)}
  .maint-cal-empty{background:var(--surface-2,#fafafa)}
  .maint-cal-num{font-size:.85em;font-weight:600}
  .maint-dots{display:flex;gap:3px;flex-wrap:wrap;margin-top:2px}
  .maint-dot{width:8px;height:8px;border-radius:50%;display:inline-block}
  .maint-dot-more{font-size:.7em;color:var(--muted,#888)}
  </style>`;

  let allEvents=[];

  function renderKpis(){
    const todayStr=today();
    const soon=new Date();soon.setDate(soon.getDate()+7);const soonStr=soon.toISOString().slice(0,10);
    const overdue=allEvents.filter(e=>e.status==='VENCIDO'||(e.status==='PROGRAMADO'&&e.scheduled_date<todayStr)).length;
    const upcoming=allEvents.filter(e=>e.status==='PROGRAMADO'&&e.scheduled_date>=todayStr&&e.scheduled_date<=soonStr).length;
    const completed=allEvents.filter(e=>e.status==='COMPLETADO').length;
    const total=allEvents.length;
    const rate=total?Math.round(100*completed/total):0;
    document.getElementById('maint-kpis').innerHTML=`
      <section class="card"><div class="muted">Vencidos / atrasados</div><div class="kpi" style="color:var(--danger,#c0392b)">${overdue}</div></section>
      <section class="card"><div class="muted">Próximos 7 días</div><div class="kpi" style="color:var(--warning,#e67e22)">${upcoming}</div></section>
      <section class="card"><div class="muted">Completados</div><div class="kpi">${completed}</div></section>
      <section class="card"><div class="muted">Tasa cumplimiento</div><div class="kpi">${rate}%</div></section>`;
  }

  function renderCalendar(){
    document.getElementById('maint-cal-title').textContent=`${MONTHS[calMonth]} ${calYear}`;
    document.getElementById('maint-calendar').innerHTML=calendarGrid(calYear,calMonth,allEvents);
    document.getElementById('maint-day-detail').innerHTML='';
    document.querySelectorAll('.maint-cal-cell[data-cal-date]').forEach(cell=>{
      cell.onclick=()=>{
        document.querySelectorAll('.maint-cal-selected').forEach(c=>c.classList.remove('maint-cal-selected'));
        cell.classList.add('maint-cal-selected');
        showDayDetail(cell.dataset.calDate);
      };
    });
  }

  function showDayDetail(dateStr){
    const dayEvs=allEvents.filter(e=>e.scheduled_date===dateStr);
    const detail=document.getElementById('maint-day-detail');
    if(!dayEvs.length){detail.innerHTML=`<p class="muted" style="margin-top:8px">Sin eventos programados para ${dateStr}.</p>`;return}
    detail.innerHTML=`<div style="margin-top:10px"><strong>${dateStr}</strong> · ${dayEvs.length} evento(s)</div>
    <div class="table-wrap"><table class="data-table"><thead><tr><th>Código</th><th>Equipo</th><th>Tipo</th><th>Estado</th><th>Resultado</th></tr></thead>
    <tbody>${dayEvs.map(e=>`<tr>
      <td><code>${esc(e.service_code)}</code></td>
      <td>${esc(e.lab_equipment?.equipment_code||eqMap[e.equipment_id]?.equipment_code||'—')}</td>
      <td>${esc(TYPE_LABEL[e.event_type]||e.event_type)}</td>
      <td>${esc(STATUS_LABEL[e.status]||e.status)}</td>
      <td>${esc(RESULT_LABEL[e.result]||e.result||'—')}</td>
    </tr>`).join('')}</tbody></table></div>`;
  }

  function renderTable(){
    const statusFilter=document.getElementById('maint-filter-status').value;
    const typeFilter=document.getElementById('maint-filter-type').value;
    let filtered=allEvents;
    if(statusFilter) filtered=filtered.filter(e=>e.status===statusFilter);
    if(typeFilter) filtered=filtered.filter(e=>e.event_type===typeFilter);

    document.getElementById('maint-body').innerHTML=filtered.length?filtered.map(e=>{
      const eq=e.lab_equipment||eqMap[e.equipment_id]||{};
      const canComplete=e.status==='PROGRAMADO'||e.status==='EN_CURSO';
      return `<tr>
        <td><code>${esc(e.service_code)}</code></td>
        <td>${esc(eq.equipment_code||'—')} · ${esc(eq.equipment_type||'')}</td>
        <td>${esc(bm[eq.branch_id]||'General')}</td>
        <td>${esc(TYPE_LABEL[e.event_type]||e.event_type)}</td>
        <td>${esc(e.scheduled_date||'—')}</td>
        <td>${esc(e.performed_date||'—')}</td>
        <td>${esc(STATUS_LABEL[e.status]||e.status)}</td>
        <td>${esc(RESULT_LABEL[e.result]||e.result||'—')}</td>
        <td>${esc(e.provider||'—')}</td>
        <td>${canComplete?`<button type="button" data-complete="${esc(e.id)}">Completar</button>`:''}</td>
      </tr>`;
    }).join(''):'<tr><td colspan="10" class="muted">Sin órdenes de trabajo.</td></tr>';

    document.getElementById('maint-body').querySelectorAll('[data-complete]').forEach(b=>{
      b.onclick=()=>openComplete(b.dataset.complete);
    });
  }

  async function load(){
    try{
      allEvents=await resourcesData.serviceEvents();
      renderKpis();
      renderCalendar();
      renderTable();
      document.getElementById('maint-msg').innerHTML='';
    }catch(e){
      document.getElementById('maint-msg').innerHTML=`<div class="status warn">${esc(e.message)} · Ejecute sql/35_RESOURCES_CONTROL_v0_35.sql.</div>`;
    }
  }

  document.getElementById('maint-filter-status').onchange=renderTable;
  document.getElementById('maint-filter-type').onchange=renderTable;

  document.getElementById('maint-prev').onclick=()=>{calMonth--;if(calMonth<0){calMonth=11;calYear--}renderCalendar()};
  document.getElementById('maint-next').onclick=()=>{calMonth++;if(calMonth>11){calMonth=0;calYear++}renderCalendar()};
  document.getElementById('maint-today').onclick=()=>{calYear=new Date().getFullYear();calMonth=new Date().getMonth();renderCalendar()};

  document.getElementById('maint-new').onclick=()=>{document.getElementById('maint-dialog-title').textContent='Nueva orden de trabajo';document.getElementById('maint-dialog').showModal()};
  document.getElementById('maint-cancel').onclick=()=>document.getElementById('maint-dialog').close();
  document.getElementById('maint-form').onsubmit=async ev=>{
    ev.preventDefault();
    try{
      await resourcesData.createService({
        service_code:document.getElementById('maint-code').value.trim(),
        equipment_id:document.getElementById('maint-equip').value,
        event_type:document.getElementById('maint-type').value,
        scheduled_date:document.getElementById('maint-sched').value,
        provider:document.getElementById('maint-provider').value.trim()||null,
        responsible:document.getElementById('maint-responsible').value.trim()||null,
        status:'PROGRAMADO'
      });
      document.getElementById('maint-dialog').close();
      ev.target.reset();
      document.getElementById('maint-sched').value=today();
      await load();
    }catch(e){document.getElementById('maint-msg').innerHTML=`<div class="status bad">${esc(e.message)}</div>`}
  };

  let completingId=null;
  function openComplete(id){
    completingId=id;
    document.getElementById('mc-date').value=today();
    document.getElementById('mc-result').value='CONFORME';
    document.getElementById('mc-cert').value='';
    document.getElementById('mc-evidence').value='';
    document.getElementById('mc-next').value='';
    document.getElementById('mc-findings').value='';
    document.getElementById('maint-complete-dialog').showModal();
  }
  document.getElementById('mc-cancel').onclick=()=>document.getElementById('maint-complete-dialog').close();
  document.getElementById('maint-complete-form').onsubmit=async ev=>{
    ev.preventDefault();
    try{
      await resourcesData.updateService(completingId,{
        performed_date:document.getElementById('mc-date').value,
        result:document.getElementById('mc-result').value,
        certificate_reference:document.getElementById('mc-cert').value.trim()||null,
        evidence_url:document.getElementById('mc-evidence').value.trim()||null,
        next_due_date:document.getElementById('mc-next').value||null,
        findings:document.getElementById('mc-findings').value.trim()||null,
        status:'COMPLETADO'
      });
      document.getElementById('maint-complete-dialog').close();
      await load();
    }catch(e){document.getElementById('maint-msg').innerHTML=`<div class="status bad">${esc(e.message)}</div>`}
  };

  await load();
}
