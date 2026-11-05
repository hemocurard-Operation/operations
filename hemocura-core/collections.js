import { loadCollections,recordPayment } from './collections-data.js';
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
function money(v){return Number(v||0).toLocaleString('es-DO',{style:'currency',currency:'DOP',maximumFractionDigits:0})}
function agingClass(days){return Number(days)>60?'bad':Number(days)>30?'warn':'ok'}
function agingBucket(days){const d=Number(days||0);if(d<=0)return'Corriente';if(d<=30)return'1-30d';if(d<=60)return'31-60d';if(d<=90)return'61-90d';return'90d+'}
export async function mountCollections(root){
  root.innerHTML='<section class="card"><div class="status info">Cargando cobranza…</div></section>';
  let state=await loadCollections(),fBranch='',fCustomer='';
  const render=()=>{
    let ar=state.ar;
    if(fBranch)ar=ar.filter(x=>x.branch_id===fBranch);
    if(fCustomer)ar=ar.filter(x=>x.customer_id===fCustomer);
    const open=ar.filter(x=>Number(x.outstanding_amount)>0);
    const total=open.reduce((a,x)=>a+Number(x.outstanding_amount||0),0);
    const totalBilled=ar.reduce((a,x)=>a+Number(x.total_amount||0),0);
    const totalPaid=ar.reduce((a,x)=>a+Number(x.paid_amount||0),0);
    const collectionRate=totalBilled?Math.round(totalPaid/totalBilled*1000)/10:0;
    const weightedDays=open.reduce((a,x)=>a+Number(x.days_past_due||0)*Number(x.outstanding_amount||0),0);
    const dso=total?Math.round(weightedDays/total):0;
    const buckets=['Corriente','1-30d','31-60d','61-90d','90d+'];
    const bucketData=buckets.map(b=>{const items=open.filter(x=>agingBucket(x.days_past_due)===b);return{label:b,count:items.length,amount:items.reduce((a,x)=>a+Number(x.outstanding_amount||0),0)}});
    const bucketClass=i=>i<=1?'ok':i<=2?'warn':'bad';
    root.innerHTML=`<div class="sales-toolbar"><div><h2 class="section-heading">Cobranza y Aging</h2><div class="muted">Venta → vencimiento → cobro → saldo.</div></div><button id="col-refresh" class="secondary">Actualizar</button></div>
    <div id="collections-status"></div>
    <form class="card filter-grid" id="col-filters"><label>Sucursal<select name="branch"><option value="">Todas</option>${state.branches.map(b=>`<option value="${esc(b.id)}" ${fBranch===b.id?'selected':''}>${esc(b.name)}</option>`).join('')}</select></label><label>Cliente<select name="customer"><option value="">Todos</option>${state.customers.map(c=>`<option value="${esc(c.id)}" ${fCustomer===c.id?'selected':''}>${esc(c.name)}</option>`).join('')}</select></label><button>Aplicar</button></form>
    <div class="grid sales-kpis"><section class="card"><div class="muted">CxC total</div><div class="kpi">${money(total)}</div></section><section class="card"><div class="muted">DSO ponderado</div><div class="kpi">${dso} días</div></section><section class="card"><div class="muted">Tasa de cobro</div><div class="kpi"><span class="status ${collectionRate>=90?'ok':collectionRate>=70?'warn':'bad'}">${collectionRate}%</span></div></section><section class="card"><div class="muted">Facturas abiertas</div><div class="kpi">${open.length}</div></section></div>
    <section class="card"><h3>Distribución de aging</h3><div class="grid">${bucketData.map((b,i)=>`<section class="card"><div class="muted">${esc(b.label)}</div><div class="kpi"><span class="status ${bucketClass(i)}">${money(b.amount)}</span></div><div class="muted">${b.count} factura(s)</div></section>`).join('')}</div></section>
    <section class="card"><h3>Detalle de cuentas por cobrar</h3><div class="table-wrap"><table class="data-table"><thead><tr><th>Venta</th><th>Cliente</th><th>Total</th><th>Pagado</th><th>Saldo</th><th>Días</th><th>Aging</th><th>Cobrar</th></tr></thead><tbody>${ar.map(x=>{const days=Number(x.days_past_due||0);return`<tr><td>${esc(x.sale_code||'')}</td><td>${esc(x.customer_name||'')}</td><td>${money(x.total_amount)}</td><td>${money(x.paid_amount)}</td><td>${money(x.outstanding_amount)}</td><td><span class="status ${agingClass(days)}">${days}</span></td><td>${esc(x.aging_bucket)}</td><td>${Number(x.outstanding_amount)>0?`<button class="secondary" data-pay="${esc(x.sale_id)}" data-customer="${esc(x.customer_id||'')}" data-branch="${esc(x.branch_id||'')}" data-balance="${esc(x.outstanding_amount)}">Registrar</button>`:'—'}</td></tr>`}).join('')||'<tr><td colspan="8" class="muted">Sin cuentas por cobrar.</td></tr>'}</tbody></table></div></section>
    <dialog id="payment-dialog" class="sales-dialog"><form id="payment-form"><h3>Registrar cobro</h3><input id="payment-sale" type="hidden"><input id="payment-customer" type="hidden"><input id="payment-branch" type="hidden"><label>Monto<input id="payment-amount" type="number" min="0.01" step="0.01" required></label><label>Método<select id="payment-method"><option>TRANSFERENCIA</option><option>EFECTIVO</option><option>CHEQUE</option><option>TARJETA</option><option>OTRO</option></select></label><label>Referencia<input id="payment-ref"></label><div class="dialog-actions"><button type="button" class="secondary" id="payment-cancel">Cancelar</button><button type="submit">Guardar cobro</button></div></form></dialog>`;
    const msg=(t,bad=false)=>{root.querySelector('#collections-status').innerHTML=`<p class="status ${bad?'bad':'ok'}">${esc(t)}</p>`};
    root.querySelector('#col-filters').onsubmit=ev=>{ev.preventDefault();const f=new FormData(ev.target);fBranch=f.get('branch');fCustomer=f.get('customer');render()};
    root.querySelector('#col-refresh').onclick=async()=>{try{state=await loadCollections();render();msg('Datos actualizados.')}catch(err){msg(err.message,true)}};
    const dlg=root.querySelector('#payment-dialog');
    root.querySelectorAll('[data-pay]').forEach(b=>b.onclick=()=>{root.querySelector('#payment-sale').value=b.dataset.pay;root.querySelector('#payment-customer').value=b.dataset.customer;root.querySelector('#payment-branch').value=b.dataset.branch;root.querySelector('#payment-amount').value=b.dataset.balance;dlg.showModal()});
    root.querySelector('#payment-cancel').onclick=()=>dlg.close();
    root.querySelector('#payment-form').onsubmit=async e=>{e.preventDefault();try{await recordPayment({sale_id:root.querySelector('#payment-sale').value,customer_id:root.querySelector('#payment-customer').value,branch_id:root.querySelector('#payment-branch').value||null,amount:Number(root.querySelector('#payment-amount').value),payment_method:root.querySelector('#payment-method').value,reference:root.querySelector('#payment-ref').value.trim()||null});dlg.close();msg('Cobro registrado.');state=await loadCollections();render()}catch(err){msg(err.message,true)}};
  };render();
}
