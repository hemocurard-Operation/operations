import {confirmDiscardProgress} from './progress-protection.js';
import {uatData} from './uat-data.js';
import {loadAccess} from './access-control.js';
import {esc,field,table} from './workflow-ui.js';
export async function mountUat(root){
 const access=await loadAccess(),userId=access.context?.user_id,canManage=access.permissions.has('UAT_MANAGE');
 let selected='',busy=false,generation=0;
 root.innerHTML=`<div class="release-workspace"><div class="sales-toolbar"><div><h2>Validación UAT · Santiago</h2><p class="muted">Registre lo observado y su evidencia. Las simulaciones no habilitan producción.</p></div><button data-uat-refresh class="secondary">Actualizar</button></div><div data-uat-message role="status" aria-live="polite"></div><div data-uat-content>Cargando…</div><dialog data-uat-dialog class="sales-dialog"></dialog></div>`;
 const content=root.querySelector('[data-uat-content]'),message=root.querySelector('[data-uat-message]'),dialog=root.querySelector('dialog');
 const tell=(text,bad=false)=>{message.className='status '+(bad?'bad':'ok');message.textContent=text};
 async function action(button,fn){if(busy)return;busy=true;button.disabled=true;const label=button.textContent;button.textContent='Guardando…';try{const result=await fn();tell(result||'Registro guardado y auditado.');await draw()}catch(e){tell(e.message,true)}finally{busy=false;if(button.isConnected){button.disabled=false;button.textContent=label}}}
 async function draw(){
  const ticket=++generation;
  try{
   const [cases,runs]=await Promise.all([uatData.cases(),uatData.runs()]);
   if(!runs.some(r=>r.id===selected))selected=runs[0]?.id||'';
   const run=runs.find(r=>r.id===selected),results=run?await uatData.results(run.id):[];
   if(ticket!==generation)return;
   const editable=canManage&&run?.status==='EN_CURSO'&&run?.tester_user_id===userId;
   content.innerHTML=`${canManage?`<details class="card"><summary><strong>Iniciar validación</strong></summary><form data-uat-start class="wf-form"><div class="filter-grid">${field('code','Identificador de ejecución','text','PRUEBA-STI-'+Date.now())}${field('version','Versión objetivo','text','1.0.0')}<label><input type="checkbox" name="practice" checked> Práctica con usuarios de prueba (no habilita producción)</label></div><p class="muted">No incluya nombres ni información clínica de pacientes en la evidencia.</p><button type="submit">Crear ejecución</button></form></details>`:''}
   <section class="card">${field('run','Ejecución','select',selected,{required:false,items:[['','Sin ejecuciones'],...runs.map(r=>[r.id,r.run_code+' · '+r.release_version+' · '+r.status])]})}${run?`<p><strong>${esc(run.release_version.startsWith('PRUEBA:')?'SIMULACIÓN DE PRÁCTICA':'VALIDACIÓN FORMAL')}</strong> · ${esc(run.status)}</p>`:'<p>Sin ejecuciones UAT. Un responsable autorizado debe iniciar la validación.</p>'}</section>
   <section class="card"><h3>Casos y evidencias</h3>${table(['Prueba','Pasos y resultado esperado','Resultado','Acción'],cases.map(c=>{const result=results.find(r=>r.test_case_id===c.id);return [`<strong>${esc(c.test_code)}</strong><br>${esc(c.title)}${c.critical?'<br><span class="state-pill state-warn">Crítica</span>':''}`,`<details><summary>Ver instrucciones</summary><p>${esc(c.steps)}</p><p>${esc(c.expected_result)}</p></details>`,`${esc(result?.result||'NOT_RUN')}<br><small>${esc(result?.actual_result||'')}<br>${esc(result?.evidence_reference||'')}</small>`,editable?`<button type="button" data-uat-case="${esc(c.id)}" class="secondary">Registrar resultado</button>`:'Solo lectura']}))}</section>
   ${editable?'<section class="card"><form data-uat-complete>'+field('summary','Resumen de la validación','textarea','')+'<button type="submit">Cerrar y evaluar ejecución</button><p class="muted">Una prueba sin ejecutar o sin evidencia impide cerrar con PASS.</p></form></section>':''}`;
   content.querySelector('[name=run]').onchange=e=>{if(!confirmDiscardProgress()){e.target.value=selected;return}selected=e.target.value;draw()};
   content.querySelector('[data-uat-start]')?.addEventListener('submit',e=>{e.preventDefault();const f=e.target,d=new FormData(f);action(f.querySelector('button'),async()=>{selected=await uatData.start(String(d.get('code')).trim(),(d.has('practice')?'PRUEBA:':'')+String(d.get('version')).trim());f.reset();return 'Ejecución creada. Registre cada caso con evidencia.'})});
   content.querySelector('[data-uat-complete]')?.addEventListener('submit',e=>{e.preventDefault();const f=e.target;action(f.querySelector('button'),async()=>{const state=await uatData.complete(selected,new FormData(f).get('summary'));f.reset();return 'Ejecución cerrada: '+state})});
   content.querySelectorAll('[data-uat-case]').forEach(button=>button.onclick=()=>{
    const c=cases.find(c=>c.id===button.dataset.uatCase),old=results.find(r=>r.test_case_id===c.id);
    dialog.innerHTML=`<form><h3>${esc(c.test_code)} · ${esc(c.title)}</h3>${field('result','Resultado','select',old?.result||'NOT_RUN',{items:['NOT_RUN','PASS','FAIL','BLOCKED']})}${field('actual','Resultado observado','textarea',old?.actual_result||'')}${field('evidence','Referencia de evidencia','text',old?.evidence_reference||'',{required:false})}<p class="muted">Para PASS se exige evidencia verificable. No copie datos personales de pacientes.</p><div class="dialog-actions"><button type="button" data-uat-cancel class="secondary">Cancelar</button><button type="submit">Guardar resultado</button></div></form>`;
    const form=dialog.querySelector('form'),evidence=form.elements.evidence;const required=()=>{evidence.required=form.elements.result.value==='PASS'};form.elements.result.onchange=required;required();
    dialog.querySelector('[data-uat-cancel]').onclick=()=>dialog.close();form.onsubmit=e=>{e.preventDefault();action(form.querySelector('[type=submit]'),async()=>{const d=Object.fromEntries(new FormData(form));await uatData.record(run.id,c.id,d);form.reset();dialog.close()})};dialog.showModal();
   });
  }catch(e){content.innerHTML='<section class="card">No se pudo cargar la validación. Puede reintentar con Actualizar.</section>';tell(e.message,true)}
 }
 root.querySelector('[data-uat-refresh]').onclick=()=>{if(confirmDiscardProgress())draw()};await draw();
}
