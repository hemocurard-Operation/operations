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
      <div><h3>¿Qué vas a registrar?</h3><div class="muted">Abre un solo formulario a la vez. La última opción usada queda recordada en este navegador.</div></div>
      <span class="role-chip">Captura simple</span>
    </div>
    <div class="grid" id="qc-flow-actions">
      ${entries.map(p=>`<button type="button" class="secondary" data-qc-open="${esc(p.key)}" title="${esc(p.hint)}"><strong>${esc(p.label)}</strong><br><small>${esc(p.hint)}</small></button>`).join('')}
    </div>`;

  if(contextCard) root.insertBefore(launcher,contextCard); else root.prepend(launcher);

  const buttons=[...launcher.querySelectorAll('[data-qc-open]')];
  let switching=false;
  function selectPanel(key,{scroll=false,remember=true}={}){
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
    if(chip) chip.textContent='v0.45.3';
    if(scroll) target.details.scrollIntoView({behavior:'smooth',block:'start'});
  }

  buttons.forEach(btn=>btn.addEventListener('click',()=>selectPanel(btn.dataset.qcOpen,{scroll:true})));
  entries.forEach(entry=>entry.details.addEventListener('toggle',()=>{
    if(switching||!entry.details.open) return;
    selectPanel(entry.key,{scroll:false});
  }));

  selectPanel(initialPanel(role),{scroll:false,remember:false});
}
