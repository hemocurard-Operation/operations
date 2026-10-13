import { localDay } from './workflow-domain.js';

export function normalizeCedula(value){
 const text=String(value??'').trim();
 if(!/^[0-9\s-]+$/.test(text))throw new Error('Escriba los 11 dígitos de la cédula, con o sin guiones.');
 const number=text.replace(/[\s-]/g,'');
 if(number.length!==11)throw new Error('La cédula debe tener 11 dígitos. No se completan números faltantes.');
 return number;
}
export function cedulaCheck(value){
 const number=normalizeCedula(value);
 const sum=[...number].reduce((s,c,i)=>{let n=Number(c)*(i%2?2:1);return s+(n>9?n-9:n)},0);
 return {number,checksumValid:sum%10===0&&!/^([0-9])\1{10}$/.test(number)};
}
function validDay(value){
 if(!/^\d{4}-\d{2}-\d{2}$/.test(value||''))return null;
 const d=new Date(value+'T00:00:00Z');return Number.isFinite(d.getTime())&&d.toISOString().slice(0,10)===value?value:null;
}
export function donationInterval(record,today=localDay()){
 const current=validDay(today);if(!current)throw new Error('Fecha actual inválida');
 const last=validDay(record?.last_donation_date);
 if(!last)return {state:'SIN_FECHA',lastDate:null,nextDate:null,elapsedDays:null,remainingDays:null,reached:false};
 const elapsed=Math.round((Date.parse(current+'T00:00:00Z')-Date.parse(last+'T00:00:00Z'))/86400000);
 if(elapsed<0)return {state:'FECHA_POR_VERIFICAR',lastDate:last,nextDate:null,elapsedDays:elapsed,remainingDays:null,reached:false};
 const next=new Date(Date.parse(last+'T00:00:00Z')+84*86400000).toISOString().slice(0,10);
 return {state:elapsed>=84?'PLAZO_ALCANZADO':'EN_ESPERA',lastDate:last,nextDate:next,elapsedDays:elapsed,remainingDays:Math.max(0,84-elapsed),reached:elapsed>=84};
}
const MONTHS={ENE:1,ENERO:1,FEB:2,FEBRERO:2,MAR:3,MARZO:3,ABR:4,ABRIL:4,MAY:5,MAYO:5,JUN:6,JUNIO:6,JUL:7,JULIO:7,AGO:8,AGOSTO:8,SEP:9,SEPT:9,SEPTIEMBRE:9,OCT:10,OCTUBRE:10,NOV:11,NOVIEMBRE:11,DIC:12,DICIEMBRE:12};
const upper=s=>String(s).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase();
function parseBirth(s){
 let match=s.match(/\b(\d{4})-(\d{2})-(\d{2})\b/);
 if(match)return validDay(`${match[1]}-${match[2]}-${match[3]}`);
 match=s.match(/\b(\d{1,2})[\s/.-]+([A-Z]+|\d{1,2})[\s/.-]+(\d{4})\b/);
 if(!match)return null;
 const month=MONTHS[match[2]]||Number(match[2]);return validDay(`${match[3]}-${String(month).padStart(2,'0')}-${match[1].padStart(2,'0')}`);
}
export function parseCedulaText(text){
 const raw=String(text||'');const lines=raw.split(/\r?\n/).map(s=>s.trim()).filter(Boolean);
 const candidates=[...new Set((raw.match(/(?<!\d)(?:\d{3}[ -]?\d{7}[ -]?\d|\d{11})(?!\d)/g)||[]).map(s=>s.replace(/[ -]/g,'')))];
 function labelled(labels){
  for(let i=0;i<lines.length;i++){
   const line=upper(lines[i]);const match=line.match(new RegExp(`^(?:${labels})\\s*[:.-]?\\s*(.*)$`));
   if(!match)continue;
   const value=match[1].trim()||upper(lines[i+1]||'');
   if(/^(NOMBRES?|APELLIDOS?|SEXO|FECHA|SANGRE|NACIONALIDAD|LUGAR|ESTADO CIVIL|OCUPACION|CEDULA)\b/.test(value))continue;
   return value;
  }return '';
 }
 const first=labelled('NOMBRES?'),last=labelled('APELLIDOS?');
 const full=labelled('NOMBRE COMPLETO')||[first,last].filter(Boolean).join(' ');
 const sexText=labelled('SEXO|GENERO');const sex=/^(F|FEMENINO)\b/.test(sexText)?'FEMENINO':/^(M|MASCULINO)\b/.test(sexText)?'MASCULINO':'';
 const birth=parseBirth(labelled('FECHA DE NACIMIENTO|FECHA NACIMIENTO|NACIMIENTO'));
 const warnings=[];
 if(candidates.length!==1)warnings.push(candidates.length?'Se detectó más de una cédula. Seleccione y revise el número.':'No se detectó un número de cédula completo.');
 if(!full)warnings.push('No se pudo extraer el nombre con etiquetas claras. Complételo manualmente.');
 if(birth&&birth>localDay())warnings.push('La fecha de nacimiento leída está en el futuro. Revísela.');
 return {cedula:candidates.length===1?candidates[0]:'',candidates,full_name:full,sex,birth_date:birth&&birth<=localDay()?birth:'',warnings};
}
export async function readCedulaImage(file,{signal,onProgress=()=>{}}={}){
 if(!file||!['image/jpeg','image/png','image/webp'].includes(file.type))throw new Error('Use una imagen JPG, PNG o WebP de la cédula.');
 if(file.size>10*1024*1024)throw new Error('La imagen debe pesar menos de 10 MB.');
 if(signal?.aborted)throw new DOMException('Lectura cancelada','AbortError');
 const {default:Tesseract}=await import('../js/vendor/ocr/tesseract.esm.min.js');
 const {createWorker}=Tesseract;
 if(signal?.aborted)throw new DOMException('Lectura cancelada','AbortError');
 let worker;
 const stop=()=>worker?.terminate();
 signal?.addEventListener('abort',stop,{once:true});
 try{
  worker=await createWorker('spa',1,{workerPath:new URL('../js/vendor/ocr/worker.min.js',import.meta.url).href,corePath:new URL('../js/vendor/ocr/core',import.meta.url).href,langPath:new URL('../js/vendor/ocr/lang',import.meta.url).href,workerBlobURL:false,cacheMethod:'none',logger:m=>onProgress(m.status==='recognizing text'?`Leyendo texto: ${Math.round(m.progress*100)}%`:'Preparando lector de cédula…')});
  if(signal?.aborted)throw new DOMException('Lectura cancelada','AbortError');
  const result=await worker.recognize(file);
  if(signal?.aborted)throw new DOMException('Lectura cancelada','AbortError');
  return {...parseCedulaText(result.data.text),text:result.data.text,confidence:result.data.confidence};
 }finally{signal?.removeEventListener('abort',stop);if(worker)await worker.terminate()}
}
