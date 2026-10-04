import { flowData } from './blood-flow-data.js';
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
export async function mountBloodFlow(root){
  root.innerHTML=`
    <div class="sales-toolbar">
      <div><h2 class="section-heading">Flujo Sanguíneo</h2><div class="muted">Trazabilidad operacional desde donación hasta salida.</div></div>
      <button id="flow-refresh" class="secondary">Actualizar</button>
    </div>
    <div id="flow-msg"></div>
    <div class="grid sales-kpis" id="flow-kpis"></div>
    <section class="card">
      <div class="card-head"><h3>Cola de revisión / liberación</h3><span class="muted">La decisión APTO nunca es automática.</span></div>
      <div class="table-wrap"><table class="data-table">
        <thead><tr><th>Unidad origen</th><th>Donación</th><th>Pruebas</th><th>Validadas</th><th>Reactivos</th><th>Indeterm.</th><th>Estado</th><th>Decisión</th><th></th></tr></thead>
        <tbody id="release-body"></tbody>
      </table></div>
    </section>
    <section class="card">
      <h3>Trazabilidad del flujo</h3>
      <div class="table-wrap"><table class="data-table">
        <thead><tr><th>Fecha</th><th>Donación</th><th>Unidad</th><th>Estado donación</th><th>Cola</th><th>Componentes</th><th>Disponibles</th><th>Despachados</th><th>Próx. venc.</th></tr></thead>
        <tbody id="flow-body"></tbody>
      </table></div>
    </section>
    <section class="card">
      <h3>Alertas operativas</h3>
      <div class="table-wrap"><table class="data-table">
        <thead><tr><th>Tipo</th><th>Referencia</th><th>Severidad</th><th>Alerta</th></tr></thead>
        <tbody id="alerts-body"></tbody>
      </table></div>
    </section>
    <dialog id="release-dialog" class="sales-dialog">
      <form id="release-form">
        <h3>Revisión y liberación manual</h3>
        <div class="status warn">Esta acción registra una decisión humana autorizada. No constituye una decisión automática del sistema.</div>
        <label>Unidad origen<input id="release-unit" readonly></label>
        <label>Decisión<select id="release-decision"><option>RETENER</option><option>APTO</option><option>NO_APTO</option></select></label>
        <label>Justificación<textarea id="release-rationale" required></textarea></label>
        <label>Referencia de evidencia<input id="release-evidence" placeholder="Informe, corrida, registro o URL"></label>
        <div class="dialog-actions"><button type="button" id="release-cancel" class="secondary">Cancelar</button><button>Registrar decisión</button></div>
      </form>
    </dialog>`;
  async function load(){
    try{
      const [queue,flow,alerts,funnel]=await Promise.all([flowData.queue(),flowData.flow(),flowData.alerts(),flowData.funnel()]);
      document.getElementById('release-body').innerHTML=queue.length?queue.map(r=>`<tr>
        <td><code>${esc(r.source_unit_code)}</code></td><td>${esc(r.donation_code)}</td>
        <td>${esc(r.total_tests)}</td><td>${esc(r.validated_tests)}</td><td>${esc(r.reactive_tests)}</td><td>${esc(r.indeterminate_tests)}</td>
        <td>${esc(r.queue_status)}</td><td>${esc(r.latest_release_decision||'—')}</td>
        <td><button class="secondary compact" data-release="${esc(r.source_unit_code)}">Revisar</button></td>
      </tr>`).join(''):'<tr><td colspan="9">Sin unidades en cola.</td></tr>';

      document.getElementById('flow-body').innerHTML=flow.length?flow.map(r=>`<tr>
        <td>${esc(r.donation_date)}</td><td>${esc(r.donation_code)}</td><td><code>${esc(r.source_unit_code)}</code></td>
        <td>${esc(r.donation_status)}</td><td>${esc(r.queue_status)}</td><td>${esc(r.component_count)}</td>
        <td>${esc(r.available_components)}</td><td>${esc(r.dispatched_components)}</td><td>${esc(r.nearest_expiry||'—')}</td>
      </tr>`).join(''):'<tr><td colspan="9">Sin datos.</td></tr>';

      document.getElementById('alerts-body').innerHTML=alerts.length?alerts.map(r=>`<tr>
        <td>${esc(r.alert_type)}</td><td>${esc(r.reference_code)}</td><td>${esc(r.severity)}</td><td>${esc(r.message)}</td>
      </tr>`).join(''):'<tr><td colspan="4">Sin alertas.</td></tr>';

      const t=funnel.reduce((a,x)=>({d:a.d+Number(x.donors||0),e:a.e+Number(x.effective_donations||0),s:a.s+Number(x.screened_units||0),r:a.r+Number(x.released_units||0),i:a.i+Number(x.available_units||0),o:a.o+Number(x.dispatched_units||0)}),{d:0,e:0,s:0,r:0,i:0,o:0});
      document.getElementById('flow-kpis').innerHTML=`
        <section class="card"><div class="muted">Donantes 30d</div><div class="kpi">${t.d}</div></section>
        <section class="card"><div class="muted">Tamizadas 30d</div><div class="kpi">${t.s}</div></section>
        <section class="card"><div class="muted">Liberadas 30d</div><div class="kpi">${t.r}</div></section>
        <section class="card"><div class="muted">Disponibles</div><div class="kpi">${t.i}</div></section>`;

      document.querySelectorAll('[data-release]').forEach(b=>b.onclick=()=>{
        document.getElementById('release-unit').value=b.dataset.release;
        document.getElementById('release-dialog').showModal();
      });
      document.getElementById('flow-msg').innerHTML='';
    }catch(e){
      document.getElementById('flow-msg').innerHTML=`<div class="status warn">${esc(e.message)} · Ejecute sql/24_CONTROLLED_BLOOD_FLOW_v0_24.sql.</div>`;
    }
  }
  document.getElementById('flow-refresh').onclick=load;
  document.getElementById('release-cancel').onclick=()=>document.getElementById('release-dialog').close();
  document.getElementById('release-form').onsubmit=async e=>{
    e.preventDefault();
    try{
      await flowData.releaseUnit(
        document.getElementById('release-unit').value,
        document.getElementById('release-decision').value,
        document.getElementById('release-rationale').value.trim(),
        document.getElementById('release-evidence').value.trim()||null
      );
      document.getElementById('release-dialog').close();
      e.target.reset();
      await load();
    }catch(x){document.getElementById('flow-msg').innerHTML=`<div class="status bad">${esc(x.message)}</div>`}
  };
  await load();
}
