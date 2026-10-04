import { resourcesData } from './resources-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);

export async function mountResources(root){
  const [branches,profiles,points]=await Promise.all([
    resourcesData.branches(),resourcesData.profiles(),resourcesData.points()
  ]);
  const bm=Object.fromEntries(branches.map(x=>[x.id,x.name]));

  root.innerHTML=`
  <div class="sales-toolbar"><div><h2 class="section-heading">Recursos Críticos</h2>
  <div class="muted">Equipos, mantenimiento/calibración, reactivos y condiciones ambientales.</div></div>
  <button id="res-eq-new">Nuevo equipo</button></div>

  <div id="res-msg"></div><div class="grid sales-kpis" id="res-kpis"></div>

  <section class="card"><h3>Equipos</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Código</th><th>Sucursal</th><th>Tipo</th><th>Modelo</th><th>Serie</th><th>Criticidad</th><th>Estado</th><th>Calibración</th><th>Mantenimiento</th></tr></thead>
  <tbody id="res-eq"></tbody></table></div></section>

  <section class="card"><h3>Alertas de equipos</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Equipo</th><th>Sucursal</th><th>Tipo alerta</th><th>Fecha</th><th>Severidad</th><th>Mensaje</th></tr></thead>
  <tbody id="res-eq-alerts"></tbody></table></div></section>

  <section class="card"><h3>Reactivos / lotes</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Reactivo</th><th>Lote</th><th>Sucursal</th><th>Vence</th><th>Disponible</th><th>Verificación</th></tr></thead>
  <tbody id="res-reagents"></tbody></table></div></section>

  <section class="card"><h3>Excursiones ambientales — 30 días</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Fecha/hora</th><th>Sucursal</th><th>Punto</th><th>Área</th><th>Parámetro</th><th>Valor</th><th>Rango</th><th>Mensaje</th></tr></thead>
  <tbody id="res-env"></tbody></table></div></section>

  <dialog id="res-eq-dialog" class="sales-dialog"><form id="res-eq-form">
  <h3>Registrar equipo</h3>
  <label>Código<input id="re-code" required></label>
  <label>Sucursal<select id="re-branch"><option value="">General</option>${branches.map(x=>`<option value="${x.id}">${esc(x.name)}</option>`).join('')}</select></label>
  <label>Tipo<input id="re-type" required></label>
  <label>Fabricante<input id="re-maker"></label>
  <label>Modelo<input id="re-model"></label>
  <label>Serie<input id="re-serial"></label>
  <label>Ubicación<input id="re-location"></label>
  <label>Criticidad<select id="re-critical"><option>MEDIA</option><option>ALTA</option><option>CRITICA</option><option>BAJA</option></select></label>
  <label>Responsable<select id="re-owner"><option value="">Sin asignar</option>${profiles.map(x=>`<option value="${x.id}">${esc(x.full_name||x.id)}</option>`).join('')}</select></label>
  <label><input id="re-cal-required" type="checkbox"> Requiere calibración</label>
  <label>Próxima calibración<input id="re-cal-date" type="date"></label>
  <label>Próximo mantenimiento<input id="re-main-date" type="date"></label>
  <div class="dialog-actions"><button type="button" id="re-cancel" class="secondary">Cancelar</button><button>Guardar</button></div>
  </form></dialog>`;

  async function load(){
    try{
      const [eq,eqa,rg,rga,env,sum]=await Promise.all([
        resourcesData.equipment(),resourcesData.equipmentAlerts(),
        resourcesData.reagents(),resourcesData.reagentAlerts(),
        resourcesData.environmental(),resourcesData.summary()
      ]);

      document.getElementById('res-eq').innerHTML=eq.length?eq.map(x=>`<tr>
        <td><code>${esc(x.equipment_code)}</code></td><td>${esc(bm[x.branch_id]||'General')}</td>
        <td>${esc(x.equipment_type)}</td><td>${esc(x.model||'—')}</td><td>${esc(x.serial_number||'—')}</td>
        <td>${esc(x.criticality)}</td><td>${esc(x.status)}</td>
        <td>${esc(x.next_calibration_date||'—')}</td><td>${esc(x.next_maintenance_date||'—')}</td>
      </tr>`).join(''):'<tr><td colspan="9">Sin equipos.</td></tr>';

      document.getElementById('res-eq-alerts').innerHTML=eqa.length?eqa.map(x=>`<tr>
        <td><code>${esc(x.equipment_code)}</code></td><td>${esc(bm[x.branch_id]||'General')}</td>
        <td>${esc(x.alert_type)}</td><td>${esc(x.due_date)}</td><td>${esc(x.severity)}</td><td>${esc(x.message)}</td>
      </tr>`).join(''):'<tr><td colspan="6">Sin alertas.</td></tr>';

      document.getElementById('res-reagents').innerHTML=rg.length?rg.map(x=>`<tr>
        <td>${esc(x.reagent_code)} · ${esc(x.reagent_name)}</td><td>${esc(x.lot_number)}</td>
        <td>${esc(bm[x.branch_id]||'General')}</td><td>${esc(x.expiry_date)}</td>
        <td>${esc(x.quantity_available)} ${esc(x.unit||'')}</td><td>${esc(x.verification_status)}</td>
      </tr>`).join(''):'<tr><td colspan="6">Sin reactivos.</td></tr>';

      document.getElementById('res-env').innerHTML=env.length?env.map(x=>`<tr>
        <td>${esc(new Date(x.reading_time).toLocaleString('es-DO'))}</td>
        <td>${esc(bm[x.branch_id]||x.branch_id)}</td><td>${esc(x.point_code)}</td><td>${esc(x.area)}</td>
        <td>${esc(x.parameter)}</td><td>${esc(x.value)} ${esc(x.unit)}</td>
        <td>${esc(x.min_allowed??'−∞')} a ${esc(x.max_allowed??'+∞')}</td><td>${esc(x.message)}</td>
      </tr>`).join(''):'<tr><td colspan="8">Sin excursiones.</td></tr>';

      document.getElementById('res-kpis').innerHTML=`
        <section class="card"><div class="muted">Equipos activos</div><div class="kpi">${sum.active_equipment}</div></section>
        <section class="card"><div class="muted">Alertas equipos</div><div class="kpi">${sum.equipment_high_alerts}</div></section>
        <section class="card"><div class="muted">Alertas reactivos</div><div class="kpi">${sum.reagent_high_alerts}</div></section>
        <section class="card"><div class="muted">Excursiones 30d</div><div class="kpi">${sum.environmental_excursions_30d}</div></section>`;
      document.getElementById('res-msg').innerHTML='';
    }catch(e){
      document.getElementById('res-msg').innerHTML=`<div class="status warn">${esc(e.message)} · Ejecute sql/35_RESOURCES_CONTROL_v0_35.sql.</div>`;
    }
  }

  document.getElementById('res-eq-new').onclick=()=>document.getElementById('res-eq-dialog').showModal();
  document.getElementById('re-cancel').onclick=()=>document.getElementById('res-eq-dialog').close();
  document.getElementById('res-eq-form').onsubmit=async e=>{
    e.preventDefault();
    try{
      await resourcesData.createEquipment({
        equipment_code:document.getElementById('re-code').value.trim(),
        branch_id:document.getElementById('re-branch').value||null,
        equipment_type:document.getElementById('re-type').value.trim(),
        manufacturer:document.getElementById('re-maker').value.trim()||null,
        model:document.getElementById('re-model').value.trim()||null,
        serial_number:document.getElementById('re-serial').value.trim()||null,
        location:document.getElementById('re-location').value.trim()||null,
        criticality:document.getElementById('re-critical').value,
        responsible_user_id:document.getElementById('re-owner').value||null,
        calibration_required:document.getElementById('re-cal-required').checked,
        next_calibration_date:document.getElementById('re-cal-date').value||null,
        next_maintenance_date:document.getElementById('re-main-date').value||null,
        maintenance_required:true,status:'ACTIVO'
      });
      document.getElementById('res-eq-dialog').close();e.target.reset();await load();
    }catch(err){
      document.getElementById('res-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`;
    }
  };

  await load();
}
