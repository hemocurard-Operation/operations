import { competencyData } from './competency-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);

export async function mountCompetencies(root){
  const [profiles,branches,roles,competencies]=await Promise.all([
    competencyData.profiles(),competencyData.branches(),competencyData.roles(),competencyData.competencies()
  ]);
  const um=Object.fromEntries(profiles.map(x=>[x.id,x.full_name||x.id]));
  const bm=Object.fromEntries(branches.map(x=>[x.id,x.name]));

  root.innerHTML=`
  <div class="sales-toolbar"><div><h2 class="section-heading">Competencias y Capacitación</h2>
  <div class="muted">Puesto → competencia → evaluación → evidencia → vigencia → brecha.</div></div>
  <button id="comp-assess">Nueva evaluación</button></div>

  <div id="comp-msg"></div><div class="grid sales-kpis" id="comp-kpis"></div>

  <section class="card"><h3>Cumplimiento por persona</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Persona</th><th>Sucursal</th><th>Requeridas</th><th>Competente</th><th>Brechas</th><th>Por vencer</th><th>% Cumplimiento</th></tr></thead>
  <tbody id="comp-compliance"></tbody></table></div></section>

  <section class="card"><h3>Brechas y vigencias</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Persona</th><th>Puesto</th><th>Competencia</th><th>Nivel req.</th><th>Nivel</th><th>Resultado</th><th>Válida hasta</th><th>Estado</th></tr></thead>
  <tbody id="comp-gaps"></tbody></table></div></section>

  <section class="card"><h3>Alertas</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Persona</th><th>Sucursal</th><th>Competencia</th><th>Estado</th><th>Severidad</th><th>Mensaje</th></tr></thead>
  <tbody id="comp-alerts"></tbody></table></div></section>

  <section class="card"><h3>Capacitaciones</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Fecha</th><th>Código</th><th>Título</th><th>Proveedor</th><th>Modalidad</th><th>Horas</th><th>Estado</th></tr></thead>
  <tbody id="comp-trainings"></tbody></table></div></section>

  <dialog id="comp-assess-dialog" class="sales-dialog"><form id="comp-assess-form">
  <h3>Evaluar competencia</h3>
  <label>Código<input id="ca-code" required placeholder="EVA-2026-001"></label>
  <label>Persona<select id="ca-user" required><option value="">Seleccionar…</option>${profiles.map(x=>`<option value="${x.id}">${esc(x.full_name||x.id)}</option>`).join('')}</select></label>
  <label>Competencia<select id="ca-comp" required><option value="">Seleccionar…</option>${competencies.map(x=>`<option value="${x.id}">${esc(x.competency_code)} · ${esc(x.title)}</option>`).join('')}</select></label>
  <label>Evaluador<select id="ca-assessor" required><option value="">Seleccionar…</option>${profiles.map(x=>`<option value="${x.id}">${esc(x.full_name||x.id)}</option>`).join('')}</select></label>
  <label>Sucursal<select id="ca-branch"><option value="">General</option>${branches.map(x=>`<option value="${x.id}">${esc(x.name)}</option>`).join('')}</select></label>
  <label>Fecha<input id="ca-date" type="date" value="${today()}" required></label>
  <label>Método<input id="ca-method" required placeholder="Observación directa / prueba / revisión de registros"></label>
  <label>Nivel alcanzado<input id="ca-level" type="number" min="1" max="5"></label>
  <label>Resultado<select id="ca-result"><option>COMPETENTE</option><option>REQUIERE_SUPERVISION</option><option>NO_COMPETENTE</option></select></label>
  <label>Válida hasta<input id="ca-valid" type="date"></label>
  <label>Evidencia<input id="ca-evidence" required placeholder="Registro, acta, evaluación, certificado..."></label>
  <label>Notas<textarea id="ca-notes"></textarea></label>
  <div class="status warn">La persona evaluada no puede evaluarse a sí misma.</div>
  <div class="dialog-actions"><button type="button" id="ca-cancel" class="secondary">Cancelar</button><button>Guardar evaluación</button></div>
  </form></dialog>`;

  async function load(){
    try{
      const [c,g,a,t]=await Promise.all([
        competencyData.compliance(),competencyData.gaps(),competencyData.alerts(),competencyData.trainings()
      ]);

      document.getElementById('comp-compliance').innerHTML=c.length?c.map(x=>`<tr>
        <td>${esc(um[x.user_id]||x.user_id)}</td><td>${esc(bm[x.branch_id]||'—')}</td>
        <td>${esc(x.required_competencies)}</td><td>${esc(x.competent)}</td><td>${esc(x.gaps)}</td>
        <td>${esc(x.expiring_soon)}</td><td><strong>${esc(x.compliance_pct)}%</strong></td>
      </tr>`).join(''):'<tr><td colspan="7">Sin matriz asignada.</td></tr>';

      document.getElementById('comp-gaps').innerHTML=g.length?g.map(x=>`<tr>
        <td>${esc(um[x.user_id]||x.user_id)}</td><td>${esc(x.job_title)}</td>
        <td>${esc(x.competency_code)} · ${esc(x.competency_title)}</td>
        <td>${esc(x.required_level)}</td><td>${esc(x.level_achieved??'—')}</td>
        <td>${esc(x.result||'—')}</td><td>${esc(x.valid_until||'—')}</td><td>${esc(x.competency_status)}</td>
      </tr>`).join(''):'<tr><td colspan="8">Sin datos.</td></tr>';

      document.getElementById('comp-alerts').innerHTML=a.length?a.map(x=>`<tr>
        <td>${esc(um[x.user_id]||x.user_id)}</td><td>${esc(bm[x.branch_id]||'—')}</td>
        <td>${esc(x.competency_code)} · ${esc(x.competency_title)}</td>
        <td>${esc(x.competency_status)}</td><td>${esc(x.severity)}</td><td>${esc(x.message)}</td>
      </tr>`).join(''):'<tr><td colspan="6">Sin alertas.</td></tr>';

      document.getElementById('comp-trainings').innerHTML=t.length?t.map(x=>`<tr>
        <td>${esc(x.start_date)}</td><td><code>${esc(x.training_code)}</code></td><td>${esc(x.title)}</td>
        <td>${esc(x.provider||'—')}</td><td>${esc(x.modality||'—')}</td><td>${esc(x.duration_hours??'—')}</td><td>${esc(x.status)}</td>
      </tr>`).join(''):'<tr><td colspan="7">Sin capacitaciones.</td></tr>';

      const avg=c.length?Math.round(c.reduce((s,x)=>s+Number(x.compliance_pct||0),0)/c.length):0;
      const high=a.filter(x=>x.severity==='ALTA').length;
      document.getElementById('comp-kpis').innerHTML=`
        <section class="card"><div class="muted">Personas evaluadas</div><div class="kpi">${c.length}</div></section>
        <section class="card"><div class="muted">Cumplimiento promedio</div><div class="kpi">${avg}%</div></section>
        <section class="card"><div class="muted">Alertas altas</div><div class="kpi">${high}</div></section>
        <section class="card"><div class="muted">Capacitaciones</div><div class="kpi">${t.length}</div></section>`;
      document.getElementById('comp-msg').innerHTML='';
    }catch(e){
      document.getElementById('comp-msg').innerHTML=`<div class="status warn">${esc(e.message)} · Ejecute sql/34_COMPETENCY_TRAINING_v0_34.sql.</div>`;
    }
  }

  document.getElementById('comp-assess').onclick=()=>document.getElementById('comp-assess-dialog').showModal();
  document.getElementById('ca-cancel').onclick=()=>document.getElementById('comp-assess-dialog').close();

  document.getElementById('comp-assess-form').onsubmit=async e=>{
    e.preventDefault();
    try{
      await competencyData.createAssessment({
        assessment_code:document.getElementById('ca-code').value.trim(),
        user_id:document.getElementById('ca-user').value,
        competency_id:document.getElementById('ca-comp').value,
        assessor_user_id:document.getElementById('ca-assessor').value,
        branch_id:document.getElementById('ca-branch').value||null,
        assessment_date:document.getElementById('ca-date').value,
        method:document.getElementById('ca-method').value.trim(),
        level_achieved:document.getElementById('ca-level').value?Number(document.getElementById('ca-level').value):null,
        result:document.getElementById('ca-result').value,
        valid_until:document.getElementById('ca-valid').value||null,
        evidence_reference:document.getElementById('ca-evidence').value.trim(),
        notes:document.getElementById('ca-notes').value.trim()||null
      });
      document.getElementById('comp-assess-dialog').close();
      e.target.reset();
      await load();
    }catch(err){
      document.getElementById('comp-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`;
    }
  };

  await load();
}
