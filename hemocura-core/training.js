import {trainingData} from './training-data.js';
import {loadAccess} from './access-control.js';
import {navigate} from './router.js';
import {consumeTrainingContext} from './training-context.js';
import {trainingEvents,TRAINING_EVENT} from './training-events.js';

const esc=(v='')=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot',"'":'&#039;'}[c]));
const shuffle=a=>{a=[...a];for(let i=a.length-1;i>0;i--){const j=crypto.getRandomValues(new Uint32Array(1))[0]%(i+1);[a[i],a[j]]=[a[j],a[i]]}return a};
const pct=(a,b)=>b?Math.round(100*Number(a||0)/Number(b)):0;

function permissionSet(access){return access?.permissions instanceof Set?access.permissions:new Set(access?.rows?.map(x=>x.permission_code)||[])}
function badge(status){const s=String(status||'').toUpperCase();const cls=['COMPETENTE','VIGENTE','APPROVED','APROBADO'].includes(s)?'ok':['REENTRENAMIENTO','RECERTIFICACION_DUE','POR_VENCER','DRAFT','BORRADOR'].includes(s)?'warn':'bad';return `<span class="status ${cls}">${esc(status||'—')}</span>`}
function nextActionLabel(code){return ({CONTINUAR_MODULOS:'Continuar módulos',PRACTICA_SUPERVISADA:'Práctica supervisada',REALIZAR_EVALUACION:'Realizar evaluación',PENDIENTE_CERTIFICACION:'Pendiente de certificación',VER_COMPETENCIA:'Ver competencia'})[code]||String(code||'Continuar')}

