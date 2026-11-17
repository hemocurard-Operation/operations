import {localDay,localDateTime} from './workflow-domain.js';
export const TRIP_STATUS={ENVIADO:'Pendiente de autorización',DEVUELTO:'Necesita una corrección',APROBADO:'Viaje autorizado',RECHAZADO:'No aprobado',LIQUIDADO:'Incluido en liquidación',ANULADO:'Anulado'};
export const PURPOSES=[['ENTREGA','Entregar'],['RECOGIDA','Recoger'],['TRASLADO','Trasladar'],['OTRO','Otro motivo']];
export const tripFolio=n=>'VJ-'+String(n||'').padStart(6,'0');
export function nextTripDay(day){const d=new Date(day+'T12:00:00-04:00');d.setUTCDate(d.getUTCDate()+1);return localDay(d)}
export const SCHEDULE_LABELS={DIA_NO_LABORABLE:'Día sin jornada laboral',ANTES_DE_JORNADA:'Antes de las 8:00 a. m.',DESPUES_DE_JORNADA:'Después de terminar la jornada',DENTRO_DE_JORNADA:'Dentro del horario laboral'};
export function tripSchedule(local){const d=new Date(local.slice(0,10)+'T12:00:00Z'),dow=d.getUTCDay()===0?7:d.getUTCDay(),time=local.slice(11).split(':'),seconds=Number(time[0])*3600+Number(time[1])*60+Number(time[2]||0),end=dow===6?'12:00':'18:00';return {classification:dow===7?'DIA_NO_LABORABLE':seconds<28800?'ANTES_DE_JORNADA':seconds>(dow===6?43200:64800)?'DESPUES_DE_JORNADA':'DENTRO_DE_JORNADA',end:dow===7?null:end};}
export function tripPayload(d,now=new Date()){
 if(!d.branch_id)throw Error('Selecciona tu sucursal.');
 if((d.origin||'').trim().length<2)throw Error('Escribe de dónde saliste.');if((d.destination||'').trim().length<2)throw Error('Escribe adónde fuiste.');
 if(!/^\d{4}-\d{2}-\d{2}$/.test(d.date||'')||!Number.isFinite(Date.parse(d.date+'T12:00:00-04:00'))||localDay(new Date(d.date+'T12:00:00-04:00'))!==d.date)throw Error('Revisa la fecha del viaje.');
 if(!/^([01]\d|2[0-3]):[0-5]\d$/.test(d.departure_time||'')||!/^([01]\d|2[0-3]):[0-5]\d$/.test(d.arrival_time||''))throw Error('Indica la hora de salida y de llegada.');
 const departure_local=d.date+'T'+d.departure_time,arrival_local=(d.next_day?nextTripDay(d.date):d.date)+'T'+d.arrival_time;
 if(arrival_local<=departure_local)throw Error('La llegada debe ser después de la salida. Si llegaste al día siguiente, marca esa opción.');
 if(arrival_local>localDateTime(now).slice(0,16))throw Error('El viaje debe haber terminado. Revisa la fecha y la hora de llegada.');
 if(!PURPOSES.some(([x])=>x===d.purpose))throw Error('Selecciona el motivo del viaje.');
 return {branch_id:d.branch_id,origin:d.origin.trim(),destination:d.destination.trim(),departure_local,arrival_local,purpose:d.purpose,delivery_reference:(d.delivery_reference||'').trim(),note:(d.note||'').trim()};
}
export const TRIP_TIMING_FILTERS=[['TODOS','Todos los viajes'],['CUALQUIERA_FUERA','Inician o terminan fuera de horario'],['INICIA_FUERA','Inician fuera de horario'],['TERMINA_FUERA','Terminan fuera de horario'],['AMBOS_FUERA','Inician y terminan fuera de horario'],['AMBOS_DENTRO','Inicio y fin dentro de horario']];
function pointSchedule(at){const local=localDateTime(at);if(!local)return null;const d=new Date(at);return tripSchedule(local+':'+String(d.getUTCSeconds()).padStart(2,'0')+'.'+String(d.getUTCMilliseconds()).padStart(3,'0')).classification;}
export function tripTiming(r){const snapshot=r.schedule_snapshot||{};const departure=snapshot.departure?.classification||pointSchedule(r.departure_at),arrival=snapshot.arrival?.classification||snapshot.classification||pointSchedule(r.arrival_at);return {departure,arrival,startOutside:departure?departure!=='DENTRO_DE_JORNADA':null,endOutside:arrival?arrival!=='DENTRO_DE_JORNADA':null};}
export function tripMatchesTiming(r,filter='TODOS'){const t=tripTiming(r);switch(filter){case 'TODOS':return true;case 'CUALQUIERA_FUERA':return t.startOutside===true||t.endOutside===true;case 'INICIA_FUERA':return t.startOutside===true;case 'TERMINA_FUERA':return t.endOutside===true;case 'AMBOS_FUERA':return t.startOutside===true&&t.endOutside===true;case 'AMBOS_DENTRO':return t.startOutside===false&&t.endOutside===false;default:return false;}}
export const tripMonth=t=>localDay(new Date(t.arrival_at)).slice(0,7);
export function tripTotals(rows){return {submitted:rows.filter(r=>r.status==='ENVIADO').length,corrections:rows.filter(r=>r.status==='DEVUELTO').length,approved:rows.filter(r=>r.status==='APROBADO').reduce((s,r)=>s+Math.round(Number(r.amount)*100),0)/100,settled:rows.filter(r=>r.status==='LIQUIDADO').reduce((s,r)=>s+Math.round(Number(r.amount)*100),0)/100};}
export function tripCsv(rows){const cell=v=>'"'+String(v??'').replace(/^[\s]*[=+@-]/,s=>"'"+s).replaceAll('"','""')+'"';return '\ufeff'+[['Folio','Colaborador','Salida RD','Llegada RD','Origen','Destino','Estado','Incentivo fijo DOP','Fin de horario verificado RD','Revisor','Observación','Referencia de liquidación','Horario de salida','Horario de llegada'],...rows.map(r=>[tripFolio(r.trip_no),r.worker_name,localDateTime(r.departure_at),localDateTime(r.arrival_at),r.origin,r.destination,TRIP_STATUS[r.status]||r.status,r.amount??'',r.scheduled_end_at?localDateTime(r.scheduled_end_at):'',r.reviewer_name,r.review_note,r.payroll_reference,SCHEDULE_LABELS[tripTiming(r).departure]||'Sin información',SCHEDULE_LABELS[tripTiming(r).arrival]||'Sin información'])].map(r=>r.map(cell).join(',')).join('\r\n');}
export function tripCalendarMonth(month){
 if(!/^\d{4}-(0[1-9]|1[0-2])$/.test(month))throw Error('Selecciona un mes válido.');
 const [year,m]=month.split('-').map(Number),first=new Date(Date.UTC(year,m-1,1)),days=new Date(Date.UTC(year,m,0)).getUTCDate();
 return {month,days,offset:(first.getUTCDay()+6)%7};
}
export function shiftTripMonth(month,offset){tripCalendarMonth(month);const [year,m]=month.split('-').map(Number),d=new Date(Date.UTC(year,m-1+offset,1));return d.toISOString().slice(0,7)}
export function tripsByArrivalDay(rows,month){const out=new Map();for(const r of rows){const day=localDay(new Date(r.arrival_at));if(day.slice(0,7)!==month)continue;if(!out.has(day))out.set(day,[]);out.get(day).push(r)}return out}
export function fixedTripIncentive(row){if(!['APROBADO','LIQUIDADO'].includes(row.status))return {known:false,amount:null,label:'Pendiente de autorización'};const n=row.amount==null?null:Number(row.amount);return n!==null&&Number.isFinite(n)&&n>0?{known:true,amount:n,label:'Tarifa aplicada'}:{known:false,amount:null,label:'Pendiente de configurar tarifa'};}
