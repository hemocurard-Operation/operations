import {readDocumentImage} from './image-ocr.js';
import {PHOTO_GROUPS,PHOTO_FIELDS,photoKey,parseDailyPhotoText,reviewedInventory,validateDailyPhoto} from './daily-photo-domain.js';
import {dailyPhotoData as api} from './daily-photo-data.js';
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const same=(a,b)=>a.branch===b.branch&&a.date===b.date;
export function mountDailyPhoto(root,{getScope,onApply}){
 const section=document.createElement('section');section.className='card daily-photo';section.innerHTML='<h3>Cargar reporte desde una foto</h3><p>El lector se ejecuta en este dispositivo. La escritura manuscrita puede leerse mal: compare siempre con la imagen. Las casillas no leídas no se convierten en cero.</p><button type="button" data-photo-open>Seleccionar fotografía</button><div data-photo-status role="status" aria-live="polite"></div><div data-photo-history></div><dialog class="sales-dialog" data-photo-dialog aria-label="Revisar fotografía del reporte"></dialog>';
 root.querySelector('.sales-toolbar').after(section);
 const style=document.createElement('link');style.rel='stylesheet';style.href=new URL('../css/daily-photo.css',import.meta.url).href;if(!document.querySelector('[data-daily-photo-style]')){style.dataset.dailyPhotoStyle='';document.head.append(style)}
 const q=s=>section.querySelector(s),dialog=q('dialog');let pending=null,selection=null,url=null,angle=0,abort=null,busy=false,ticket=0;
 const status=text=>{q('[data-photo-status]').textContent=text};
 function dispose(){abort?.abort();abort=null;if(url)URL.revokeObjectURL(url);url=null;selection=null;}
 function hide(){if(busy)abort?.abort();dialog.close();dispose()}
 function editable(){return getScope().editable&&root.isConnected}
 function editor(values={}){
  return `<div class="table-wrap"><table class="data-table"><thead><tr><th>Grupo</th>${PHOTO_FIELDS.map(([,label])=>`<th>${label}</th>`).join('')}</tr></thead><tbody>${PHOTO_GROUPS.map(g=>`<tr><th>${g}</th>${PHOTO_FIELDS.map(([field,label])=>`<td><label><span class="photo-label">${g} · ${label}</span><input data-photo-group="${g}" data-photo-field="${field}" type="number" min="0" max="99999" step="1" inputmode="numeric" placeholder="No leído" value="${values[g]?.[field]??''}"></label></td>`).join('')}</tr>`).join('')}</tbody></table></div>`;
 }
 q('[data-photo-open]').onclick=()=>{
  if(!editable())return;dispose();angle=0;
  dialog.innerHTML=`<h3>Leer fotografía y revisar</h3><p>Contexto: ${esc(getScope().branchName)} · ${esc(getScope().date)}. Se aplicarán únicamente cantidades revisadas al borrador actual.</p><label>Fotografía (JPG, PNG o WebP; máximo 5 MB)<input data-photo-file type="file" accept="image/jpeg,image/png,image/webp"></label><img data-photo-preview alt="Fotografía seleccionada" hidden><div class="dialog-actions"><button type="button" data-photo-rotate disabled>Girar 90°</button><button type="button" data-photo-read disabled>Detectar contenido</button></div><div data-photo-progress role="status" aria-live="polite"></div><div data-photo-review hidden><p>Solo se proponen filas con dos cantidades claramente separadas en «Unidades disponibles». Revise o complete contra la foto. Otros apartados se conservan en el texto detectado; no se importan automáticamente.</p><label>Fecha de la foto<input data-photo-date type="date" required></label><div data-photo-values></div><details><summary>Texto detectado (puede contener errores)</summary><pre data-photo-text></pre></details><label><input data-photo-confirm type="checkbox"> Comprobé la fecha, la sucursal y cada cantidad que voy a aplicar. Las cantidades existentes de esos campos se reemplazarán.</label><button type="button" data-photo-apply>Aplicar cantidades revisadas al borrador</button></div><button type="button" class="secondary" data-photo-cancel>Cancelar</button>`;
  dialog.showModal();q('[data-photo-cancel]').onclick=hide;
  q('[data-photo-file]').onchange=async()=>{
   const my=++ticket;abort?.abort();dispose();q('[data-photo-review]').hidden=true;q('[data-photo-read]').disabled=true;q('[data-photo-rotate]').disabled=true;
   const file=q('[data-photo-file]').files[0];if(!file)return;
   try{const data=await validateDailyPhoto(file);const bitmap=await createImageBitmap(file);const valid=bitmap.width*bitmap.height<=16000000;bitmap.close();if(!valid)throw Error('La foto supera 16 megapíxeles; reduzca su tamaño antes de cargarla.');if(my!==ticket||!dialog.open)return;
    selection={file,...data,scope:{...getScope()}};url=URL.createObjectURL(file);q('[data-photo-preview]').src=url;q('[data-photo-preview]').hidden=false;angle=0;q('[data-photo-preview]').style.transform='';q('[data-photo-read]').disabled=false;q('[data-photo-rotate]').disabled=false;q('[data-photo-progress]').textContent='Oriente la hoja antes de detectar contenido.';
   }catch(e){if(my===ticket)q('[data-photo-progress]').textContent=e.message}
  };
  q('[data-photo-rotate]').onclick=()=>{angle=(angle+90)%360;q('[data-photo-preview]').style.transform=`rotate(${angle}deg)`;q('[data-photo-review]').hidden=true};
  q('[data-photo-read]').onclick=async()=>{
   if(!selection||busy)return;const my=++ticket;busy=true;abort=new AbortController();const controller=abort,timer=setTimeout(()=>controller.abort(),120000);q('[data-photo-read]').disabled=true;q('[data-photo-rotate]').disabled=true;q('[data-photo-file]').disabled=true;q('[data-photo-review]').hidden=true;
   try{
    const bitmap=await createImageBitmap(selection.file),canvas=document.createElement('canvas');const swap=angle%180!==0;canvas.width=swap?bitmap.height:bitmap.width;canvas.height=swap?bitmap.width:bitmap.height;const ctx=canvas.getContext('2d');ctx.translate(canvas.width/2,canvas.height/2);ctx.rotate(angle*Math.PI/180);ctx.drawImage(bitmap,-bitmap.width/2,-bitmap.height/2);bitmap.close();
    const blob=await new Promise(r=>canvas.toBlob(r,'image/png'));canvas.width=canvas.height=0;if(!blob)throw Error('No se pudo preparar la imagen.');
    const result=await readDocumentImage(blob,{signal:controller.signal,onProgress:t=>{if(my===ticket&&dialog.open)q('[data-photo-progress]').textContent=t}});if(my!==ticket||!dialog.open||!root.isConnected)return;
    const parsed=parseDailyPhotoText(result.text);q('[data-photo-values]').innerHTML=editor(parsed.inventory);q('[data-photo-date]').value=parsed.date||'';q('[data-photo-text]').textContent=result.text;q('[data-photo-confirm]').checked=false;q('[data-photo-review]').hidden=false;q('[data-photo-progress]').textContent='Lectura terminada. Todos los valores requieren revisión; una lectura vacía no acredita ausencia de actividad.';
   }catch(e){if(my===ticket&&dialog.open)q('[data-photo-progress]').textContent=controller.signal.aborted?'Lectura cancelada o tiempo agotado. Puede reintentar.':e.message}
   finally{clearTimeout(timer);busy=false;if(dialog.open){q('[data-photo-read]').disabled=false;q('[data-photo-rotate]').disabled=false;q('[data-photo-file]').disabled=false}}
  };
  q('[data-photo-apply]').onclick=()=>{
   try{if(!selection||!editable()||!same(selection.scope,getScope()))throw Error('Cambió la fecha, sucursal o permiso. Vuelva a cargar la foto en el contexto correcto.');if(!q('[data-photo-confirm]').checked||q('[data-photo-date]').value!==getScope().date)throw Error('Confirme la revisión y que la fecha de la foto coincide con el reporte.');
    const values={};section.querySelectorAll('[data-photo-group]').forEach(el=>{(values[el.dataset.photoGroup]??={})[el.dataset.photoField]=el.value});const reviewed=reviewedInventory(values);
    onApply(reviewed);pending={...selection,values:reviewed};status('Cantidades aplicadas al borrador, sin guardar. Complete el reporte y pulse Guardar borrador para adjuntar la foto como respaldo privado.');hide();
   }catch(e){q('[data-photo-progress]').textContent=e.message}
  };
 };
 dialog.addEventListener('cancel',()=>{++ticket;dispose()});dialog.addEventListener('close',()=>{++ticket;dispose()});
 async function refresh(){
  q('[data-photo-open]').disabled=!editable();if(pending&&!same(pending.scope,getScope())){pending=null;status('La foto pendiente se descartó al cambiar fecha o sucursal. Vuelva a cargarla si corresponde.')}
  const scope={...getScope()};q('[data-photo-history]').replaceChildren();if(!scope.id)return;
  try{const photos=await api.list(scope.id);if(!root.isConnected||getScope().id!==scope.id)return;q('[data-photo-history]').innerHTML=photos.map(p=>`<p>${esc(p.file_name)} · Respaldo privado · ${esc(p.recorded_at)} <button type="button" class="secondary" data-view-photo="${esc(p.id)}">Ver imagen</button></p>`).join('');
   section.querySelectorAll('[data-view-photo]').forEach(b=>b.onclick=async()=>{b.disabled=true;try{const data=await api.image(b.dataset.viewPhoto),bytes=Uint8Array.from(atob(data.image_base64),c=>c.charCodeAt(0));const hash=[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(b=>b.toString(16).padStart(2,'0')).join('');if(hash!==data.content_sha256)throw Error('No coincide la integridad de la imagen.');dispose();url=URL.createObjectURL(new Blob([bytes],{type:data.mime_type}));dialog.innerHTML='<h3>Imagen de respaldo</h3><img data-photo-preview alt="Imagen archivada del reporte"><button type="button" data-photo-cancel>Cerrar</button>';q('img').src=url;q('[data-photo-cancel]').onclick=hide;dialog.showModal()}catch(e){status(e.message)}finally{b.disabled=false}});
  }catch{status('No se pudieron consultar los respaldos fotográficos. Actualice para reintentar.')}
 }
 const beforeUnload=e=>{if(pending){e.preventDefault();e.returnValue=''}};window.addEventListener('beforeunload',beforeUnload);
 const observer=new MutationObserver(()=>{if(!root.isConnected){dispose();pending=null;observer.disconnect();window.removeEventListener('beforeunload',beforeUnload)}});observer.observe(document.body,{childList:true,subtree:true});
 return {refresh,beforeLoad(){if(pending){if(same(pending.scope,getScope())&&!confirm('Hay una foto pendiente. ¿Descartar la foto y recargar el reporte?'))return false;pending=null;status('Foto pendiente descartada al recargar o cambiar de contexto.')}return true;},hasPending:()=>!!pending,beforeSave(){if(pending&&(!editable()||!same(pending.scope,getScope())))throw Error('La foto no corresponde al contexto actual. Vuelva a cargarla.');},async afterSave(id){if(!pending)return;try{await api.save(id,pending);pending=null;status('Borrador y fotografía de respaldo guardados.')}catch{throw Error('El borrador se guardó, pero la foto no pudo adjuntarse. Se conserva pendiente: pulse Guardar borrador para reintentar antes de enviar a revisión.')}}};
}
