import { getBranches } from './sales-data.js';
import { loadAccess } from './access-control.js';
import { loadDailyInventoryCapture,saveDailyInventoryCapture,recentDailyInventoryCaptures } from './daily-inventory-data.js';

const GROUPS=['A+','A-','B+','B-','O+','O-','AB+','AB-'];
const EQUIPMENT=['Vidas','GenXpert','Mindray','Horiba','Centrífugas','Microscopio','PC Server','PC Bioanalista'];
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const today=()=>new Date().toISOString().slice(0,10);
const n=v=>Math.max(0,Number(v||0));

function numberInput(id,value=0){return `<input id="${id}" type="number" min="0" step="1" inputmode="numeric" value="${n(value)}">`}
function movementRow(g,data={}){const k=g.replace('+','p').replace('-','n');return `<tr><th>${g}</th><td>${numberInput(`mv-${k}-received`,data.received)}</td><td>${numberInput(`mv-${k}-pending`,data.pending)}</td><td>${numberInput(`mv-${k}-discarded`,data.discarded)}</td></tr>`}
function inventoryRow(g,data={}){const k=g.replace('+','p').replace('-','n');return `<tr><th>${g}</th><td>${numberInput(`av-${k}-whole`,data.whole_blood)}</td><td>${numberInput(`av-${k}-packed`,data.packed_cells)}</td><td>${numberInput(`av-${k}-plasma`,data.plasma)}</td><td>${numberInput(`av-${k}-platelets`,data.platelets)}</td></tr>`}
function equipmentRow(name,index,data={}){return `<tr><th>${esc(name)}</th><td><select id="eq-${index}-state"><option value="OPERATIVO" ${data.operational!==false?'selected':''}>Operativo</option><option value="AVERIA" ${data.operational===false?'selected':''}>Avería</option></select></td><td><input id="eq-${index}-note" value="${esc(data.observation||'')}" placeholder="Opcional"></td></tr>`}

function emptyCapture(){return {donor_counts:{accepted:0,deferred:0,discarded:0},daily_movement:{},available_inventory:{},equipment_status:{},observations:'',status:'BORRADOR'}}
function key(g){return g.replace('+','p').replace('-','n')}
function val(id){return document.getElementById(id)?.value??''}

