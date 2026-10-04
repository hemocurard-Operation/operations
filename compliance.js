import { listRisks, createRisk } from './integrated-qms-data.js';
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
export async function mountCompliance(root){
  root.innerHTML=`
    <div class="sales-toolbar"><div><h2 class="section-heading">Compliance</h2>
    <div class="muted">Riesgos, controles, evidencia y seguimiento.</div></div><button id="risk-new">Nuevo riesgo</button></div>
    <div id="risk-status"></div>
    <section class="card"><div class="status info">Cadena: Riesgo → Control → Procedimiento → Responsable → Registro → Evidencia → KPI</div></section>
    <section class="card"><div class="table-wrap"><table class="data-table">
      <thead><tr><th>Código</th><th>Dominio</th><th>Proceso</th><th>Riesgo</th><th>P</th><th>I</th><th>Nivel</th><th>Estado</th></tr></thead>
      <tbody id="risk-body"></tbody></table></div></section>
    <section class="card"><div class="status warn">El contenido jurídico y los controles penales deben ser validados por asesor legal dominicano antes de aprobación formal.</div></section>
    <dialog id="risk-dialog" class="sales-dialog"><form id="risk-form">
      <h3>Nuevo riesgo</h3>
      <label>Código<input id="risk-code" required placeholder="R-CMP-001"></label>
      <label>Dominio<select id="risk-domain"><option>COMPLIANCE</option><option>LEGAL</option><option>SGC</option><option>OPERACIONAL</option><option>BIOSEGURIDAD</option><option>TECNOLOGIA</option></select></label>
      <label>Proceso<input id="risk-process" required></label>
      <label>Descripción<textarea id="risk-desc" required></textarea></label>
      <label>Causa<textarea id="risk-cause"></textarea></label>
      <label>Consecuencia<textarea id="risk-cons"></textarea></label>
      <label>Probabilidad<input id="risk-p" type="number" min="1" max="5" value="3"></label>
      <label>Impacto<input id="risk-i" type="number" min="1" max="5" value="3"></label>
      <label>Controles existentes<textarea id="risk-controls"></textarea></label>
      <label>Acción<textarea id="risk-action"></textarea></label>
      <div class="dialog-actions"><button type="button" id="risk-cancel" class="secondary">Cancelar</button><button type="submit">Guardar</button></div>
    </form></dialog>`;
  async function load(){
    try{
      const rows=await listRisks();
      document.getElementById('risk-body').innerHTML=rows.length?rows.map(r=>`<tr>
        <td><code>${esc(r.risk_code)}</code></td><td>${esc(r.risk_domain)}</td><td>${esc(r.process_name)}</td>
        <td>${esc(r.risk_description)}</td><td>${esc(r.probability)}</td><td>${esc(r.impact)}</td>
        <td><strong>${esc(r.inherent_score)}</strong></td><td>${esc(r.status)}</td></tr>`).join(''):
        `<tr><td colspan="8" class="muted">No hay riesgos registrados.</td></tr>`;
      document.getElementById('risk-status').innerHTML='';
    }catch(e){document.getElementById('risk-status').innerHTML=`<div class="status warn">${esc(e.message)} · Instale la migración v0.22.0.</div>`}
  }
  document.getElementById('risk-new').onclick=()=>document.getElementById('risk-dialog').showModal();
  document.getElementById('risk-cancel').onclick=()=>document.getElementById('risk-dialog').close();
  document.getElementById('risk-form').onsubmit=async ev=>{
    ev.preventDefault();
    try{
      await createRisk({
        risk_code:document.getElementById('risk-code').value.trim(),
        risk_domain:document.getElementById('risk-domain').value,
        process_name:document.getElementById('risk-process').value.trim(),
        risk_description:document.getElementById('risk-desc').value.trim(),
        cause:document.getElementById('risk-cause').value.trim()||null,
        consequence:document.getElementById('risk-cons').value.trim()||null,
        probability:Number(document.getElementById('risk-p').value),
        impact:Number(document.getElementById('risk-i').value),
        existing_controls:document.getElementById('risk-controls').value.trim()||null,
        treatment_action:document.getElementById('risk-action').value.trim()||null
      });
      document.getElementById('risk-dialog').close();ev.target.reset();await load();
    }catch(e){document.getElementById('risk-status').innerHTML=`<div class="status bad">${esc(e.message)}</div>`}
  };
  await load();
}
