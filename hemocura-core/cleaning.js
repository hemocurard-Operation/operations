// HemoCura v11 Brecha L1 §5.8 — Limpieza de equipos (UI mínima).
// Patrón alineado con maintenance.js / inspections.js: tabs + tabla +
// diálogos de captura. La segregación verificador≠ejecutor se refuerza
// a nivel de DB por CHECK; aquí solo guiamos al usuario para evitar el
// 23514 obvio.
import { cleaningData } from './cleaning-data.js';
import { loadAccess } from './access-control.js';
import { esc, field, table } from './workflow-ui.js';
import { localDateTime } from './workflow-domain.js';

const SEVERITY_CLASS={CRITICA:'stock-critical',ALTA:'stock-warning',MEDIA:'stock-warning',BAJA:'stock-ok'};

function pill(label,severity){
  const cls=SEVERITY_CLASS[severity]||'';
  return `<span class="stock-pill ${cls}">${esc(label)}</span>`;
}

function fmtDate(v){return v?new Date(v).toISOString().slice(0,10):'—';}

export async function mountCleaning(root){
  root.innerHTML='<section class="card"><div class="status info">Cargando limpieza de equipos…</div></section>';
  let access,branches,branchId,equipment=[],plans=[],records=[],alerts=[],people=[],tab='alerts',busy=false,message='';
  try{
    [access,branches]=await Promise.all([loadAccess(),cleaningData.branches()]);
  }catch(err){
    root.innerHTML=`<section class="card"><div class="status bad" role="alert">${esc(err.message)}</div></section>`;
    return;
  }
  const canWrite=access.permissions.has('CLEANING_WRITE');
  const canVerify=access.permissions.has('CLEANING_VERIFY');
  const actor=access.context?.user_id||access.context?.id||null;
  branchId=access.context?.branch_id||branches[0]?.id||'';

  async function reload(){
    if(!branchId){equipment=plans=records=alerts=people=[];return;}
    [equipment,plans,records,alerts,people]=await Promise.all([
      cleaningData.equipment(branchId),
      cleaningData.plans(branchId),
      cleaningData.records(branchId),
      cleaningData.alerts(branchId),
      cleaningData.people(branchId)
    ]);
  }

  function status(text,bad=false){message=`<div class="status ${bad?'bad':'ok'}">${esc(text)}</div>`;draw();}

  function draw(){
    const tabs=[['alerts','Alertas',alerts.length],['plans','Planes',plans.length],['records','Registros',records.length]];
    const rowsAlerts=alerts.map(a=>{
      const eq=equipment.find(e=>e.id===a.equipment_id);
      return [
        esc(a.equipment_code||eq?.equipment_code||a.equipment_id),
        pill(a.severity,a.severity),
        a.last_performed_at?fmtDate(a.last_performed_at):'Nunca',
        fmtDate(a.next_due_date),
        String(a.days_overdue||0)
      ];
    });
    const rowsPlans=plans.map(p=>{
      const eq=equipment.find(e=>e.id===p.equipment_id);
      return [
        esc(eq?.equipment_code||p.equipment_id),
        String(p.frequency_days)+' d',
        esc(p.procedure_ref||'—'),
        esc(p.product_name||'—'),
        p.active?pill('Activo','BAJA'):pill('Inactivo','MEDIA'),
        canWrite?`<button class="secondary compact" data-cleaning-record="${esc(p.id)}" data-eq="${esc(p.equipment_id)}">Registrar limpieza</button>`:'Consulta'
      ];
    });
    const rowsRecords=records.map(r=>{
      const eq=equipment.find(e=>e.id===r.equipment_id);
      const verifyBtn=(canVerify&&!r.verified_at&&actor&&r.performed_by!==actor)
        ?`<button class="secondary compact" data-cleaning-verify="${esc(r.id)}">Verificar</button>`
        :(r.verified_at?esc('Verificado '+fmtDate(r.verified_at)):'Pendiente');
      return [
        esc(eq?.equipment_code||r.equipment_id),
        esc(localDateTime(r.performed_at)),
        esc(r.product_used||'—'),
        esc(r.evidence_reference||'—'),
        verifyBtn
      ];
    });

    root.innerHTML=`
      <div class="sales-toolbar">
        <div><h2 class="section-heading">Limpieza de equipos</h2>
          <div class="muted">Planes recurrentes, registros ejecutados y verificación independiente (§5.8).</div></div>
        <div>
          ${field('cleaning_branch','Sucursal','select',branchId,{items:branches.map(b=>[b.id,b.name])})}
          <button data-cleaning-refresh class="secondary">Actualizar</button>
          ${canWrite?'<button data-cleaning-new-plan>+ Nuevo plan</button>':''}
        </div>
      </div>
      <div data-cleaning-msg role="status" aria-live="polite">${message}</div>
      <nav class="lab-tabs" role="tablist">
        ${tabs.map(([k,t,n])=>`<button data-cleaning-tab="${k}" role="tab" aria-selected="${tab===k}">${t} (${n})</button>`).join('')}
      </nav>
      <section class="card">
        ${tab==='alerts'?table(['Equipo','Severidad','Última','Próxima','Días vencida'],rowsAlerts):''}
        ${tab==='plans'?table(['Equipo','Frecuencia','Procedimiento','Producto','Estado','Acción'],rowsPlans):''}
        ${tab==='records'?table(['Equipo','Ejecutado','Producto','Evidencia','Verificación'],rowsRecords):''}
      </section>
      <dialog data-cleaning-dialog class="sales-dialog"><form data-cleaning-form>
        <h3 data-cleaning-title></h3>
        <div data-cleaning-fields class="filter-grid"></div>
        <p data-cleaning-error role="alert"></p>
        <div class="dialog-actions">
          <button type="button" data-cleaning-cancel class="secondary">Cancelar</button>
          <button type="submit">Guardar</button>
        </div>
      </form></dialog>`;

    root.querySelectorAll('[data-cleaning-tab]').forEach(b=>b.onclick=()=>{tab=b.dataset.cleaningTab;draw();});
    root.querySelector('[name=cleaning_branch]').onchange=async ev=>{branchId=ev.target.value;try{await reload();draw();}catch(e){status(e.message,true);}};
    root.querySelector('[data-cleaning-refresh]').onclick=async()=>{try{await reload();status('Datos actualizados.');}catch(e){status(e.message,true);}};
    const planBtn=root.querySelector('[data-cleaning-new-plan]');
    if(planBtn) planBtn.onclick=()=>openPlanDialog();
    root.querySelectorAll('[data-cleaning-record]').forEach(b=>b.onclick=()=>openRecordDialog(b.dataset.cleaningRecord,b.dataset.eq));
    root.querySelectorAll('[data-cleaning-verify]').forEach(b=>b.onclick=()=>verify(b.dataset.cleaningVerify));
  }

  function openDialog(title,fieldsHtml,onSubmit){
    const d=root.querySelector('[data-cleaning-dialog]');
    const form=root.querySelector('[data-cleaning-form]');
    root.querySelector('[data-cleaning-title]').textContent=title;
    root.querySelector('[data-cleaning-fields]').innerHTML=fieldsHtml;
    root.querySelector('[data-cleaning-error]').textContent='';
    form.onsubmit=async ev=>{
      ev.preventDefault();
      if(busy||!form.reportValidity()) return;
      busy=true;
      const btn=form.querySelector('[type=submit]');btn.disabled=true;
      try{
        await onSubmit(Object.fromEntries(new FormData(form)));
        d.close();await reload();status('Guardado.');
      }catch(err){
        root.querySelector('[data-cleaning-error]').textContent=err.message;
      }finally{busy=false;btn.disabled=false;}
    };
    root.querySelector('[data-cleaning-cancel]').onclick=()=>{if(!busy)d.close();};
    d.showModal();
  }

  function openPlanDialog(){
    const html=field('equipment_id','Equipo','select','',{items:equipment.map(e=>[e.id,e.equipment_code+' · '+e.equipment_type]),required:true})
      +field('frequency_days','Frecuencia (días)','number',7,{required:true})
      +field('procedure_ref','Referencia de procedimiento','text')
      +field('product_name','Producto utilizado','text')
      +field('responsible_role','Rol responsable','text');
    openDialog('Nuevo plan de limpieza',html,async f=>{
      await cleaningData.createPlan({
        equipment_id:f.equipment_id,
        branch_id:branchId,
        frequency_days:Number(f.frequency_days),
        procedure_ref:f.procedure_ref||null,
        product_name:f.product_name||null,
        responsible_role:f.responsible_role||null,
        created_by:actor
      });
    });
  }

  function openRecordDialog(planId,equipmentId){
    const html=field('product_used','Producto utilizado','text')
      +field('evidence_reference','Referencia de evidencia','text')
      +field('observations','Observaciones','textarea');
    openDialog('Registrar limpieza ejecutada',html,async f=>{
      await cleaningData.recordExecution({
        plan_id:planId,
        equipment_id:equipmentId,
        branch_id:branchId,
        performed_by:actor,
        product_used:f.product_used||null,
        observations:f.observations||null,
        evidence_reference:f.evidence_reference||null
      });
    });
  }

  async function verify(recordId){
    if(!actor) return status('No se pudo identificar al verificador.',true);
    try{await cleaningData.verifyRecord(recordId,actor);await reload();status('Verificación registrada.');}
    catch(e){status(e.message,true);}
  }

  try{await reload();draw();}
  catch(err){root.innerHTML=`<section class="card"><div class="status bad">${esc(err.message)}</div></section>`;}
}
