export const PHOTO_GROUPS=['A+','A-','B+','B-','O+','O-','AB+','AB-'];
export const PHOTO_FIELDS=[['whole_blood','Sangre total','whole'],['packed_cells','Paquete globular','packed']];
export const photoKey=g=>g.replace('+','p').replace('-','n');
export function parseDailyPhotoText(text){
 const normalized=String(text||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase();
 const date=normalized.match(/\bFECHA\s*[:.-]?\s*(\d{1,2})[ /.-](\d{1,2})[ /.-](\d{2}|\d{4})\b/);
 let day=null;if(date){const y=date[3].length===2?'20'+date[3]:date[3];const d=`${y}-${date[2].padStart(2,'0')}-${date[1].padStart(2,'0')}`;const dt=new Date(d+'T00:00:00Z');if(Number.isFinite(dt.getTime())&&dt.toISOString().slice(0,10)===d)day=d}
 const inventory={};const headings=[...normalized.matchAll(/UNIDADES\s+DISPONIBLES/g)];const start=headings.length===1?headings[0].index:-1;
 // No column guessing: only complete two-number rows inside the named inventory section.
 if(start>=0){const section=normalized.slice(start).split(/FUNCIONAMIENTO|PAQUETES RECIBIDOS|RESULTADOS|COMENTARIOS?/)[0];
  for(const line of section.split(/\r?\n/)){
   const m=line.trim().match(/^(AB|A|B|O)\s*([+-])\s*[|:]?\s+(\d{1,5})\s*[|]?\s+(\d{1,5})\s*[|]?\s*$/);
   if(m){const group=m[1]+m[2];if(group in inventory)inventory[group]=null;else inventory[group]={whole_blood:Number(m[3]),packed_cells:Number(m[4])}}
  }
 }
 return {date:day,inventory};
}
export function reviewedInventory(values){
 const result={};for(const group of PHOTO_GROUPS)for(const [field] of PHOTO_FIELDS){const raw=String(values[group]?.[field]??'').trim();if(!raw)continue;if(!/^\d{1,5}$/.test(raw))throw Error('Las cantidades revisadas deben ser enteros de 0 a 99999.');(result[group]??={})[field]=Number(raw)}
 if(!Object.keys(result).length)throw Error('Revise al menos una cantidad. Las casillas vacías no se importan.');return result;
}
export async function validateDailyPhoto(file){
 if(!file||!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size<12||file.size>5*1024*1024)throw Error('Seleccione una foto JPG, PNG o WebP de hasta 5 MB.');
 const bytes=new Uint8Array(await file.arrayBuffer());const hex=[...bytes.slice(0,8)].map(b=>b.toString(16).padStart(2,'0')).join('');
 const ok=file.type==='image/jpeg'?hex.startsWith('ffd8ff'):file.type==='image/png'?hex==='89504e470d0a1a0a':new TextDecoder().decode(bytes.slice(0,4))==='RIFF'&&new TextDecoder().decode(bytes.slice(8,12))==='WEBP';
 if(!ok)throw Error('El contenido no corresponde al formato de imagen indicado.');
 return {hash:[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(b=>b.toString(16).padStart(2,'0')).join(''),bytes};
}
