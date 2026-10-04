import { internalAuditData } from './internal-audit-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);

export async function mountInternalAudits(root){
  const [branches,processes,profiles,criteria]=await Promise.all([
    internalAuditData.branches(),internalAuditData.processes(),internalAuditData.profiles(),internalAuditData.criteria()
  ]);
  const bm=Object.fromEntries(branches.map(x=>[x.id,x.name]));
  const pm=Object.fromEntries(processes.map(x=>[x.id,`${x.code} · ${x.name}`]));
  const um=Object.fromEntries(profiles.map(x=>[x.id,x.full_name||x.id]));

  root.innerHTML=`
  <div class="sales-toolbar"><div><h2 class="section-heading">Auditorías Internas</h2>
  <div class="muted">Programa anual, independencia, criterios, hallazgos, evidencia, NC y CAPA.</div></div>
  <div><button id="aud33-program">Nuevo programa</button> <button id="aud33-new">Nueva auditoría</button></div></div>
  <div id="aud33-msg"></div><div class="grid sales-kpis" id="aud33-kpis"></div>

  <section class="card"><h3>Programa anual</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Año</th><th>Código</th><th>Programa</th><th>Estado</th><th>Auditorías</th><th>Cerradas</th><th>Vencidas</th><th>NC</th><th>Hallazgos abiertos</th></tr></thead>
  <tbody id="aud33-programs"></tbody></table></div></section>

  <section class="card"><h3>Auditorías</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Fecha</th><th>Código</th><th>Sucursal</th><th>Proceso</th><th>Título</th><th>Estado</th><th>Hallazgos</th><th>NC</th><th>Abiertos</th></tr></thead>
  <tbody id="aud33-audits"></tbody></table></div></section>

  <section class="card"><h3>Hallazgos abiertos</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Código</th><th>Auditoría</th><th>Tipo</th><th>Severidad</th><th>Título</th><th>Vence</th><th>Edad</th><th>NC</th><th>CAPA</th></tr></thead>
  <tbody id="aud33-findings"></tbody></table></div></section>

  <section class="card"><h3>Referencias de criterios</h3>
  <div class="status info">Se muestran referencias y resúmenes configurables. El sistema no reproduce el texto íntegro de ISO 15189.</div>
  <div class="table-wrap"><table class="data-table"><thead><tr><th>Marco</th><th>Cláusula</th><th>Código</th><th>Resumen</th><th>Área</th></tr></thead>
  <tbody>${criteria.map(c=>`<tr><td>${esc(c.framework)}</td><td>${esc(c.clause_reference)}</td><td><code>${esc(c.criterion_code)}</code></td><td>${esc(c.criterion_summary)}</td><td>${esc(c.process_area||'—')}</td></tr>`).join('')}</tbody></table></div></section>

  <dialog id="aud33-program-dialog" class="sales-dialog"><form id="aud33-program-form">
  <h3>Nuevo programa anual</h3>
  <label>Código<input id="p-code" required placeholder="PAI-2027"></label>
  <label>Año<input id="p-year" type="number" min="2020" max="2100" value="${new Date().getFullYear()}" required></label>
  <label>Título<input id="p-title" required value="Programa Anual de Auditorías Internas"></label>
  <label>Objetivo<textarea id="p-objective" required></textarea></label>
  <label>Alcance<textarea id="p-scope"></textarea></label>
  <div class="dialog-actions"><button type="button" id="p-cancel" class="secondary">Cancelar</button><button>Guardar</button></div>
  </form></dialog>

  <dialog id="aud33-audit-dialog" class="sales-dialog"><form id="aud33-audit-form">
  <h3>Nueva auditoría</h3>
  <label>Código<input id="a-code" required placeholder="AUD-2027-001"></label>
  <label>Programa<select id="a-program"><option value="">Sin programa</option></select></label>
  <label>Sucursal<select id="a-branch"><option value="">General</option>${branches.map(x=>`<option value="${x.id}">${esc(x.name)}</option>`).join('')}</select></label>
  <label>Proceso<select id="a-process"><option value="">Seleccionar…</option>${processes.map(x=>`<option value="${x.id}">${esc(x.code)} · ${esc(x.name)}</option>`).join('')}</select></label>
  <label>Auditor líder<select id="a-auditor" required><option value="">Seleccionar…</option>${profiles.map(x=>`<option value="${x.id}">${esc(x.full_name||x.id)}</option>`).join('')}</select></label>
  <label>Fecha<input id="a-date" type="date" value="${today()}" required></label>
  <label>Título<input id="a-title" required></label>
  <label>Objetivo<textarea id="a-objective" required></textarea></label>
  <label>Alcance<textarea id="a-scope"></textarea></label>
  <div class="status warn">El sistema bloqueará al auditor líder si es propietario del proceso auditado.</div>
  <div class="dialog-actions"><button type="button" id="a-cancel" class="secondary">Cancelar</button><button>Guardar</button></div>
  </form></dialog>`;

  let programs=[];
  async function load(){
    try{
      const [p,a,f]=await Promise.all([internalAuditData.programs(),internalAuditData.audits(),internalAuditData.findings()]);
      programs=p;
      document.getElementById('a-program').innerHTML='<option value="">Sin programa</option>'+p.map(x=>`<option value="${x.id}">${esc(x.program_code)} · ${esc(x.title)}</option>`).join('');
      document.getElementById('aud33-programs').innerHTML=p.length?p.map(x=>`<tr><td>${esc(x.program_year)}</td><td><code>${esc(x.program_code)}</code></td><td>${esc(x.title)}</td><td>${esc(x.status)}</td><td>${esc(x.audits_total)}</td><td>${esc(x.audits_closed)}</td><td>${esc(x.audits_overdue)}</td><td>${esc(x.nc_findings)}</td><td>${esc(x.open_findings)}</td></tr>`).join(''):'<tr><td colspan="9">Sin programa.</td></tr>';
      document.getElementById('aud33-audits').innerHTML=a.length?a.map(x=>`<tr><td>${esc(x.planned_date)}</td><td><code>${esc(x.audit_code)}</code></td><td>${esc(bm[x.branch_id]||'General')}</td><td>${esc(pm[x.process_id]||'—')}</td><td>${esc(x.title)}</td><td>${esc(x.status)}</td><td>${esc(x.findings_count)}</td><td>${esc(x.nc_findings)}</td><td>${esc(x.open_findings)}</td></tr>`).join(''):'<tr><td colspan="9">Sin auditorías.</td></tr>';
      document.getElementById('aud33-findings').innerHTML=f.length?f.map(x=>`<tr><td><code>${esc(x.finding_code)}</code></td><td>${esc(x.audit_code)}</td><td>${esc(x.finding_type)}</td><td>${esc(x.severity)}</td><td>${esc(x.title)}</td><td>${esc(x.due_date||'—')}</td><td>${esc(x.age_days)} d</td><td>${x.nonconformity_id?'Sí':'No'}</td><td>${x.capa_id?'Sí':'No'}</td></tr>`).join(''):'<tr><td colspan="9">Sin hallazgos abiertos.</td></tr>';
      const overdue=f.filter(x=>x.overdue).length,nc=f.filter(x=>x.finding_type==='NO_CONFORMIDAD').length;
      document.getElementById('aud33-kpis').innerHTML=`<section class="card"><div class="muted">Programas</div><div class="kpi">${p.length}</div></section><section class="card"><div class="muted">Auditorías</div><div class="kpi">${a.length}</div></section><section class="card"><div class="muted">NC abiertas</div><div class="kpi">${nc}</div></section><section class="card"><div class="muted">Hallazgos vencidos</div><div class="kpi">${overdue}</div></section>`;
      document.getElementById('aud33-msg').innerHTML='';
    }catch(e){document.getElementById('aud33-msg').innerHTML=`<div class="status warn">${esc(e.message)} · Ejecute sql/33_INTERNAL_AUDITS_v0_33.sql.</div>`}
  }

  document.getElementById('aud33-program').onclick=()=>document.getElementById('aud33-program-dialog').showModal();
  document.getElementById('aud33-new').onclick=()=>document.getElementById('aud33-audit-dialog').showModal();
  document.getElementById('p-cancel').onclick=()=>document.getElementById('aud33-program-dialog').close();
  document.getElementById('a-cancel').onclick=()=>document.getElementById('aud33-audit-dialog').close();

  document.getElementById('aud33-program-form').onsubmit=async e=>{
    e.preventDefault();
    try{
      await internalAuditData.createProgram({
        program_code:document.getElementById('p-code').value.trim(),
        program_year:Number(document.getElementById('p-year').value),
        title:document.getElementById('p-title').value.trim(),
        objective:document.getElementById('p-objective').value.trim(),
        scope:document.getElementById('p-scope').value.trim()||null,
        status:'BORRADOR'
      });
      document.getElementById('aud33-program-dialog').close();e.target.reset();await load();
    }catch(err){document.getElementById('aud33-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
  };

  document.getElementById('aud33-audit-form').onsubmit=async e=>{
    e.preventDefault();
    try{
      const processId=document.getElementById('a-process').value||null;
      const process=processes.find(x=>x.id===processId);
      await internalAuditData.createAudit({
        audit_code:document.getElementById('a-code').value.trim(),
        program_id:document.getElementById('a-program').value||null,
        branch_id:document.getElementById('a-branch').value||null,
        process_id:processId,
        process_owner_user_id:process?.owner_user_id||null,
        audit_type:'INTERNA',
        title:document.getElementById('a-title').value.trim(),
        objective:document.getElementById('a-objective').value.trim(),
        scope:document.getElementById('a-scope').value.trim()||null,
        lead_auditor_id:document.getElementById('a-auditor').value,
        planned_date:document.getElementById('a-date').value,
        status:'PLANIFICADA'
      });
      document.getElementById('aud33-audit-dialog').close();e.target.reset();await load();
    }catch(err){document.getElementById('aud33-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
  };

  await load();
}
