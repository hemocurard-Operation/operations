import { commandData } from './command-data.js';
import { bloodData } from './blood-operations-data.js';
import { resourcesData } from './resources-data.js';
import { loadAccess } from './access-control.js';

const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const num=v=>Number(v||0).toLocaleString('es-DO',{maximumFractionDigits:2});
const today=()=>new Date().toISOString().slice(0,10);

function kpi(label,value,detail=''){
  return `<section class="card ops-kpi-card"><div class="muted">${esc(label)}</div><div class="kpi">${esc(value)}</div>${detail?`<small class="muted">${esc(detail)}</small>`:''}</section>`;
}

export async function mountDailyInventory(root){
  root.innerHTML='<section class="card"><div class="status info">Preparando cierre diario…</div></section>';
  const [branches,access]=await Promise.all([commandData.branches(),loadAccess()]);
  const bm=Object.fromEntries(branches.map(b=>[b.id,b.name]));
  const preferred=access?.context?.branch_id||access?.context?.current_branch_id||'';

  root.innerHTML=`
    <div class="sales-toolbar"><div><h2 class="section-heading">Cierre diario de laboratorio</h2><div class="muted">El sistema calcula los datos ya registrados. El usuario revisa excepciones, añade observaciones y cierra.</div></div><button id="dc-refresh" class="secondary">Actualizar</button></div>
    <div id="dc-msg"></div>

    <section class="card quick-capture">
      <div class="quick-capture-head"><div><div class="eyebrow">Único cierre operativo</div><h3>${today()}</h3></div><span id="dc-status" class="state-pill state-info">ABIERTO</span></div>
      <div class="filter-grid"><label>Sucursal<select id="dc-branch"><option value="">Seleccionar…</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label></div>
      <p class="muted">No se vuelven a capturar donantes, tamizajes, inventario ni equipos. Corrija el dato en su módulo de origen si detecta una diferencia.</p>
    </section>

    <section class="ops-section"><div class="ops-section-head"><div><div class="eyebrow">Resumen automático</div><h3>Operación del día</h3></div></div><div class="ops-kpi-grid" id="dc-kpis"></div></section>

    <section class="card"><div class="card-head"><div><h3>Inventario disponible</h3><div class="muted">Fuente: inventario sanguíneo vigente</div></div><a class="secondary" href="#bloodinventory">Corregir inventario</a></div><div class="table-wrap"><table class="data-table"><thead><tr><th>Componente</th><th>ABO</th><th>Rh</th><th>Disponibles</th><th>Cuarentena</th><th>Reservadas</th><th>Próx. vencimiento</th></tr></thead><tbody id="dc-inventory"></tbody></table></div></section>

    <section class="card"><div class="card-head"><div><h3>Equipos que requieren atención</h3><div class="muted">Solo se muestran excepciones; los equipos normales no necesitan marcarse uno por uno.</div></div><a class="secondary" href="#resources">Gestionar equipos</a></div><div class="table-wrap"><table class="data-table"><thead><tr><th>Equipo</th><th>Tipo</th><th>Estado</th><th>Ubicación</th><th>Próxima atención</th></tr></thead><tbody id="dc-equipment"></tbody></table></div></section>

    <section class="card quick-capture"><label><strong>Observaciones / novedades no registradas en otro módulo</strong><textarea id="dc-notes" rows="4" placeholder="Ej.: incidencia operativa relevante, aclaración del cierre o dato pendiente de corregir"></textarea></label><div class="dialog-actions"><button id="dc-close">Cerrar día</button></div><p class="muted">Cerrar el día toma una fotografía de los indicadores operativos existentes. No libera unidades ni sustituye decisiones clínicas.</p></section>

    <details class="card"><summary><strong>Cierres recientes</strong></summary><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Sucursal</th><th>Estado</th><th>Donantes</th><th>Tamizaje</th><th>Disponibles</th><th>Despachadas</th><th>Facturado</th></tr></thead><tbody id="dc-history"></tbody></table></div></details>`;

  if(preferred&&branches.some(b=>b.id===preferred))document.getElementById('dc-branch').value=preferred;
  else if(branches.length===1)document.getElementById('dc-branch').value=branches[0].id;

  async function load(){
    const branchId=document.getElementById('dc-branch').value;
    if(!branchId){document.getElementById('dc-msg').innerHTML='<div class="status warn">Seleccione una sucursal.</div>';return}
    document.getElementById('dc-msg').innerHTML='<div class="status info">Actualizando datos del sistema…</div>';
    try{
      const [ops,recon,inventory,equipment,alerts,history]=await Promise.all([
        commandData.today(),commandData.reconciliation(),bloodData.inventory(),resourcesData.equipment(),resourcesData.equipmentAlerts(),commandData.recentCloses()
      ]);
      const o=ops.find(x=>x.branch_id===branchId)||{};
      const r=recon.find(x=>x.branch_id===branchId)||{};
      const closed=r.close_status==='CERRADO';
      document.getElementById('dc-status').textContent=closed?'CERRADO':'ABIERTO';
      document.getElementById('dc-status').className=`state-pill ${closed?'state-ok':'state-info'}`;
      document.getElementById('dc-kpis').innerHTML=
        kpi('Donantes',o.donors||0,'registrados hoy')+
        kpi('Donaciones efectivas',o.effective_donations||0)+
        kpi('Unidades tamizadas',o.screened_units||0)+
        kpi('Resultados reactivos',o.reactive_results||0)+
        kpi('Unidades disponibles',o.available_units||0)+
        kpi('Unidades despachadas',o.dispatched_units||0)+
        kpi('Facturado',num(o.invoiced_amount||0),'RD$')+
        kpi('Alertas críticas',o.critical_alerts||0,'revisar antes de cerrar');

      const inv=inventory.filter(x=>x.branch_id===branchId);
      document.getElementById('dc-inventory').innerHTML=inv.length?inv.map(x=>`<tr><td>${esc(x.component_name)}</td><td>${esc(x.abo||'—')}</td><td>${esc(x.rh||'—')}</td><td><strong>${esc(x.available_units)}</strong></td><td>${esc(x.quarantine_units)}</td><td>${esc(x.reserved_units)}</td><td>${esc(x.nearest_expiry||'—')}</td></tr>`).join(''):'<tr><td colspan="7">Sin inventario visible.</td></tr>';

      const eq=equipment.filter(x=>x.branch_id===branchId && x.status!=='ACTIVO');
      const alertById=Object.fromEntries(alerts.filter(x=>x.branch_id===branchId).map(x=>[x.equipment_id,x]));
      const attention=[...equipment.filter(x=>x.branch_id===branchId && (x.status!=='ACTIVO'||alertById[x.id]))];
      document.getElementById('dc-equipment').innerHTML=attention.length?attention.map(x=>{const a=alertById[x.id];return `<tr><td><code>${esc(x.equipment_code)}</code></td><td>${esc(x.equipment_type)}</td><td>${esc(x.status)}</td><td>${esc(x.location||'—')}</td><td>${esc(a?`${a.alert_type}: ${a.due_date}`:(x.next_maintenance_date||x.next_calibration_date||'—'))}</td></tr>`}).join(''):'<tr><td colspan="5"><span class="status ok">Sin equipos con atención pendiente.</span></td></tr>';

      const hist=history.filter(x=>x.branch_id===branchId);
      document.getElementById('dc-history').innerHTML=hist.length?hist.map(x=>`<tr><td>${esc(x.close_date)}</td><td>${esc(bm[x.branch_id]||x.branch_id)}</td><td>${esc(x.status)}</td><td>${esc(x.donors_count)}</td><td>${esc(x.screened_units)}</td><td>${esc(x.available_units)}</td><td>${esc(x.dispatched_units)}</td><td>${num(x.invoiced_amount)}</td></tr>`).join(''):'<tr><td colspan="8">Sin cierres recientes.</td></tr>';
      document.getElementById('dc-msg').innerHTML=closed?'<div class="status ok">El día ya está cerrado. Puede actualizar para revisar el estado actual.</div>':'';
      document.getElementById('dc-close').disabled=closed;
    }catch(e){document.getElementById('dc-msg').innerHTML=`<div class="status bad">${esc(e.message)}</div>`}
  }

  document.getElementById('dc-branch').onchange=load;
  document.getElementById('dc-refresh').onclick=load;
  document.getElementById('dc-close').onclick=async()=>{
    const branchId=document.getElementById('dc-branch').value;if(!branchId)return;
    const btn=document.getElementById('dc-close');btn.disabled=true;const old=btn.textContent;btn.textContent='Cerrando…';
    try{await commandData.closeBranch(branchId,document.getElementById('dc-notes').value.trim()||null);document.getElementById('dc-msg').innerHTML='<div class="status ok">Cierre diario registrado.</div>';await load()}catch(e){document.getElementById('dc-msg').innerHTML=`<div class="status bad">${esc(e.message)}</div>`;btn.disabled=false}finally{btn.textContent=old}
  };
  if(document.getElementById('dc-branch').value)await load();
}
