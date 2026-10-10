import { commandData } from './command-data.js';

const GROUPS=['A+','A-','B+','B-','O+','O-','AB+','AB-'];
const key=g=>g.replace('+','p').replace('-','n');
const n=v=>Math.max(0,Number(v||0));
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));

function setValue(root,id,value){
  const el=root.querySelector(`#${id}`);
  if(!el)return;
  el.value=String(n(value));
  el.dispatchEvent(new Event('input',{bubbles:true}));
}

function toggleActivity(root,checkboxId,bodyId,buttonId){
  const checkbox=root.querySelector(`#${checkboxId}`);
  const body=root.querySelector(`#${bodyId}`)?.closest('.table-wrap');
  const button=root.querySelector(`#${buttonId}`);
  if(!checkbox||!body)return ()=>{};
  const apply=()=>{
    body.hidden=checkbox.checked;
    if(button)button.disabled=checkbox.checked||checkbox.disabled;
    checkbox.closest('section')?.classList.toggle('dor-inactive-section',checkbox.checked);
  };
  checkbox.addEventListener('change',apply);
  apply();
  return apply;
}

function message(root,html){
  const target=root.querySelector('#dor-msg');
  if(target)target.innerHTML=html;
}

async function copyPreviousInventory(root,button){
  const branch=root.querySelector('#dor-branch')?.value;
  const closeDate=root.querySelector('#dor-date')?.value;
  if(!branch||!closeDate){
    message(root,'<div class="status warn">Seleccione fecha y sucursal antes de buscar el inventario anterior.</div>');
    return;
  }
  button.disabled=true;
  const label=button.textContent;
  button.textContent='Buscando…';
  try{
    const previous=await commandData.previousDailyReport(closeDate,branch);
    const inventory=previous?.manual_inventory;
    if(!previous||!inventory||typeof inventory!=='object'){
      message(root,'<div class="status info">No hay un inventario anterior disponible para copiar.</div>');
      return;
    }
    const ok=confirm(`Se copiará el inventario del ${previous.close_date}. Debe verificar físicamente cada cantidad antes de guardar. ¿Continuar?`);
    if(!ok)return;
    for(const group of GROUPS){
      const row=inventory[group]||{};
      const k=key(group);
      setValue(root,`inv-${k}-whole`,row.whole_blood);
      setValue(root,`inv-${k}-packed`,row.packed_cells);
      setValue(root,`inv-${k}-plasma`,row.plasma);
      setValue(root,`inv-${k}-platelets`,row.platelets);
    }
    message(root,`<div class="status info"><strong>Inventario anterior copiado.</strong> Verifique físicamente las cantidades antes de guardar. Origen: ${esc(previous.close_date)}.</div>`);
    root.querySelector('#dor-inventory')?.scrollIntoView({behavior:'smooth',block:'center'});
  }catch(error){
    message(root,`<div class="status bad">No se pudo copiar el inventario anterior: ${esc(error?.message||error)}</div>`);
  }finally{
    button.textContent=label;
    syncInventoryAssist(root,button);
  }
}

function syncInventoryAssist(root,button){
  if(!button)return;
  const firstInput=root.querySelector('#dor-inventory input');
  const status=root.querySelector('#dor-status')?.textContent?.trim()||'BORRADOR';
  button.disabled=!!firstInput?.disabled||!['BORRADOR','REABIERTO'].includes(status);
}

function addInventoryAssist(root){
  const body=root.querySelector('#dor-inventory');
  const card=body?.closest('section.card');
  const head=card?.querySelector('.card-head');
  if(!head)return null;
  let button=head.querySelector('[data-copy-prev-inventory]');
  if(!button){
    const tools=document.createElement('div');
    tools.className='dor-section-tools';
    tools.innerHTML='<button type="button" class="secondary compact" data-copy-prev-inventory>Usar inventario anterior</button><span class="form-hint">Copia asistida; requiere verificación física.</span>';
    head.appendChild(tools);
    button=tools.querySelector('[data-copy-prev-inventory]');
    button.addEventListener('click',()=>copyPreviousInventory(root,button));
  }
  syncInventoryAssist(root,button);
  return button;
}

function addMobileHints(root){
  root.querySelectorAll('.capture-table').forEach(table=>table.classList.add('dor-capture-table'));
  root.querySelectorAll('[data-inventory-row]').forEach(row=>row.classList.add('dor-inventory-row'));
  root.querySelectorAll('[data-lot-row],[data-dispatch-row]').forEach(row=>row.classList.add('dor-entry-row'));
  const actions=root.querySelector('#dor-save')?.closest('.dialog-actions');
  if(actions)actions.classList.add('dor-primary-actions');
}

export function enhanceDailyInventoryFlow(root){
  if(!root||root.dataset.dorEnhanced==='1')return;
  root.dataset.dorEnhanced='1';
  const syncScreening=toggleActivity(root,'dor-no-screening','dor-lots','dor-add-lot');
  const syncDispatch=toggleActivity(root,'dor-no-dispatch','dor-dispatches','dor-add-dispatch');
  const inventoryButton=addInventoryAssist(root);
  addMobileHints(root);

  const syncLoadedState=()=>{
    syncScreening();
    syncDispatch();
    syncInventoryAssist(root,inventoryButton);
    addMobileHints(root);
  };
  const status=root.querySelector('#dor-status');
  if(status){
    const observer=new MutationObserver(syncLoadedState);
    observer.observe(status,{childList:true,subtree:true,characterData:true});
  }

  const responsible=root.querySelector('#dor-responsible');
  if(responsible&&!responsible.value.trim())responsible.focus();
}
