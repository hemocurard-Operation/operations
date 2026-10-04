import { bloodData } from './blood-operations-data.js';
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);

export async function mountDonors(root){
 const branches=await bloodData.branches(); const bm=Object.fromEntries(branches.map(b=>[b.id,b.name]));
 root.innerHTML=`<div class="sales-toolbar"><div><h2 class="section-heading">Donantes</h2><div class="muted">Control de donantes y origen del inventario sanguíneo.</div></div><button id="don-new">Nuevo donante</button></div>
 <div id="don-msg"></div><div class="grid sales-kpis" id="don-kpis"></div>
 <section class="card"><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Código</th><th>Sucursal</th><th>Tipo</th><th>ABO</th><th>Rh</th><th>Estado</th><th>Donación</th></tr></thead><tbody id="don-body"></tbody></table></div></section>
 <dialog id="don-dialog" class="sales-dialog"><form id="don-form"><h3>Registro de donante</h3>
 <label>Código<input id="don-code" required placeholder="DON-2026-001"></label><label>Fecha<input id="don-date" type="date" value="${today()}" required></label>
 <label>Sucursal<select id="don-branch" required><option value="">Seleccionar…</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
 <label>Tipo<select id="don-type"><option>VOLUNTARIO</option><option>REPOSICION</option><option>DIRIGIDO</option></select></label>
 <div class="filter-grid"><label>ABO<select id="don-abo"><option value=""></option><option>A</option><option>B</option><option>AB</option><option>O</option></select></label>
 <label>Rh<select id="don-rh"><option value=""></option><option>POSITIVO</option><option>NEGATIVO</option></select></label></div>
 <label>Estado<select id="don-status"><option>ACEPTADO</option><option>DIFERIDO</option></select></label>
 <label>Motivo diferimiento<input id="don-reason"></label><label><input id="don-effective" type="checkbox"> Donación efectiva</label>
 <label>Observaciones<textarea id="don-notes"></textarea></label>
 <div class="dialog-actions"><button type="button" id="don-cancel" class="secondary">Cancelar</button><button>Guardar</button></div></form></dialog>`;
 async function load(){try{const [rows,sum]=await Promise.all([bloodData.donors(),bloodData.donorSummary()]);document.getElementById('don-body').innerHTML=rows.length?rows.map(r=>`<tr><td>${esc(r.registration_date)}</td><td><code>${esc(r.donor_code)}</code></td><td>${esc(bm[r.branch_id]||r.branch_id)}</td><td>${esc(r.donor_type)}</td><td>${esc(r.abo||'—')}</td><td>${esc(r.rh||'—')}</td><td>${esc(r.status)}</td><td>${r.effective_donation?'Sí':'No'}</td></tr>`).join(''):'<tr><td colspan="8">Sin donantes.</td></tr>';
 const total=sum.reduce((a,x)=>a+Number(x.total_donors||0),0), eff=sum.reduce((a,x)=>a+Number(x.effective_donations||0),0), def=sum.reduce((a,x)=>a+Number(x.deferred_donors||0),0);
 document.getElementById('don-kpis').innerHTML=`<section class="card"><div class="muted">Donantes</div><div class="kpi">${total}</div></section><section class="card"><div class="muted">Efectivos</div><div class="kpi">${eff}</div></section><section class="card"><div class="muted">Diferidos</div><div class="kpi">${def}</div></section>`;
 }catch(e){document.getElementById('don-msg').innerHTML=`<div class="status warn">${esc(e.message)} · Instale SQL v0.23.0.</div>`}}
 document.getElementById('don-new').onclick=()=>document.getElementById('don-dialog').showModal();document.getElementById('don-cancel').onclick=()=>document.getElementById('don-dialog').close();
 document.getElementById('don-form').onsubmit=async e=>{e.preventDefault();try{await bloodData.createDonor({donor_code:donCode(),branch_id:val('don-branch'),donor_type:val('don-type'),abo:val('don-abo')||null,rh:val('don-rh')||null,status:val('don-status'),deferral_reason:val('don-reason')||null,effective_donation:document.getElementById('don-effective').checked,observations:val('don-notes')||null,registration_date:val('don-date')});document.getElementById('don-dialog').close();e.target.reset();await load()}catch(x){document.getElementById('don-msg').innerHTML=`<div class="status bad">${esc(x.message)}</div>`}};
 function val(id){return document.getElementById(id).value.trim()} function donCode(){return val('don-code')} await load();
}
