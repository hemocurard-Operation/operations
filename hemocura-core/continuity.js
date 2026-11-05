import {continuityData} from './continuity-data.js';
const e=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const today=()=>new Date().toISOString().slice(0,10);
const statusBadge=(s)=>{const m={ACTIVO:'ok',BORRADOR:'info',EN_REVISION:'warn',RETIRADO:'bad'};return `<span class="status ${m[s]||'info'}">${e(s)}</span>`};
const resultBadge=(r)=>{const m={EXITOSA:'ok',PARCIAL:'warn',FALLIDA:'bad'};return `<span class="status ${m[r]||'info'}">${e(r)}</span>`};

export async function mountContinuity(root){
  let filterStatus='';
  root.innerHTML=`<div class="sales-toolbar"><div><h2 class="section-heading">Continuidad e Integridad</h2><div class="muted">Planes, pruebas y controles de integridad de datos.</div></div>
  <div class="dialog-actions"><button id="ct-new-test" class="secondary">Registrar prueba</button><button id="ct-new-plan">Nuevo plan</button></div></div>
  <div id="ct-msg"></div><div class="grid sales-kpis" id="ct-kpis"></div>

  <section class="card"><h3>Planes</h3>
  <div class="filter-grid" style="margin-bottom:.75rem"><label>Estado <select id="ct-filter-status"><option value="">Todos</option><option>BORRADOR</option><option>ACTIVO</option><option>EN_REVISION</option><option>RETIRADO</option></select></label></div>
  <div class="table-wrap"><table class="data-table"><thead><tr><th>Código</th><th>Escenario</th><th>Estado</th><th>RTO/RPO</th><th>Revisión</th></tr></thead><tbody id="ct-plans"></tbody></table></div></section>

  <section class="card"><h3>Pruebas</h3><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Tipo</th><th>Resultado</th><th>Hallazgos</th></tr></thead><tbody id="ct-tests"></tbody></table></div></section>

  <section class="card"><h3>Integridad de datos</h3><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Código</th><th>Subsistema</th><th>Tipo</th><th>Resultado</th><th>Detalle</th></tr></thead><tbody id="ct-checks"></tbody></table></div></section>

  <dialog id="ct-plan-dialog" class="sales-dialog"><form id="ct-plan-form"><h3>Nuevo plan de continuidad</h3>
  <label>Código<input id="cp-code" required placeholder="BCP-2026-001"></label>
  <label>Escenario<input id="cp-scenario" required placeholder="Pérdida de energía, fallo de red…"></label>
  <label>Estado<select id="cp-status"><option>BORRADOR</option><option>ACTIVO</option><option>EN_REVISION</option><option>RETIRADO</option></select></label>
  <label>Objetivo de recuperación (RTO/RPO)<input id="cp-rto" placeholder="RTO 4h / RPO 1h"></label>
  <label>Fecha de revisión<input id="cp-review" type="date"></label>
  <div class="dialog-actions"><button type="button" id="cp-cancel" class="secondary">Cancelar</button><button>Guardar</button></div></form></dialog>

  <dialog id="ct-test-dialog" class="sales-dialog"><form id="ct-test-form"><h3>Registrar prueba</h3>
  <label>Fecha<input id="tt-date" type="date" value="${today()}" required></label>
  <label>Tipo<select id="tt-type" required><option>TABLETOP</option><option>FUNCIONAL</option><option>COMPLETA</option></select></label>
  <label>Resultado<select id="tt-result" required><option>EXITOSA</option><option>PARCIAL</option><option>FALLIDA</option></select></label>
  <label>Hallazgos<textarea id="tt-findings" rows="3"></textarea></label>
  <div class="dialog-actions"><button type="button" id="tt-cancel" class="secondary">Cancelar</button><button>Guardar</button></div></form></dialog>`;

  async function load(){
    try{
      const[p,t,c,s]=await Promise.all([continuityData.plans(),continuityData.tests(),continuityData.checks(),continuityData.summary()]);
      const filtered=filterStatus?p.filter(x=>x.status===filterStatus):p;
      document.getElementById('ct-plans').innerHTML=filtered.map(x=>`<tr><td><code>${e(x.plan_code)}</code></td><td>${e(x.scenario)}</td><td>${statusBadge(x.status)}</td><td>${e(x.recovery_objective||'—')}</td><td>${e(x.review_date||'—')}</td></tr>`).join('')||'<tr><td colspan="5">Sin planes.</td></tr>';
      document.getElementById('ct-tests').innerHTML=t.map(x=>`<tr><td>${e(x.test_date)}</td><td>${e(x.test_type)}</td><td>${resultBadge(x.result)}</td><td>${e(x.findings||'—')}</td></tr>`).join('')||'<tr><td colspan="4">Sin pruebas.</td></tr>';
      document.getElementById('ct-checks').innerHTML=c.map(x=>`<tr><td>${e(new Date(x.check_date).toLocaleString('es-DO'))}</td><td><code>${e(x.check_code)}</code></td><td>${e(x.subsystem)}</td><td>${e(x.check_type)}</td><td>${resultBadge(x.result)}</td><td>${e(x.detail||'—')}</td></tr>`).join('')||'<tr><td colspan="6">Sin controles.</td></tr>';
      document.getElementById('ct-kpis').innerHTML=Object.entries(s||{}).map(([k,v])=>`<section class="card"><div class="muted">${e(k)}</div><div class="kpi">${e(v)}</div></section>`).join('');
      document.getElementById('ct-msg').innerHTML='';
    }catch(err){document.getElementById('ct-msg').innerHTML=`<div class="status warn">${e(err.message)}</div>`}
  }

  document.getElementById('ct-filter-status').onchange=ev=>{filterStatus=ev.target.value;load()};
  document.getElementById('ct-new-plan').onclick=()=>document.getElementById('ct-plan-dialog').showModal();
  document.getElementById('cp-cancel').onclick=()=>document.getElementById('ct-plan-dialog').close();
  document.getElementById('ct-plan-form').onsubmit=async ev=>{ev.preventDefault();try{await continuityData.createPlan({plan_code:v('cp-code'),scenario:v('cp-scenario'),status:v('cp-status'),recovery_objective:v('cp-rto')||null,review_date:v('cp-review')||null});document.getElementById('ct-plan-dialog').close();ev.target.reset();await load()}catch(err){document.getElementById('ct-msg').innerHTML=`<div class="status bad">${e(err.message)}</div>`}};

  document.getElementById('ct-new-test').onclick=()=>document.getElementById('ct-test-dialog').showModal();
  document.getElementById('tt-cancel').onclick=()=>document.getElementById('ct-test-dialog').close();
  document.getElementById('ct-test-form').onsubmit=async ev=>{ev.preventDefault();try{await continuityData.createTest({test_date:v('tt-date'),test_type:v('tt-type'),result:v('tt-result'),findings:v('tt-findings')||null});document.getElementById('ct-test-dialog').close();ev.target.reset();await load()}catch(err){document.getElementById('ct-msg').innerHTML=`<div class="status bad">${e(err.message)}</div>`}};

  function v(id){return document.getElementById(id).value.trim()}
  await load();
}
