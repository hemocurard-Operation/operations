import { qmsGovernanceData } from './qms-governance-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}

export async function mountQmsGovernance(root){
  root.innerHTML=`
  <div class="sales-toolbar">
    <div><h2 class="section-heading">Gobierno QMS</h2>
    <div class="muted">Control documental, CAPA, aprobaciones y vencimientos.</div></div>
    <button id="qmsg-refresh" class="secondary">Actualizar</button>
  </div>
  <div id="qmsg-msg"></div>
  <div class="grid sales-kpis" id="qmsg-kpis"></div>

  <section class="card">
    <h3>Control documental</h3>
    <div class="table-wrap"><table class="data-table">
    <thead><tr><th>Código</th><th>Título</th><th>Versión</th><th>Estado</th><th>Revisión</th><th>Vence revisión</th><th>Aprobación</th><th></th></tr></thead>
    <tbody id="qmsg-docs"></tbody></table></div>
  </section>

  <section class="card">
    <h3>CAPA</h3>
    <div class="table-wrap"><table class="data-table">
    <thead><tr><th>Código</th><th>Problema</th><th>Estado</th><th>Efectividad</th><th>Vence</th><th>Vencida</th><th>Aprobación</th><th></th></tr></thead>
    <tbody id="qmsg-capa"></tbody></table></div>
  </section>

  <dialog id="qmsg-dialog" class="sales-dialog">
    <form id="qmsg-form">
      <h3 id="qmsg-title">Solicitar aprobación</h3>
      <input id="qmsg-id" type="hidden">
      <input id="qmsg-type" type="hidden">
      <label>Justificación<textarea id="qmsg-reason" required></textarea></label>
      <div class="dialog-actions"><button type="button" id="qmsg-cancel" class="secondary">Cancelar</button><button>Enviar solicitud</button></div>
    </form>
  </dialog>`;

  async function load(){
    try{
      const [docs,capas,sum]=await Promise.all([
        qmsGovernanceData.documents(),
        qmsGovernanceData.capas(),
        qmsGovernanceData.summary()
      ]);

      document.getElementById('qmsg-docs').innerHTML=docs.length?docs.map(d=>`<tr>
        <td><code>${esc(d.document_code)}</code></td>
        <td>${esc(d.title)}</td>
        <td>${esc(d.version)}</td>
        <td>${esc(d.status)}</td>
        <td>${esc(d.review_status||'—')}</td>
        <td>${esc(d.review_date||'—')}${d.review_overdue?' · VENCIDA':''}</td>
        <td>${esc(d.approval_status||'—')}</td>
        <td>${['BORRADOR','EN_REVISION','APROBADO'].includes(d.status) && !['PENDIENTE','EN_REVISION','APROBADA'].includes(d.approval_status)
          ? `<button class="secondary compact" data-doc="${d.id}">Solicitar aprobación</button>`:''}</td>
      </tr>`).join(''):'<tr><td colspan="8">Sin documentos.</td></tr>';

      document.getElementById('qmsg-capa').innerHTML=capas.length?capas.map(c=>`<tr>
        <td><code>${esc(c.code)}</code></td>
        <td>${esc(c.problem)}</td>
        <td>${esc(c.status)}</td>
        <td>${esc(c.effectiveness_status)}</td>
        <td>${esc(c.due_date||'—')}</td>
        <td>${c.overdue?'Sí':'No'}</td>
        <td>${esc(c.approval_status||'—')}</td>
        <td>${!['CERRADA','CANCELADA'].includes(c.status) && ['EFECTIVA','VERIFICADA'].includes(c.effectiveness_status) && !['PENDIENTE','EN_REVISION','APROBADA'].includes(c.approval_status)
          ? `<button class="secondary compact" data-capa="${c.id}">Solicitar cierre</button>`:''}</td>
      </tr>`).join(''):'<tr><td colspan="8">Sin CAPA.</td></tr>';

      document.getElementById('qmsg-kpis').innerHTML=`
        <section class="card"><div class="muted">Docs en revisión</div><div class="kpi">${sum.documents_in_review}</div></section>
        <section class="card"><div class="muted">Revisiones vencidas</div><div class="kpi">${sum.overdue_document_reviews}</div></section>
        <section class="card"><div class="muted">CAPA abiertas</div><div class="kpi">${sum.open_capa}</div></section>
        <section class="card"><div class="muted">CAPA vencidas</div><div class="kpi">${sum.overdue_capa}</div></section>`;

      document.querySelectorAll('[data-doc]').forEach(b=>b.onclick=()=>{
        document.getElementById('qmsg-id').value=b.dataset.doc;
        document.getElementById('qmsg-type').value='DOCUMENT';
        document.getElementById('qmsg-title').textContent='Solicitar aprobación documental';
        document.getElementById('qmsg-dialog').showModal();
      });

      document.querySelectorAll('[data-capa]').forEach(b=>b.onclick=()=>{
        document.getElementById('qmsg-id').value=b.dataset.capa;
        document.getElementById('qmsg-type').value='CAPA';
        document.getElementById('qmsg-title').textContent='Solicitar cierre CAPA';
        document.getElementById('qmsg-dialog').showModal();
      });

      document.getElementById('qmsg-msg').innerHTML='';
    }catch(e){
      document.getElementById('qmsg-msg').innerHTML=`<div class="status warn">${esc(e.message)} · Ejecute sql/32_QMS_APPROVAL_INTEGRATION_v0_32.sql.</div>`;
    }
  }

  document.getElementById('qmsg-refresh').onclick=load;
  document.getElementById('qmsg-cancel').onclick=()=>document.getElementById('qmsg-dialog').close();

  document.getElementById('qmsg-form').onsubmit=async e=>{
    e.preventDefault();
    const id=document.getElementById('qmsg-id').value;
    const type=document.getElementById('qmsg-type').value;
    const reason=document.getElementById('qmsg-reason').value.trim();

    try{
      if(type==='DOCUMENT') await qmsGovernanceData.requestDocumentApproval(id,reason);
      else await qmsGovernanceData.requestCapaClose(id,reason);

      document.getElementById('qmsg-dialog').close();
      e.target.reset();
      await load();
    }catch(err){
      document.getElementById('qmsg-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`;
    }
  };

  await load();
}
