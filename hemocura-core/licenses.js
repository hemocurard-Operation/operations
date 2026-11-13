// HemoCura v11 C2 §8 — UI mínima de habilitaciones sanitarias.
import { getSupabase } from './supabase.js';
import { loadAccess } from './access-control.js';
import { esc, field, table } from './workflow-ui.js';

const SEV={CRITICA:'stock-critical',ALTA:'stock-warning',MEDIA:'stock-warning',BAJA:'stock-ok',OK:'stock-ok',INFO:''};
function pill(v){return `<span class="stock-pill ${SEV[v]||''}">${esc(v)}</span>`;}

export async function mountLicenses(root){
  root.innerHTML='<section class="card"><div class="status info">Cargando habilitaciones…</div></section>';
  let access,branches,alerts=[],licenses=[],busy=false;
  const sb=getSupabase();
  try{
    access=await loadAccess();
    const [b,a,l]=await Promise.all([
      sb.from('branches').select('id,name').eq('active',true).order('name'),
      sb.from('vw_license_alerts').select('*').order('severity').order('days_to_expiry').limit(200),
      sb.from('facility_licenses').select('*').order('expires_at',{ascending:true}).limit(200)
    ]);
    if(b.error) throw new Error(b.error.message);
    branches=b.data||[];alerts=a.data||[];licenses=l.data||[];
  }catch(err){root.innerHTML=`<section class="card"><div class="status bad">${esc(err.message)}</div></section>`;return;}
  const canWrite=access.permissions.has('LICENSE_WRITE');
  const actor=access.context?.user_id||null;
  const bname=id=>branches.find(b=>b.id===id)?.name||esc(id);

  function render(){
    const rowsAlerts=alerts.map(a=>[bname(a.branch_id),esc(a.license_type),esc(a.license_number),esc(a.expires_at||'—'),String(a.days_to_expiry||0),pill(a.severity),esc(a.recommended_action)]);
    const rowsAll=licenses.map(l=>[bname(l.branch_id),esc(l.license_type),esc(l.authority),esc(l.license_number),esc(l.issued_at),esc(l.expires_at||'—'),esc(l.status)]);
    root.innerHTML=`
      <div class="sales-toolbar"><div>
        <h2 class="section-heading">Habilitaciones sanitarias</h2>
        <div class="muted">MSP, banco de sangre, cámara hiperbárica, residuos, ISO. Alertas 90/60/30 días.</div>
      </div>${canWrite?'<button data-lic-new>+ Registrar</button>':''}</div>
      <div data-lic-msg role="status"></div>
      <section class="card"><h3>Alertas próximas al vencimiento</h3>
        ${table(['Sucursal','Tipo','Número','Vence','Días','Severidad','Acción recomendada'],rowsAlerts)}
      </section>
      <section class="card"><h3>Expediente completo</h3>
        ${table(['Sucursal','Tipo','Autoridad','Número','Emitida','Vence','Estado'],rowsAll)}
      </section>
      <dialog data-lic-dialog class="sales-dialog"><form data-lic-form>
        <h3>Registrar habilitación</h3>
        <div data-lic-fields class="filter-grid"></div>
        <p data-lic-error role="alert"></p>
        <div class="dialog-actions">
          <button type="button" data-lic-cancel class="secondary">Cancelar</button>
          <button type="submit">Guardar</button>
        </div>
      </form></dialog>`;
    const newBtn=root.querySelector('[data-lic-new]');
    if(newBtn) newBtn.onclick=openNew;
  }

  function openNew(){
    const types=['HABILITACION_BANCO_SANGRE','HABILITACION_LABORATORIO','HABILITACION_CAMARA_HIPERBARICA',
                 'PERMISO_MANEJO_RESIDUOS','AUTORIZACION_SANITARIA_GENERAL','REGISTRO_MSP',
                 'LICENCIA_RADIACIONES','CERTIFICACION_ISO','OTRO'];
    const today=new Date().toISOString().slice(0,10);
    const html=field('branch_id','Sucursal','select','',{items:branches.map(b=>[b.id,b.name]),required:true})
      +field('license_type','Tipo','select','',{items:types.map(t=>[t,t]),required:true})
      +field('authority','Autoridad emisora','text','',{required:true})
      +field('license_number','Número','text','',{required:true})
      +field('issued_at','Fecha de emisión','date',today,{required:true})
      +field('expires_at','Fecha de vencimiento','date','')
      +field('scope','Alcance','textarea','')
      +field('document_ref','Referencia documental','text','');
    const d=root.querySelector('[data-lic-dialog]');
    const form=root.querySelector('[data-lic-form]');
    root.querySelector('[data-lic-fields]').innerHTML=html;
    root.querySelector('[data-lic-error]').textContent='';
    form.onsubmit=async ev=>{
      ev.preventDefault();if(busy||!form.reportValidity())return;busy=true;
      const btn=form.querySelector('[type=submit]');btn.disabled=true;
      try{
        const f=Object.fromEntries(new FormData(form));
        const {error}=await sb.from('facility_licenses').insert({
          branch_id:f.branch_id,license_type:f.license_type,authority:f.authority,
          license_number:f.license_number,issued_at:f.issued_at,expires_at:f.expires_at||null,
          scope:f.scope||null,document_ref:f.document_ref||null,entered_by:actor
        });
        if(error) throw new Error(error.message);
        d.close();await reload();root.querySelector('[data-lic-msg]').innerHTML='<div class="status ok">Habilitación registrada.</div>';
      }catch(err){root.querySelector('[data-lic-error]').textContent=err.message;}
      finally{busy=false;btn.disabled=false;}
    };
    root.querySelector('[data-lic-cancel]').onclick=()=>{if(!busy)d.close();};
    d.showModal();
  }

  async function reload(){
    const [a,l]=await Promise.all([
      sb.from('vw_license_alerts').select('*').order('severity').order('days_to_expiry').limit(200),
      sb.from('facility_licenses').select('*').order('expires_at',{ascending:true}).limit(200)
    ]);
    alerts=a.data||[];licenses=l.data||[];render();
  }

  render();
}
