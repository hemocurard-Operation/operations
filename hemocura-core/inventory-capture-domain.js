import {isBloodComponent} from './blood-component-catalog.js';
export function inventoryBatchPayload(shared,lines){
 if(!shared.branch_id||!/^\d{4}-\d{2}-\d{2}$/.test(shared.count_date||''))throw Error('Selecciona sucursal y fecha del conteo.');
 if(!lines.length||lines.length>50)throw Error('Agrega entre 1 y 50 hemocomponentes y grupos.');
 const seen=new Set();
 return lines.map(line=>{
  if(!isBloodComponent(line.component_name))throw Error('Selecciona un hemocomponente del catálogo.');
  if(!['PENDIENTE',...['A','B','AB','O'].flatMap(a=>['POSITIVO','NEGATIVO'].map(r=>a+'|'+r))].includes(line.group))throw Error('Selecciona el grupo sanguíneo o Pendiente de tipificación.');
  const key=line.component_name+':'+line.group;if(seen.has(key))throw Error('El hemocomponente y grupo están repetidos.');seen.add(key);
  const counts={available_units:Number(line.quantity),quarantine_units:Number(line.quarantine),reserved_units:Number(line.reserved)};
  for(const [key,value] of Object.entries(counts))if(line[{available_units:'quantity',quarantine_units:'quarantine',reserved_units:'reserved'}[key]]===''||!Number.isInteger(value)||value<0||value>1000000)throw Error('Indica cantidades enteras entre 0 y 1,000,000.');
  return {component_name:line.component_name,group_code:line.group,...counts,previous_id:line.previous_id||null};
 });
}
