import { bloodData } from './blood-operations-data.js';
import { flowData } from './blood-flow-data.js';
import { supplyData } from './supply-data.js';
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}

export async function mountBI(root){
  root.innerHTML='<section class="card"><div class="status info">Cargando inteligencia de negocios…</div></section>';
  try{
    const [allRows,allFunnel,allSupply]=await Promise.all([bloodData.biToday(),flowData.funnel(),supplyData.plan()]);
    const branchNames=[...new Set(allRows.map(r=>r.branch_name).filter(Boolean))].sort();
    let fBranch='';

    const render=()=>{
      const rows=fBranch?allRows.filter(r=>r.branch_name===fBranch):allRows;
      const funnel=fBranch?allFunnel.filter(r=>r.branch_name===fBranch):allFunnel;
      const supply=fBranch?allSupply.filter(r=>{const bn=allRows.find(b=>b.branch_id===r.branch_id);return bn&&bn.branch_name===fBranch}):allSupply;
      const totals=rows.reduce((a,x)=>({d:a.d+Number(x.donors||0),e:a.e+Number(x.effective_donations||0),s:a.s+Number(x.screened_tests||0),r:a.r+Number(x.reactive_tests||0),i:a.i+Number(x.available_blood_units||0),o:a.o+Number(x.sales_outflows||0),f:a.f+Number(x.invoiced_amount||0)}),{d:0,e:0,s:0,r:0,i:0,o:0,f:0});

      root.innerHTML=`
      <div class="sales-toolbar"><div><h2 class="section-heading">Inteligencia de Negocios</h2>
      <div class="muted">Operaciones, sangre, tamizaje, salidas y calidad.</div></div>
      <div class="filter-grid"><label>Sucursal<select id="bi-f-branch">
        <option value="">Todas</option>${branchNames.map(b=>`<option value="${esc(b)}"${b===fBranch?' selected':''}>${esc(b)}</option>`).join('')}
      </select></label></div></div>
      <div id="bi-msg"></div>

      <div class="grid sales-kpis">
        <section class="card"><div class="muted">Donantes</div><div class="kpi">${totals.d}</div></section>
        <section class="card"><div class="muted">Tamizajes</div><div class="kpi">${totals.s}</div></section>
        <section class="card"><div class="muted">Unidades disponibles</div><div class="kpi">${totals.i}</div></section>
        <section class="card"><div class="muted">Facturado hoy</div><div class="kpi">RD$${totals.f.toLocaleString('es-DO')}</div></section>
      </div>

      <section class="card"><h3>Comparativo por sucursal — hoy</h3><div class="table-wrap"><table class="data-table">
      <thead><tr><th>Sucursal</th><th>Donantes</th><th>Donaciones efectivas</th><th>Tamizajes</th><th>Reactivos</th><th>Unidades disponibles</th><th>Salidas</th><th>Facturado</th></tr></thead>
      <tbody>${rows.map(r=>`<tr><td>${esc(r.branch_name)}</td><td>${esc(r.donors)}</td><td>${esc(r.effective_donations)}</td><td>${esc(r.screened_tests)}</td><td>${esc(r.reactive_tests)}</td><td>${esc(r.available_blood_units)}</td><td>${esc(r.sales_outflows)}</td><td>${Number(r.invoiced_amount||0).toLocaleString('es-DO')}</td></tr>`).join('')}</tbody>
      </table></div></section>

      <section class="card"><h3>Embudo sanguíneo 30 días</h3><div class="table-wrap"><table class="data-table">
      <thead><tr><th>Sucursal</th><th>Donantes</th><th>Efectivas</th><th>Recolectadas</th><th>Tamizadas</th><th>Liberadas</th><th>Disponibles</th><th>Despachadas</th></tr></thead>
      <tbody>${funnel.length?funnel.map(r=>`<tr><td>${esc(r.branch_name)}</td><td>${esc(r.donors)}</td><td>${esc(r.effective_donations)}</td><td>${esc(r.collected_units)}</td><td>${esc(r.screened_units)}</td><td>${esc(r.released_units)}</td><td>${esc(r.available_units)}</td><td>${esc(r.dispatched_units)}</td></tr>`).join(''):'<tr><td colspan="8">Sin datos.</td></tr>'}</tbody>
      </table></div></section>

      <section class="card"><h3>Abastecimiento</h3><div class="table-wrap"><table class="data-table">
      <thead><tr><th>Sucursal</th><th>Componente</th><th>ABO</th><th>Rh</th><th>Disponible</th><th>Cobertura</th><th>Necesarias</th><th>Estado</th></tr></thead>
      <tbody>${supply.length?supply.map(r=>`<tr><td>${esc(r.branch_id)}</td><td>${esc(r.component_name)}</td><td>${esc(r.abo||'—')}</td><td>${esc(r.rh||'—')}</td><td>${esc(r.available_units)}</td><td>${esc(r.coverage_days??'—')}</td><td>${esc(r.required_units)}</td><td>${esc(r.stock_status)}</td></tr>`).join(''):'<tr><td colspan="8">Sin plan de abastecimiento.</td></tr>'}</tbody>
      </table></div></section>

      <section class="card"><h3>Indicadores de gestión</h3><ul>
      <li>Tasa de donación efectiva = donaciones efectivas / donantes.</li>
      <li>Tasa reactiva = resultados reactivos / pruebas realizadas.</li>
      <li>Cobertura operativa = inventario disponible vs salidas.</li>
      <li>Conversión despacho→facturación y cartera pendiente.</li>
      <li>NC/CAPA y proyectos se mantienen en sus módulos de SGC/PM.</li></ul></section>`;

      document.getElementById('bi-f-branch').onchange=e=>{fBranch=e.target.value;render()};
    };
    render();
  }catch(e){root.innerHTML=`<section class="card"><div class="status warn">${esc(e.message)} · Instale SQL v0.23.0.</div></section>`}
}
