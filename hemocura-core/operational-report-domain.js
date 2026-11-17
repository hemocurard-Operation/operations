import {isActiveSale,unitSalesSummary} from './unit-sales-domain.js';
// Reject monetary signals instead of presenting an amount as a physical unit.
export function isOperationalSignal(row={}){
 const domain=String(row.domain||row.source_domain||'').toUpperCase();
 if(['FINANZAS','CAJA','COBRANZA','ECONOMIA','ECONÓMICO'].includes(domain))return false;
 return !/(RD\s*\$|US\s*\$|\bUSD\b|\bDOP\b|cobranz|facturad|rentabilidad|saldo\s+vencid|deuda|valor\s+(?:90|30)\s*días|importe\s+monetario)/i.test([row.title,row.description,row.recommended_action].filter(Boolean).join(' '));
}
export function salesQuantities(rows,key){
 const groups=new Map();for(const r of rows){if(!isActiveSale(r))continue;const id=r[key];if(id==null||id==='')continue;if(!groups.has(id))groups.set(id,[]);groups.get(id).push(r)}
 return new Map([...groups].map(([id,items])=>[id,unitSalesSummary(items)]));
}
export function customerUnitSummary(metadata,sales){const quantities=salesQuantities(sales,'customer_id');return metadata.map(r=>({...r,units:quantities.get(r.customer_id)?.units||0,sales_count:quantities.get(r.customer_id)?.sales||0,missing_units:quantities.get(r.customer_id)?.missing||0}))}

export const PLANNING_QUANTITY_METRICS=Object.freeze({UNITS_SOLD:'Unidades vendidas',DONORS_PRESENTED:'Donantes recibidos',DONORS_EFFECTIVE:'Donaciones efectivas',UNITS_PRODUCED:'Unidades producidas',ENDING_INVENTORY:'Inventario final'});
export const isPlanningQuantityMetric=code=>Object.hasOwn(PLANNING_QUANTITY_METRICS,code);
