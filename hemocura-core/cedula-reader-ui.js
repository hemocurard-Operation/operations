import { cedulaCheck, donationInterval, readCedulaImage } from './cedula-reader.js';
import { localDay } from './workflow-domain.js';
import { esc } from './workflow-ui.js';

export function mountCedulaReader(root,{canWrite,lookup,onOpen,onApply}){
 root.innerHTML=`<dialog class="sales-dialog cedula-dialog"><h3>Leer y consultar cédula</h3><p class="muted">Escriba el número o use un escáner que lo envíe como texto y finalice con Enter.</p><form data-id-lookup><label>Número de cédula<input name="cedula" inputmode="numeric" autocomplete="off" maxlength="40" placeholder="000-0000000-0" required></label><button type="submit">Consultar donante</button></form><div data-id-result role="status" aria-live="polite"></div><section class="donor-section"><h4>Leer foto de la cédula</h4><p class="muted">JPG, PNG o WebP, hasta 10 MB. Procesamiento local; la imagen no se guarda.</p><label>Seleccionar imagen<input data-id-file type="file" accept="image/jpeg,image/png,image/webp"></label><div class="donor-actions"><button type="button" class="secondary" data-id-camera>Abrir cámara</button><button type="button" data-id-read disabled>Leer imagen</button></div><div data-id-camera-panel hidden><video data-id-video autoplay playsinline muted></video><div class="donor-actions"><button type="button" data-id-capture>Capturar y leer</button><button type="button" class="secondary" data-id-stop>Cerrar cámara</button></div></div><div data-id-progress role="status" aria-live="polite"></div></section><section class="donor-section" data-id-review hidden><h4>Revisar datos para la ficha</h4><div class="filter-grid"><label>Nombre completo<input data-id-name autocomplete="off"></label><label>Sexo<select data-id-sex><option value="">Pendiente</option><option value="FEMENINO">Femenino</option><option value="MASCULINO">Masculino</option><option value="NO_INFORMADO">No informado</option></select></label><label>Fecha de nacimiento<input data-id-birth type="date" max="${localDay()}"></label></div><div data-id-warnings class="muted"></div><details data-id-text-panel hidden><summary>Texto leído del documento</summary><textarea data-id-text readonly aria-label="Texto leído de la cédula"></textarea></details>${canWrite?'<label class="cedula-confirm"><input data-id-reviewed type="checkbox"> Revisé el número y los datos con la cédula presentada.</label><button type="button" data-id-apply>Usar datos en la ficha</button>':'<p class="muted">Su permiso permite consultar la ficha; guardar requiere permiso de escritura.</p>'}</section><div class="dialog-actions"><button type="button" class="secondary" data-id-close>Cerrar</button></div></dialog>`;
 const q=s=>root.querySelector(s),dialog=q('dialog');let image=null,stream=null,abort=null,reading=false,lookupTicket=0,documentRead=false;
 const number=()=>q('[name=cedula]').value;
 function stopCamera(){stream?.getTracks().forEach(t=>t.stop());stream=null;q('[data-id-video]').srcObject=null;q('[data-id-camera-panel]').hidden=true}
 function progress(text,bad=false){q('[data-id-progress]').innerHTML=`<p class="status ${bad?'bad':'info'}">${esc(text)}</p>`}
 function changed(){lookupTicket++;q('[data-id-result]').innerHTML='';q('[data-id-reviewed]')&&(q('[data-id-reviewed]').checked=false)}
 q('[name=cedula]').oninput=changed;
 for(const selector of ['[data-id-name]','[data-id-sex]','[data-id-birth]'])q(selector).oninput=()=>{if(q('[data-id-reviewed]'))q('[data-id-reviewed]').checked=false};
 async function consult(){
  const check=cedulaCheck(number());const ticket=++lookupTicket;
  q('[data-id-result]').innerHTML='<p class="status info">Consultando ficha y última donación…</p>';
  const record=await lookup(check.number);if(ticket!==lookupTicket||!dialog.open)return null;
  const warning=check.checksumValid?'':'<p class="status warn">El número requiere revisar el dígito verificador con el documento. La consulta no verifica autenticidad ante la JCE.</p>';
  if(!record){q('[data-id-result]').innerHTML=warning+'<p>No hay una ficha visible con esa cédula.</p>';q('[data-id-review]').hidden=false;return null}
  const interval=donationInterval(record);
  const state=interval.state==='SIN_FECHA'?'Última donación no registrada: plazo pendiente de verificar.':interval.state==='FECHA_POR_VERIFICAR'?'La última fecha está en el futuro: requiere corrección.':interval.reached?'Se alcanzaron las 12 semanas. La aptitud para donar requiere revisión clínica.':`Faltan ${interval.remainingDays} días para completar las 12 semanas.`;
  q('[data-id-result]').innerHTML=warning+`<article class="donor-entry"><strong>Coincide con ficha: ${esc(record.full_name||record.donor_code)}</strong><dl class="donor-fields"><div><dt>Última donación</dt><dd>${esc(interval.lastDate||'Sin fecha válida')}</dd></div><div><dt>Días transcurridos</dt><dd>${interval.elapsedDays===null?'Pendiente':esc(interval.elapsedDays)}</dd></div><div><dt>Próxima fecha (84 días)</dt><dd>${esc(interval.nextDate||'Pendiente')}</dd></div><div><dt>Origen</dt><dd>${record.reference_source==='EXCEL_IMPORTADO'?'Antecedente declarado en Excel':record.reference_source==='REGISTRO_HEMOCURA'?'Registro en HemoCura':'Sin fecha de referencia'}</dd></div></dl><p>${esc(state)}</p><button type="button" class="secondary" data-id-open>Abrir ficha</button></article>`;
  q('[data-id-open]').onclick=()=>{dialog.close();onOpen(record)};
  if(!documentRead){q('[data-id-name]').value=record.full_name||'';q('[data-id-sex]').value=record.sex||'';q('[data-id-birth]').value=record.birth_date||''}
  q('[data-id-review]').hidden=false;return record;
 }
 q('[data-id-lookup]').onsubmit=async e=>{e.preventDefault();try{await consult()}catch(e){q('[data-id-result]').innerHTML=`<p class="status bad">${esc(e.message)}</p>`}};
 q('[data-id-file]').onchange=e=>{abort?.abort();image=e.target.files[0]||null;documentRead=false;q('[data-id-read]').disabled=!image;q('[data-id-review]').hidden=true;changed();stopCamera()};
 async function read(){
  if(reading||!image)return;reading=true;abort=new AbortController();q('[data-id-read]').disabled=true;q('[data-id-capture]').disabled=true;
  try{
   const data=await readCedulaImage(image,{signal:abort.signal,onProgress:text=>{if(dialog.open)progress(text)}});
   if(!dialog.open)return;
   documentRead=true;changed();q('[name=cedula]').value=data.cedula;q('[data-id-name]').value=data.full_name;q('[data-id-sex]').value=data.sex;q('[data-id-birth]').value=data.birth_date;
   q('[data-id-review]').hidden=false;q('[data-id-text-panel]').hidden=false;q('[data-id-text]').value=data.text;q('[data-id-warnings]').textContent=data.warnings.join(' ');progress('Lectura terminada. Revise y corrija los datos antes de usarlos.');
   if(data.cedula)await consult();
  }catch(e){if(dialog.open&&e.name!=='AbortError')progress(e.message,true)}finally{reading=false;if(dialog.open){q('[data-id-read]').disabled=!image;q('[data-id-capture]').disabled=false}}
 }
 q('[data-id-read]').onclick=read;
 q('[data-id-camera]').onclick=async()=>{
  try{
   stopCamera();if(!navigator.mediaDevices?.getUserMedia)throw new Error('La cámara requiere un navegador compatible y conexión HTTPS. Puede seleccionar una imagen.');
   const active=await navigator.mediaDevices.getUserMedia({video:{facingMode:{ideal:'environment'},width:{ideal:1920}},audio:false});
   if(!dialog.open){active.getTracks().forEach(t=>t.stop());return}
   stream=active;q('[data-id-video]').srcObject=stream;q('[data-id-camera-panel]').hidden=false;await q('[data-id-video]').play();
  }catch(e){stopCamera();progress(e.name==='NotAllowedError'?'No se concedió permiso para usar la cámara. Puede seleccionar una imagen.':e.message,true)}
 };
 q('[data-id-stop]').onclick=stopCamera;
 q('[data-id-capture]').onclick=async()=>{const video=q('[data-id-video]');if(!video.videoWidth){progress('Espere a que la cámara muestre la imagen.',true);return}const canvas=document.createElement('canvas');canvas.width=video.videoWidth;canvas.height=video.videoHeight;canvas.getContext('2d').drawImage(video,0,0);const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/jpeg',0.9));if(!blob){progress('No se pudo capturar la imagen.',true);return}image=new File([blob],'cedula.jpg',{type:'image/jpeg'});stopCamera();await read()};
 if(canWrite)q('[data-id-apply]').onclick=async()=>{
  const button=q('[data-id-apply]');if(button.disabled)return;
  try{
   const check=cedulaCheck(number());if(!q('[data-id-reviewed]').checked)throw new Error('Confirme que revisó los datos con el documento.');
   const draft={cedula:check.number,full_name:q('[data-id-name]').value.trim(),sex:q('[data-id-sex]').value||'NO_INFORMADO',birth_date:q('[data-id-birth]').value||null};
   if(!draft.full_name)throw new Error('Complete el nombre del donante.');if(draft.birth_date&&draft.birth_date>localDay())throw new Error('La fecha de nacimiento no puede estar en el futuro.');
   button.disabled=true;const record=await lookup(check.number);if(!dialog.open)return;
   dialog.close();onApply(record,draft);
  }catch(e){progress(e.message,true)}finally{button.disabled=false}
 };
 q('[data-id-close]').onclick=()=>dialog.close();
 dialog.addEventListener('close',()=>{lookupTicket++;abort?.abort();stopCamera();image=null;documentRead=false;q('[data-id-file]').value='';q('[data-id-text]').value='';q('[data-id-progress]').innerHTML='';q('[data-id-result]').innerHTML='';q('[data-id-review]').hidden=true;q('[data-id-text-panel]').hidden=true;for(const s of ['[name=cedula]','[data-id-name]','[data-id-birth]'])q(s).value='';q('[data-id-sex]').value='';if(q('[data-id-reviewed]'))q('[data-id-reviewed]').checked=false});
 const observer=new MutationObserver(()=>{if(!root.isConnected){observer.disconnect();abort?.abort();stopCamera();if(dialog.open)dialog.close()}});observer.observe(document.body,{childList:true,subtree:true});
 return {open(){dialog.showModal();q('[name=cedula]').focus()}};
}
