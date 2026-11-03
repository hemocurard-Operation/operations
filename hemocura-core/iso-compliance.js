import {isoComplianceData,isoFrameworks,isoStatuses} from './iso-compliance-data.js';
import {qualityPeople} from './quality-data.js';
import {getBranches} from './sales-data.js';
import {loadAccess} from './access-control.js';
import {esc as e,table,field,downloadText} from './workflow-ui.js';

function statusLabel(s){return ({CUMPLE:'Cumple',PARCIAL:'Cumplimiento parcial',NO_CUMPLE:'No cumple',NO_APLICA:'No aplica',PENDIENTE:'Pendiente de evaluar'})[s]||s}
function statusTone(s){return ({CUMPLE:'ok',PARCIAL:'warn',NO_CUMPLE:'bad',NO_APLICA:'info',PENDIENTE:'info'})[s]||'info'}
function fmtDate(d){return d||'Sin fecha'}
function today(){return new Date().toISOString().slice(0,10)}

export async function mountIsoCompliance(root){
  root.innerHTML='<section class="card"><div class="status info">Cargando checklist de cumplimiento ISO…</div></section>';
  let branches,access;
  try{[branches,access]=await Promise.all([getBranches(),loadAccess()])}
  catch(err){root.innerHTML=`<section class="card"><div class="status bad">${e(err.message)}</div></section>`;return}
  const write=access.permissions.has('ISO_COMPLIANCE_WRITE');
  const branchName=id=>branches.find(b=>b.id===id)?.name||'Corporativo';

  let catalog=[],assessmentsByCriterion={},summary=[];
  let framework=isoFrameworks[0];
  let scope=''; // '' = corporativo (branch_id null)

  function row(c){
    const a=assessmentsByCriterion[c.id];
    const status=a?.status||'PENDIENTE';
    const canCreateNc=write&&status==='NO_CUMPLE'&&!a?.nonconformity_id;
    return [
      `${e(c.clause_reference)}<div class="muted">${e(c.process_area||'')}</div>`,
      e(c.criterion_summary),
      `<span class="status ${statusTone(status)}">${e(statusLabel(status))}</span>`,
      e(a?.responsible_user_id?'Asignado':'Sin responsable'),
      `${fmtDate(a?.last_reviewed_at?.slice(0,10))} → ${fmtDate(a?.next_review_date)}`,
      write?`<div class="quick-links"><button class="secondary compact" data-assess="${e(c.id)}">Evaluar</button>${a?`<button class="secondary compact" data-evidence="${e(a.id)}">Evidencia</button>`:''}${canCreateNc?`<button class="secondary compact" data-nc="${e(a.id)}">Crear NC</button>`:''}</div>`:(a?`<button class="secondary compact" data-evidence="${e(a.id)}">Evidencia</button>`:'—')
    ];
  }

  function kpis(){
    const s=summary.find(x=>x.framework===framework)||{};
    const n=k=>s[k]??0;
    return `<div class="grid sales-kpis">
      <section class="card"><div class="muted">Cláusulas</div><div class="kpi">${n('clauses_total')}</div></section>
      <section class="card"><div class="muted">Cumple</div><div class="kpi">${n('compliant')}</div></section>
      <section class="card"><div class="muted">Parcial</div><div class="kpi">${n('partial')}</div></section>
      <section class="card"><div class="muted">No cumple</div><div class="kpi">${n('non_compliant')}</div></section>
      <section class="card"><div class="muted">Pendiente</div><div class="kpi">${n('pending')}</div></section>
      <section class="card"><div class="muted">Revisión vencida</div><div class="kpi">${n('overdue_review')}</div></section>
    </div>`;
  }

  function draw(){
    const rows=catalog.filter(c=>c.framework===framework);
    root.innerHTML=`
      <div class="sales-toolbar"><div><h2 class="section-heading">Cumplimiento ISO 9001 / ISO 15189</h2><div class="muted">Autoevaluación continua por cláusula, con evidencia y vínculo a no conformidades. Nota: esto no certifica cumplimiento normativo; documenta el estado interno registrado.</div></div><button id="iso-export" class="secondary">Exportar</button></div>
      <div id="iso-msg"></div>
      <nav class="qms-tabs" aria-label="Norma">${isoFrameworks.map(f=>`<button type="button" data-fw="${e(f)}" aria-pressed="${f===framework}">${e(f)}</button>`).join('')}</nav>
      <form id="iso-scope" class="card filter-grid">
        <label>Ámbito<select id="iso-scope-select"><option value="">Corporativo</option>${branches.map(b=>`<option value="${e(b.id)}" ${scope===b.id?'selected':''}>${e(b.name)}</option>`).join('')}</select></label>
      </form>
      ${kpis()}
      ${table(['Cláusula','Descripción','Estado','Responsable','Última / próxima revisión','Acciones'],rows.map(row))}
      <dialog id="iso-dialog" class="sales-dialog"></dialog>
    `;
    root.querySelectorAll('[data-fw]').forEach(b=>b.onclick=()=>{framework=b.dataset.fw;draw()});
    root.querySelector('#iso-scope-select').onchange=ev=>{scope=ev.target.value;load()};
    root.querySelector('#iso-export').onclick=()=>{
      const csv=['framework,clausula,descripcion,estado,ultima_revision,proxima_revision'].concat(
        catalog.filter(c=>c.framework===framework).map(c=>{
          const a=assessmentsByCriterion[c.id];
          return [c.framework,c.clause_reference,`"${(c.criterion_summary||'').replace(/"/g,'""')}"`,a?.status||'PENDIENTE',a?.last_reviewed_at?.slice(0,10)||'',a?.next_review_date||''].join(',');
        })
      ).join('\n');
      downloadText(`cumplimiento-${framework.replace(/\s+/g,'-')}-${today()}.csv`,csv);
    };
    root.querySelectorAll('[data-assess]').forEach(b=>b.onclick=()=>openAssess(b.dataset.assess));
    root.querySelectorAll('[data-evidence]').forEach(b=>b.onclick=()=>openEvidence(b.dataset.evidence));
    root.querySelectorAll('[data-nc]').forEach(b=>b.onclick=()=>openNc(b.dataset.nc));
  }

  function dialogShell(title,content){
    const d=root.querySelector('#iso-dialog');
    d.innerHTML=`<form><h3>${e(title)}</h3>${content}<p data-dialog-error role="alert"></p><div class="dialog-actions"><button type="button" data-close class="secondary">Cerrar</button><button type="submit">Guardar</button></div></form>`;
    d.querySelector('[data-close]').onclick=()=>d.close();
    d.showModal();
    return d;
  }

  async function openAssess(criterionId){
    const c=catalog.find(x=>x.id===criterionId);
    const a=assessmentsByCriterion[criterionId];
    let people=[];
    if(scope){try{people=await qualityPeople(scope)}catch{people=[]}}
    const d=dialogShell(`Evaluar ${c.clause_reference} · ${c.framework}`,
      `<p class="muted">${e(c.criterion_summary)}</p>
      ${field('status','Estado','select',a?.status||'PENDIENTE',{items:isoStatuses.map(s=>[s,statusLabel(s)])})}
      ${scope?field('responsible','Responsable','select',a?.responsible_user_id||'',{required:false,items:[['','Sin asignar'],...people.map(p=>[p.id,p.full_name])]}):'<p class="muted">Seleccione una sucursal en el ámbito para asignar responsable.</p>'}
      ${field('notes','Notas / justificación','textarea',a?.notes||'',{required:false})}
      ${field('next_review','Próxima revisión','date',a?.next_review_date||'',{required:false})}`
    );
    d.querySelector('form').onsubmit=async ev=>{
      ev.preventDefault();
      const fd=Object.fromEntries(new FormData(ev.target));
      try{
        await isoComplianceData.upsertAssessment({
          criterionId,branchId:scope||null,status:fd.status,
          responsibleUserId:fd.responsible||null,notes:fd.notes||null,nextReviewDate:fd.next_review||null
        });
        d.close();
        await load();
      }catch(err){d.querySelector('[data-dialog-error]').textContent=err.message}
    };
  }

  async function openEvidence(assessmentId){
    const d=root.querySelector('#iso-dialog');
    d.innerHTML='<p class="status info">Cargando evidencia…</p>';
    d.showModal();
    try{
      const rows=await isoComplianceData.evidence(assessmentId);
      d.innerHTML=`<h3>Evidencia</h3>${table(['Fecha','Tipo','Título','Referencia'],rows.map(r=>[r.captured_at?.slice(0,10),e(r.evidence_type),e(r.title),e(r.source_reference||r.source_url||'—')]))}
        ${write?`<form id="iso-evidence-form">${field('title','Título')}${field('evidence_type','Tipo','select','DOCUMENTO',{items:['DOCUMENTO','REGISTRO','ENTREVISTA','OBSERVACION','MUESTRA','FOTO','OTRO']})}${field('source_reference','Referencia (código, folio)','text','',{required:false})}${field('source_url','Enlace','text','',{required:false})}<div class="dialog-actions"><button type="button" data-close class="secondary">Cerrar</button><button type="submit">Agregar evidencia</button></div></form>`:'<div class="dialog-actions"><button type="button" data-close class="secondary">Cerrar</button></div>'}`;
      d.querySelector('[data-close]').onclick=()=>d.close();
      const form=d.querySelector('#iso-evidence-form');
      if(form)form.onsubmit=async ev=>{
        ev.preventDefault();
        const fd=Object.fromEntries(new FormData(ev.target));
        try{
          await isoComplianceData.addEvidence(assessmentId,{evidenceType:fd.evidence_type,title:fd.title,sourceReference:fd.source_reference,sourceUrl:fd.source_url});
          d.close();
          await load();
        }catch(err){root.querySelector('#iso-msg').innerHTML=`<div class="status bad">${e(err.message)}</div>`}
      };
    }catch(err){d.innerHTML=`<div class="status bad">${e(err.message)}</div><div class="dialog-actions"><button type="button" data-close class="secondary">Cerrar</button></div>`;d.querySelector('[data-close]').onclick=()=>d.close()}
  }

  async function openNc(assessmentId){
    let people=[];
    if(scope){try{people=await qualityPeople(scope)}catch{people=[]}}
    const d=dialogShell('Crear no conformidad desde cláusula',
      `${field('owner','Responsable de la NC','select','',{items:[['','Seleccionar…'],...people.map(p=>[p.id,p.full_name])]})}
      ${field('due','Fecha de compromiso','date',today())}
      ${field('description','Descripción adicional','textarea','',{required:false})}`
    );
    d.querySelector('form').onsubmit=async ev=>{
      ev.preventDefault();
      const fd=Object.fromEntries(new FormData(ev.target));
      try{
        await isoComplianceData.createNonconformity(assessmentId,{ownerUserId:fd.owner,dueDate:fd.due,description:fd.description});
        d.close();
        await load();
      }catch(err){d.querySelector('[data-dialog-error]').textContent=err.message}
    };
  }

  async function load(){
    root.querySelector('#iso-msg')?.setAttribute('aria-busy','true');
    try{
      const [c,a,s]=await Promise.all([isoComplianceData.catalog(),isoComplianceData.assessments(scope||null),isoComplianceData.summary()]);
      catalog=c;summary=s;
      assessmentsByCriterion=Object.fromEntries(a.map(x=>[x.criterion_id,x]));
      draw();
    }catch(err){root.innerHTML=`<section class="card"><div class="status bad">${e(err.message)} · Instale la migración 20261103130000_iso_compliance_checklist.</div></section>`}
  }

  await load();
}
