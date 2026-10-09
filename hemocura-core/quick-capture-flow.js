const PANEL_KEY='hemocura_quick_capture_panel_v3';

const PANELS=[
  {key:'donor',formId:'qc-donor-form',label:'Donante',hint:'Registro mínimo y revisión humana'},
  {key:'screening',formId:'qc-screen-form',label:'Tamizaje',hint:'Unidad y resultados explícitos'},
  {key:'requisition',formId:'qc-req-form',label:'Requisición',hint:'Artículos en líneas dinámicas'},
  {key:'dispatch',formId:'qc-dispatch-form',label:'Despacho',hint:'Borrador por producto y cantidad'},
  {key:'incident',formId:'qc-inc-form',label:'Incidencia',hint:'Reporte breve y detalle condicional'}
];

const ROLE_DEFAULT={
  ENCARGADA_LABORATORIO:'screening',
  LABORATORIO:'screening',
  ASISTENTE_OPERACIONES:'requisition',
  MEDICO_GERENTE_TECNICO:'incident',
  CALIDAD:'incident',
  GERENCIA_OPERATIVA:'requisition',
  GERENCIA_GENERAL:'requisition',
  SUPER_USUARIO:'requisition',
  ADMIN:'requisition'
};

function esc(v=''){
  return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
}

function initialPanel(role='USUARIO'){
  try{
    const saved=localStorage.getItem(PANEL_KEY);
    if(PANELS.some(p=>p.key===saved)) return saved;
  }catch{}
  return ROLE_DEFAULT[role]||'donor';
}

function focusFirstField(entry){
  const form=entry?.details?.querySelector('form');
  const field=form?.querySelector('input:not([type="hidden"]):not([disabled]),select:not([disabled]),textarea:not([disabled])');
  if(field) setTimeout(()=>field.focus({preventScroll:true}),180);
}

function setMessage(root,message,type='bad'){
  const target=root.querySelector('#qc-msg');
  if(!target) return;
  target.innerHTML=`<div class="status ${esc(type)}">${esc(message)}</div>`;
  target.scrollIntoView({behavior:'smooth',block:'nearest'});
}

function applySingleBranchDefault(root){
  const branch=root.querySelector('#qc-branch');
  if(!branch||branch.value) return;
  const candidates=[...branch.options].filter(o=>o.value);
  if(candidates.length!==1) return;
  branch.value=candidates[0].value;
  branch.dispatchEvent(new Event('change',{bubbles:true}));
  const state=root.querySelector('#qc-context-state');
  if(state) state.textContent='Sucursal preseleccionada';
}

function enhanceDonorConsistency(root){
  const form=root.querySelector('#qc-donor-form');
  const status=root.querySelector('#qc-donor-status');
  const effective=root.querySelector('#qc-donor-effective');
  const reason=root.querySelector('#qc-donor-reason');
  const optional=reason?.closest('details');
  if(!form||!status||!effective||!reason) return;

  function sync(){
    const deferred=status.value==='DIFERIDO';
    if(deferred){
      effective.checked=false;
      effective.disabled=true;
      reason.required=true;
      if(optional) optional.open=true;
    }else{
      effective.disabled=false;
      reason.required=false;
    }
  }

  status.addEventListener('change',sync);
  form.addEventListener('submit',event=>{
    if(status.value==='DIFERIDO'&&effective.checked){
      event.preventDefault();
      event.stopImmediatePropagation();
      setMessage(root,'Un donante DIFERIDO no puede registrarse como donación efectiva.','bad');
      status.focus();
      return;
    }
    if(status.value==='DIFERIDO'&&!reason.value.trim()){
      event.preventDefault();
      event.stopImmediatePropagation();
      if(optional) optional.open=true;
      setMessage(root,'Indique el motivo de diferimiento antes de guardar.','bad');
      reason.focus();
    }
  },true);
  sync();
}

function enhanceIncidentDisclosure(root){
  const form=root.querySelector('#qc-inc-form');
  const details=form?.querySelector('details');
  const affected=root.querySelector('#qc-inc-affected');
  const followup=root.querySelector('#qc-inc-followup');
  const severity=root.querySelector('#qc-inc-severity');
  const impact=root.querySelector('#qc-inc-impact');
  const action=root.querySelector('#qc-inc-action');
  if(!form||!details||!affected||!followup||!severity) return;

  function sync(){
    const needsDetail=affected.checked||followup.checked||Number(severity.value)>=4;
    if(needsDetail) details.open=true;
    if(impact) impact.placeholder=affected.checked?'Describa brevemente la afectación observada':'Detalle opcional de afectación';
    if(action) action.placeholder=(followup.checked||Number(severity.value)>=4)?'Registre la acción inmediata o medida de contención':'Acción inmediata, si aplica';
  }
  [affected,followup,severity].forEach(el=>el.addEventListener('change',sync));
  sync();
}

export function enhanceQuickCaptureFlow(root,role='USUARIO'){
  if(!root||root.dataset.flowEnhanced==='1') return;
  const entries=PANELS.map(meta=>{
    const form=root.querySelector(`#${meta.formId}`);
    const details=form?.closest('details');
    return details?{...meta,details}:null;
  }).filter(Boolean);
  if(!entries.length) return;

  root.dataset.flowEnhanced='1';
  const message=root.querySelector('#qc-msg');
  const contextCard=message?.nextElementSibling;
  const launcher=document.createElement('section');
  launcher.className='card';
  launcher.id='qc-flow-launcher';
  launcher.innerHTML=`
    <div class="card-head">
      <div><h3>¿Qué vas a registrar?</h3><div class="muted">Abre un solo formulario a la vez. El sistema conserva sólo contexto operativo seguro, nunca resultados clínicos.</div></div>
      <span class="role-chip">Captura simple</span>
    </div>
    <div class="grid" id="qc-flow-actions">
      ${entries.map(p=>`<button type="button" class="secondary" data-qc-open="${esc(p.key)}" title="${esc(p.hint)}"><strong>${esc(p.label)}</strong><br><small>${esc(p.hint)}</small></button>`).join('')}
    </div>`;

  if(contextCard) root.insertBefore(launcher,contextCard); else root.prepend(launcher);

  const buttons=[...launcher.querySelectorAll('[data-qc-open]')];
  let switching=false;
  function selectPanel(key,{scroll=false,remember=true,focus=false}={}){
    const target=entries.find(p=>p.key===key)||entries[0];
    switching=true;
    entries.forEach(p=>{p.details.open=p.key===target.key});
    switching=false;
    buttons.forEach(btn=>{
      const active=btn.dataset.qcOpen===target.key;
      btn.setAttribute('aria-pressed',active?'true':'false');
      btn.classList.toggle('active',active);
    });
    if(remember){try{localStorage.setItem(PANEL_KEY,target.key)}catch{}}
    const chip=root.querySelector('.sales-toolbar .role-chip');
    if(chip) chip.textContent='v0.45.4';
    if(scroll) target.details.scrollIntoView({behavior:'smooth',block:'start'});
    if(focus) focusFirstField(target);
  }

  buttons.forEach(btn=>btn.addEventListener('click',()=>selectPanel(btn.dataset.qcOpen,{scroll:true,focus:true})));
  entries.forEach(entry=>entry.details.addEventListener('toggle',()=>{
    if(switching||!entry.details.open) return;
    selectPanel(entry.key,{scroll:false});
  }));

  applySingleBranchDefault(root);
  enhanceDonorConsistency(root);
  enhanceIncidentDisclosure(root);
  selectPanel(initialPanel(role),{scroll:false,remember:false});
}