import {getSupabase} from './supabase.js';
import {loadAccess,filterRoutes} from './access-control.js';
import {routeList} from './router.js';
import {quotationData} from './quotation-data.js';
import {compareQuotations} from './quotation-domain.js';
import {localDay} from './workflow-domain.js';
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const money=(v,c)=>new Intl.NumberFormat('es-DO',{style:'currency',currency:c,maximumFractionDigits:6}).format(Number(v));
async function access(){const [a,routes]=await Promise.all([loadAccess(),filterRoutes(routeList())]);return a.permissions.has('PURCHASE_VIEW')&&routes.some(([k])=>k==='inventory'||k==='suppliers')}
export async function mountAgentPriceReview(root){
 root.innerHTML='<section class="card"><h3>Revisión de precios de cotizaciones</h3><p data-price-status role="status">Verificando acceso…</p><div data-price-controls></div><div data-price-results></div></section>';
 const status=root.querySelector('[data-price-status]'),controls=root.querySelector('[data-price-controls]'),results=root.querySelector('[data-price-results]');let generation=0;
 try{
  if(!await access()){if(root.isConnected)status.textContent='Se requiere permiso de compras y un módulo de Inventario o Proveedores habilitado.';return}
  const {data:branches,error}=await getSupabase().from('branches').select('id,name').eq('active',true).order('name').order('id');if(error)throw error;if(!root.isConnected)return;
  if(!branches?.length){status.textContent='No hay sucursales autorizadas disponibles para revisar cotizaciones.';return}
  status.textContent='Seleccione una sucursal y solicite la revisión. No se descargan PDF ni se registran decisiones de compra.';
  controls.innerHTML=`<div class="agent-filter"><label>Sucursal de las cotizaciones<select data-price-branch aria-label="Sucursal de las cotizaciones">${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label><button type="button" data-price-run>Revisar cambios de precio</button></div>`;
  const select=controls.querySelector('select'),button=controls.querySelector('button');
  select.onchange=()=>{generation++;button.disabled=false;results.replaceChildren();status.textContent='Solicite una revisión para la sucursal seleccionada.'};
  button.onclick=async()=>{
   const current=++generation,branch=select.value;button.disabled=true;results.replaceChildren();status.textContent='Revisando el historial de cotizaciones…';
   try{
    if(!await access())throw Error('Acceso no disponible');
    const quotes=await quotationData.list(branch);if(current!==generation||!root.isConnected)return;
    const {alerts}=compareQuotations(quotes,localDay());
    status.textContent=`${quotes.length} cotizaciones consultadas · ${alerts.length} cambios históricos de precio · ${new Date().toLocaleString('es-DO')}`;
    results.innerHTML='<p>Compara el precio por unidad sin impuesto con el registro anterior del mismo proveedor, referencia, unidad y moneda. El costo final también depende de impuestos y transporte.</p>'+(!alerts.length?'<div class="status info">Sin cambios históricos de precio en las cotizaciones consultadas. La primera cotización establece la referencia.</div>':`<div class="table-wrap"><table class="data-table"><thead><tr><th>Artículo / unidad</th><th>Cotización</th><th>Anterior</th><th>Nuevo</th><th>Variación</th></tr></thead><tbody>${alerts.map(a=>`<tr><td>${esc(a.line.description)}<br><small>${esc(a.line.reference)} · ${esc(a.line.unit)}</small></td><td>${esc(a.quote.code)}<br><small>${esc(a.quote.quote_date)} · ${esc(a.quote.currency)}${a.expired?' · Vencida':''}</small><details><summary>Origen</summary>Proveedor: ${esc(a.quote.supplier_id)}<br>Cotización: ${esc(a.quote.id)}</details></td><td>${esc(money(a.previous,a.quote.currency))}</td><td>${esc(money(a.line.unit_price,a.quote.currency))}</td><td><strong>${a.delta>0?'Aumento':'Reducción'}: ${esc(money(Math.abs(a.delta),a.quote.currency))}</strong><br>${a.percent==null?'Base anterior cero':esc(Math.abs(a.percent).toFixed(2))+'%'}</td></tr>`).join('')}</tbody></table></div><p class="muted">Son cambios históricos, no compras aprobadas ni necesariamente precios vigentes. Revise las condiciones y el PDF original en Cotizaciones antes de decidir.</p>`);
   }catch{if(current===generation&&root.isConnected){results.replaceChildren();status.textContent='No se pudo revisar el historial. No se muestran resultados anteriores. Verifique su acceso o vuelva a intentar.'}}
   finally{if(current===generation&&root.isConnected)button.disabled=false}
  };
 }catch{if(root.isConnected){controls.replaceChildren();results.replaceChildren();status.textContent='No se pudieron consultar las sucursales o permisos para revisar precios.'}}
}