export async function mountDailyInventory(root){
  const [branches,access]=await Promise.all([getBranches(),loadAccess()]);
  const branchMap=Object.fromEntries(branches.map(b=>[b.id,b.name]));
  const preferredBranch=access?.context?.branch_id||access?.context?.current_branch_id||'';

  root.innerHTML=`
    <div class="sales-toolbar"><div><h2 class="section-heading">Captura diaria de inventario</h2><div class="muted">Un solo formato para donantes, movimiento, disponibilidad y funcionamiento de equipos.</div></div><button id="di-refresh" class="secondary">Actualizar</button></div>
    <div id="di-msg"></div>
    <section class="card quick-capture">
      <div class="quick-capture-head"><div><div class="eyebrow">Paso 1</div><h3>Identifica el reporte</h3></div><span id="di-state" class="state-pill state-info">BORRADOR</span></div>
      <div class="filter-grid">
        <label>Fecha<input id="di-date" type="date" value="${today()}"></label>
        <label>Turno<select id="di-shift"><option>DIURNO</option><option>NOCTURNO</option><option>24 HORAS</option></select></label>
        <label>Sucursal<select id="di-branch"><option value="">Seleccionar…</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
        <label>Responsable / Bioanalista<input id="di-responsible" placeholder="Nombre"></label>
        <label>Área / Servicio<input id="di-area" value="LABORATORIO"></label>
      </div>
      <button id="di-load" class="secondary">Cargar reporte del día</button>
    </section>

    <section class="card"><div class="quick-capture-head"><div><div class="eyebrow">Paso 2</div><h3>Donantes atendidos</h3></div></div>
      <div class="ops-kpi-grid capture-counts">
        <label class="capture-box"><strong>Aceptados</strong>${numberInput('di-accepted')}</label>
        <label class="capture-box"><strong>Diferidos</strong>${numberInput('di-deferred')}</label>
        <label class="capture-box"><strong>Descartados</strong>${numberInput('di-discarded')}</label>
      </div>
    </section>

    <section class="card"><div class="quick-capture-head"><div><div class="eyebrow">Paso 3</div><h3>Movimiento del día</h3></div></div>
      <div class="table-wrap"><table class="data-table capture-table"><thead><tr><th>Grupo</th><th>Recibidos</th><th>Pendientes de análisis</th><th>Descartadas</th></tr></thead><tbody id="di-movement"></tbody></table></div>
    </section>

    <section class="card"><div class="quick-capture-head"><div><div class="eyebrow">Paso 4</div><h3>Inventario disponible</h3></div></div>
      <div class="table-wrap"><table class="data-table capture-table"><thead><tr><th>Grupo</th><th>Sangre total</th><th>Paquete globular</th><th>Plasma</th><th>Plaquetas</th></tr></thead><tbody id="di-available"></tbody></table></div>
    </section>

    <section class="card"><div class="quick-capture-head"><div><div class="eyebrow">Paso 5</div><h3>Equipos / funcionalidad</h3></div></div>
      <div class="table-wrap"><table class="data-table capture-table"><thead><tr><th>Equipo</th><th>Estado</th><th>Avería / observación</th></tr></thead><tbody id="di-equipment"></tbody></table></div>
    </section>

    <section class="card"><label><strong>Observaciones</strong><textarea id="di-observations" rows="4" placeholder="Novedades del turno, faltantes, incidencias u observaciones relevantes"></textarea></label></section>

    <section class="card"><div class="dialog-actions"><button id="di-save" class="secondary">Guardar borrador</button><button id="di-complete">Guardar como completado</button></div><p class="muted">“Completado” indica que el reporte diario fue terminado. No sustituye revisión o aprobación clínica.</p></section>

    <details class="card"><summary><strong>Histórico reciente</strong></summary><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Turno</th><th>Sucursal</th><th>Responsable</th><th>Estado</th><th>Actualizado</th></tr></thead><tbody id="di-history"></tbody></table></div></details>`;

  if(preferredBranch&&branches.some(b=>b.id===preferredBranch))document.getElementById('di-branch').value=preferredBranch;
  else if(branches.length===1)document.getElementById('di-branch').value=branches[0].id;

  function renderTables(data=emptyCapture()){
    document.getElementById('di-accepted').value=n(data.donor_counts?.accepted);
    document.getElementById('di-deferred').value=n(data.donor_counts?.deferred);
    document.getElementById('di-discarded').value=n(data.donor_counts?.discarded);
    document.getElementById('di-movement').innerHTML=GROUPS.map(g=>movementRow(g,data.daily_movement?.[g]||{})).join('');
    document.getElementById('di-available').innerHTML=GROUPS.map(g=>inventoryRow(g,data.available_inventory?.[g]||{})).join('');
    document.getElementById('di-equipment').innerHTML=EQUIPMENT.map((name,i)=>equipmentRow(name,i,data.equipment_status?.[name]||{})).join('');
    document.getElementById('di-observations').value=data.observations||'';
    document.getElementById('di-state').textContent=data.status||'BORRADOR';
    document.getElementById('di-state').className=`state-pill ${data.status==='COMPLETADO'?'state-ok':'state-info'}`;
  }

  function payload(status){
    const daily_movement={},available_inventory={},equipment_status={};
    for(const g of GROUPS){const k=key(g);daily_movement[g]={received:n(val(`mv-${k}-received`)),pending:n(val(`mv-${k}-pending`)),discarded:n(val(`mv-${k}-discarded`))};available_inventory[g]={whole_blood:n(val(`av-${k}-whole`)),packed_cells:n(val(`av-${k}-packed`)),plasma:n(val(`av-${k}-plasma`)),platelets:n(val(`av-${k}-platelets`))}}
    EQUIPMENT.forEach((name,i)=>equipment_status[name]={operational:val(`eq-${i}-state`)==='OPERATIVO',observation:val(`eq-${i}-note`).trim()||null});
    return {capture_date:val('di-date'),shift:val('di-shift'),branch_id:val('di-branch'),responsible_name:val('di-responsible').trim()||null,service_area:val('di-area').trim()||'LABORATORIO',donor_counts:{accepted:n(val('di-accepted')),deferred:n(val('di-deferred')),discarded:n(val('di-discarded'))},daily_movement,available_inventory,equipment_status,observations:val('di-observations').trim()||null,status};
  }

  async function loadHistory(){const rows=await recentDailyInventoryCaptures();document.getElementById('di-history').innerHTML=rows.length?rows.map(r=>`<tr><td>${esc(r.capture_date)}</td><td>${esc(r.shift)}</td><td>${esc(branchMap[r.branch_id]||r.branch_id)}</td><td>${esc(r.responsible_name||'—')}</td><td>${esc(r.status)}</td><td>${esc(r.updated_at?new Date(r.updated_at).toLocaleString('es-DO'):'—')}</td></tr>`).join(''):'<tr><td colspan="6" class="muted">Sin reportes.</td></tr>'}

  async function loadCurrent(){const branchId=val('di-branch');if(!branchId){document.getElementById('di-msg').innerHTML='<div class="status warn">Seleccione una sucursal.</div>';return}document.getElementById('di-msg').innerHTML='<div class="status info">Buscando reporte…</div>';try{const row=await loadDailyInventoryCapture({captureDate:val('di-date'),shift:val('di-shift'),branchId});if(row){document.getElementById('di-responsible').value=row.responsible_name||'';document.getElementById('di-area').value=row.service_area||'LABORATORIO';renderTables(row);document.getElementById('di-msg').innerHTML='<div class="status ok">Reporte existente cargado.</div>'}else{renderTables(emptyCapture());document.getElementById('di-msg').innerHTML='<div class="status info">No existe reporte para esta combinación. Puede iniciar uno nuevo.</div>'}}catch(e){document.getElementById('di-msg').innerHTML=`<div class="status bad">${esc(e.message)} · Verifique que sql/40_DAILY_INVENTORY_CAPTURE_v0_40.sql esté instalado.</div>`}}

  async function save(status){if(!val('di-branch')){document.getElementById('di-msg').innerHTML='<div class="status warn">Seleccione una sucursal.</div>';return}const btn=status==='COMPLETADO'?document.getElementById('di-complete'):document.getElementById('di-save');btn.disabled=true;const old=btn.textContent;btn.textContent='Guardando…';try{const row=await saveDailyInventoryCapture(payload(status));renderTables(row);document.getElementById('di-msg').innerHTML=`<div class="status ok">Reporte ${status==='COMPLETADO'?'completado':'guardado como borrador'}.</div>`;await loadHistory()}catch(e){document.getElementById('di-msg').innerHTML=`<div class="status bad">${esc(e.message)}</div>`}finally{btn.disabled=false;btn.textContent=old}}

  document.getElementById('di-load').onclick=loadCurrent;
  document.getElementById('di-refresh').onclick=async()=>{await loadCurrent();await loadHistory()};
  document.getElementById('di-save').onclick=()=>save('BORRADOR');
  document.getElementById('di-complete').onclick=()=>save('COMPLETADO');
  renderTables(emptyCapture());
  await loadHistory();
  if(val('di-branch'))await loadCurrent();
}
