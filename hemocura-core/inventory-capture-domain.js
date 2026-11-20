import {isBloodComponent} from './blood-component-catalog.js';
function validDay(value){return /^\d{4}-\d{2}-\d{2}$/.test(value||'')&&Number.isFinite(Date.parse(value+'T12:00:00Z'))&&new Date(value+'T12:00:00Z').toISOString().slice(0,10)===value;}
export function inventoryBatchPayload(shared,lines){
 if(!shared.branch_id||!validDay(shared.production_date))throw Error('Selecciona sucursal y fecha de producción válida.');
 const rows=[],codes=new Set();
 if(!lines.length||lines.length>10)throw Error('Agrega entre 1 y 10 filas de hemocomponentes.');
 for(const line of lines){
  if(!isBloodComponent(line.component_name))throw Error('Selecciona un hemocomponente del catálogo de Producción. Los insumos se registran en su inventario.');
  const n=Number(line.quantity);if(!Number.isInteger(n)||n<1||n>50)throw Error('La cantidad debe ser un entero entre 1 y 50.');
  if(rows.length+n>50)throw Error('Puedes registrar hasta 50 unidades por envío.');
  const production=line.production_date||shared.production_date,expiry=line.expiry_date||null;
  if(!validDay(production)||expiry&&(!validDay(expiry)||expiry<production))throw Error('Revisa producción y vencimiento de cada hemocomponente.');
  const pending=line.group==='PENDIENTE';const [abo,rh]=String(line.group||'').split('|');
  if(!pending&&(!['A','B','AB','O'].includes(abo)||!['POSITIVO','NEGATIVO'].includes(rh)))throw Error('Selecciona el grupo sanguíneo o Pendiente de tipificación.');
  if(!Array.isArray(line.units)||line.units.length<n)throw Error('Completa los códigos de cada unidad.');
  for(const unit of line.units.slice(0,n)){
   const code=unit.code?.trim(),source=unit.source?.trim();
   if(!code||!source)throw Error('Completa el código y la unidad de origen de cada unidad.');
   if(codes.has(code))throw Error('Hay códigos de unidad repetidos en la lista.');codes.add(code);
   rows.push({branch_id:shared.branch_id,production_date:production,expiry_date:expiry,component_name:line.component_name,abo:pending?null:abo,rh:pending?null:rh,quantity:1,unit_code:code,source_unit_code:source,screening_status:'PENDIENTE',inventory_status:'CUARENTENA'});
  }
 }
 return rows;
}
