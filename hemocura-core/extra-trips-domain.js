import {localDay,localDateTime} from './workflow-domain.js';
export const TRIP_STATUS={ENVIADO:'En revisión',DEVUELTO:'Necesita una corrección',APROBADO:'Incentivo aprobado',RECHAZADO:'No aprobado',LIQUIDADO:'Incluido en liquidación',ANULADO:'Anulado'};
export const PURPOSES=[['ENTREGA','Entregar'],['RECOGIDA','Recoger'],['TRASLADO','Trasladar'],['OTRO','Otro motivo']];
export const tripFolio=n=>'VJ-'+String(n||'').padStart(6,'0');
export function nextTripDay(day){const d=new Date(day+'T12:00:00-04:00');d.setUTCDate(d.getUTCDate()+1);return localDay(d)}
export const SCHEDULE_LABELS={DIA_NO_LABORABLE:'Día sin jornada laboral',ANTES_DE_JORNADA:'Antes de las 8:00 a. m.',DESPUES_DE_JORNADA:'Después de terminar la jornada',DENTRO_DE_JORNADA:'Dentro del horario laboral'};
export function tripSchedule(local){const d=new Date(local.slice(0,10)+'T12:00:00Z'),dow=d.getUTCDay()===0?7:d.getUTCDay(),time=local.slice(11,16),end=dow===6?'12:00':'18:00';return {classification:dow===7?'DIA_NO_LABORABLE':time<'08:00'?'ANTES_DE_JORNADA':time>end?'DESPUES_DE_JORNADA':'DENTRO_DE_JORNADA',end:dow===7?null:end};}
export function tripPayload(d,now=new Date()){
 if(!d.branch_id)throw Error('Selecciona tu sucursal.');
 if((d.origin||'').trim().length<2)throw Error('Escribe de dónde saliste.');if((d.destination||'').trim().length<2)throw Error('Escribe adónde fuiste.');
 if(!/^\d{4}-\d{2}-\d{2}$/.test(d.date||'')||!Number.isFinite(Date.parse(d.date+'T12:00:00-04:00'))||localDay(new Date(d.date+'T12:00:00-04:00'))!==d.date)throw Error('Revisa la fecha del viaje.');
 if(!/^([01]\d|2[0-3]):[0-5]\d$/.test(d.departure_time||'')||!/^([01]\d|2[0-3]):[0-5]\d$/.test(d.arrival_time||''))throw Error('Indica la hora de salida y de llegada.');
 const departure_local=d.date+'T'+d.departure_time,arrival_local=(d.next_day?nextTripDay(d.date):d.date)+'T'+d.arrival_time;
 if(arrival_local<=departure_local)throw Error('La llegada debe ser después de la salida. Si llegaste al día siguiente, marca esa opción.');
 if(arrival_local>localDateTime(now).slice(0,16))throw Error('El viaje debe haber terminado. Revisa la fecha y la hora de llegada.');
 if(tripSchedule(arrival_local).classification==='DENTRO_DE_JORNADA')throw Error('Ese viaje terminó dentro del horario laboral. Revisa la hora: lunes a viernes hasta las 6:00 p. m.; sábados hasta las 12:00 del mediodía.');
 if(!PURPOSES.some(([x])=>x===d.purpose))throw Error('Selecciona el motivo del viaje.');
 return {branch_id:d.branch_id,origin:d.origin.trim(),destination:d.destination.trim(),departure_local,arrival_local,purpose:d.purpose,delivery_reference:(d.delivery_reference||'').trim(),note:(d.note||'').trim()};
}
export const tripMonth=t=>localDay(new Date(t.arrival_at)).slice(0,7);
export function tripTotals(rows){return {submitted:rows.filter(r=>r.status==='ENVIADO').length,corrections:rows.filter(r=>r.status==='DEVUELTO').length,approved:rows.filter(r=>r.status==='APROBADO').reduce((s,r)=>s+Math.round(Number(r.amount)*100),0)/100,settled:rows.filter(r=>r.status==='LIQUIDADO').reduce((s,r)=>s+Math.round(Number(r.amount)*100),0)/100};}
export function tripCsv(rows){const cell=v=>'"'+String(v??'').replace(/^[\s]*[=+@-]/,s=>"'"+s).replaceAll('"','""')+'"';return '\ufeff'+[['Folio','Colaborador','Salida RD','Llegada RD','Origen','Destino','Estado','Incentivo DOP','Fin de horario verificado RD','Revisor','Observación','Referencia de liquidación'],...rows.map(r=>[tripFolio(r.trip_no),r.worker_name,localDateTime(r.departure_at),localDateTime(r.arrival_at),r.origin,r.destination,TRIP_STATUS[r.status]||r.status,r.amount??'',r.scheduled_end_at?localDateTime(r.scheduled_end_at):'',r.reviewer_name,r.review_note,r.payroll_reference])].map(r=>r.map(cell).join(',')).join('\r\n');}
