const key = l => JSON.stringify([l.reference.trim().toUpperCase(), l.unit.trim().toUpperCase()]);
export function validateQuotation(q) {
 if(!q.supplier_id || !q.branch_id || !q.code?.trim()) throw Error('Indique sucursal, proveedor y número de cotización.');
 if(!/^\d{4}-\d{2}-\d{2}$/.test(q.quote_date)||!/^\d{4}-\d{2}-\d{2}$/.test(q.valid_until)||q.valid_until<q.quote_date) throw Error('Revise las fechas y la vigencia.');
 if(!['DOP','USD','EUR'].includes(q.currency)) throw Error('Moneda inválida.');
 if(!Array.isArray(q.lines)||!q.lines.length||q.lines.length>100) throw Error('Registre entre 1 y 100 artículos.');
 const seen=new Set();
 for(const l of q.lines){
  if(!l.reference?.trim()||!l.description?.trim()||!l.unit?.trim()) throw Error('Cada artículo requiere referencia común, descripción y unidad.');
  if(seen.has(key(l))) throw Error('Combine las líneas con la misma referencia y unidad.');seen.add(key(l));
  for(const n of ['quantity','unit_price','tax','freight']) if(l[n]===''||!Number.isFinite(Number(l[n]))||Number(l[n])<0||Number(l[n])>1e9) throw Error('Revise cantidades, precios y cargos.');
  if(Number(l.quantity)<=0||Number(l.tax)>100) throw Error('Cantidad positiva e impuesto entre 0 y 100 requeridos.');
 }
 return q;
}
export const unitCost = l => Math.round((Number(l.unit_price)*(1+Number(l.tax)/100)+Number(l.freight)/Number(l.quantity))*1e6)/1e6;
export const quoteTotal = q => q.lines.reduce((n,l)=>n+Math.round(unitCost(l)*Number(l.quantity)*100)/100,0);
export function compareQuotations(quotes,today){
 const history=new Map(),latest=new Map(),alerts=[];
 for(const q of [...quotes].sort((a,b)=>a.recorded_at.localeCompare(b.recorded_at)||a.id.localeCompare(b.id))){
  for(const l of q.lines){const group=JSON.stringify([q.branch_id,q.currency,key(l)]),supplier=JSON.stringify([group,q.supplier_id]);const old=history.get(supplier);
   const row={quote:q,line:l,cost:unitCost(l),expired:q.valid_until<today};
   if(old&&Number(old.line.unit_price)!==Number(l.unit_price)) alerts.push({ ...row,previous:Number(old.line.unit_price),delta:Number(l.unit_price)-Number(old.line.unit_price),percent:Number(old.line.unit_price)===0?null:(Number(l.unit_price)/Number(old.line.unit_price)-1)*100 });
   history.set(supplier,row);latest.set(supplier,row);
  }
 }
 const groups=new Map();for(const row of latest.values()){const k=JSON.stringify([row.quote.branch_id,row.quote.currency,key(row.line)]);if(!groups.has(k))groups.set(k,[]);groups.get(k).push(row)}
 return {groups:[...groups.values()].map(rows=>rows.sort((a,b)=>Number(a.expired)-Number(b.expired)||a.cost-b.cost)),alerts:alerts.reverse()};
}
