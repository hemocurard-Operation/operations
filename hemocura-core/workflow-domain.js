// Pure rules shared by operational screens; server-side RPCs enforce authorization independently.
export const BLOOD_GROUPS=['A+','A-','B+','B-','O+','O-','AB+','AB-'];
export const SCREENING_MARKERS=['VIH (Ag/Ac)','HBsAg','Anti-HCV','Sífilis','HTLV I/II','CORE'];
export const PLATFORMS=['AutoLumo','MiniVidas','ELISA'];
export const SHIFTS=['DIURNO','NOCTURNO'];
export const QUALITY_ROUTINES=[
 ['Apertura y relevo','Continuidad'],['Cadena de frío','Almacenamiento y transporte'],
 ['Identificación y trazabilidad','Trazabilidad'],['QC analítico y reactivos','Laboratorio'],
 ['Stock y vencimientos','Suministros'],['Equipos y limpieza','Recursos'],
 ['Despacho y transporte','Despachos'],['Incidentes y hemovigilancia','Seguridad'],
 ['Documentos y competencia','Documentación'],['Conciliación y cierre','Cierre diario']
];
export function localDay(date=new Date()){
 const p=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Santo_Domingo',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(date);
 const get=k=>p.find(x=>x.type===k).value;return `${get('year')}-${get('month')}-${get('day')}`;
}
export function rdTimestamp(value){
 if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value||''))throw new Error('Fecha y hora requeridas');
 const time=new Date(value+'-04:00');if(!Number.isFinite(time.getTime())||localDay(time)!==value.slice(0,10))throw new Error('Fecha y hora inválidas');
 const hours=Number(value.slice(11,13)),minutes=Number(value.slice(14,16));if(hours>23||minutes>59)throw new Error('Hora inválida');return time.toISOString();
}
export function localDateTime(timestamp){if(!timestamp)return '';const d=new Date(timestamp);if(!Number.isFinite(d.getTime()))return '';const p=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Santo_Domingo',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(d);const g=k=>p.find(x=>x.type===k).value;return `${g('year')}-${g('month')}-${g('day')}T${g('hour')}:${g('minute')}`;}
export function nonnegativeInteger(v,label){if(v===null||v===undefined||String(v).trim()===''||!Number.isSafeInteger(Number(v))||Number(v)<0)throw new Error(`${label}: entero no negativo requerido`);return Number(v)}
export function amount(v,label='Importe'){if(v===null||v===undefined||String(v).trim()===''||!Number.isFinite(Number(v))||Number(v)<0)throw new Error(`${label} inválido`);return Math.round(Number(v)*100)/100}
export function validateDailySections(data){
 if(!data.donor_batch?.trim())throw new Error('Lote de captación requerido');
 for(const f of ['accepted','deferred','discarded'])nonnegativeInteger(data[f],f);
 if(!Array.isArray(data.markers)||data.markers.length!==6||new Set(data.markers.map(x=>x.marker)).size!==6)throw new Error('Se requieren seis marcadores distintos');
 for(const m of data.markers){
  if(!SCREENING_MARKERS.includes(m.marker))throw new Error('Marcador inválido');
  for(const k of ['tested','nonreactive','reactive'])nonnegativeInteger(m[k],k);
  const entries=m.platforms===undefined?[m]:m.platforms;
  if(!Array.isArray(entries)||entries.length<1||entries.length>3||new Set(entries.map(x=>x.platform)).size!==entries.length)throw new Error('Plataformas duplicadas o ausentes');
  const totals={tested:0,nonreactive:0,reactive:0};
  for(const row of entries){
   if(!PLATFORMS.includes(row.platform))throw new Error('Plataforma inválida');
   for(const k of Object.keys(totals)){nonnegativeInteger(row[k],k);totals[k]+=Number(row[k])}
   if(Number(row.tested)!==Number(row.nonreactive)+Number(row.reactive))throw new Error(`${m.marker}: pruebas debe coincidir con resultados por plataforma`);
   if(Number(row.tested)>0&&(!row.reagent_lot?.trim()||!row.control_reference?.trim()))throw new Error(`${m.marker} / ${row.platform}: lote de reactivo y control requeridos`);
  }
  if(Object.keys(totals).some(k=>Number(m[k])!==totals[k]))throw new Error(`${m.marker}: total y desglose de plataformas no coinciden`);
 }
 if(!Array.isArray(data.receipts)||data.receipts.length!==8||new Set(data.receipts.map(x=>x.group)).size!==8)throw new Error('Se requieren ocho grupos distintos');
 for(const r of data.receipts){if(!BLOOD_GROUPS.includes(r.group))throw new Error('Grupo inválido');for(const k of ['received','pending','discarded'])nonnegativeInteger(r[k],k);if(r.pending+r.discarded>r.received)throw new Error(`${r.group}: pendientes y descartadas exceden recibidas`)}
 return data;
}
export function appointmentReport(a){
 const start=new Date(a.starts_at);if(!Number.isFinite(start.getTime()))throw new Error('Fecha de cita inválida');
 const parts=new Intl.DateTimeFormat('es-DO',{timeZone:'America/Santo_Domingo',weekday:'long',day:'2-digit',month:'2-digit',year:'numeric'}).formatToParts(start);
 const g=k=>parts.find(x=>x.type===k).value;const dt=localDateTime(a.starts_at);const hour=Number(dt.slice(11,13));
 const time=`${String(hour%12||12).padStart(2,'0')}:${dt.slice(14,16)} ${hour>=12?'pm':'am'}`;
 if(!['USD','DOP'].includes(a.currency))throw new Error('Moneda no admitida');
 return `Asignación de cita- Cámara Hiperbarica\nPaciente: ${a.patient_name}\nTeléfono: ${a.patient_phone}\nHora: ${time}\nDía y Fecha: ${g('weekday')} ${g('day')}/${g('month')}/${g('year')}\nValor: ${amount(a.price)} ${a.currency==='USD'?'dólares':'pesos dominicanos'}\nSesión: ${a.session_label}\nReferidor: ${a.referrer_name}\nNota: ${a.note||''}`;
}
export function summarizeCurrencies(rows){const totals={};for(const r of rows){if(!['USD','DOP'].includes(r.currency))throw new Error('Moneda sin definición');const t=totals[r.currency]??={invoiced:0,paid:0,outstanding:0,records:0};const inv=amount(r.invoiced),paid=amount(r.paid);t.invoiced=Math.round((t.invoiced+inv)*100)/100;t.paid=Math.round((t.paid+paid)*100)/100;t.outstanding=Math.round((t.outstanding+Math.max(inv-paid,0))*100)/100;t.records++}return totals}
export function qualitySummary(tasks,now=new Date()){return {scheduled:tasks.length,required:tasks.filter(x=>x.status!=='NO_APLICA').length,accepted:tasks.filter(x=>x.status==='ACEPTADA').length,notApplicable:tasks.filter(x=>x.status==='NO_APLICA').length,inReview:tasks.filter(x=>x.status==='EN_REVISION').length,overdue:tasks.filter(x=>!['ACEPTADA','NO_APLICA'].includes(x.status)&&new Date(x.due_at)<now).length,criticalOpen:tasks.filter(x=>x.priority==='CRITICA'&&!['ACEPTADA','NO_APLICA'].includes(x.status)).length,onTime:tasks.filter(x=>x.status==='ACEPTADA'&&x.reviewed_at&&new Date(x.reviewed_at)<=new Date(x.due_at)).length}}
export function cycleWeek(cycleStart,date){const start=new Date(cycleStart+'T12:00:00Z'),day=new Date(date+'T12:00:00Z');const delta=Math.floor((day-start)/86400000);return delta<0||delta>=84?null:Math.floor(delta/7)+1}
export function distanceKm(a,b){for(const p of [a,b])if(!p||p.latitude===null||p.longitude===null||p.latitude===''||p.longitude===''||!Number.isFinite(Number(p.latitude))||!Number.isFinite(Number(p.longitude))||Math.abs(Number(p.latitude))>90||Math.abs(Number(p.longitude))>180)return null;const r=Math.PI/180,lat1=Number(a.latitude)*r,lat2=Number(b.latitude)*r,dlat=lat2-lat1,dlon=(Number(b.longitude)-Number(a.longitude))*r;return 6371*2*Math.asin(Math.min(1,Math.sqrt(Math.sin(dlat/2)**2+Math.cos(lat1)*Math.cos(lat2)*Math.sin(dlon/2)**2)))}
export function routeSuggestions(visits,locations,start,now=new Date()){
 return visits.filter(v=>v.status!=='CANCELADA'&&(v.status!=='REALIZADA'||(v.commitment&&!v.commitment_closed_at))).map(v=>{const l=locations.find(l=>l.customer_id===v.customer_id&&l.verified_at);return {...v,location:l||null,km:l?distanceKm(start,l):null,overdue:!!v.followup_at&&new Date(v.followup_at)<now}}).sort((a,b)=>Number(b.overdue)-Number(a.overdue)||(a.km??Infinity)-(b.km??Infinity)||new Date(a.scheduled_at)-new Date(b.scheduled_at));
}
