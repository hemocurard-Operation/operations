export function inventoryBatchPayload(shared,lines){
 if(!shared.branch_id||!shared.production_date)throw Error('Selecciona sucursal y fecha de producción.');
 if(shared.expiry_date&&shared.expiry_date<shared.production_date)throw Error('El vencimiento no puede ser anterior a la producción.');
 const rows=[],codes=new Set();
 if(!lines.length)throw Error('Agrega al menos un producto.');
 for(const line of lines){
  if(!line.component_name?.trim())throw Error('Selecciona el producto de cada fila.');
  const n=Number(line.quantity);if(!Number.isInteger(n)||n<1||n>50)throw Error('La cantidad debe ser un entero entre 1 y 50.');
  if(rows.length+n>50)throw Error('Puedes registrar hasta 50 unidades por envío.');
  const [abo,rh]=String(line.group||'').split('|');
  if(!['A','B','AB','O'].includes(abo)||!['POSITIVO','NEGATIVO'].includes(rh))throw Error('Selecciona el grupo sanguíneo de cada producto.');
  if(line.units.length<n)throw Error('Completa los códigos de cada unidad.');
  for(const unit of line.units.slice(0,n)){
   const code=unit.code?.trim(),source=unit.source?.trim();
   if(!code||!source)throw Error('Completa el código y la unidad de origen de cada unidad.');
   if(codes.has(code))throw Error('Hay códigos de unidad repetidos en la lista.');codes.add(code);
   rows.push({...shared,component_name:line.component_name.trim(),...(line.product_id?{product_id:line.product_id}:{}),abo,rh,quantity:1,unit_code:code,source_unit_code:source});
  }
 }
 return rows;
}
