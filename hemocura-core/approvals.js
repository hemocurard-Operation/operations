import { approvalData } from './approval-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}

export async function mountApprovals(root){
  const branches=await approvalData.branches();
  const bm=Object.fromEntries(branches.map(b=>[b.id,b.name]));

  root.innerHTML=`
  <div class="sales-toolbar">
    <div>
      <h2 class="section-heading">Aprobaciones</h2>
      <div class="muted">Solicitud → revisión → aprobación/rechazo → ejecución → auditoría.</div>
    </div>
    <button id="apr-new">Nueva solicitud</button>
  </div>
  <div id="apr-msg"></div>
  <div class="grid sales-kpis" id="apr-kpis"></div>

  <section class="card">
    <h3>Bandeja</h3>
    <div class="table-wrap"><table class="data-table">
      <thead><tr><th>Código</th><th>Acción</th><th>Sucursal</th><th>Título</th><th>Solicitante</th><th>Estado</th><th>Aprob.</th><th>Edad</th><th></th></tr></thead>
      <tbody id="apr-body"></tbody>
    </table></div>
  </section>

  <section class="card">
    <h3>Historial de decisiones</h3>
    <div class="table-wrap"><table class="data-table">
      <thead><tr><th>Fecha</th><th>Solicitud</th><th>Acción</th><th>Decisión</th><th>Aprobador</th><th>Rol</th><th>Comentario</th></tr></thead>
      <tbody id="apr-history"></tbody>
    </table></div>
  </section>

  <dialog id="apr-new-dialog" class="sales-dialog">
    <form id="apr-new-form">
      <h3>Nueva solicitud</h3>
      <label>Tipo de acción
        <select id="apr-action" required>
          <option value="UNIT_RELEASE">Liberación de unidad</option>
          <option value="DAILY_CLOSE">Cierre diario</option>
          <option value="DOCUMENT_APPROVAL">Aprobación documental</option>
          <option value="CAPA_CLOSE">Cierre CAPA</option>
        </select>
      </label>
      <label>Sucursal<select id="apr-branch"><option value="">General</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
      <label>Referencia<input id="apr-reference" placeholder="Unidad, documento, CAPA..."></label>
      <label>Título<input id="apr-title" required></label>
      <label>Justificación<textarea id="apr-reason" required></textarea></label>
      <label>Payload JSON<textarea id="apr-payload" placeholder='Ej. {"source_unit_code":"U-001","decision":"APTO","rationale":"..."}'></textarea></label>
      <div class="dialog-actions"><button type="button" id="apr-new-cancel" class="secondary">Cancelar</button><button>Solicitar</button></div>
    </form>
  </dialog>

  <dialog id="apr-decision-dialog" class="sales-dialog">
    <form id="apr-decision-form">
      <h3>Decidir solicitud</h3>
      <input id="apr-id" type="hidden">
      <label>Decisión<select id="apr-decision"><option>APROBAR</option><option>RECHAZAR</option></select></label>
      <label>Comentario<textarea id="apr-comment" required></textarea></label>
      <label>Declaración de conformidad<textarea id="apr-ack" required>Confirmo que revisé la información disponible y asumo responsabilidad por esta decisión dentro de mis atribuciones.</textarea></label>
      <div class="status warn">La firma operativa registra usuario, fecha, rol y declaración. No sustituye una firma digital cualificada cuando la legislación o el procedimiento la exija.</div>
      <div class="dialog-actions"><button type="button" id="apr-decision-cancel" class="secondary">Cancelar</button><button>Registrar decisión</button></div>
    </form>
  </dialog>`;

  async function load(){
    try{
      const [rows,hist]=await Promise.all([approvalData.inbox(),approvalData.history()]);
      document.getElementById('apr-body').innerHTML=rows.length?rows.map(r=>`<tr>
        <td><code>${esc(r.request_code)}</code></td>
        <td>${esc(r.action_type)}</td>
        <td>${esc(bm[r.branch_id]||'General')}</td>
        <td>${esc(r.title)}</td>
        <td>${esc(r.requested_by_name||r.requested_by)}</td>
        <td>${esc(r.status)}</td>
        <td>${esc(r.approvals_count)}/${esc(r.required_approvals)}</td>
        <td>${esc(r.age_days)} d</td>
        <td>
          ${['PENDIENTE','EN_REVISION'].includes(r.status)?`<button class="secondary compact" data-decide="${r.id}">Decidir</button>`:''}
          ${r.status==='APROBADA'?`<button class="compact" data-execute="${r.id}">Ejecutar</button>`:''}
        </td>
      </tr>`).join(''):'<tr><td colspan="9">Sin solicitudes.</td></tr>';

      document.getElementById('apr-history').innerHTML=hist.length?hist.map(h=>`<tr>
        <td>${esc(new Date(h.decision_at).toLocaleString('es-DO'))}</td>
        <td><code>${esc(h.request_code)}</code></td>
        <td>${esc(h.action_type)}</td>
        <td>${esc(h.decision)}</td>
        <td>${esc(h.approver_name||h.approver_id)}</td>
        <td>${esc(h.approver_role||'—')}</td>
        <td>${esc(h.comment)}</td>
      </tr>`).join(''):'<tr><td colspan="7">Sin decisiones.</td></tr>';

      const pending=rows.filter(x=>['PENDIENTE','EN_REVISION'].includes(x.status)).length;
      const approved=rows.filter(x=>x.status==='APROBADA').length;
      const executed=rows.filter(x=>x.status==='EJECUTADA').length;
      const rejected=rows.filter(x=>x.status==='RECHAZADA').length;
      document.getElementById('apr-kpis').innerHTML=`
        <section class="card"><div class="muted">Pendientes</div><div class="kpi">${pending}</div></section>
        <section class="card"><div class="muted">Aprobadas</div><div class="kpi">${approved}</div></section>
        <section class="card"><div class="muted">Ejecutadas</div><div class="kpi">${executed}</div></section>
        <section class="card"><div class="muted">Rechazadas</div><div class="kpi">${rejected}</div></section>`;

      document.querySelectorAll('[data-decide]').forEach(b=>b.onclick=()=>{
        document.getElementById('apr-id').value=b.dataset.decide;
        document.getElementById('apr-decision-dialog').showModal();
      });

      document.querySelectorAll('[data-execute]').forEach(b=>b.onclick=async()=>{
        if(!confirm('¿Ejecutar la acción ya aprobada?')) return;
        try{
          await approvalData.execute(b.dataset.execute);
          document.getElementById('apr-msg').innerHTML='<div class="status ok">Acción ejecutada.</div>';
          await load();
        }catch(e){
          document.getElementById('apr-msg').innerHTML=`<div class="status bad">${esc(e.message)}</div>`;
        }
      });

      document.getElementById('apr-msg').innerHTML='';
    }catch(e){
      document.getElementById('apr-msg').innerHTML=`<div class="status warn">${esc(e.message)} · Ejecute sql/31_APPROVALS_SOD_v0_31.sql.</div>`;
    }
  }

  document.getElementById('apr-new').onclick=()=>document.getElementById('apr-new-dialog').showModal();
  document.getElementById('apr-new-cancel').onclick=()=>document.getElementById('apr-new-dialog').close();
  document.getElementById('apr-decision-cancel').onclick=()=>document.getElementById('apr-decision-dialog').close();

  document.getElementById('apr-new-form').onsubmit=async e=>{
    e.preventDefault();
    try{
      let payload={};
      const raw=document.getElementById('apr-payload').value.trim();
      if(raw) payload=JSON.parse(raw);

      await approvalData.request({
        action_type:document.getElementById('apr-action').value,
        branch_id:document.getElementById('apr-branch').value||null,
        entity_type:document.getElementById('apr-action').value,
        entity_reference:document.getElementById('apr-reference').value.trim()||null,
        title:document.getElementById('apr-title').value.trim(),
        reason:document.getElementById('apr-reason').value.trim(),
        payload
      });

      document.getElementById('apr-new-dialog').close();
      e.target.reset();
      await load();
    }catch(err){
      document.getElementById('apr-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`;
    }
  };

  document.getElementById('apr-decision-form').onsubmit=async e=>{
    e.preventDefault();
    try{
      await approvalData.decide(
        document.getElementById('apr-id').value,
        document.getElementById('apr-decision').value,
        document.getElementById('apr-comment').value.trim(),
        document.getElementById('apr-ack').value.trim()
      );
      document.getElementById('apr-decision-dialog').close();
      e.target.reset();
      await load();
    }catch(err){
      document.getElementById('apr-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`;
    }
  };

  await load();
}
