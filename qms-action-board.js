import { listOpenQmsActions } from './integrated-qms-data.js';
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
export async function mountQmsActionBoard(root){
  if(!root) return;
  try{
    const rows=await listOpenQmsActions();
    root.innerHTML=`<section class="card"><div class="card-head"><h3>Acciones abiertas del SGC</h3><span class="muted">${rows.length}</span></div>
    <div class="table-wrap"><table class="data-table"><thead><tr><th>Tipo</th><th>Código</th><th>Descripción</th><th>Vence</th><th>Estado</th></tr></thead>
    <tbody>${rows.length?rows.map(r=>`<tr><td>${esc(r.source_type)}</td><td>${esc(r.code||'—')}</td><td>${esc(r.description)}</td><td>${esc(r.due_date||'—')}</td><td>${esc(r.status)}</td></tr>`).join(''):`<tr><td colspan="5" class="muted">Sin acciones abiertas.</td></tr>`}</tbody></table></div></section>`;
  }catch(e){root.innerHTML=`<section class="card"><div class="status warn">${esc(e.message)}</div></section>`}
}
