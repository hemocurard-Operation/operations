import {supplierData} from './supplier-data.js';
import {mountProcurement} from './procurement.js';
import {esc as e,table} from './workflow-ui.js';
export async function mountSuppliers(root){
 root.innerHTML='<div class="sales-toolbar"><div><h2>Proveedores y Compras</h2><p class="muted">Órdenes de compra, recepción por lotes y evaluación de proveedores.</p></div></div><div data-procurement></div><section class="card" data-supplier-performance><h3>Desempeño de proveedores</h3><p>Cargando…</p></section>';
 await mountProcurement(root.querySelector('[data-procurement]'));
 async function performance(){try{const rows=await supplierData.suppliers();root.querySelector('[data-supplier-performance]').innerHTML='<h3>Desempeño de proveedores</h3>'+table(['Código','Proveedor','Crítico','Estado','Última evaluación','Puntuación','Resultado','Próxima revisión'],rows.map(x=>[e(x.supplier_code),e(x.legal_name),x.critical?'Sí':'No',e(x.status),e(x.evaluation_date||'—'),e(x.total_score??'—'),e(x.result||'—'),e(x.next_review_date||'—')+(x.review_overdue?' · VENCIDA':'')]))}catch(err){root.querySelector('[data-supplier-performance]').innerHTML=`<div class="status warn">${e(err.message)}</div>`}}
 root.addEventListener('procurement-supplier-updated',performance);await performance();
}
