// HemoCura v11 F3 §10 — UI mínima de presupuestos.
import { getSupabase } from './supabase.js';
import { loadAccess } from './access-control.js';
import { esc, field, table } from './workflow-ui.js';

const STATE={DENTRO:'stock-ok',ATENCION:'stock-warning',DESVIADO:'stock-critical',BORRADOR:'',SIN_PRESUPUESTO:''};
const money=v=>new Intl.NumberFormat('es-DO',{style:'currency',currency:'DOP',maximumFractionDigits:0}).format(Number(v||0));
const pct=v=>v==null?'—':Number(v).toFixed(1)+'%';
function pill(s){return `<span class="stock-pill ${STATE[s]||''}">${esc(s)}</span>`;}

export async function mountBudgets(root){
  root.innerHTML='<section class="card"><div class="status info">Cargando presupuestos…</div></section>';
  let access,branches,rows=[],busy=false;
  const sb=getSupabase();
  try{
    access=await loadAccess();
    const [b,r]=await Promise.all([
      sb.from('branches').select('id,name').eq('active',true).order('name'),
      sb.from('vw_budget_vs_actual').select('*').order('period_month',{ascending:false}).limit(500)
    ]);
    if(b.error) throw new Error(b.error.message);
    branches=b.data||[];rows=r.data||[];
  }catch(err){root.innerHTML=`<section class="card"><div class="status bad">${esc(err.message)}</div></section>`;return;}
  const canWrite=access.permissions.has('FINANCE_WRITE');
  const actor=access.context?.user_id||null;
  const bname=id=>branches.find(b=>b.id===id)?.name||'—';

  function render(){
    const t=table(['Período','Sucursal','Categoría','Presupuesto','Real','Variación','% Var','Estado'],
      rows.map(r=>[
        esc(r.period_month),bname(r.branch_id),esc(r.category),
        money(r.amount_budget),money(r.actual_amount),money(r.variance_amount),pct(r.variance_pct),pill(r.status)
      ]));
    root.innerHTML=`
      <div class="sales-toolbar"><div>
        <h2 class="section-heading">Presupuestos y ejecución</h2>
        <div class="muted">Comparación presupuestado vs ejecutado por categoría. Umbrales: DENTRO ≤100%, ATENCION ≤110%, DESVIADO &gt;110%.</div>
      </div>${canWrite?'<button data-bud-new>+ Presupuesto</button>':''}</div>
      <div data-bud-msg role="status"></div>
      <section class="card"><h3>Último estado</h3>${t}</section>
      <dialog data-bud-dialog class="sales-dialog"><form data-bud-form>
        <h3>Nuevo presupuesto</h3>
        <div data-bud-fields class="filter-grid"></div>
        <p data-bud-error role="alert"></p>
        <div class="dialog-actions">
          <button type="button" data-bud-cancel class="secondary">Cancelar</button>
          <button type="submit">Guardar</button>
        </div>
      </form></dialog>`;
    const newBtn=root.querySelector('[data-bud-new]');
    if(newBtn) newBtn.onclick=openNew;
  }

  function openNew(){
    const cats=['MATERIAL','LABOR','SCREENING','INDIRECT','WASTE','TRANSPORT','OTHER','VENTAS','COMERCIAL','ADMIN','TOTAL'];
    const month=new Date();month.setDate(1);
    const periodDefault=month.toISOString().slice(0,10);
    const html=field('period_month','Período (día 1 del mes)','date',periodDefault,{required:true})
      +field('branch_id','Sucursal','select','',{items:[['','Corporativo'],...branches.map(b=>[b.id,b.name])]})
      +field('category','Categoría','select','',{items:cats.map(c=>[c,c]),required:true})
      +field('amount_budget','Monto presupuestado','number',0,{required:true})
      +field('currency','Moneda','select','DOP',{items:[['DOP','DOP'],['USD','USD']]})
      +field('notes','Notas','textarea','');
    const d=root.querySelector('[data-bud-dialog]');
    const form=root.querySelector('[data-bud-form]');
    root.querySelector('[data-bud-fields]').innerHTML=html;
    root.querySelector('[data-bud-error]').textContent='';
    form.onsubmit=async ev=>{
      ev.preventDefault();if(busy||!form.reportValidity())return;busy=true;
      const btn=form.querySelector('[type=submit]');btn.disabled=true;
      try{
        const f=Object.fromEntries(new FormData(form));
        const {error}=await sb.from('budgets').insert({
          period_month:f.period_month,branch_id:f.branch_id||null,category:f.category,
          amount_budget:Number(f.amount_budget),currency:f.currency,notes:f.notes||null,
          created_by:actor
        });
        if(error) throw new Error(error.message);
        d.close();await reload();root.querySelector('[data-bud-msg]').innerHTML='<div class="status ok">Presupuesto guardado. Requiere aprobación independiente para activar comparación.</div>';
      }catch(err){root.querySelector('[data-bud-error]').textContent=err.message;}
      finally{busy=false;btn.disabled=false;}
    };
    root.querySelector('[data-bud-cancel]').onclick=()=>{if(!busy)d.close();};
    d.showModal();
  }

  async function reload(){
    const {data}=await sb.from('vw_budget_vs_actual').select('*').order('period_month',{ascending:false}).limit(500);
    rows=data||[];render();
  }

  render();
}
