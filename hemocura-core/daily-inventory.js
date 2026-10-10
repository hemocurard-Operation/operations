import { commandData } from './command-data.js';
import { resourcesData } from './resources-data.js';
import { loadAccess } from './access-control.js';

const GROUPS=['A+','A-','B+','B-','O+','O-','AB+','AB-'];
const COMPONENTS=['Sangre total','Paquete globular','Plasma','Plaquetas'];
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const n=v=>Math.max(0,Number(v||0));
const today=()=>new Date().toISOString().slice(0,10);
const key=g=>g.replace('+','p').replace('-','n');

function lotRow(x={}){
  return `<tr data-lot-row>
    <td><input data-f="lot" value="${esc(x.lot||'')}" placeholder="Tanda / lote"></td>
    <td><input data-f="received" type="number" min="0" inputmode="numeric" value="${n(x.received)}"></td>
    <td><input data-f="non_reactive" type="number" min="0" inputmode="numeric" value="${n(x.non_reactive)}"></td>
    <td><input data-f="reactive" type="number" min="0" inputmode="numeric" value="${n(x.reactive)}"></td>
    <td><input data-f="pending" type="number" min="0" inputmode="numeric" value="${n(x.pending)}"></td>
    <td><input data-f="discarded" type="number" min="0" inputmode="numeric" value="${n(x.discarded)}"></td>
    <td data-balance class="num">0</td>
    <td><button type="button" class="secondary compact" data-remove-row>×</button></td>
  </tr>`;
}

function dispatchRow(x={}){
  return `<tr data-dispatch-row>
    <td><input data-f="destination" list="dor-destinations" value="${esc(x.destination||'')}" placeholder="Centro / destino"></td>
    <td><select data-f="group"><option value="">—</option>${GROUPS.map(g=>`<option ${x.group===g?'selected':''}>${g}</option>`).join('')}</select></td>
    <td><select data-f="component"><option value="">Seleccionar…</option>${COMPONENTS.map(c=>`<option ${x.component===c?'selected':''}>${c}</option>`).join('')}</select></td>
    <td><input data-f="quantity" type="number" min="0" inputmode="numeric" value="${n(x.quantity)}"></td>
    <td><input data-f="note" value="${esc(x.note||'')}" placeholder="Opcional"></td>
    <td><button type="button" class="secondary compact" data-remove-row>×</button></td>
  </tr>`;
}

function inventoryRows(data={}){
  return GROUPS.map(g=>{
    const x=data[g]||{},k=key(g);
    return `<tr data-inventory-row="${g}">
      <th>${g}</th>
      <td><input id="inv-${k}-whole" type="number" min="0" inputmode="numeric" value="${n(x.whole_blood)}"></td>
      <td><input id="inv-${k}-packed" type="number" min="0" inputmode="numeric" value="${n(x.packed_cells)}"></td>
      <td><input id="inv-${k}-plasma" type="number" min="0" inputmode="numeric" value="${n(x.plasma)}"></td>
      <td><input id="inv-${k}-platelets" type="number" min="0" inputmode="numeric" value="${n(x.platelets)}"></td>
      <td data-group-total class="num"><strong>0</strong></td>
    </tr>`;
  }).join('');
}

