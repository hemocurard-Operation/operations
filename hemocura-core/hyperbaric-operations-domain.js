import {rdTimestamp} from './workflow-domain.js';
export function operationalAppointmentPayload(fields,existing=null){
 const starts_at=rdTimestamp(fields.starts_at),ends_at=rdTimestamp(fields.ends_at);
 if(new Date(ends_at)<=new Date(starts_at))throw Error('La hora final debe ser posterior al inicio');
 if(existing&&(existing.price==null||!Number.isFinite(Number(existing.price))||Number(existing.price)<0||!['USD','DOP'].includes(existing.currency)))throw Error('No fue posible preservar los datos históricos de esta cita. Actualice antes de guardar.');
 return {...fields,starts_at,ends_at,price:existing?existing.price:0,currency:existing?existing.currency:'DOP'};
}
