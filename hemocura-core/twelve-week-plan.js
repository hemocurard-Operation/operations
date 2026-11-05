import {listPlans,createPlan,listPlanLines,createPlanLine,updatePlanLine,listTasks,createTask,updateTask,listProfiles} from './twelve-week-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);

function addDays(iso,days){const d=new Date(iso+'T00:00:00');d.setDate(d.getDate()+days);return d.toISOString().slice(0,10)}
function weekRange(startDate,weekNum){const s=addDays(startDate,(weekNum-1)*7);const e=addDays(s,6);return{start:s,end:e}}
function currentWeek(startDate){const now=new Date();const s=new Date(startDate+'T00:00:00');const diff=Math.floor((now-s)/(1000*60*60*24));if(diff<0)return 0;const w=Math.floor(diff/7)+1;return w>12?13:w}

export async function mountTwelveWeekPlan(root){
  const profiles=await listProfiles();
  const um=Object.fromEntries(profiles.map(p=>[p.id,p.full_name||p.id]));
  let plans=await listPlans();
  let selectedPlanId=plans.find(p=>p.status==='ACTIVO')?.id||plans[0]?.id||null;
  let lines=[],tasks=[],weekFilter=0,statusFilter='';

  async function load(){
    if(!selectedPlanId){render();return}
    [lines,tasks]=await Promise.all([listPlanLines(selectedPlanId),listTasks(selectedPlanId)]);
    render();
  }

  function goalForWeek(w){return lines.find(l=>l.week_number===w)}
  function tasksForWeek(w){return tasks.filter(t=>t.week_number===w)}
  function taskStatus(t){
    if(t.status==='COMPLETADA')return 'COMPLETADA';
    if(t.status==='CANCELADA')return 'CANCELADA';
    if(t.due_date&&t.due_date<today()&&t.status!=='COMPLETADA')return 'VENCIDA';
    if(t.status==='EN_PROGRESO')return 'EN_PROGRESO';
    return 'PENDIENTE';
  }
  function statusClass(s){return s==='COMPLETADA'?'ok':s==='EN_PROGRESO'?'info':s==='VENCIDA'?'bad':'warn'}

  function render(){
    const plan=plans.find(p=>p.id===selectedPlanId);
    const allStatuses=tasks.map(taskStatus);
    const completed=allStatuses.filter(s=>s==='COMPLETADA').length;
    const inProgress=allStatuses.filter(s=>s==='EN_PROGRESO').length;
    const overdue=allStatuses.filter(s=>s==='VENCIDA').length;
    const cw=plan?currentWeek(plan.start_date):0;

    const filteredTasks=tasks.filter(t=>{
      if(weekFilter&&t.week_number!==weekFilter)return false;
      if(statusFilter&&taskStatus(t)!==statusFilter)return false;
      return true;
    });

    root.innerHTML=`
    <div class="sales-toolbar"><div><h2 class="section-heading">Plan de 12 Semanas</h2>
    <div class="muted">Ejecución estratégica: metas semanales, tareas, responsables y seguimiento.</div></div>
    <div class="dialog-actions"><button id="tw-new-plan">Nuevo plan</button><button id="tw-new-task" class="secondary"${!selectedPlanId?' disabled':''}>Nueva tarea</button></div></div>

    <div id="tw-msg"></div>

    <div class="filter-grid" style="margin-bottom:12px">
      <label>Plan activo<select id="tw-plan-select">
        ${plans.length?plans.map(p=>`<option value="${esc(p.id)}" ${p.id===selectedPlanId?'selected':''}>${esc(p.title||p.plan_code||'Sin título')} (${esc(p.status)})</option>`).join(''):'<option value="">Sin planes</option>'}
      </select></label>
      <label>Filtrar estado<select id="tw-status-filter">
        <option value="">Todos</option><option value="PENDIENTE"${statusFilter==='PENDIENTE'?' selected':''}>Pendiente</option><option value="EN_PROGRESO"${statusFilter==='EN_PROGRESO'?' selected':''}>En progreso</option><option value="COMPLETADA"${statusFilter==='COMPLETADA'?' selected':''}>Completada</option><option value="VENCIDA"${statusFilter==='VENCIDA'?' selected':''}>Vencida</option>
      </select></label>
      ${weekFilter?`<button id="tw-clear-week" class="secondary">Semana ${weekFilter} ✕</button>`:''}
    </div>

    <div class="grid sales-kpis">
      <section class="card"><div class="muted">Total tareas</div><div class="kpi">${tasks.length}</div></section>
      <section class="card"><div class="muted">Completadas</div><div class="kpi">${completed}</div></section>
      <section class="card"><div class="muted">En progreso</div><div class="kpi">${inProgress}</div></section>
      <section class="card"><div class="muted">Vencidas</div><div class="kpi">${overdue}</div></section>
    </div>

    ${plan?`<section class="card"><h3>Semanas del plan</h3>
    <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-top:8px">
      ${Array.from({length:12},(_,i)=>{
        const w=i+1;
        const wr=weekRange(plan.start_date,w);
        const wTasks=tasksForWeek(w);
        const wDone=wTasks.filter(t=>taskStatus(t)==='COMPLETADA').length;
        const pct=wTasks.length?Math.round(wDone/wTasks.length*100):0;
        const goal=goalForWeek(w);
        const isCurrent=w===cw;
        const isPast=w<cw;
        const barColor=pct>=80?'#22c55e':pct>=50?'#eab308':'#ef4444';
        const bg=isCurrent?'border:2px solid #3b82f6':'';
        const opacity=!isPast&&!isCurrent?'opacity:0.6':'';
        return `<div class="card" style="padding:12px;cursor:pointer;${bg};${opacity}" data-tw-week="${w}">
          <div><strong>Semana ${w}</strong>${isCurrent?' <span class="status info" style="font-size:11px">ACTUAL</span>':''}</div>
          <div class="muted" style="font-size:11px">${esc(wr.start)} → ${esc(wr.end)}</div>
          ${goal?`<div style="font-size:12px;margin:4px 0">${esc((goal.goal||goal.description||'').slice(0,60))}</div>`:'<div class="muted" style="font-size:11px">Sin meta definida</div>'}
          <div style="font-size:11px">${wTasks.length} tarea(s) · ${pct}%</div>
          <div style="height:4px;background:#e5e7eb;border-radius:2px;margin-top:4px"><div style="height:100%;width:${pct}%;background:${barColor};border-radius:2px"></div></div>
        </div>`;
      }).join('')}
    </div></section>`:'<section class="card"><div class="muted">Seleccione o cree un plan para comenzar.</div></section>'}

    <section class="card"><h3>Tareas${weekFilter?` — Semana ${weekFilter}`:''}</h3>
    <div class="table-wrap"><table class="data-table">
    <thead><tr><th>Sem.</th><th>Tarea</th><th>Responsable</th><th>Prioridad</th><th>Fecha límite</th><th>Estado</th><th>Acciones</th></tr></thead>
    <tbody>${filteredTasks.length?filteredTasks.map(t=>{
      const s=taskStatus(t);
      return `<tr><td>${esc(t.week_number||'—')}</td><td>${esc(t.description||t.title||'—')}</td><td>${esc(um[t.assigned_to]||t.assigned_to||'—')}</td><td>${esc(t.priority||'MEDIA')}</td><td>${esc(t.due_date||'—')}</td><td><span class="status ${statusClass(s)}">${esc(s)}</span></td><td>${s!=='COMPLETADA'&&s!=='CANCELADA'?`<button class="secondary" data-tw-complete="${esc(t.id)}" style="font-size:11px">Completar</button>${s==='PENDIENTE'?`<button class="secondary" data-tw-start="${esc(t.id)}" style="font-size:11px;margin-left:4px">Iniciar</button>`:''}`:'—'}</td></tr>`;
    }).join(''):'<tr><td colspan="7" class="muted">Sin tareas.</td></tr>'}</tbody>
    </table></div></section>

    <dialog id="tw-plan-dialog" class="sales-dialog"><form id="tw-plan-form">
    <h3>Nuevo plan de 12 semanas</h3>
    <label>Título<input id="twp-title" required placeholder="Plan Q1 2026"></label>
    <label>Fecha de inicio<input id="twp-start" type="date" value="${today()}" required></label>
    <label>Fecha fin (auto 12 sem.)<input id="twp-end" type="date" value="${addDays(today(),83)}" required></label>
    <label>Objetivo estratégico<textarea id="twp-objective" required placeholder="Incrementar captación de donantes en 20%…"></textarea></label>
    <label>Estado<select id="twp-status"><option>ACTIVO</option><option>BORRADOR</option></select></label>
    <div class="dialog-actions"><button type="button" id="twp-cancel" class="secondary">Cancelar</button><button>Crear plan</button></div>
    </form></dialog>

    <dialog id="tw-task-dialog" class="sales-dialog"><form id="tw-task-form">
    <h3>Nueva tarea</h3>
    <label>Descripción<input id="twt-desc" required></label>
    <label>Responsable<select id="twt-assign" required><option value="">Seleccionar…</option>${profiles.map(p=>`<option value="${esc(p.id)}">${esc(p.full_name||p.id)}</option>`).join('')}</select></label>
    <div class="filter-grid">
      <label>Semana (1-12)<input id="twt-week" type="number" min="1" max="12" value="${cw||1}" required></label>
      <label>Fecha límite<input id="twt-due" type="date" required></label>
      <label>Prioridad<select id="twt-priority"><option>MEDIA</option><option>ALTA</option><option>BAJA</option></select></label>
    </div>
    <label>Notas<textarea id="twt-notes"></textarea></label>
    <div class="dialog-actions"><button type="button" id="twt-cancel" class="secondary">Cancelar</button><button>Crear tarea</button></div>
    </form></dialog>

    <dialog id="tw-goal-dialog" class="sales-dialog"><form id="tw-goal-form">
    <h3>Meta semanal</h3>
    <label>Semana<input id="twg-week" type="number" min="1" max="12" readonly></label>
    <label>Meta / objetivo<textarea id="twg-goal" required placeholder="Completar revisión de procesos de tamizaje…"></textarea></label>
    <label>Métrica objetivo<input id="twg-metric" placeholder="Ej: donaciones efectivas"></label>
    <label>Valor objetivo<input id="twg-value" placeholder="Ej: 150"></label>
    <div class="dialog-actions"><button type="button" id="twg-cancel" class="secondary">Cancelar</button><button>Guardar meta</button></div>
    </form></dialog>`;

    // Event bindings
    document.getElementById('tw-plan-select').onchange=e=>{selectedPlanId=e.target.value;weekFilter=0;load()};
    document.getElementById('tw-status-filter').onchange=e=>{statusFilter=e.target.value;render()};
    document.getElementById('tw-clear-week')?.addEventListener('click',()=>{weekFilter=0;render()});

    document.getElementById('tw-new-plan').onclick=()=>{
      document.getElementById('twp-end').value=addDays(document.getElementById('twp-start').value,83);
      document.getElementById('tw-plan-dialog').showModal();
    };
    document.getElementById('twp-start')?.addEventListener('change',e=>{
      document.getElementById('twp-end').value=addDays(e.target.value,83);
    });
    document.getElementById('twp-cancel').onclick=()=>document.getElementById('tw-plan-dialog').close();
    document.getElementById('tw-plan-form').onsubmit=async e=>{
      e.preventDefault();
      try{
        const p=await createPlan({title:document.getElementById('twp-title').value.trim(),start_date:document.getElementById('twp-start').value,end_date:document.getElementById('twp-end').value,objective:document.getElementById('twp-objective').value.trim(),status:document.getElementById('twp-status').value});
        document.getElementById('tw-plan-dialog').close();
        plans=await listPlans();selectedPlanId=p.id;await load();
      }catch(err){document.getElementById('tw-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
    };

    document.getElementById('tw-new-task').onclick=()=>{
      if(!selectedPlanId)return;
      document.getElementById('tw-task-dialog').showModal();
    };
    document.getElementById('twt-cancel').onclick=()=>document.getElementById('tw-task-dialog').close();
    document.getElementById('tw-task-form').onsubmit=async e=>{
      e.preventDefault();
      try{
        await createTask({plan_id:selectedPlanId,description:document.getElementById('twt-desc').value.trim(),assigned_to:document.getElementById('twt-assign').value,week_number:Number(document.getElementById('twt-week').value),due_date:document.getElementById('twt-due').value,priority:document.getElementById('twt-priority').value,notes:document.getElementById('twt-notes').value.trim()||null,status:'PENDIENTE'});
        document.getElementById('tw-task-dialog').close();e.target.reset();await load();
      }catch(err){document.getElementById('tw-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
    };

    root.querySelectorAll('[data-tw-week]').forEach(card=>{
      card.onclick=()=>{const w=Number(card.dataset.twWeek);weekFilter=weekFilter===w?0:w;render()};
      card.oncontextmenu=e=>{e.preventDefault();openGoalDialog(Number(card.dataset.twWeek))};
      card.ondblclick=()=>openGoalDialog(Number(card.dataset.twWeek));
    });

    root.querySelectorAll('[data-tw-complete]').forEach(btn=>btn.onclick=async()=>{
      try{await updateTask(btn.dataset.twComplete,{status:'COMPLETADA',completed_at:new Date().toISOString()});await load()}catch(err){document.getElementById('tw-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
    });
    root.querySelectorAll('[data-tw-start]').forEach(btn=>btn.onclick=async()=>{
      try{await updateTask(btn.dataset.twStart,{status:'EN_PROGRESO'});await load()}catch(err){document.getElementById('tw-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
    });
  }

  function openGoalDialog(weekNum){
    const existing=goalForWeek(weekNum);
    document.getElementById('twg-week').value=weekNum;
    document.getElementById('twg-goal').value=existing?.goal||existing?.description||'';
    document.getElementById('twg-metric').value=existing?.target_metric||'';
    document.getElementById('twg-value').value=existing?.target_value||'';
    document.getElementById('twg-cancel').onclick=()=>document.getElementById('tw-goal-dialog').close();
    document.getElementById('tw-goal-form').onsubmit=async e=>{
      e.preventDefault();
      try{
        const payload={goal:document.getElementById('twg-goal').value.trim(),target_metric:document.getElementById('twg-metric').value.trim()||null,target_value:document.getElementById('twg-value').value.trim()||null};
        if(existing)await updatePlanLine(existing.id,payload);
        else await createPlanLine({plan_id:selectedPlanId,week_number:weekNum,...payload});
        document.getElementById('tw-goal-dialog').close();await load();
      }catch(err){document.getElementById('tw-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
    };
    document.getElementById('tw-goal-dialog').showModal();
  }

  await load();
}
