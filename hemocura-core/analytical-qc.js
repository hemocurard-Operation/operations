import { analyticalQcData } from './analytical-qc-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}

export async function mountAnalyticalQc(root){
  const [branches,equipment]=await Promise.all([analyticalQcData.branches(),analyticalQcData.equipment()]);
  const bm=Object.fromEntries(branches.map(x=>[x.id,x.name]));
  const em=Object.fromEntries(equipment.map(x=>[x.id,x.equipment_code]));

  root.innerHTML=`
  <div class="sales-toolbar"><div><h2 class="section-heading">Control de Calidad Analítico</h2>
  <div class="muted">Métodos, IQC, desviaciones y EQA/PT con trazabilidad.</div></div>
  <button id="aqc-method-new">Nuevo método</button></div>
  <div id="aqc-msg"></div><div class="grid sales-kpis" id="aqc-kpis"></div>

  <section class="card"><h3>Métodos</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Código</th><th>Prueba</th><th>Disciplina</th><th>Sucursal</th><th>Equipo</th><th>Estado</th><th>Revisión</th></tr></thead>
  <tbody id="aqc-methods"></tbody></table></div></section>

  <section class="card"><h3>Alertas IQC</h3><div class="status info">
  La clasificación automática solo identifica controles fuera de límites configurados. La investigación y disposición siguen siendo humanas.</div>
  <div class="table-wrap"><table class="data-table">
  <thead><tr><th>Fecha</th><th>Método</th><th>Control</th><th>Valor</th><th>Estado</th><th>Bandera</th><th>Severidad</th></tr></thead>
  <tbody id="aqc-iqc"></tbody></table></div></section>

  <section class="card"><h3>Desviaciones QC</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Código</th><th>Fecha</th><th>Severidad</th><th>Descripción</th><th>Estado</th><th>Vence</th><th>NC</th><th>CAPA</th></tr></thead>
  <tbody id="aqc-dev"></tbody></table></div></section>

  <section class="card"><h3>EQA / PT</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Evento</th><th>Programa</th><th>Sucursal</th><th>Ciclo</th><th>Vence</th><th>Resultado</th><th>Estado</th></tr></thead>
  <tbody id="aqc-eqa"></tbody></table></div></section>

  <section class="card"><h3>Alertas EQA/PT</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Evento</th><th>Proveedor</th><th>Programa</th><th>Vence</th><th>Resultado</th><th>Severidad</th><th>Mensaje</th></tr></thead>
  <tbody id="aqc-eqa-alerts"></tbody></table></div></section>

  <dialog id="aqc-method-dialog" class="sales-dialog"><form id="aqc-method-form">
  <h3>Registrar método</h3>
  <label>Código<input id="am-code" required placeholder="M-001"></label>
  <label>Prueba<input id="am-test" required></label>
  <label>Disciplina<input id="am-disc"></label>
  <label>Principio<textarea id="am-principle"></textarea></label>
  <label>Sucursal<select id="am-branch"><option value="">General</option>${branches.map(x=>`<option value="${x.id}">${esc(x.name)}</option>`).join('')}</select></label>
  <label>Equipo<select id="am-equipment"><option value="">Sin asignar</option>${equipment.map(x=>`<option value="${x.id}">${esc(x.equipment_code)} · ${esc(x.equipment_type)}</option>`).join('')}</select></label>
  <label>Código reactivo<input id="am-reagent"></label>
  <label>Estado<select id="am-status"><option>EN_VERIFICACION</option><option>APROBADO</option><option>SUSPENDIDO</option></select></label>
  <label>Próxima revisión<input id="am-review" type="date"></label>
  <div class="dialog-actions"><button type="button" id="am-cancel" class="secondary">Cancelar</button><button>Guardar</button></div>
  </form></dialog>`;

  async function load(){
    try{
      const [methods,iqc,eqaAlerts,dev,eqa,sum]=await Promise.all([
        analyticalQcData.methods(),analyticalQcData.iqcAlerts(),
        analyticalQcData.eqaAlerts(),analyticalQcData.deviations(),
        analyticalQcData.eqaEvents(),analyticalQcData.summary()
      ]);

      const mm=Object.fromEntries(methods.map(x=>[x.id,`${x.method_code} · ${x.test_name}`]));

      document.getElementById('aqc-methods').innerHTML=methods.length?methods.map(x=>`<tr>
        <td><code>${esc(x.method_code)}</code></td><td>${esc(x.test_name)}</td><td>${esc(x.discipline||'—')}</td>
        <td>${esc(bm[x.branch_id]||'General')}</td><td>${esc(em[x.equipment_id]||'—')}</td>
        <td>${esc(x.status)}</td><td>${esc(x.review_date||'—')}</td>
      </tr>`).join(''):'<tr><td colspan="7">Sin métodos.</td></tr>';

      document.getElementById('aqc-iqc').innerHTML=iqc.length?iqc.map(x=>`<tr>
        <td>${esc(new Date(x.run_time).toLocaleString('es-DO'))}</td>
        <td>${esc(x.method_code)} · ${esc(x.test_name)}</td><td>${esc(x.control_name)} ${esc(x.control_level||'')}</td>
        <td>${esc(x.value)}</td><td>${esc(x.result_status)}</td>
        <td>${esc((x.rule_flags||[]).join(', ')||'—')}</td><td>${esc(x.severity)}</td>
      </tr>`).join(''):'<tr><td colspan="7">Sin alertas IQC.</td></tr>';

      document.getElementById('aqc-dev').innerHTML=dev.length?dev.map(x=>`<tr>
        <td><code>${esc(x.deviation_code)}</code></td><td>${esc(new Date(x.opened_at).toLocaleDateString('es-DO'))}</td>
        <td>${esc(x.severity)}</td><td>${esc(x.description)}</td><td>${esc(x.status)}</td><td>${esc(x.due_date||'—')}</td>
        <td>${x.nonconformity_id?'Sí':'No'}</td><td>${x.capa_id?'Sí':'No'}</td>
      </tr>`).join(''):'<tr><td colspan="8">Sin desviaciones.</td></tr>';

      document.getElementById('aqc-eqa').innerHTML=eqa.length?eqa.map(x=>`<tr>
        <td><code>${esc(x.event_code)}</code></td><td>${esc(x.program_id)}</td><td>${esc(bm[x.branch_id]||'General')}</td>
        <td>${esc(x.cycle||'—')}</td><td>${esc(x.due_date||'—')}</td><td>${esc(x.result||'PENDIENTE')}</td><td>${esc(x.status)}</td>
      </tr>`).join(''):'<tr><td colspan="7">Sin eventos EQA/PT.</td></tr>';

      document.getElementById('aqc-eqa-alerts').innerHTML=eqaAlerts.length?eqaAlerts.map(x=>`<tr>
        <td><code>${esc(x.event_code)}</code></td><td>${esc(x.provider)}</td><td>${esc(x.program_name)}</td>
        <td>${esc(x.due_date||'—')}</td><td>${esc(x.result||'—')}</td><td>${esc(x.severity)}</td><td>${esc(x.message)}</td>
      </tr>`).join(''):'<tr><td colspan="7">Sin alertas EQA/PT.</td></tr>';

      document.getElementById('aqc-kpis').innerHTML=`
        <section class="card"><div class="muted">Métodos aprobados</div><div class="kpi">${sum.approved_methods}</div></section>
        <section class="card"><div class="muted">Verificaciones abiertas</div><div class="kpi">${sum.open_verifications}</div></section>
        <section class="card"><div class="muted">IQC fuera control 30d</div><div class="kpi">${sum.iqc_out_of_control_30d}</div></section>
        <section class="card"><div class="muted">EQA no satisfactorio 12m</div><div class="kpi">${sum.eqa_unsatisfactory_12m}</div></section>`;
      document.getElementById('aqc-msg').innerHTML='';
    }catch(e){
      document.getElementById('aqc-msg').innerHTML=`<div class="status warn">${esc(e.message)} · Ejecute sql/36_ANALYTICAL_QC_v0_36.sql.</div>`;
    }
  }

  document.getElementById('aqc-method-new').onclick=()=>document.getElementById('aqc-method-dialog').showModal();
  document.getElementById('am-cancel').onclick=()=>document.getElementById('aqc-method-dialog').close();
  document.getElementById('aqc-method-form').onsubmit=async e=>{
    e.preventDefault();
    try{
      await analyticalQcData.createMethod({
        method_code:document.getElementById('am-code').value.trim(),
        test_name:document.getElementById('am-test').value.trim(),
        discipline:document.getElementById('am-disc').value.trim()||null,
        principle:document.getElementById('am-principle').value.trim()||null,
        branch_id:document.getElementById('am-branch').value||null,
        equipment_id:document.getElementById('am-equipment').value||null,
        reagent_code:document.getElementById('am-reagent').value.trim()||null,
        status:document.getElementById('am-status').value,
        review_date:document.getElementById('am-review').value||null
      });
      document.getElementById('aqc-method-dialog').close();e.target.reset();await load();
    }catch(err){
      document.getElementById('aqc-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`;
    }
  };

  await load();
}
