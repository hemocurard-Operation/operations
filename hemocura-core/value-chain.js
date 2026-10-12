import { loadValueChainWorkspace,createDemand,updateDemandStatus } from './value-chain-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
function n(v){return Number(v||0).toLocaleString('es-DO',{maximumFractionDigits:2})}
function nowLocal(){const d=new Date();d.setMinutes(d.getMinutes()-d.getTimezoneOffset());return d.toISOString().slice(0,16)}
function mapBy(rows,key='id'){return Object.fromEntries(rows.map(x=>[x[key],x]))}

export async function mountValueChain(root){
  root.innerHTML='<section class="card"><div class="status info">Cargando cadena de valor…</div></section>';
  let state=null;
  async function load(){state=await loadValueChainWorkspace();render()}
  function render(){
    const customers=mapBy(state.customers),products=mapBy(state.products),branches=mapBy(state.branches);
    const totalDemand=state.scorecard.reduce((a,x)=>a+Number(x.open_demand||0),0);
    const stock=state.scorecard.reduce((a,x)=>a+Number(x.available_units||0),0);
    const billed=state.scorecard.reduce((a,x)=>a+Number(x.billed_30d||0),0);
    const collected=state.scorecard.reduce((a,x)=>a+Number(x.collected_30d||0),0);
    const actions=state.scorecard.reduce((a,x)=>a+Number(x.open_actions||0),0);
    root.innerHTML=`
      <div class="sales-toolbar"><div><h2 class="section-heading">Cadena de Valor HemoCura</h2><div class="muted">Demanda → planificación → donación → procesamiento → inventario → despacho → ingreso → mejora.</div></div><button id="vc-new-demand">Nueva demanda</button></div>
      <div id="vc-status"></div>
      <div class="grid sales-kpis">
        <section class="card"><div class="muted">Demanda abierta</div><div class="kpi">${n(totalDemand)}</div></section>
        <section class="card"><div class="muted">Unidades disponibles</div><div class="kpi">${n(stock)}</div></section>
        <section class="card"><div class="muted">Facturado 30d</div><div class="kpi">RD$ ${n(billed)}</div></section>
        <section class="card"><div class="muted">Cobrado 30d</div><div class="kpi">RD$ ${n(collected)}</div></section>
        <section class="card"><div class="muted">Acciones abiertas</div><div class="kpi">${n(actions)}</div></section>
      </div>
      <section class="card"><h3>Flujo de creación de valor</h3><div class="work-grid">${state.stages.map(s=>`<article class="work-card"><span class="work-kicker">${esc(s.stage_code)} · ${esc(s.owner_domain)}</span><strong>${esc(s.stage_name)}</strong><small>${esc(s.objective)}</small></article>`).join('')}</div></section>
      <section class="card"><div class="card-head"><h3>Scorecard por sucursal</h3><span class="muted">últimos 30 días donde aplica</span></div><div class="table-wrap"><table class="data-table"><thead><tr><th>Sucursal</th><th>Demanda</th><th>Stock</th><th>Despachos</th><th>Facturado</th><th>Cobrado</th><th>Campañas</th><th>Feedback</th><th>Acciones</th></tr></thead><tbody>${state.scorecard.map(r=>`<tr><td><strong>${esc(r.branch_name)}</strong></td><td>${n(r.open_demand)}</td><td>${n(r.available_units)}</td><td>${n(r.dispatches_30d)}</td><td>RD$ ${n(r.billed_30d)}</td><td>RD$ ${n(r.collected_30d)}</td><td>${n(r.active_campaigns)}</td><td>${n(r.open_feedback)}</td><td>${n(r.open_actions)}</td></tr>`).join('')||'<tr><td colspan="9" class="muted">Sin datos visibles.</td></tr>'}</tbody></table></div></section>
      <section class="card"><div class="card-head"><h3>Demanda clínica y operativa</h3><span class="muted">priorizar necesidad antes de producir o despachar</span></div><div class="table-wrap"><table class="data-table"><thead><tr><th>Solicitada</th><th>Sucursal</th><th>Cliente</th><th>Producto</th><th>ABO/Rh</th><th>Unid.</th><th>Necesaria</th><th>Prioridad</th><th>Estado</th></tr></thead><tbody>${state.demand.map(d=>`<tr><td>${esc(new Date(d.requested_at).toLocaleString('es-DO'))}</td><td>${esc(branches[d.branch_id]?.name||'—')}</td><td>${esc(customers[d.customer_id]?.name||'—')}</td><td>${esc(products[d.product_id]?.name||d.product_id)}</td><td>${esc([d.blood_group,d.rh_factor].filter(Boolean).join(' ')||'—')}</td><td>${n(d.requested_units)}</td><td>${esc(new Date(d.needed_by).toLocaleString('es-DO'))}</td><td>${esc(d.priority)}</td><td><select data-demand-status="${esc(d.id)}"><option ${d.status==='ABIERTA'?'selected':''}>ABIERTA</option><option ${d.status==='EN_PROCESO'?'selected':''}>EN_PROCESO</option><option ${d.status==='ATENDIDA'?'selected':''}>ATENDIDA</option><option ${d.status==='CANCELADA'?'selected':''}>CANCELADA</option></select></td></tr>`).join('')||'<tr><td colspan="9" class="muted">No hay demandas registradas.</td></tr>'}</tbody></table></div></section>
      <dialog id="vc-demand-dialog" class="sales-dialog"><form id="vc-demand-form"><h3>Nueva demanda</h3>
        <label>Sucursal<select id="vc-branch" required><option value="">Seleccione…</option>${state.branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
        <label>Cliente<select id="vc-customer"><option value="">Sin cliente definido</option>${state.customers.map(c=>`<option value="${esc(c.id)}">${esc(c.name)}</option>`).join('')}</select></label>
        <label>Producto<select id="vc-product" required><option value="">Seleccione…</option>${state.products.map(p=>`<option value="${esc(p.id)}">${esc(p.code)} · ${esc(p.name)}</option>`).join('')}</select></label>
        <div class="filter-grid"><label>Grupo ABO<input id="vc-abo" placeholder="O, A, B, AB"></label><label>Rh<input id="vc-rh" placeholder="+ / -"></label><label>Unidades<input id="vc-units" type="number" min="1" value="1" required></label></div>
        <label>Necesaria para<input id="vc-needed" type="datetime-local" value="${nowLocal()}" required></label>
        <label>Prioridad<select id="vc-priority"><option>NORMAL</option><option>URGENTE</option><option>CRITICA</option></select></label>
        <label>Orden / referencia clínica<input id="vc-ref"></label>
        <div class="dialog-actions"><button type="button" id="vc-cancel" class="secondary">Cancelar</button><button type="submit">Registrar demanda</button></div>
      </form></dialog>`;
    root.querySelector('#vc-new-demand').onclick=()=>root.querySelector('#vc-demand-dialog').showModal();
    root.querySelector('#vc-cancel').onclick=()=>root.querySelector('#vc-demand-dialog').close();
    root.querySelector('#vc-demand-form').onsubmit=async e=>{e.preventDefault();try{
      await createDemand({branch_id:root.querySelector('#vc-branch').value,customer_id:root.querySelector('#vc-customer').value||null,product_id:root.querySelector('#vc-product').value,blood_group:root.querySelector('#vc-abo').value.trim()||null,rh_factor:root.querySelector('#vc-rh').value.trim()||null,requested_units:Number(root.querySelector('#vc-units').value),requested_at:new Date().toISOString(),needed_by:new Date(root.querySelector('#vc-needed').value).toISOString(),priority:root.querySelector('#vc-priority').value,status:'ABIERTA',clinical_order_ref:root.querySelector('#vc-ref').value.trim()||null});
      root.querySelector('#vc-demand-dialog').close();await load();
    }catch(err){root.querySelector('#vc-status').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}};
    root.querySelectorAll('[data-demand-status]').forEach(sel=>sel.onchange=async()=>{try{await updateDemandStatus(sel.dataset.demandStatus,sel.value);root.querySelector('#vc-status').innerHTML='<div class="status ok">Demanda actualizada.</div>'}catch(err){root.querySelector('#vc-status').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}});
  }
  try{await load()}catch(err){root.innerHTML=`<section class="card"><div class="status bad">${esc(err.message)}</div></section>`}
}
