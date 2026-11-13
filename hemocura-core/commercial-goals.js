// HemoCura v11 CM1 §9 — UI mínima de metas comerciales.
import { getSupabase } from './supabase.js';
import { loadAccess } from './access-control.js';
import { esc, field, table } from './workflow-ui.js';

function bar(actual,target){
  if(!target) return '—';
  const pct=Math.min(100,Math.max(0,Math.round((Number(actual||0)/Number(target))*100)));
  const cls=pct>=100?'stock-ok':pct>=70?'stock-warning':'stock-critical';
  return `<span class="stock-pill ${cls}">${pct}%</span>`;
}

export async function mountCommercialGoals(root){
  root.innerHTML='<section class="card"><div class="status info">Cargando metas comerciales…</div></section>';
  let access,branches,goals=[],busy=false;
  const sb=getSupabase();
  try{
    access=await loadAccess();
    const [b,g]=await Promise.all([
      sb.from('branches').select('id,name').eq('active',true).order('name'),
      sb.from('vw_commercial_goal_progress').select('*').order('period_end',{ascending:false}).limit(200)
    ]);
    if(b.error) throw new Error(b.error.message);
    branches=b.data||[];goals=g.data||[];
  }catch(err){root.innerHTML=`<section class="card"><div class="status bad">${esc(err.message)}</div></section>`;return;}
  const canWrite=access.permissions.has('COMMERCIAL_WRITE');
  const actor=access.context?.user_id||null;
  const bname=id=>branches.find(b=>b.id===id)?.name||'Corporativo';

  function render(){
    const t=table(['Período','Sucursal','Métrica','Objetivo','Real','Progreso'],
      goals.map(g=>[
        esc(g.period_start)+' → '+esc(g.period_end),
        bname(g.branch_id),esc(g.metric),
        esc(g.target_value),esc(g.actual_value??'—'),bar(g.actual_value,g.target_value)
      ]));
    root.innerHTML=`
      <div class="sales-toolbar"><div>
        <h2 class="section-heading">Metas comerciales</h2>
        <div class="muted">Objetivos cuantitativos por sucursal/agente/servicio comparados con el desempeño real.</div>
      </div>${canWrite?'<button data-cg-new>+ Nueva meta</button>':''}</div>
      <div data-cg-msg role="status"></div>
      <section class="card">${t}</section>
      <dialog data-cg-dialog class="sales-dialog"><form data-cg-form>
        <h3>Nueva meta</h3>
        <div data-cg-fields class="filter-grid"></div>
        <p data-cg-error role="alert"></p>
        <div class="dialog-actions">
          <button type="button" data-cg-cancel class="secondary">Cancelar</button>
          <button type="submit">Guardar</button>
        </div>
      </form></dialog>`;
    const newBtn=root.querySelector('[data-cg-new]');
    if(newBtn) newBtn.onclick=openNew;
  }

  function openNew(){
    const metrics=['VISITAS_COMPLETADAS','VISITAS_EDUCATIVAS','REFERIDOS_NUEVOS','DONANTES_CAPTADOS',
                   'VENTAS_UNIDADES','VENTAS_MONTO','OPORTUNIDADES_ABIERTAS','OPORTUNIDADES_GANADAS',
                   'OPORTUNIDADES_MONTO','CLIENTES_ACTIVOS','TASA_CONVERSION_PCT'];
    const today=new Date().toISOString().slice(0,10);
    const d=new Date();d.setMonth(d.getMonth()+3);
    const future=d.toISOString().slice(0,10);
    const html=field('period_start','Inicio','date',today,{required:true})
      +field('period_end','Fin','date',future,{required:true})
      +field('branch_id','Sucursal','select','',{items:[['','Corporativo'],...branches.map(b=>[b.id,b.name])]})
      +field('metric','Métrica','select','',{items:metrics.map(m=>[m,m]),required:true})
      +field('target_value','Objetivo','number',0,{required:true})
      +field('notes','Notas','textarea','');
    const dlg=root.querySelector('[data-cg-dialog]');
    const form=root.querySelector('[data-cg-form]');
    root.querySelector('[data-cg-fields]').innerHTML=html;
    root.querySelector('[data-cg-error]').textContent='';
    form.onsubmit=async ev=>{
      ev.preventDefault();if(busy||!form.reportValidity())return;busy=true;
      const btn=form.querySelector('[type=submit]');btn.disabled=true;
      try{
        const f=Object.fromEntries(new FormData(form));
        const {error}=await sb.from('commercial_goals').insert({
          period_start:f.period_start,period_end:f.period_end,
          branch_id:f.branch_id||null,metric:f.metric,
          target_value:Number(f.target_value),notes:f.notes||null,
          created_by:actor
        });
        if(error) throw new Error(error.message);
        dlg.close();await reload();root.querySelector('[data-cg-msg]').innerHTML='<div class="status ok">Meta creada. Requiere aprobación para activarse.</div>';
      }catch(err){root.querySelector('[data-cg-error]').textContent=err.message;}
      finally{busy=false;btn.disabled=false;}
    };
    root.querySelector('[data-cg-cancel]').onclick=()=>{if(!busy)dlg.close();};
    dlg.showModal();
  }

  async function reload(){
    const {data}=await sb.from('vw_commercial_goal_progress').select('*').order('period_end',{ascending:false}).limit(200);
    goals=data||[];render();
  }

  render();
}
