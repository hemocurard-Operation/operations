import { supplyData } from './supply-data.js';
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);
const COMPONENTS=['SANGRE_TOTAL','CONCENTRADO_HEMATIES','PLASMA_FRESCO_CONGELADO','PLAQUETAS','CRIOPRECIPITADO'];
export async function mountProduction(root){
 const branches=await supplyData.branches(),bm=Object.fromEntries(branches.map(b=>[b.id,b.name]));
 root.innerHTML=`<div class="sales-toolbar"><div><h2 class="section-heading">Producción</h2><div class="muted">Captura guiada de componentes obtenidos desde unidades origen.</div></div><button id="prod-new">Nueva producción</button></div>
 <div id="prod-msg"></div><section class="card"><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Código</th><th>Sucursal</th><th>Unidad origen</th><th>Componente</th><th>ABO</th><th>Rh</th><th>Cantidad</th><th>Vence</th><th>Estado</th></tr></thead><tbody id="prod-body"></tbody></table></div></section>
 <dialog id="prod-dialog" class="sales-dialog"><form id="prod-form"><h3>Registro de producción</h3><div class="quick-form-grid">
 <label>Código<input id="prod-code" required placeholder="PROD-2026-001" autocomplete="off"></label><label>Fecha<input id="prod-date" type="date" value="${today()}" required></label>
 <label>Sucursal<select id="prod-branch" required><option value="">Seleccionar…</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
 <label>Unidad origen<input id="prod-source" list="prod-sources" required autocomplete="off"><datalist id="prod-sources"></datalist></label>
 <label>Componente<select id="prod-comp" required><option value="">Seleccionar…</option>${COMPONENTS.map(x=>`<option>${esc(x)}</option>`).join('')}</select></label>
 <label>ABO<select id="prod-abo"><option value="">Pendiente</option><option>A</option><option>B</option><option>AB</option><option>O</option></select></label>
 <label>Rh<select id="prod-rh"><option value="">Pendiente</option><option>POSITIVO</option><option>NEGATIVO</option></select></label>
 <label>Cantidad<input id="prod-qty" type="number" min="1" value="1" required></label><label>Vencimiento<input id="prod-exp" type="date"></label>
 <label>Responsable<input id="prod-resp" list="prod-responsibles" autocomplete="off"><datalist id="prod-responsibles"></datalist></label>
 <label>Estado<select id="prod-status"><option>CUARENTENA</option><option>DISPONIBLE</option><option>RESERVADA</option><option>DESCARTADA</option></select></label>
 <label class="full">Notas<textarea id="prod-notes"></textarea></label></div><div class="dialog-actions"><button type="button" id="prod-cancel" class="secondary">Cancelar</button><button>Guardar</button></div></form></dialog>`;
 async function load(){try{const rows=await supplyData.production();document.getElementById('prod-body').innerHTML=rows.length?rows.map(r=>`<tr><td>${esc(r.production_date)}</td><td><code>${esc(r.production_code)}</code></td><td>${esc(bm[r.branch_id]||r.branch_id)}</td><td><code>${esc(r.source_unit_code)}</code></td><td>${esc(r.component_name)}</td><td>${esc(r.abo||'—')}</td><td>${esc(r.rh||'—')}</td><td>${esc(r.quantity)}</td><td>${esc(r.expiry_date||'—')}</td><td>${esc(r.status)}</td></tr>`).join(''):'<tr><td colspan="10">Sin producción.</td></tr>';
 const fill=(id,vals)=>document.getElementById(id).innerHTML=[...new Set(vals.filter(Boolean))].slice(0,50).map(x=>`<option value="${esc(x)}">`).join('');fill('prod-sources',rows.map(r=>r.source_unit_code));fill('prod-responsibles',rows.map(r=>r.responsible));}catch(e){document.getElementById('prod-msg').innerHTML=`<div class="status warn">${esc(e.message)}</div>`}}
 document.getElementById('prod-new').onclick=()=>document.getElementById('prod-dialog').showModal();document.getElementById('prod-cancel').onclick=()=>document.getElementById('prod-dialog').close();
 document.getElementById('prod-form').onsubmit=async e=>{e.preventDefault();try{await supplyData.createProduction({production_code:v('prod-code'),branch_id:v('prod-branch'),production_date:v('prod-date'),source_unit_code:v('prod-source'),component_name:v('prod-comp'),abo:v('prod-abo')||null,rh:v('prod-rh')||null,quantity:Number(v('prod-qty')),expiry_date:v('prod-exp')||null,responsible:v('prod-resp')||null,status:v('prod-status'),notes:v('prod-notes')||null});document.getElementById('prod-dialog').close();e.target.reset();document.getElementById('prod-date').value=today();document.getElementById('prod-qty').value='1';await load()}catch(x){document.getElementById('prod-msg').innerHTML=`<div class="status bad">${esc(x.message)}</div>`}};function v(id){return document.getElementById(id).value.trim()}await load();
}
