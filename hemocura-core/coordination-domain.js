import { localDay,localDateTime,rdTimestamp } from './workflow-domain.js';
export const ORDER_STATES={PENDIENTE:'Pendiente',EN_GESTION:'En gestión',LISTO:'Listo',COMPLETADO:'Completado',CANCELADO:'Cancelado'};
export const ORDER_NEXT={PENDIENTE:['EN_GESTION','CANCELADO'],EN_GESTION:['LISTO','CANCELADO'],LISTO:['EN_GESTION','COMPLETADO','CANCELADO'],COMPLETADO:[],CANCELADO:[]};
export const CONTACT_STATES={SEGUIMIENTO_VENCIDO:'Seguimiento pendiente',CONTACTAR:'Fecha alcanzada · contactar',SIN_SEGUIMIENTO:'Definir próximo contacto',VERIFICAR_FECHA:'Verificar última donación',ESPERAR:'Esperar intervalo',SEGUIMIENTO_FUTURO:'Seguimiento programado',CON_CITA:'Con cita',PAUSADO:'No desea donar'};
export function plusDays(day,n){return new Date(Date.parse(day+'T12:00:00Z')+n*86400000).toISOString().slice(0,10)}
export function suggestedVisitStart(reference,now=Date.now()){
 const today=localDay(new Date(now));if(reference&&reference>today)return{date:reference,time:'09:00'};
 const local=localDateTime(new Date(now).toISOString()),m=Number(local.slice(11,13))*60+Number(local.slice(14,16)),next=Math.max(540,(Math.floor(m/30)+1)*30);
 return next>=1440?{date:plusDays(today,1),time:'09:00'}:{date:today,time:`${String(Math.floor(next/60)).padStart(2,'0')}:${String(next%60).padStart(2,'0')}`};
}
export function contactQueueState(d,now=Date.now()){
 if(d.last_contact_outcome==='NO_DESEA')return 'PAUSADO';
 if(d.active_visit_id)return 'CON_CITA';
 if(d.next_contact_at)return Date.parse(d.next_contact_at)<=now?'SEGUIMIENTO_VENCIDO':'SEGUIMIENTO_FUTURO';
 if(d.last_contact_id)return 'SIN_SEGUIMIENTO';
 if(!d.last_donation_date||!d.next_donation_date||d.last_donation_date>localDay(new Date(now)))return 'VERIFICAR_FECHA';
 return d.next_donation_date<=localDay(new Date(now))?'CONTACTAR':'ESPERAR';
}
export function donorPhone(value){let p=String(value||'').replace(/\D/g,'');if(p.length===11&&p.startsWith('1'))p=p.slice(1);return /^(809|829|849)\d{7}$/.test(p)?'1'+p:null}
export function donorMessage(d,visit=null,branch='HemoCura'){
 const name=String(d.full_name||'').trim().split(/\s+/)[0];
 return visit?`Hola${name?' '+name:''}, te recordamos tu visita a ${branch} el ${localDateTime(visit.starts_at).replace('T',' a las ')}. ¿Puedes confirmar tu asistencia? Si necesitas cambiarla, indícanos otro horario. Gracias, HemoCura.`:`Hola${name?' '+name:''}, te contactamos desde HemoCura para coordinar una próxima visita de donación. ¿Te gustaría que acordemos una fecha? La donación está sujeta a evaluación clínica. Gracias.`;
}
export function orderDraft(p){
 const units=Number(p.units);if(!Number.isInteger(units)||units<1||units>10000)throw Error('Indique una cantidad entera entre 1 y 10,000.');
 for(const key of ['branch_id','reference','requester','component','responsible','due_at'])if(!String(p[key]||'').trim())throw Error('Complete sucursal, referencia, solicitante, componente, responsable y fecha.');
 return {branch_id:p.branch_id,reference:p.reference.trim(),requester:p.requester.trim(),component:p.component.trim(),units,abo:p.abo||null,rh:p.rh||null,due_at:rdTimestamp(p.due_at),priority:p.priority||'NORMAL',responsible:p.responsible.trim(),notes:p.notes?.trim()||null};
}
export function orderIsOpen(o){return !['COMPLETADO','CANCELADO'].includes(o.status)}
export function orderIsLate(o,now=Date.now()){return orderIsOpen(o)&&Date.parse(o.due_at)<now}
export function slotKey(startsAt,minutes){const l=localDateTime(startsAt);const m=Number(l.slice(11,13))*60+Number(l.slice(14,16));return `${l.slice(0,10)} ${String(Math.floor(m/minutes)*minutes/60|0).padStart(2,'0')}:${String(Math.floor(m/minutes)*minutes%60).padStart(2,'0')}`}
