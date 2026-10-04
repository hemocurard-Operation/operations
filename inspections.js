import { getBranches } from './sales-data.js';
import { listInspections, createInspection } from './integrated-qms-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);

export async function mountInspections(root){
  const branches=await getBranches();
  root.innerHTML=`
    <div class="sales-toolbar"><div><h2 class="section-heading">Inspecciones de Sucursal</h2>
    <div class="muted">Inspección → hallazgo → seguimiento SGC.</div></div><button id="insp-new">Nueva inspección</button></div>
    <div id="insp-status"></div>
    <section class="card"><div class="table-wrap"><table class="data-table">
      <thead><tr><th>Fecha</th><th>Código</th><th>Sucursal</th><th>Tipo</th><th>Cumplimiento</th><th>NC</th><th>Estado</th></tr></thead>
      <tbody id="insp-body"></tbody></table></div></section>
    <dialog id="insp-dialog" class="sales-dialog"><form id="insp-form">
      <h3>Nueva inspección</h3>
      <label>Código<input id="insp-code" required placeholder="INS-2026-001"></label>
      <label>Fecha<input id="insp-date" type="date" value="${today()}" required></label>
      <label>Sucursal<select id="insp-branch" required><option value="">Seleccionar…</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
      <label>Tipo<select id="insp-type"><option>RUTINA</option><option>SEGUIMIENTO</option><option>APERTURA</option><option>EXTRAORDINARIA</option></select></label>
      <label>Responsable en sitio<input id="insp-responsible"></label>
      <h4>Primer criterio / hallazgo</h4>
      <label>Sección<input id="insp-section" value="Infraestructura e Instalaciones"></label>
      <label>Criterio<input id="insp-criterion" required></label>
      <label>Resultado<select id="insp-result"><option value="C">Cumple</option><option value="NC">No cumple</option><option value="NA">No aplica</option></select></label>
      <label>Observación<textarea id="insp-observation"></textarea></label>
      <div class="dialog-actions"><button type="button" id="insp-cancel" class="secondary">Cancelar</button><button type="submit">Guardar</button></div>
    </form></dialog>`;

  const branchMap=Object.fromEntries(branches.map(b=>[b.id,b.name]));
  async function load(){
    try{
      const rows=await listInspections();
      document.getElementById('insp-body').innerHTML=rows.length?rows.map(r=>`<tr>
        <td>${esc(r.inspection_date)}</td><td><code>${esc(r.inspection_code)}</code></td>
        <td>${esc(branchMap[r.branch_id]||r.branch_id)}</td><td>${esc(r.inspection_type)}</td>
        <td>${r.compliance_pct==null?'—':esc(r.compliance_pct)+'%'}</td><td>${esc(r.nc_findings||0)}</td><td>${esc(r.status)}</td>
      </tr>`).join(''):`<tr><td colspan="7" class="muted">No hay inspecciones registradas.</td></tr>`;
      document.getElementById('insp-status').innerHTML='';
    }catch(e){document.getElementById('insp-status').innerHTML=`<div class="status warn">${esc(e.message)} · Ejecute la migración v0.22.0 si falta.</div>`}
  }
  document.getElementById('insp-new').onclick=()=>document.getElementById('insp-dialog').showModal();
  document.getElementById('insp-cancel').onclick=()=>document.getElementById('insp-dialog').close();
  document.getElementById('insp-form').onsubmit=async(ev)=>{
    ev.preventDefault();
    const result=document.getElementById('insp-result').value;
    try{
      await createInspection({
        inspection_code:document.getElementById('insp-code').value.trim(),
        inspection_date:document.getElementById('insp-date').value,
        branch_id:document.getElementById('insp-branch').value,
        inspection_type:document.getElementById('insp-type').value,
        site_responsible:document.getElementById('insp-responsible').value.trim()||null,
        status:'FINALIZADA',
        compliant_count:result==='C'?1:0,
        nonconforming_count:result==='NC'?1:0,
        not_applicable_count:result==='NA'?1:0,
        compliance_pct:result==='C'?100:(result==='NC'?0:null),
        overall_rating:result==='NC'?'CON_OBSERVACIONES':'SATISFACTORIO'
      },[{
        section_name:document.getElementById('insp-section').value.trim(),
        criterion_no:'1',
        criterion:document.getElementById('insp-criterion').value.trim(),
        result,
        observation:document.getElementById('insp-observation').value.trim()||null,
        severity:result==='NC'?3:null
      }]);
      document.getElementById('insp-dialog').close(); ev.target.reset(); await load();
    }catch(e){document.getElementById('insp-status').innerHTML=`<div class="status bad">${esc(e.message)}</div>`}
  };
  await load();
}
