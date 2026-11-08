import {localDay} from './workflow-domain.js';
// Inventory units are dispatched whole. Server validation remains authoritative.
export function eligibleOutputUnits(units,branch,day=localDay()){
 return units.filter(u=>(!branch||u.branch_id===branch)&&u.expiry_date&&u.expiry_date>=day&&Number.isFinite(Number(u.quantity))&&Number(u.quantity)>0);
}
export function outputPayload(fields,unit,day=localDay()){
 if(!unit||!eligibleOutputUnits([unit],fields.branch_id,day).length)throw new Error('Seleccione una unidad vigente de la sucursal indicada.');
 if(!fields.sale_code?.trim()||!fields.customer_id||!fields.treating_doctor?.trim()||!fields.sale_date||!['DIURNO','NOCTURNO'].includes(fields.shift))throw new Error('Complete código, fecha, centro, médico y turno.');
 return {header:{sale_code:fields.sale_code.trim(),sale_date:fields.sale_date,branch_id:unit.branch_id,customer_id:fields.customer_id,shift:fields.shift,treating_doctor:fields.treating_doctor.trim(),request_number:fields.request_number?.trim()||null,patient_code:fields.patient_code?.trim()||null,notes:fields.notes?.trim()||null,status:'DESPACHADA',invoice_number:null,total_amount:0,collected_amount:0},lines:[{blood_inventory_unit_id:unit.id,quantity:Number(unit.quantity),unit_price:0}]};
}
export function outputSummary(rows,lines){
 const active=new Set(rows.filter(r=>r.status!=='CANCELADA').map(r=>r.id));
 return {records:active.size,units:lines.filter(l=>active.has(l.sale_id)).reduce((sum,l)=>sum+Number(l.quantity||0),0),centers:new Set(rows.filter(r=>active.has(r.id)).map(r=>r.customer_id).filter(Boolean)).size};
}
