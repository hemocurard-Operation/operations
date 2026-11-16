import {isActiveSale,unitSalesSummary} from './unit-sales-domain.js';
const DAY=86400000;
export function insightDay(day,offset=0){
 if(!/^\d{4}-\d{2}-\d{2}$/.test(String(day)))throw Error('Fecha de corte inválida.');
 const date=new Date(day+'T00:00:00Z');if(!Number.isFinite(date.valueOf())||date.toISOString().slice(0,10)!==day)throw Error('Fecha de corte inválida.');
 return new Date(date.valueOf()+offset*DAY).toISOString().slice(0,10);
}
export function insightWindow(asOf){return {from:insightDay(asOf,-89),to:insightDay(asOf),recentFrom:insightDay(asOf,-29),previousFrom:insightDay(asOf,-59),previousTo:insightDay(asOf,-30),forecastFrom:insightDay(asOf,1),forecastTo:insightDay(asOf,30)}}
const round=n=>Math.round(n*10)/10;
function metrics(rows,w){
 const summary=unitSalesSummary(rows),recent=unitSalesSummary(rows.filter(r=>r.sale_date>=w.recentFrom)),previous=unitSalesSummary(rows.filter(r=>r.sale_date>=w.previousFrom&&r.sale_date<=w.previousTo));
 const known=rows.filter(r=>r.line_id&&r.quantity!=null&&Number(r.quantity)>0),days=new Set(known.map(r=>r.sale_date)).size,last=known.map(r=>r.sale_date).sort().at(-1)||null;
 return {...summary,recentUnits:recent.units,previousUnits:previous.units,changePct:previous.units>0?round((recent.units-previous.units)/previous.units*100):null,recordedDays:days,reference30:days>=3?round(summary.units/90*30):null,lastDate:last,daysSinceLast:last?Math.round((Date.parse(w.to)-Date.parse(last))/DAY):null};
}
export function commercialInsights(rows,{asOf,branch='',center='',component=''}={}){
 const window=insightWindow(asOf),visible=rows.filter(r=>isActiveSale(r)&&r.sale_date>=window.from&&r.sale_date<=window.to&&(!branch||r.branch_id===branch)&&(!center||(r.customer_id||r.center_name)===center)&&(!component||r.component_name===component));
 const group=(key,name)=>{const groups=new Map();for(const row of visible){const id=key(row);if(!groups.has(id))groups.set(id,[]);groups.get(id).push(row)}return [...groups].map(([id,rs])=>({id,name:name(rs[0]),...metrics(rs,window)})).sort((a,b)=>b.recentUnits-a.recentUnits||b.units-a.units||String(a.name).localeCompare(String(b.name)))};
 const centers=group(r=>r.customer_id||r.center_name,r=>r.center_name||'Centro no registrado'),components=group(r=>r.component_name||'',r=>r.component_name||'Sin detalle');
 return {window,...metrics(visible,window),centers,components,reactivation:centers.filter(c=>c.units>0&&c.recentUnits===0).sort((a,b)=>b.units-a.units)};
}
export function opportunityStages(opportunities,{branch='',center=''}={}){
 const stages=['PROSPECTO','CONTACTO','PROPUESTA','NEGOCIACION','GANADA','PERDIDA'],scoped=opportunities.filter(o=>(!branch||o.branch_id===branch)&&(!center||o.customer_id===center));
 return stages.map(stage=>({stage,count:scoped.filter(o=>o.stage===stage).length}));
}
export function opportunityPlan(opportunities,{asOf,branch='',center=''}={}){
 const w=insightWindow(asOf),open=opportunities.filter(o=>['PROSPECTO','CONTACTO','PROPUESTA','NEGOCIACION'].includes(o.stage)&&(!branch||o.branch_id===branch)&&(!center||o.customer_id===center));
 const hasQuantity=o=>o.target_units!=null&&Number.isFinite(Number(o.target_units))&&Number(o.target_units)>0;
 const planned=open.filter(o=>hasQuantity(o)&&o.target_date>=w.forecastFrom&&o.target_date<=w.forecastTo);
 return {bloodUnits:round(planned.filter(o=>o.service_type==='SANGRE').reduce((n,o)=>n+Number(o.target_units),0)),sessions:round(planned.filter(o=>o.service_type==='CAMARA_HIPERBARICA').reduce((n,o)=>n+Number(o.target_units),0)),planned:planned.length,undocumented:open.filter(o=>!hasQuantity(o)||!o.target_date).length,overdue:open.filter(o=>o.target_date&&o.target_date<asOf).length};
}
export function commercialInsightsCsv(insights){
 const cell=v=>'"'+String(v??'Sin base suficiente').replace(/^[\s]*[=+@-]/,s=>"'"+s).replaceAll('"','""')+'"';
 const header=['Tipo','Centro o componente','Unidades históricas 90 días','Unidades últimos 30 días','Unidades 30 días previos','Referencia histórica próximos 30 días (no compromiso)','Días con entregas','Última entrega','Corte','Inicio proyección','Fin proyección'];
 const row=(type,r)=>[type,r.name,r.units,r.recentUnits,r.previousUnits,r.reference30,r.recordedDays,r.lastDate,insights.window.to,insights.window.forecastFrom,insights.window.forecastTo];
 return '\ufeff'+[header,...insights.centers.map(r=>row('Centro',r)),...insights.components.map(r=>row('Componente',r))].map(r=>r.map(cell).join(',')).join('\r\n');
}