export async function mountDailyInventory(root){
  root.innerHTML='<section class="card"><div class="status info">Preparando reporte operativo diario…</div></section>';

  const [branches,access,recent]=await Promise.all([
    commandData.branches(),
    loadAccess(),
    commandData.recentCloses(30)
  ]);
  const permissions=access?.permissions||new Set();
  const canWrite=permissions.has('DAILY_REPORT_WRITE');
  const canSubmit=permissions.has('DAILY_REPORT_SUBMIT');
  const canClose=permissions.has('DAILY_REPORT_CLOSE');
  const canReopen=permissions.has('DAILY_REPORT_REOPEN');
  const preferred=access?.context?.branch_id||access?.context?.current_branch_id||'';
  const displayName=access?.context?.full_name||access?.context?.name||access?.context?.email||'';
  let current=null;
  let loading=false;

  root.innerHTML=`
    <div class="sales-toolbar">
      <div><h2 class="section-heading">Reporte Operativo Diario</h2><div class="muted">Una sola captura consolidada para lotes, inventario, despachos y novedades.</div></div>
      <div class="dialog-actions"><button id="dor-print" class="secondary">Imprimir</button><button id="dor-refresh" class="secondary">Cargar</button></div>
    </div>
    <div id="dor-msg"></div>
    <datalist id="dor-destinations"></datalist>

    <section class="card quick-capture">
      <div class="quick-capture-head"><div><div class="eyebrow">Identificación</div><h3>Reporte diario</h3></div><div><span id="dor-version" class="state-pill state-info">v1</span> <span id="dor-status" class="state-pill state-info">BORRADOR</span></div></div>
      <div class="filter-grid">
        <label>Fecha<input id="dor-date" type="date" value="${today()}"></label>
        <label>Sucursal<select id="dor-branch"><option value="">Seleccionar…</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
        <label>Responsable / Bioanalista<input id="dor-responsible" value="${esc(displayName)}"></label>
      </div>
      <div id="dor-signature" class="muted"></div>
    </section>

    <section class="card" data-editable>
      <div class="card-head"><div><h3>1. Lotes diarios de tamizaje</h3><div class="muted">Registro agregado por lote. No interpreta resultados ni decide liberación.</div></div><div><label class="inline-check"><input id="dor-no-screening" type="checkbox"> Sin actividad</label> <button id="dor-add-lot" class="secondary" type="button">+ Lote</button></div></div>
      <div class="table-wrap"><table class="data-table capture-table"><thead><tr><th>Lote</th><th>Recibidos</th><th>No reactivos</th><th>Reactivos</th><th>Pendientes</th><th>Descartados</th><th>Balance</th><th></th></tr></thead><tbody id="dor-lots"></tbody></table></div>
      <div id="dor-lot-warning"></div>
    </section>

    <section class="card" data-editable>
      <div class="card-head"><div><h3>2. Inventario disponible</h3><div class="muted">Conteo físico consolidado; requiere verificación humana.</div></div><span id="dor-inventory-total" class="state-pill state-info">0 unidades</span></div>
      <div class="table-wrap"><table class="data-table capture-table"><thead><tr><th>Grupo</th><th>Sangre total</th><th>Paquete globular</th><th>Plasma</th><th>Plaquetas</th><th>Total</th></tr></thead><tbody id="dor-inventory"></tbody></table></div>
    </section>

    <section class="card" data-editable>
      <div class="card-head"><div><h3>3. Despachos del día</h3><div class="muted">Una fila por destino, grupo y componente.</div></div><div><label class="inline-check"><input id="dor-no-dispatch" type="checkbox"> Sin despachos</label> <span id="dor-dispatch-total" class="state-pill state-info">0 unidades</span> <button id="dor-add-dispatch" class="secondary" type="button">+ Despacho</button></div></div>
      <div class="table-wrap"><table class="data-table capture-table"><thead><tr><th>Destino</th><th>Grupo</th><th>Componente</th><th>Cantidad</th><th>Observación</th><th></th></tr></thead><tbody id="dor-dispatches"></tbody></table></div>
      <div id="dor-dispatch-warning"></div>
    </section>

    <section class="card">
      <div class="card-head"><div><h3>4. Equipos con novedad</h3><div class="muted">Se muestran únicamente excepciones disponibles para la sucursal.</div></div><span id="dor-equipment-count" class="state-pill state-info">0 novedades</span></div>
      <div class="table-wrap"><table class="data-table"><thead><tr><th>Equipo</th><th>Tipo</th><th>Estado</th><th>Ubicación</th><th>Alerta</th></tr></thead><tbody id="dor-equipment"></tbody></table></div>
    </section>

    <section class="card quick-capture" data-editable>
      <label><strong>Observaciones generales</strong><textarea id="dor-notes" rows="4" placeholder="Solo novedades o aclaraciones necesarias"></textarea></label>
      <div id="dor-check" class="muted"></div>
      <div class="dialog-actions">
        <button id="dor-save" class="secondary">Guardar borrador</button>
        <button id="dor-submit">Enviar a revisión</button>
        <button id="dor-close">Cerrar y firmar</button>
        <button id="dor-reopen" class="secondary">Reabrir</button>
      </div>
      <p class="muted">El cierre es una acción humana autorizada del reporte operativo; no libera componentes sanguíneos.</p>
    </section>

    <details class="card"><summary><strong>Historial de versiones</strong></summary><div class="table-wrap"><table class="data-table"><thead><tr><th>Versión</th><th>Estado</th><th>Fecha/hora</th><th>Usuario</th></tr></thead><tbody id="dor-versions"></tbody></table></div></details>
    <details class="card"><summary><strong>Reportes recientes</strong></summary><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Estado</th><th>Versión</th><th>Responsable</th><th>Actualizado</th></tr></thead><tbody id="dor-history"></tbody></table></div></details>`;

  const q=id=>root.querySelector(`#${id}`);
  if(preferred&&branches.some(b=>b.id===preferred))q('dor-branch').value=preferred;
  else if(branches.length===1)q('dor-branch').value=branches[0].id;

  q('dor-destinations').innerHTML=[...new Set(recent.flatMap(r=>(r.manual_dispatches||[]).map(d=>d.destination)).filter(Boolean))]
    .slice(0,30).map(x=>`<option value="${esc(x)}"></option>`).join('');

  function rows(selector){
    return [...root.querySelectorAll(selector)].map(tr=>{
      const out={};
      tr.querySelectorAll('[data-f]').forEach(el=>out[el.dataset.f]=el.type==='number'?n(el.value):el.value.trim());
      return out;
    }).filter(o=>Object.values(o).some(v=>v!==''&&v!==0));
  }

  function inventoryPayload(){
    const out={};
    for(const g of GROUPS){
      const k=key(g);
      out[g]={
        whole_blood:n(q(`inv-${k}-whole`)?.value),
        packed_cells:n(q(`inv-${k}-packed`)?.value),
        plasma:n(q(`inv-${k}-plasma`)?.value),
        platelets:n(q(`inv-${k}-platelets`)?.value)
      };
    }
    return out;
  }

  function payload(){
    return {
      close_date:q('dor-date').value,
      branch_id:q('dor-branch').value,
      responsible_name:q('dor-responsible').value.trim(),
      screening_lots:q('dor-no-screening').checked?[]:rows('[data-lot-row]'),
      manual_inventory:inventoryPayload(),
      manual_dispatches:q('dor-no-dispatch').checked?[]:rows('[data-dispatch-row]'),
      notes:q('dor-notes').value.trim()||null
    };
  }

  function lotDiagnosis(){
    const list=q('dor-no-screening').checked?[]:rows('[data-lot-row]');
    const names=list.map(x=>String(x.lot||'').trim().toUpperCase()).filter(Boolean);
    const duplicate=names.some((x,i)=>names.indexOf(x)!==i);
    let imbalance=false;
    root.querySelectorAll('[data-lot-row]').forEach(tr=>{
      const get=f=>n(tr.querySelector(`[data-f="${f}"]`)?.value);
      const diff=get('received')-(get('non_reactive')+get('reactive')+get('pending')+get('discarded'));
      if(diff!==0)imbalance=true;
      const cell=tr.querySelector('[data-balance]');
      if(cell){cell.textContent=diff===0?'OK':String(diff);cell.className=`num ${diff===0?'capture-balanced':'capture-unbalanced'}`;}
    });
    return {list,duplicate,imbalance};
  }

  function dispatchDiagnosis(){
    const list=q('dor-no-dispatch').checked?[]:rows('[data-dispatch-row]');
    const keys=list.map(x=>`${String(x.destination||'').trim().toUpperCase()}|${x.group}|${x.component}`);
    const duplicate=keys.some((x,i)=>x&&keys.indexOf(x)!==i);
    const complete=list.every(x=>x.destination&&x.group&&x.component&&n(x.quantity)>0);
    return {list,duplicate,complete,total:list.reduce((a,x)=>a+n(x.quantity),0)};
  }

  function inventoryTotal(){
    const inv=inventoryPayload();
    let all=0;
    GROUPS.forEach(g=>{
      const total=Object.values(inv[g]).reduce((a,v)=>a+n(v),0);
      all+=total;
      const cell=root.querySelector(`[data-inventory-row="${g}"] [data-group-total]`);
      if(cell)cell.innerHTML=`<strong>${total}</strong>`;
    });
    return all;
  }

  function validate(){
    const lots=lotDiagnosis(),dispatch=dispatchDiagnosis(),inv=inventoryTotal();
    const idOk=!!q('dor-branch').value&&!!q('dor-responsible').value.trim();
    const lotsOk=q('dor-no-screening').checked||(lots.list.length>0&&!lots.duplicate&&!lots.imbalance);
    const dispatchOk=q('dor-no-dispatch').checked||(dispatch.list.length>0&&!dispatch.duplicate&&dispatch.complete);
    const ok=idOk&&lotsOk&&dispatchOk;
    q('dor-inventory-total').textContent=`${inv} unidades`;
    q('dor-dispatch-total').textContent=`${dispatch.total} unidades`;
    q('dor-lot-warning').innerHTML=lots.duplicate?'<div class="status warn">Hay lotes duplicados.</div>':lots.imbalance?'<div class="status warn">Hay lotes desbalanceados. Recibidos debe coincidir con la suma documentada.</div>':'';
    q('dor-dispatch-warning').innerHTML=dispatch.duplicate?'<div class="status warn">Hay despachos duplicados.</div>':(!dispatchOk&&!q('dor-no-dispatch').checked)?'<div class="status warn">Complete destino, grupo, componente y cantidad.</div>':'';
    q('dor-check').textContent=ok?'Reporte consistente para guardar/enviar.':'Revise identificación, tamizaje o despachos antes de enviar.';
    return ok;
  }

  function bindRows(){
    root.querySelectorAll('[data-remove-row]').forEach(btn=>btn.onclick=()=>{btn.closest('tr')?.remove();validate();});
    root.querySelectorAll('input,select,textarea').forEach(el=>{
      if(el.dataset.dorBound)return;
      el.addEventListener('input',validate);
      el.addEventListener('change',validate);
      el.dataset.dorBound='1';
    });
  }

  function setEditable(){
    const editable=canWrite&&(!current||['BORRADOR','REABIERTO'].includes(current.status));
    root.querySelectorAll('[data-editable] input,[data-editable] select,[data-editable] textarea,[data-editable] button').forEach(el=>el.disabled=!editable);
    q('dor-save').disabled=!editable;
    q('dor-submit').disabled=!(editable&&canSubmit&&current?.id&&validate());
    q('dor-close').disabled=!(canClose&&current?.status==='EN_REVISION');
    q('dor-reopen').disabled=!(canReopen&&current?.status==='CERRADO');
    q('dor-date').disabled=false;
    q('dor-branch').disabled=false;
  }

  function render(report=null){
    loading=true;
    current=report;
    const lots=Array.isArray(report?.screening_lots)?report.screening_lots:[];
    const dispatches=Array.isArray(report?.manual_dispatches)?report.manual_dispatches:[];
    q('dor-responsible').value=report?.responsible_name||displayName;
    q('dor-no-screening').checked=!!report&&lots.length===0;
    q('dor-no-dispatch').checked=!!report&&dispatches.length===0;
    q('dor-lots').innerHTML=(lots.length?lots:[{}]).map(lotRow).join('');
    q('dor-inventory').innerHTML=inventoryRows(report?.manual_inventory||{});
    q('dor-dispatches').innerHTML=(dispatches.length?dispatches:[{}]).map(dispatchRow).join('');
    q('dor-notes').value=report?.notes||'';
    q('dor-status').textContent=report?.status||'BORRADOR';
    q('dor-version').textContent=`v${report?.report_version||1}`;
    q('dor-signature').textContent=report?.status==='CERRADO'
      ?`Firmado ${report.closed_at?new Date(report.closed_at).toLocaleString('es-DO'):''}`
      :report?.status==='EN_REVISION'
        ?`En revisión desde ${report.submitted_at?new Date(report.submitted_at).toLocaleString('es-DO'):''}`
        :report?.status==='REABIERTO'
          ?`Reabierto ${report.reopened_at?new Date(report.reopened_at).toLocaleString('es-DO'):''} · ${report.reopen_reason||''}`:'';
    bindRows();
    loading=false;
    validate();
    setEditable();
  }

  async function equipmentSnapshot(){
    try{
      const [equipment,alerts]=await Promise.all([resourcesData.equipment(),resourcesData.equipmentAlerts()]);
      const branch=q('dor-branch').value;
      const alertMap=Object.fromEntries(alerts.filter(a=>a.branch_id===branch).map(a=>[a.equipment_id,a]));
      return equipment.filter(x=>x.branch_id===branch&&(x.status!=='ACTIVO'||alertMap[x.id])).map(x=>({
        equipment_code:x.equipment_code,equipment_type:x.equipment_type,status:x.status,
        location:x.location||null,alert:alertMap[x.id]?.message||null
      }));
    }catch{return [];}
  }

  async function showEquipment(){
    const list=await equipmentSnapshot();
    q('dor-equipment-count').textContent=`${list.length} novedades`;
    q('dor-equipment').innerHTML=list.length
      ?list.map(x=>`<tr><td><code>${esc(x.equipment_code)}</code></td><td>${esc(x.equipment_type)}</td><td>${esc(x.status)}</td><td>${esc(x.location||'—')}</td><td>${esc(x.alert||'—')}</td></tr>`).join('')
      :'<tr><td colspan="5">Sin novedades disponibles.</td></tr>';
    return list;
  }

  async function showVersions(){
    if(!current?.id){q('dor-versions').innerHTML='<tr><td colspan="4">Sin versiones.</td></tr>';return;}
    try{
      const list=await commandData.reportVersions(current.id);
      q('dor-versions').innerHTML=list.length
        ?list.map(v=>`<tr><td>v${v.report_version}</td><td>${esc(v.status)}</td><td>${esc(new Date(v.changed_at).toLocaleString('es-DO'))}</td><td>${esc(v.changed_by||'—')}</td></tr>`).join('')
        :'<tr><td colspan="4">Sin versiones.</td></tr>';
    }catch(e){q('dor-versions').innerHTML=`<tr><td colspan="4">${esc(e.message)}</td></tr>`;}
  }

  function showHistory(){
    const branch=q('dor-branch').value;
    const list=recent.filter(x=>!branch||x.branch_id===branch);
    q('dor-history').innerHTML=list.length
      ?list.map(x=>`<tr><td>${esc(x.close_date)}</td><td>${esc(x.status)}</td><td>v${esc(x.report_version||1)}</td><td>${esc(x.responsible_name||'—')}</td><td>${esc(x.updated_at?new Date(x.updated_at).toLocaleString('es-DO'):'—')}</td></tr>`).join('')
      :'<tr><td colspan="5">Sin reportes.</td></tr>';
  }

  async function load(){
    const branch=q('dor-branch').value;
    if(!branch){q('dor-msg').innerHTML='<div class="status warn">Seleccione una sucursal.</div>';return;}
    loading=true;
    try{
      const report=await commandData.dailyReport(q('dor-date').value,branch);
      render(report);
      await showEquipment();
      await showVersions();
      showHistory();
      q('dor-msg').innerHTML=report?'<div class="status ok">Reporte cargado.</div>':'<div class="status info">Nuevo reporte para esta fecha y sucursal.</div>';
    }catch(e){q('dor-msg').innerHTML=`<div class="status bad">${esc(e.message)}</div>`;}
    finally{loading=false;}
  }

  async function save(){
    if(!canWrite||loading)return;
    if(!validate()){q('dor-msg').innerHTML='<div class="status warn">Corrija las inconsistencias antes de guardar.</div>';return;}
    const btn=q('dor-save'),label=btn.textContent;
    btn.disabled=true;btn.textContent='Guardando…';
    try{
      const equipment=await equipmentSnapshot();
      await commandData.saveDailyReport({...payload(),equipment_snapshot:equipment});
      await load();
    }catch(e){q('dor-msg').innerHTML=`<div class="status bad">${esc(e.message)}</div>`;}
    finally{btn.textContent=label;setEditable();}
  }

  async function submit(){
    if(!current?.id||!canSubmit||!validate())return;
    if(!confirm('¿Enviar el reporte a revisión? Quedará bloqueado para edición.'))return;
    try{await commandData.submitDailyReport(current.id);await load();}
    catch(e){q('dor-msg').innerHTML=`<div class="status bad">${esc(e.message)}</div>`;}
  }

  async function closeReport(){
    if(!current?.id||!canClose)return;
    if(!confirm('¿Cerrar y firmar este reporte operativo?'))return;
    try{await commandData.closeDailyReport(current.id);await load();}
    catch(e){q('dor-msg').innerHTML=`<div class="status bad">${esc(e.message)}</div>`;}
  }

  async function reopen(){
    if(!current?.id||!canReopen)return;
    const reason=prompt('Motivo de reapertura:','');
    if(!reason?.trim())return;
    try{await commandData.reopenDailyReport(current.id,reason.trim());await load();}
    catch(e){q('dor-msg').innerHTML=`<div class="status bad">${esc(e.message)}</div>`;}
  }

  q('dor-add-lot').onclick=()=>{q('dor-no-screening').checked=false;q('dor-lots').insertAdjacentHTML('beforeend',lotRow());bindRows();validate();};
  q('dor-add-dispatch').onclick=()=>{q('dor-no-dispatch').checked=false;q('dor-dispatches').insertAdjacentHTML('beforeend',dispatchRow());bindRows();validate();};
  q('dor-refresh').onclick=load;
  q('dor-branch').onchange=load;
  q('dor-date').onchange=load;
  q('dor-save').onclick=save;
  q('dor-submit').onclick=submit;
  q('dor-close').onclick=closeReport;
  q('dor-reopen').onclick=reopen;
  q('dor-print').onclick=()=>window.print();

  render();
  await showEquipment();
  showHistory();
  if(q('dor-branch').value)await load();
}
