export const isActiveSale=row=>!['CANCELADA','ANULADA','PENDIENTE'].includes(row.status);
export function filterUnitSales(rows,{branch='',shift='',center='',component=''}={}){
 return rows.filter(r=>isActiveSale(r)&&(!branch||r.branch_id===branch)&&(!shift||r.shift===shift)&&(!center||(r.customer_id||r.center_name)===center)&&(!component||r.component_name===component));
}
export function unitSalesSummary(rows){
 const sales=new Set(),centers=new Set(),missing=new Set();let units=0;
 for(const row of rows){if(!isActiveSale(row))continue;sales.add(row.sale_id);centers.add(row.customer_id||row.center_name);if(!row.line_id||row.quantity===null||row.quantity===undefined){missing.add(row.sale_id);continue}const n=Number(row.quantity);if(!Number.isFinite(n)||n<0)throw Error('Hay una cantidad física inválida en el reporte.');units=Math.round((units+n)*1e6)/1e6;}
 return {units,sales:sales.size,centers:centers.size,missing:missing.size};
}
export function groupUnitSales(rows,key){
 const groups=new Map();for(const row of rows){if(!isActiveSale(row))continue;const value=key(row);if(!groups.has(value))groups.set(value,[]);groups.get(value).push(row)}
 return [...groups].map(([label,items])=>({label,...unitSalesSummary(items)})).sort((a,b)=>b.units-a.units||a.label.localeCompare(b.label));
}
export function unitSalesCsv(rows,branchNames={}){
 const cell=v=>'"'+String(v??'').replace(/^[\s]*[=+@-]/,s=>"'"+s).replaceAll('"','""')+'"';
 const lines=[['Fecha','Sucursal','Turno','Salida','Centro','Componente','ABO','Rh','Unidades'],...rows.filter(isActiveSale).map(r=>[r.sale_date,branchNames[r.branch_id]||'Sucursal no disponible',r.shift,r.sale_code,r.center_name,r.component_name||'Sin detalle',r.abo,r.rh,r.line_id&&r.quantity!=null?r.quantity:'No registrado'])];
 return '\ufeff'+lines.map(r=>r.map(cell).join(',')).join('\r\n');
}
export function previousSalesPeriod(from,to){
 const a=new Date(from+'T00:00:00Z'),b=new Date(to+'T00:00:00Z'),day=86400000;
 if(!Number.isFinite(+a)||!Number.isFinite(+b)||a>b||a.toISOString().slice(0,10)!==from||b.toISOString().slice(0,10)!==to)throw Error('Revise el rango de fechas.');
 const days=Math.round((b-a)/day)+1;
 return {from:new Date(+a-days*day).toISOString().slice(0,10),to:new Date(+a-day).toISOString().slice(0,10),days};
}
export function compareSalesUnits(current,previous){
 const now=unitSalesSummary(current),before=unitSalesSummary(previous),delta=Math.round((now.units-before.units)*1e6)/1e6;
 return {current:now.units,previous:before.units,delta,percent:before.units?Math.round(delta/before.units*1000)/10:null,missing:now.missing+before.missing};
}