export async function mountTraining(root){
  const access=await loadAccess(),permissions=permissionSet(access),user=await trainingData.currentUser();
  const canAssess=permissions.has('TRAINING_ASSESS'),canAdmin=permissions.has('TRAINING_ADMIN');
  let contextRoute=consumeTrainingContext(),selectedAssignment=null,learnerCatalog=[];

  root.innerHTML=`
  <div class="sales-toolbar"><div><h2 class="section-heading">Mi Capacitación</h2><div class="muted">Puesto → aprendizaje → práctica observada → evaluación → competencia → recertificación.</div></div>
    <div class="dialog-actions"><button class="secondary" data-mode="learner">Mi ruta</button>${canAssess?'<button class="secondary" data-mode="instructor">Instructor</button>':''}${canAdmin?'<button class="secondary" data-mode="admin">Administración</button>':''}</div>
  </div>
  <div id="training-msg"></div><div id="training-root"></div>`;

  const msg=(text,type='warn')=>{document.getElementById('training-msg').innerHTML=text?`<div class="status ${type}">${esc(text)}</div>`:''};
  const area=()=>document.getElementById('training-root');

  async function loadLearner(){
    msg('');learnerCatalog=await trainingData.myCatalog();
    if(!learnerCatalog.length){
      area().innerHTML=`<section class="card"><h3>No hay capacitación asignada</h3><p>El sistema no encontró un <strong>puesto activo</strong> con un programa aprobado para tu perfil.</p><div class="status warn">La capacitación ya no se selecciona manualmente por rol. Calidad o Gerencia Operativa debe asignar el puesto y aprobar el contenido controlado.</div>${canAdmin?'<p class="muted">Como administrador puedes revisar el estado en la pestaña Administración.</p>':''}</section>`;
      return;
    }
    if(contextRoute){const hit=learnerCatalog.find(x=>(x.modules||[]).some(m=>m.route===contextRoute));if(hit)learnerCatalog=[hit,...learnerCatalog.filter(x=>x!==hit)]}
    area().innerHTML=`<div class="grid">${learnerCatalog.map(x=>{const mp=pct((x.assignment_id?1:0),1);return `<section class="card"><div class="status ${x.assignment_id?'ok':'warn'}">${esc(x.assignment_status)}</div><h3>${esc(x.title)}</h3><p>${esc(x.job_role_title)}</p><p class="muted">Crítico: ${esc(x.critical_process)}</p><div class="dialog-actions"><button data-open-program="${x.program_id}">${x.assignment_id?'Continuar':'Comenzar'}</button></div></section>`}).join('')}</div>`;
    area().querySelectorAll('[data-open-program]').forEach(b=>b.onclick=()=>openLearnerProgram(b.dataset.openProgram));
  }

  async function openLearnerProgram(programId){
    const item=learnerCatalog.find(x=>x.program_id===programId);if(!item)return;
    try{
      selectedAssignment=await trainingData.ensureAssignment(item,user.id);
      if(!item.assignment_id){await trainingData.startAssignment(selectedAssignment);trainingEvents.emit('TRAINING_STARTED',{assignmentId:selectedAssignment,programId})}
      const [detail,progress,questions,next]=await Promise.all([trainingData.assignment(selectedAssignment),trainingData.moduleProgress(selectedAssignment),trainingData.questions(programId),trainingData.nextAction(selectedAssignment)]);
      const done=new Set(progress.map(x=>x.module_code)),modules=detail.modules||[],practices=detail.practices||[],micro=detail.microlearning||[];
      const focus=contextRoute?modules.find(x=>x.route===contextRoute)?.code:null;contextRoute='';
      area().innerHTML=`
      <section class="card"><div class="sales-toolbar"><div><h3>${esc(detail.program_title)}</h3><div class="muted">${esc(detail.job_role_title)} · ${esc(detail.critical_process)}</div></div>${badge(detail.status)}</div>
        <div class="grid sales-kpis"><section class="card"><div class="muted">Módulos</div><div class="kpi">${detail.modules_completed}/${detail.modules_total}</div></section><section class="card"><div class="muted">Prácticas</div><div class="kpi">${detail.practices_completed}/${detail.practices_total}</div></section><section class="card"><div class="muted">Mejor nota</div><div class="kpi">${detail.best_score??'—'}${detail.best_score!=null?'%':''}</div></section><section class="card"><div class="muted">Siguiente acción</div><strong>${esc(nextActionLabel(next.next_action))}</strong></section></div>
      </section>
      ${focus?`<div class="status warn">Entraste desde un proceso real. Se resaltó el módulo relacionado con <strong>${esc(focus)}</strong>.</div>`:''}
      <section class="card"><h3>1. Aprendizaje</h3><div id="tr-modules">${modules.map(m=>`<div class="card" data-module-card="${esc(m.code)}" ${m.code===focus?'style="outline:2px solid var(--navy)"':''}><div class="sales-toolbar"><div><strong>${esc(m.code)} · ${esc(m.title)}</strong><div class="muted">Proceso relacionado: ${esc(m.route||'—')}</div></div><div class="dialog-actions">${m.route?`<button class="secondary" data-live-route="${esc(m.route)}">Abrir proceso real</button>`:''}<label><input type="checkbox" data-module="${esc(m.code)}" ${done.has(m.code)?'checked':''}> Completado</label></div></div></div>`).join('')}</div></section>
      <section class="card"><h3>Microentrenamiento</h3><div class="grid">${micro.map(x=>`<section class="card"><strong>${esc(x.title)}</strong><p>${esc(x.content)}</p><div class="status warn">${esc(x.critical)}</div></section>`).join('')}</div></section>
      <section class="card"><h3>2. Práctica supervisada</h3><p class="muted">El participante no puede marcar su propia práctica como competente. Un instructor autorizado debe observarla.</p>${practices.map(p=>`<div class="status ${detail.practices_completed>=detail.practices_total?'ok':'warn'}"><strong>${esc(p.code)}</strong> · ${esc(p.label)}</div>`).join('')}</section>
      <section class="card"><h3>3. Evaluación</h3><p>Umbral de aprobación: <strong>${esc(detail.pass_threshold)}%</strong>.</p><div id="training-quiz"></div><div class="dialog-actions"><button id="training-start-quiz" ${detail.modules_completed<detail.modules_total?'disabled':''}>${detail.modules_completed<detail.modules_total?'Completa los módulos primero':'Iniciar evaluación'}</button></div><div id="training-quiz-msg"></div></section>
      <section class="card"><h3>Necesito ayuda</h3><textarea id="training-tutor-q" placeholder="Describe la tarea o pega el mensaje de error"></textarea><div class="dialog-actions"><button id="training-tutor">Consultar Tutor HemoCura</button><button id="training-exercise" class="secondary">Generar ejercicio</button></div><div id="training-tutor-a"></div></section>`;

      area().querySelectorAll('[data-live-route]').forEach(b=>b.onclick=()=>navigate(b.dataset.liveRoute));
      area().querySelectorAll('[data-module]').forEach(ch=>ch.onchange=async()=>{try{if(ch.checked){await trainingData.completeModule(selectedAssignment,user.id,ch.dataset.module);trainingEvents.emit(TRAINING_EVENT.MODULE_COMPLETED,{assignmentId:selectedAssignment,moduleCode:ch.dataset.module})}else await trainingData.reopenModule(selectedAssignment,ch.dataset.module);await openLearnerProgram(programId)}catch(e){msg(e.message,'bad')}});
      document.getElementById('training-start-quiz').onclick=()=>renderQuiz(questions,detail);
      document.getElementById('training-tutor').onclick=()=>askTutor('tutor',detail.job_role_code);
      document.getElementById('training-exercise').onclick=()=>askTutor('exercise',detail.job_role_code);
    }catch(e){msg(e.message,'bad')}
  }

  function renderQuiz(questions,detail){
    const q=shuffle(questions).slice(0,Math.min(5,questions.length)),startedAt=new Date().toISOString(),host=document.getElementById('training-quiz');
    host.innerHTML=q.map((x,i)=>`<div class="card"><strong>${i+1}. ${esc(x.prompt)}</strong>${(x.options||[]).map((o,j)=>`<label style="display:block;padding:6px"><input type="radio" name="tq${i}" value="${j}"> ${esc(o)}</label>`).join('')}</div>`).join('')+`<button id="training-submit-quiz">Calificar evaluación</button>`;
    document.getElementById('training-submit-quiz').onclick=async()=>{const answers=[];for(let i=0;i<q.length;i++){const a=document.querySelector(`input[name=tq${i}]:checked`);if(!a){document.getElementById('training-quiz-msg').innerHTML='<div class="status warn">Completa todas las preguntas.</div>';return}answers.push({question_id:q[i].id,selected_index:Number(a.value)})}try{const r=await trainingData.submitQuiz(selectedAssignment,answers,startedAt);const row=Array.isArray(r)?r[0]:r;trainingEvents.emit(TRAINING_EVENT.QUIZ_SUBMITTED,{assignmentId:selectedAssignment,score:row.score,passed:row.passed});document.getElementById('training-quiz-msg').innerHTML=`<div class="status ${row.passed?'ok':'warn'}"><strong>${esc(row.score)}%</strong> · ${row.passed?'Evaluación aprobada. La competencia aún requiere práctica observada y certificación.':'Requiere remediación antes del siguiente intento.'}</div>`;if(!row.passed)document.getElementById('training-tutor-a').innerHTML='<div class="status warn">Usa el microentrenamiento y el Tutor HemoCura para repasar antes de repetir.</div>'}catch(e){msg(e.message,'bad')}};
  }

  async function askTutor(action,roleCode){const q=document.getElementById('training-tutor-q').value.trim();if(!q&&action!=='exercise')return;try{const r=await trainingData.tutor(action,roleCode,q||'Genera un ejercicio');const data=r?.data||r;document.getElementById('training-tutor-a').innerHTML=`<div class="status ${data?.error?'warn':'ok'}">${esc(data?.answer||data?.error||'Sin respuesta')}</div>`}catch(e){document.getElementById('training-tutor-a').innerHTML=`<div class="status warn">${esc(e.message)}</div>`}}

  async function loadInstructor(){
    msg('');const rows=await trainingData.instructorQueue();
    area().innerHTML=`<section class="card"><h3>Cola del instructor</h3><div class="table-wrap"><table class="data-table"><thead><tr><th>Persona</th><th>Puesto</th><th>Programa</th><th>Estado</th><th>Prácticas</th><th>Nota</th><th></th></tr></thead><tbody>${rows.length?rows.map(x=>`<tr><td>${esc(x.full_name)}</td><td>${esc(x.job_role_title)}</td><td>${esc(x.program_title)}</td><td>${esc(x.status)}</td><td>${esc(x.competent_practices)}/${esc(x.required_practices)}</td><td>${esc(x.best_passing_score??'—')}</td><td><button data-assess="${x.assignment_id}">Abrir</button></td></tr>`).join(''):'<tr><td colspan="7">No hay personas pendientes.</td></tr>'}</tbody></table></div></section>`;
    area().querySelectorAll('[data-assess]').forEach(b=>b.onclick=()=>openInstructorAssignment(b.dataset.assess));
  }

  async function openInstructorAssignment(id){
    try{const a=await trainingData.assignment(id),tasks=a.practices||[];area().innerHTML=`<section class="card"><h3>${esc(a.full_name)}</h3><p>${esc(a.program_title)} · ${esc(a.job_role_title)}</p><div class="status warn">La práctica debe reflejar observación real. El sistema impide que una persona se certifique a sí misma.</div></section><section class="card"><h3>Práctica observada</h3>${tasks.map(t=>`<div class="card"><strong>${esc(t.code)} · ${esc(t.label)}</strong><div class="grid"><select data-result="${esc(t.code)}"><option value="COMPETENTE">COMPETENTE</option><option value="REQUIERE_SUPERVISION">REQUIERE_SUPERVISION</option><option value="NO_COMPETENTE">NO_COMPETENTE</option></select><input data-evidence="${esc(t.code)}" placeholder="Referencia de evidencia"><input data-notes="${esc(t.code)}" placeholder="Notas"><button data-save-practice="${esc(t.code)}">Guardar observación</button></div></div>`).join('')}</section><section class="card"><h3>Certificación</h3><textarea id="training-final-notes" placeholder="Observaciones finales"></textarea><div class="dialog-actions"><button id="training-finalize">Certificar competencia</button></div><div id="training-final-result"></div></section>`;
      area().querySelectorAll('[data-save-practice]').forEach(b=>b.onclick=async()=>{const code=b.dataset.savePractice;try{await trainingData.observePractice(id,code,document.querySelector(`[data-result="${code}"]`).value,document.querySelector(`[data-evidence="${code}"]`).value,document.querySelector(`[data-notes="${code}"]`).value);trainingEvents.emit(TRAINING_EVENT.PRACTICE_OBSERVED,{assignmentId:id,taskCode:code});msg(`Práctica ${code} registrada.`,'ok')}catch(e){msg(e.message,'bad')}});
      document.getElementById('training-finalize').onclick=async()=>{try{const r=await trainingData.finalize(id,document.getElementById('training-final-notes').value);const row=Array.isArray(r)?r[0]:r;trainingEvents.emit(TRAINING_EVENT.COMPETENCY_CERTIFIED,{assignmentId:id,certificate:row.cert_code});document.getElementById('training-final-result').innerHTML=`<div class="status ok">Competencia certificada: <strong>${esc(row.cert_code)}</strong> · válida hasta ${esc(row.valid_until)}.</div><button id="training-authorize">Autorizar uso del sistema</button>`;document.getElementById('training-authorize').onclick=async()=>{try{await trainingData.authorizeUse(id,`SYSTEM_USE_${a.job_role_code}`,`Autorización de uso de la Suite HemoCura para ${a.job_role_title}. No concede autoridad clínica adicional.`);trainingEvents.emit(TRAINING_EVENT.AUTHORIZATION_GRANTED,{assignmentId:id});msg('Autorización de uso registrada; no modifica autoridad clínica.','ok')}catch(e){msg(e.message,'bad')}}}catch(e){document.getElementById('training-final-result').innerHTML=`<div class="status bad">${esc(e.message)}</div>`}}
    }catch(e){msg(e.message,'bad')}
  }

  async function loadAdmin(){
    msg('');const [version,doc,programs,recert,mgmt,risk]=await Promise.all([trainingData.contentVersion(),trainingData.controlledDocument(),trainingData.programs(),trainingData.recertification(),trainingData.managementInput(),trainingData.criticalRisk()]);
    area().innerHTML=`<div class="grid sales-kpis"><section class="card"><div class="muted">Programas</div><div class="kpi">${programs.length}</div></section><section class="card"><div class="muted">Versión</div><strong>${esc(version.version_code)}</strong><div>${badge(version.status)}</div></section><section class="card"><div class="muted">Documento controlado</div><strong>${esc(doc.document_code)}</strong><div>${badge(doc.status)}</div></section><section class="card"><div class="muted">Alertas altas</div><div class="kpi">${esc(mgmt.high_recertification_alerts??0)}</div></section></div>
    <section class="card"><h3>Gobierno del contenido</h3><p>${esc(version.change_summary)}</p><div class="status warn">El contenido no puede declararse aprobado desde esta pantalla. Primero debe completar el flujo formal en Control Documental.</div><button id="training-docs">Abrir Control Documental</button></section>
    <section class="card"><h3>Riesgo por competencia</h3><div class="table-wrap"><table class="data-table"><thead><tr><th>Competencia</th><th>Brechas</th><th>Riesgo</th></tr></thead><tbody>${risk.length?risk.map(x=>`<tr><td>${esc(x.competency_title)}</td><td>${esc(x.people_with_gap)}</td><td>${esc(x.risk_level)}</td></tr>`).join(''):'<tr><td colspan="3">Sin datos.</td></tr>'}</tbody></table></div></section>
    <section class="card"><h3>Recertificación</h3><div class="table-wrap"><table class="data-table"><thead><tr><th>Persona</th><th>Competencia</th><th>Vence</th><th>Días</th><th>Severidad</th></tr></thead><tbody>${recert.length?recert.map(x=>`<tr><td>${esc(x.full_name)}</td><td>${esc(x.competency_title)}</td><td>${esc(x.valid_until)}</td><td>${esc(x.days_remaining)}</td><td>${esc(x.severity)}</td></tr>`).join(''):'<tr><td colspan="5">Sin alertas.</td></tr>'}</tbody></table></div></section>`;
    document.getElementById('training-docs').onclick=()=>navigate('documents');
  }

  root.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>{root.querySelectorAll('[data-mode]').forEach(x=>x.classList.toggle('active',x===b));if(b.dataset.mode==='learner')loadLearner().catch(e=>msg(e.message,'bad'));if(b.dataset.mode==='instructor')loadInstructor().catch(e=>msg(e.message,'bad'));if(b.dataset.mode==='admin')loadAdmin().catch(e=>msg(e.message,'bad'))});
  await loadLearner();
}
