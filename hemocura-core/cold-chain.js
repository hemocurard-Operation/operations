import {coldChainData} from './cold-chain-data.js';
const e=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));

export async function mountColdChain(root){
  let devices=[], excursions=[], transports=[];
  root.innerHTML=`
    <div class="sales-toolbar">
      <div><h2 class="section-heading">Cadena de Frío</h2><div class="muted">Registra temperatura en segundos y revisa solo las desviaciones que requieren atención.</div></div>
      <button id="cc-new">Registrar temperatura</button>
    </div>
    <div id="cc-msg"></div>

    <section class="card quick-capture">
      <div class="quick-capture-head"><div><div class="eyebrow">Control rápido</div><h3>Temperatura actual</h3></div></div>
      <p class="muted">Selecciona el dispositivo y registra el valor observado. La fecha/hora se genera automáticamente.</p>
      <div class="filter-grid">
        <label>Filtrar dispositivo<input id="cc-filter" type="search" placeholder="Código, tipo o ubicación"></label>
        <label>Estado<select id="cc-status-filter"><option value="">Todos</option><option value="FUERA_RANGO">Solo fuera de rango</option></select></label>
      </div>
    </section>

    <section class="card"><div class="card-head"><h3>Excursiones térmicas</h3><span id="cc-count" class="muted"></span></div><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Dispositivo</th><th>Tipo</th><th>Ubicación</th><th>Temperatura</th><th>Rango</th><th>Estado</th></tr></thead><tbody id="cc-body"></tbody></table></div></section>

    <details class="card"><summary><strong>Transportes</strong> <span class="muted">Ver eventos de traslado</span></summary><div class="table-wrap"><table class="data-table"><thead><tr><th>Código</th><th>Origen</th><th>Destino</th><th>Salida</th><th>Llegada</th><th>Estado</th></tr></thead><tbody id="cc-trans"></tbody></table></div></details>

    <dialog id="cc-dialog" class="sales-dialog"><form id="cc-form">
      <h3>Registrar temperatura</h3><p class="muted">Solo dos datos son obligatorios.</p>
      <label>Dispositivo<select id="cc-device" required autofocus><option value="">Seleccionar…</option></select></label>
      <label>Temperatura<input id="cc-temp" type="number" step="0.01" inputmode="decimal" required placeholder="Ej. 4.2"></label>
      <details class="advanced-fields"><summary>Observación opcional</summary><label>Observación<textarea id="cc-observation" placeholder="Ej. lectura al inicio del turno"></textarea></label></details>
      <div id="cc-form-msg" role="status" aria-live="polite"></div>
      <div class="dialog-actions"><button type="button" id="cc-cancel" class="secondary">Cancelar</button><button type="submit">Guardar lectura</button></div>
    </form></dialog>`;

  function deviceLabel(d){return `${d.device_code} · ${d.device_type}${d.location?` · ${d.location}`:''}`}
  function renderDevices(){
    const q=document.getElementById('cc-filter').value.trim().toLowerCase();
    const visible=devices.filter(d=>!q||deviceLabel(d).toLowerCase().includes(q));
    document.getElementById('cc-device').innerHTML=`<option value="">Seleccionar…</option>${visible.map(d=>`<option value="${e(d.id)}">${e(deviceLabel(d))} · ${e(d.min_temp)} a ${e(d.max_temp)} °C</option>`).join('')}`;
  }
  function renderExcursions(){
    const onlyOut=document.getElementById('cc-status-filter').value==='FUERA_RANGO';
    const q=document.getElementById('cc-filter').value.trim().toLowerCase();
    const rows=excursions.filter(r=>(!onlyOut||r.status==='FUERA_RANGO')&&(!q||`${r.device_code} ${r.device_type} ${r.location||''}`.toLowerCase().includes(q)));
    document.getElementById('cc-count').textContent=`${rows.length} registro(s)`;
    document.getElementById('cc-body').innerHTML=rows.length?rows.map(r=>`<tr><td>${e(new Date(r.reading_time).toLocaleString('es-DO'))}</td><td><code>${e(r.device_code)}</code></td><td>${e(r.device_type)}</td><td>${e(r.location||'—')}</td><td><strong>${e(r.temperature)} °C</strong></td><td>${e(r.min_temp)} a ${e(r.max_temp)} °C</td><td><span class="status warn">${e(r.status)}</span></td></tr>`).join(''):'<tr><td colspan="7">Sin excursiones para el filtro actual.</td></tr>';
  }
  function renderTransports(){document.getElementById('cc-trans').innerHTML=transports.length?transports.map(r=>`<tr><td><code>${e(r.transport_code)}</code></td><td>${e(r.origin)}</td><td>${e(r.destination)}</td><td>${e(r.departure_at||'—')}</td><td>${e(r.arrival_at||'—')}</td><td>${e(r.status)}</td></tr>`).join(''):'<tr><td colspan="6">Sin transportes.</td></tr>'}
  async function load(){
    try{
      [devices,excursions,transports]=await Promise.all([coldChainData.devices(),coldChainData.excursions(),coldChainData.transports()]);
      renderDevices();renderExcursions();renderTransports();
    }catch(err){document.getElementById('cc-msg').innerHTML=`<div class="status warn">${e(err.message)}</div>`}
  }
  document.getElementById('cc-new').onclick=()=>{document.getElementById('cc-form').reset();renderDevices();document.getElementById('cc-form-msg').textContent='';document.getElementById('cc-dialog').showModal()};
  document.getElementById('cc-cancel').onclick=()=>document.getElementById('cc-dialog').close();
  document.getElementById('cc-filter').addEventListener('input',()=>{renderDevices();renderExcursions()});
  document.getElementById('cc-status-filter').addEventListener('change',renderExcursions);
  document.getElementById('cc-form').onsubmit=async ev=>{
    ev.preventDefault();const btn=ev.submitter;if(btn.disabled)return;btn.disabled=true;btn.textContent='Guardando…';
    const device=devices.find(d=>d.id===document.getElementById('cc-device').value);const temp=Number(document.getElementById('cc-temp').value);const msg=document.getElementById('cc-form-msg');
    try{
      if(!device)throw new Error('Seleccione un dispositivo');
      await coldChainData.addReading({device_id:device.id,temperature:temp,source:'MANUAL',observation:document.getElementById('cc-observation').value.trim()||null});
      const out=temp<Number(device.min_temp)||temp>Number(device.max_temp);
      document.getElementById('cc-dialog').close();
      document.getElementById('cc-msg').innerHTML=out?`<div class="status warn"><strong>Lectura fuera de rango:</strong> ${e(temp)} °C. Requiere evaluación según procedimiento.</div>`:`<div class="status ok">Temperatura registrada dentro del rango configurado.</div>`;
      await load();
    }catch(err){msg.innerHTML=`<div class="status bad">${e(err.message)}. El valor permanece en el formulario.</div>`}
    finally{btn.disabled=false;btn.textContent='Guardar lectura'}
  };
  await load();
}
