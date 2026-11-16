import {localDateTime} from './workflow-domain.js';
export const openCommitment=visit=>Boolean(visit.commitment&&!visit.commitment_closed_at&&visit.status!=='CANCELADA');
export const overdueCommitment=(visit,date)=>openCommitment(visit)&&Boolean(visit.followup_at&&localDateTime(visit.followup_at).slice(0,10)<date);
export function commercialAgendaSummary(visits,date){return {today:visits.filter(v=>localDateTime(v.scheduled_at).slice(0,10)===date&&v.status!=='CANCELADA').length,pending:visits.filter(openCommitment).length,overdue:visits.filter(v=>overdueCommitment(v,date)).length}}
export function commercialAgendaRows(visits,{date,mode='all',mine=false,userId='',search='',customerName=()=>''}={}){
 const term=search.trim().toLocaleLowerCase('es');
 return visits.filter(v=>(!mine||v.agent_id===userId)&&(!term||[customerName(v.customer_id),v.purpose,v.commitment].join(' ').toLocaleLowerCase('es').includes(term))&&(mode==='all'||mode==='today'&&localDateTime(v.scheduled_at).slice(0,10)===date&&v.status!=='CANCELADA'||mode==='pending'&&openCommitment(v)||mode==='overdue'&&overdueCommitment(v,date)||mode==='done'&&v.status==='REALIZADA')).sort((a,b)=>Number(overdueCommitment(b,date))-Number(overdueCommitment(a,date))||String(a.scheduled_at).localeCompare(String(b.scheduled_at))||String(a.id).localeCompare(String(b.id)));
}
