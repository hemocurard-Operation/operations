import {localDay} from './workflow-domain.js';
export const labOpen=r=>!['COMPLETADA','CANCELADA','CERRADA','CERRADO','CANCELADO','ACEPTADA','NO_APLICA'].includes(r.status);
export const pendingScreening=r=>['PENDIENTE','REPETIR'].includes(r.status);
export function labSignals(data,today=localDay(),now=Date.now()){
 const rows=k=>data[k]?.rows||[],signals=[];
 const push=(kind,id,title,date,route,critical=false)=>signals.push({kind,id,reference:kind+':'+id,title,date,route,critical});
 rows('screenings').filter(r=>pendingScreening(r)||r.result!=='NO_REACTIVO').forEach(r=>push('TAMIZAJE',r.id,`${r.source_unit_code} · ${r.test_type} · ${r.status} / ${r.result}`,r.screening_date,'screening',r.result==='REACTIVO'));
 rows('equipment').forEach(r=>{for(const [key,label] of [['next_calibration_date','Calibración'],['next_maintenance_date','Mantenimiento']])if(r[key]&&r[key]<=today)push(key,r.id,`${label}: ${r.equipment_code}`,r[key],'resources',r[key]<today);if(['FUERA_SERVICIO','CUARENTENA'].includes(r.status))push('EQUIPO',r.id,`${r.equipment_code} · ${r.status}`,today,'resources',true)});
 rows('reagents').filter(r=>r.expiry_date<today||r.verification_status!=='APROBADO'||Number(r.quantity_available)<=0).forEach(r=>push('LOTE',r.id,`${r.reagent_name} · ${r.lot_number} · ${r.verification_status}`,r.expiry_date,'resources',r.expiry_date<today));
 const devices=new Map(rows('devices').map(r=>[r.id,r]));rows('temperatures').forEach(r=>{const d=devices.get(r.device_id);if(d&&(r.temperature<d.min_temp||r.temperature>d.max_temp))push('TEMPERATURA',r.id,`${d.device_code} · ${r.temperature} °C`,localDay(new Date(r.reading_time)),'coldchain',true)});
 rows('deviations').filter(labOpen).forEach(r=>push('QC',r.id,r.description,r.due_date,'analyticalqc',r.severity==='CRITICA'));
 rows('eqa').filter(r=>!['CERRADO','CANCELADO'].includes(r.status)).forEach(r=>push('EQA',r.id,`${r.event_code} · ${r.result||'PENDIENTE'}`,r.due_date,'analyticalqc',r.result==='NO_SATISFACTORIO'));
 rows('quality').filter(labOpen).forEach(r=>push('RUTINA',r.id,r.title,r.due_at,'bloodquality',r.priority==='CRITICA'));
 rows('tasks').filter(r=>r.area_code==='LABORATORIO'&&labOpen(r)).forEach(r=>push('TAREA',r.id,r.title,r.due_at,'areaagenda',r.priority==='CRITICA'));
 return signals.sort((a,b)=>Number(b.critical)-Number(a.critical)||(a.date||'9999').localeCompare(b.date||'9999'));
}
export function labMetrics(data,today=localDay()){
 const count=(k,fn)=>data[k]?.rows?data[k].rows.filter(fn).length:null;
 return {pending:count('screenings',pendingScreening),quarantine:count('units',r=>r.inventory_status==='CUARENTENA'),review:count('quality',r=>r.status==='EN_REVISION'),tasks:count('tasks',r=>r.area_code==='LABORATORIO'&&labOpen(r)),expired:count('units',r=>r.expiry_date&&r.expiry_date<today&&r.inventory_status!=='DESCARTADA')};
}
export function labReport(data,context){const unavailable=Object.entries(data).filter(([,v])=>v.unavailable).map(([k])=>k);if(unavailable.length)throw Error('Informe incompleto: '+unavailable.join(', '));const metrics=labMetrics(data);return 'INFORME DE GESTIÓN DEL LABORATORIO\nSucursal: '+context.branchName+'\nFecha operativa: '+context.date+' · '+context.shift+'\nConsulta actual: '+context.loadedAt+'\nLos pendientes son el estado actual; no reconstruyen un cierre histórico.\n'+Object.entries(metrics).map(([k,v])=>k+': '+v).join('\n')+'\n\nPRIORIDADES\n'+labSignals(data).map(s=>[s.critical?'CRÍTICA':'SEGUIMIENTO',s.reference,s.title,s.date||'Sin fecha'].join(' | ')).join('\n')+'\n\nEl seguimiento en agenda no cierra la alerta ni libera unidades del proceso de origen.';}
