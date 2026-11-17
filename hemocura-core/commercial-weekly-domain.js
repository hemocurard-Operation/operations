import {localDateTime} from './workflow-domain.js';
const DAY=86400000;
function dayValue(value){if(!/^\d{4}-\d{2}-\d{2}$/.test(value||''))throw Error('Fecha de agenda inválida.');const n=Date.parse(value+'T00:00:00Z');if(!Number.isFinite(n)||new Date(n).toISOString().slice(0,10)!==value)throw Error('Fecha de agenda inválida.');return n}
export function commercialWeek(date){const n=dayValue(date),weekday=new Date(n).getUTCDay(),monday=n-((weekday+6)%7)*DAY;return Array.from({length:7},(_,i)=>new Date(monday+i*DAY).toISOString().slice(0,10))}
export function shiftCommercialWeek(date,offset){return new Date(dayValue(date)+offset*7*DAY).toISOString().slice(0,10)}
export function commercialWeeklyEvents(visits=[],mapVisits=[],customerName=()=> 'Centro no disponible'){
 const event=(kind,v)=>{const local=localDateTime(v.scheduled_at);return {key:kind+':'+v.id,id:v.id,kind,date:local.slice(0,10),time:local.slice(11,16),title:kind==='crm'?v.full_name||'Ficha CRM no disponible':customerName(v.customer_id),purpose:kind==='crm'?v.objective:v.purpose,status:v.status||'Sin estado',owner:v.owner_name||'Responsable asignado',commitment:v.commitment||'',followup:v.followup_at?localDateTime(v.followup_at).replace('T',' '):''}};
 return [...visits.map(v=>event('centro',v)),...mapVisits.map(v=>event('crm',v))].filter(v=>/^\d{4}-\d{2}-\d{2}$/.test(v.date)).sort((a,b)=>(a.date+a.time).localeCompare(b.date+b.time)||a.key.localeCompare(b.key));
}
