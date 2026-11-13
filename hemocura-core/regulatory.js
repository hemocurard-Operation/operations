// HemoCura v11 C1 §8 — UI mínima de matriz regulatoria.
import { getSupabase } from './supabase.js';
import { loadAccess } from './access-control.js';
import { esc, field, table } from './workflow-ui.js';

const STATE={AL_DIA:'stock-ok',IMPLEMENTADO_SIN_VERIFICAR:'stock-warning',PENDIENTE:'stock-warning',REVISION_VENCIDA:'stock-critical',SIN_EVALUAR:'stock-critical',NO_APLICA:'',INACTIVO:''};
function pill(s){return `<span class="stock-pill ${STATE[s]||''}">${esc(s)}</span>`;}

export async function mountRegulatory(root){
  root.innerHTML='<section class="card"><div class="status info">Cargando matriz regulatoria…</div></section>';
  let access,matrix=[],busy=false;
  const sb=getSupabase();
  try{
    access=await loadAccess();
    const {data,error}=await sb.from('vw_regulatory_matrix').select('*').order('sequence_no').limit(500);
    if(error) throw new Error(error.message);
    matrix=data||[];
  }catch(err){root.innerHTML=`<section class="card"><div class="status bad">${esc(err.message)}</div></section>`;return;}
  const canWrite=access.permissions.has('REGULATORY_WRITE');
  const actor=access.context?.user_id||null;

  function render(){
    const byDomain=matrix.reduce((acc,r)=>{(acc[r.domain]=acc[r.domain]||[]).push(r);return acc;},{});
    const sections=Object.entries(byDomain).map(([domain,rows])=>`
      <section class="card"><h3>${esc(domain)}</h3>
        ${table(['#','Norma','Artículo','Obligación','Aplicabilidad','Estado','Acción'],
          rows.map(r=>[
            String(r.sequence_no),
            `<strong>${esc(r.requirement_code)}</strong><br><small>${esc(r.source_norm)}</small>`,
            esc(r.article_reference||'—'),
            esc(r.obligation),
            esc(r.applicability),
            pill(r.overall_state),
            canWrite?`<button class="secondary compact" data-reg-evaluate="${esc(r.requirement_id)}">Evaluar</button>`:'Consulta'
          ]))}
      </section>`).join('');
    root.innerHTML=`
      <div class="sales-toolbar"><div>
        <h2 class="section-heading">Matriz regulatoria</h2>
        <div class="muted">Ley 42-01, Dec. 349-04 banco de sangre, Ley 172-13, Ley 87-01, Ley 64-00, Código de Trabajo, ISO 9001/15189, MSP. Borrador: cada norma requiere aprobación de cumplimiento antes de uso vinculante.</div>
      </div></div>
      <div data-reg-msg role="status"></div>
      ${sections}
      <dialog data-reg-dialog class="sales-dialog"><form data-reg-form>
        <h3 data-reg-title></h3>
        <div data-reg-fields class="filter-grid"></div>
        <p data-reg-error role="alert"></p>
        <div class="dialog-actions">
          <button type="button" data-reg-cancel class="secondary">Cancelar</button>
          <button type="submit">Guardar evaluación</button>
        </div>
      </form></dialog>`;
    root.querySelectorAll('[data-reg-evaluate]').forEach(b=>b.onclick=()=>openEvaluate(b.dataset.regEvaluate));
  }

  function openEvaluate(requirementId){
    const r=matrix.find(x=>x.requirement_id===requirementId);
    if(!r) return;
    const html=field('status','Estado','select',r.assessment_status||'NO_INICIADO',{items:[
      ['NO_INICIADO','No iniciado'],['EN_DESARROLLO','En desarrollo'],['IMPLEMENTADO','Implementado'],
      ['VERIFICADO','Verificado'],['BLOQUEADO','Bloqueado'],['NO_APLICA','No aplica']
    ],required:true})
    +field('maturity','Madurez (0-4)','number',r.maturity||0,{required:true})
    +field('target_date','Fecha objetivo','date',r.target_date||'')
    +field('evidence_reference','Referencia de evidencia','text',r.evidence_reference||'')
    +field('notes','Notas','textarea','');
    const d=root.querySelector('[data-reg-dialog]');
    const form=root.querySelector('[data-reg-form]');
    root.querySelector('[data-reg-title]').textContent=`${r.requirement_code} · ${r.source_norm}`;
    root.querySelector('[data-reg-fields]').innerHTML=html;
    root.querySelector('[data-reg-error]').textContent='';
    form.onsubmit=async ev=>{
      ev.preventDefault();if(busy||!form.reportValidity())return;busy=true;
      const btn=form.querySelector('[type=submit]');btn.disabled=true;
      try{
        const f=Object.fromEntries(new FormData(form));
        const payload={
          requirement_id:requirementId,
          branch_id:r.branch_id||null,
          status:f.status,maturity:Number(f.maturity),
          target_date:f.target_date||null,evidence_reference:f.evidence_reference||null,
          notes:f.notes||null,created_by:actor
        };
        let {error}= r.assessment_id
          ? await sb.from('regulatory_assessments').update(payload).eq('id',r.assessment_id)
          : await sb.from('regulatory_assessments').insert(payload);
        if(error) throw new Error(error.message);
        d.close();await reload();root.querySelector('[data-reg-msg]').innerHTML='<div class="status ok">Evaluación guardada.</div>';
      }catch(err){root.querySelector('[data-reg-error]').textContent=err.message;}
      finally{busy=false;btn.disabled=false;}
    };
    root.querySelector('[data-reg-cancel]').onclick=()=>{if(!busy)d.close();};
    d.showModal();
  }

  async function reload(){
    const {data}=await sb.from('vw_regulatory_matrix').select('*').order('sequence_no').limit(500);
    matrix=data||[];render();
  }

  render();
}
