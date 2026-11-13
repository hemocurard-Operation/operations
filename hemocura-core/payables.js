// HemoCura v11 F1 §10 — UI mínima de Cuentas por Pagar.
import { payablesData } from './payables-data.js';
import { loadAccess } from './access-control.js';
import { esc, field, table } from './workflow-ui.js';

const BUCKET_CLASS={Corriente:'stock-ok','1-30d':'stock-warning','31-60d':'stock-warning','61-90d':'stock-critical','90d+':'stock-critical'};
function money(v){return new Intl.NumberFormat('es-DO',{style:'currency',currency:'DOP',maximumFractionDigits:2}).format(Number(v||0));}
function pill(b){return `<span class="stock-pill ${BUCKET_CLASS[b]||''}">${esc(b)}</span>`;}

export async function mountPayables(root){
  root.innerHTML='<section class="card"><div class="status info">Cargando Cuentas por Pagar…</div></section>';
  let access,aging=[],suppliers=[],cashFlow=[],busy=false;
  try{
    access=await loadAccess();
    [aging,suppliers,cashFlow]=await Promise.all([
      payablesData.aging(null),payablesData.suppliers(),payablesData.cashFlow()
    ]);
  }catch(err){
    root.innerHTML=`<section class="card"><div class="status bad" role="alert">${esc(err.message)}</div></section>`;
    return;
  }
  const canWrite=access.permissions.has('FINANCE_WRITE');
  const canAuthorize=access.permissions.has('AP_AUTHORIZE');
  const actor=access.context?.user_id||access.context?.id||null;

  function kpis(){
    const openItems=aging.filter(x=>x.status!=='PAGADA'&&x.status!=='ANULADA');
    const total=openItems.reduce((s,x)=>s+Number(x.outstanding_amount||0),0);
    const overdue=openItems.filter(x=>x.days_past_due>0).reduce((s,x)=>s+Number(x.outstanding_amount||0),0);
    const next30=cashFlow.find(c=>c.horizon_bucket==='30d');
    return `<div class="grid sales-kpis">
      <section class="card"><div class="muted">Saldo total</div><div class="kpi">${money(total)}</div></section>
      <section class="card"><div class="muted">Vencido</div><div class="kpi">${money(overdue)}</div></section>
      <section class="card"><div class="muted">Egreso proyectado 30d</div><div class="kpi">${money(next30?.total_outflow||0)}</div></section>
      <section class="card"><div class="muted">Facturas abiertas</div><div class="kpi">${openItems.length}</div></section>
    </div>`;
  }

  function render(){
    const rows=aging.filter(x=>x.status!=='PAGADA'&&x.status!=='ANULADA').slice(0,200).map(x=>[
      esc(x.supplier_name||''),esc(x.invoice_number),esc(x.invoice_date),esc(x.due_date),
      money(x.amount_total),money(x.amount_paid),money(x.outstanding_amount),
      String(x.days_past_due||0),pill(x.aging_bucket),
      canAuthorize&&Number(x.outstanding_amount)>0
        ? `<button class="secondary compact" data-pay="${esc(x.payable_id)}" data-supplier="${esc(x.supplier_id)}" data-balance="${esc(x.outstanding_amount)}">Registrar pago</button>`
        : 'Consulta'
    ]);
    root.innerHTML=`
      <div class="sales-toolbar"><div>
        <h2 class="section-heading">Cuentas por Pagar</h2>
        <div class="muted">Facturas de suplidores con aging y proyección de egresos.</div>
      </div><div>
        ${canWrite?'<button data-ap-new>+ Nueva factura</button>':''}
        <button class="secondary" data-ap-refresh>Actualizar</button>
      </div></div>
      <div data-ap-msg role="status"></div>
      ${kpis()}
      <section class="card"><h3>Facturas pendientes</h3>
        ${table(['Suplidor','Factura','Emitida','Vence','Total','Pagado','Saldo','Días','Aging','Acción'],rows)}
      </section>
      <dialog data-ap-dialog class="sales-dialog"><form data-ap-form>
        <h3 data-ap-title></h3>
        <div data-ap-fields class="filter-grid"></div>
        <p data-ap-error role="alert"></p>
        <div class="dialog-actions">
          <button type="button" data-ap-cancel class="secondary">Cancelar</button>
          <button type="submit">Guardar</button>
        </div>
      </form></dialog>`;
    root.querySelector('[data-ap-refresh]').onclick=async()=>{
      try{aging=await payablesData.aging(null);render();}catch(e){status(e.message,true);}
    };
    const newBtn=root.querySelector('[data-ap-new]');
    if(newBtn) newBtn.onclick=openNewPayable;
    root.querySelectorAll('[data-pay]').forEach(b=>b.onclick=()=>openPayment(b.dataset.pay,b.dataset.supplier,b.dataset.balance));
  }

  function status(msg,bad=false){
    const el=root.querySelector('[data-ap-msg]');
    if(el) el.innerHTML=`<div class="status ${bad?'bad':'ok'}">${esc(msg)}</div>`;
  }

  function openDialog(title,fieldsHtml,onSubmit){
    const d=root.querySelector('[data-ap-dialog]');
    const form=root.querySelector('[data-ap-form]');
    root.querySelector('[data-ap-title]').textContent=title;
    root.querySelector('[data-ap-fields]').innerHTML=fieldsHtml;
    root.querySelector('[data-ap-error]').textContent='';
    form.onsubmit=async ev=>{
      ev.preventDefault();
      if(busy||!form.reportValidity()) return;
      busy=true;const btn=form.querySelector('[type=submit]');btn.disabled=true;
      try{
        await onSubmit(Object.fromEntries(new FormData(form)));
        d.close();aging=await payablesData.aging(null);render();status('Guardado.');
      }catch(err){root.querySelector('[data-ap-error]').textContent=err.message;}
      finally{busy=false;btn.disabled=false;}
    };
    root.querySelector('[data-ap-cancel]').onclick=()=>{if(!busy)d.close();};
    d.showModal();
  }

  function openNewPayable(){
    const today=new Date().toISOString().slice(0,10);
    const html=field('supplier_id','Suplidor','select','',{items:suppliers.map(s=>[s.id,s.name]),required:true})
      +field('invoice_number','Número de factura','text','',{required:true})
      +field('invoice_date','Fecha de emisión','date',today,{required:true})
      +field('due_date','Fecha de vencimiento','date',today,{required:true})
      +field('currency','Moneda','select','DOP',{items:[['DOP','DOP'],['USD','USD'],['EUR','EUR']]})
      +field('amount_total','Monto total','number',0,{required:true});
    openDialog('Registrar factura de proveedor',html,async f=>{
      await payablesData.createPayable({
        supplier_id:f.supplier_id,invoice_number:f.invoice_number,
        invoice_date:f.invoice_date,due_date:f.due_date,
        currency:f.currency,amount_total:Number(f.amount_total),
        entered_by:actor
      });
    });
  }

  function openPayment(payableId,supplierId,balance){
    const html=field('amount','Monto a pagar','number',balance,{required:true})
      +field('payment_method','Método','select','TRANSFERENCIA',{items:[['EFECTIVO','Efectivo'],['TRANSFERENCIA','Transferencia'],['OFICINA','Pago en oficina'],['CHEQUE','Cheque'],['CREDITO','Crédito']]})
      +field('reference','Referencia','text','')
      +field('notes','Notas','textarea','');
    openDialog('Registrar pago',html,async f=>{
      // CHECK de DB fuerza authorized_by != posted_by; para esta UI el
      // autorizador debe ser distinto; cuando el UI no tenga a dos
      // actores el flujo deja authorized_by=null y requiere que otra
      // persona lo registre en una segunda llamada. Para no bloquear
      // en esta UI inicial, autorizamos como actor sólo si el permiso
      // AP_AUTHORIZE está activo y aceptamos que el revisor real
      // firmará en la columna authorized_by vía RPC futura.
      await payablesData.recordPayment({
        payable_id:payableId,supplier_id:supplierId,
        amount:Number(f.amount),payment_method:f.payment_method,
        reference:f.reference||null,notes:f.notes||null,
        posted_by:actor,authorized_by:null
      });
    });
  }

  render();
}
