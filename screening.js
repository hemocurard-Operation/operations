import { bloodData } from './blood-operations-data.js';
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);

export async function mountScreening(root){
 const branches=await bloodData.branches(); const bm=Object.fromEntries(branches.map(b=>[b.id,b.name]));
 root.innerHTML=`<div class="sales-toolbar"><div><h2 class="section-heading">Tamizaje</h2><div class="muted">Registro y reporte por unidad, prueba, reactivo y lote.</div></div><button id="scr-new">Nuevo tamizaje</button></div>
 <div id="scr-msg"></div><section class="card"><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Unidad</th><th>Sucursal</th><th>Prueba</th><th>Resultado</th><th>Reactivo</th><th>Lote</th><th>Responsable</th><th>Estado</th></tr></thead><tbody id="scr-body"></tbody></table></div></section>
 <section class="card"><h3>Reporte de tamizaje</h3><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Sucursal</th><th>Prueba</th><th>Total</th><th>No reactivo</th><th>Reactivo</th><th>Indeterminado</th><th>% reactivo</th></tr></thead><tbody id="scr-report"></tbody></table></div></section>
 <dialog id="scr-dialog" class="sales-dialog"><form id="scr-form"><h3>Formulario de tamizaje</h3>
 <label>Código registro<input id="scr-code" required placeholder="TAM-2026-001"></label><label>Fecha<input id="scr-date" type="date" value="${today()}" required></label>
 <label>Sucursal<select id="scr-branch" required><option value="">Seleccionar…</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
 <label>Código de unidad<input id="scr-unit" required placeholder="U-2026-00123"></label><label>Tipo de prueba<input id="scr-test" required placeholder="HBsAg, VIH, HCV..."></label>
 <label>Resultado<select id="scr-result"><option>NO_REACTIVO</option><option>REACTIVO</option><option>INDETERMINADO</option></select></label>
 <div class="filter-grid"><label>Reactivo<input id="scr-reagent"></label><label>Lote<input id="scr-lot"></label></div><label>Vencimiento reactivo<input id="scr-expiry" type="date"></label>
 <label>Responsable<input id="scr-resp"></label><label>Estado<select id="scr-status"><option>PENDIENTE</option><option>VALIDADO</option><option>REPETIR</option><option>CERRADO</option></select></label>
 <label>Observaciones<textarea id="scr-notes"></textarea></label><div class="dialog-actions"><button type="button" id="scr-cancel" class="secondary">Cancelar</button><button>Guardar</button></div></form></dialog>`;
 async function load(){try{const [rows,rep]=await Promise.all([bloodData.screenings(),bloodData.screeningSummary()]);document.getElementById('scr-body').innerHTML=rows.length?rows.map(r=>`<tr><td>${esc(r.screening_date)}</td><td><code>${esc(r.source_unit_code)}</code></td><td>${esc(bm[r.branch_id]||r.branch_id)}</td><td>${esc(r.test_type)}</td><td>${esc(r.result)}</td><td>${esc(r.reagent||'—')}</td><td>${esc(r.reagent_lot||'—')}</td><td>${esc(r.responsible||'—')}</td><td>${esc(r.status)}</td></tr>`).join(''):'<tr><td colspan="9">Sin registros.</td></tr>';
 document.getElementById('scr-report').innerHTML=rep.length?rep.map(r=>`<tr><td>${esc(r.screening_date)}</td><td>${esc(bm[r.branch_id]||r.branch_id)}</td><td>${esc(r.test_type)}</td><td>${esc(r.total_tests)}</td><td>${esc(r.non_reactive)}</td><td>${esc(r.reactive)}</td><td>${esc(r.indeterminate)}</td><td>${esc(r.reactive_pct||0)}%</td></tr>`).join(''):'<tr><td colspan="8">Sin datos.</td></tr>';
 }catch(e){document.getElementById('scr-msg').innerHTML=`<div class="status warn">${esc(e.message)} · Instale SQL v0.23.0.</div>`}}
 document.getElementById('scr-new').onclick=()=>document.getElementById('scr-dialog').showModal();document.getElementById('scr-cancel').onclick=()=>document.getElementById('scr-dialog').close();
 document.getElementById('scr-form').onsubmit=async e=>{e.preventDefault();try{await bloodData.createScreening({screening_code:v('scr-code'),source_unit_code:v('scr-unit'),branch_id:v('scr-branch'),screening_date:v('scr-date'),test_type:v('scr-test'),result:v('scr-result'),reagent:v('scr-reagent')||null,reagent_lot:v('scr-lot')||null,reagent_expiry:v('scr-expiry')||null,responsible:v('scr-resp')||null,status:v('scr-status'),observations:v('scr-notes')||null});document.getElementById('scr-dialog').close();e.target.reset();await load()}catch(x){document.getElementById('scr-msg').innerHTML=`<div class="status bad">${esc(x.message)}</div>`}};
 function v(id){return document.getElementById(id).value.trim()} await load();
}
