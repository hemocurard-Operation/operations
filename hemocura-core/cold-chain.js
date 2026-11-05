import {coldChainData} from './cold-chain-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const now=()=>{const d=new Date();return d.toISOString().slice(0,16)};

export async function mountColdChain(root){
  const devices=await coldChainData.devices();
  const dm=Object.fromEntries(devices.map(d=>[d.id,d.device_code]));
  let filterDevice='',filterStatus='';

  root.innerHTML=`
  <div class="sales-toolbar"><div><h2 class="section-heading">Cadena de Frío</h2>
  <div class="muted">Almacenamiento, transporte y excursiones térmicas.</div></div>
  <button id="cc-new-reading">Registrar lectura</button></div>

  <div id="cc-msg"></div>
  <div class="filter-grid">
    <label>Dispositivo<select id="cc-filter-device"><option value="">Todos</option>${devices.map(d=>`<option value="${esc(d.device_code)}">${esc(d.device_code)} · ${esc(d.device_type||'')}</option>`).join('')}</select></label>
    <label>Estado excursión<select id="cc-filter-status"><option value="">Todos</option><option value="ABIERTA">Abierta</option><option value="RESUELTA">Resuelta</option></select></label>
  </div>

  <div class="grid sales-kpis" id="cc-kpis"></div>

  <section class="card"><h3>Excursiones</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Fecha</th><th>Dispositivo</th><th>Tipo</th><th>Ubicación</th><th>Temperatura</th><th>Rango</th><th>Estado</th></tr></thead>
  <tbody id="cc-body"></tbody></table></div></section>

  <section class="card"><h3>Transportes</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Código</th><th>Origen</th><th>Destino</th><th>Salida</th><th>Llegada</th><th>Estado</th></tr></thead>
  <tbody id="cc-trans"></tbody></table></div></section>

  <dialog id="cc-reading-dialog" class="sales-dialog"><form id="cc-reading-form">
  <h3>Registrar lectura de temperatura</h3>
  <label>Dispositivo<select id="ccr-device" required><option value="">Seleccionar…</option>${devices.map(d=>`<option value="${esc(d.id)}">${esc(d.device_code)} · ${esc(d.device_type||'')}</option>`).join('')}</select></label>
  <label>Temperatura (°C)<input id="ccr-temp" type="number" step="0.1" required></label>
  <label>Fecha y hora<input id="ccr-time" type="datetime-local" value="${now()}" required></label>
  <label>Ubicación<input id="ccr-location" placeholder="Ej. Refrigerador principal"></label>
  <label>Notas<textarea id="ccr-notes"></textarea></label>
  <div class="dialog-actions"><button type="button" id="ccr-cancel" class="secondary">Cancelar</button><button>Guardar</button></div>
  </form></dialog>`;

  function v(id){return document.getElementById(id).value.trim()}

  async function load(){
    try{
      const [x,t]=await Promise.all([coldChainData.excursions(),coldChainData.transports()]);

      let filtered=x;
      if(filterDevice) filtered=filtered.filter(r=>r.device_code===filterDevice);
      if(filterStatus) filtered=filtered.filter(r=>(r.status||'').toUpperCase()===filterStatus);

      const total=filtered.length;
      const active=filtered.filter(r=>!['RESUELTA','CERRADA','RESOLVED','CLOSED'].includes((r.status||'').toUpperCase())).length;
      const resolved=total-active;
      const activeTrans=t.filter(r=>!['COMPLETADO','ENTREGADO','CANCELADO'].includes((r.status||'').toUpperCase())).length;

      document.getElementById('cc-kpis').innerHTML=`
        <section class="card"><div class="muted">Total excursiones</div><div class="kpi">${total}</div></section>
        <section class="card"><div class="muted">Activas</div><div class="kpi">${active}</div></section>
        <section class="card"><div class="muted">Resueltas</div><div class="kpi">${resolved}</div></section>
        <section class="card"><div class="muted">Transportes activos</div><div class="kpi">${activeTrans}</div></section>`;

      document.getElementById('cc-body').innerHTML=filtered.length?filtered.map(r=>{
        const st=(r.status||'').toUpperCase();
        const cls=['RESUELTA','CERRADA','RESOLVED','CLOSED'].includes(st)?'ok':'bad';
        return `<tr><td>${esc(new Date(r.reading_time).toLocaleString('es-DO'))}</td><td><code>${esc(r.device_code)}</code></td><td>${esc(r.device_type)}</td><td>${esc(r.location||'—')}</td><td>${esc(r.temperature)}</td><td>${esc(r.min_temp)} a ${esc(r.max_temp)}</td><td><span class="status ${cls}">${esc(r.status)}</span></td></tr>`;
      }).join(''):'<tr><td colspan="7">Sin excursiones.</td></tr>';

      document.getElementById('cc-trans').innerHTML=t.length?t.map(r=>{
        const st=(r.status||'').toUpperCase();
        const cls=['COMPLETADO','ENTREGADO'].includes(st)?'ok':st==='CANCELADO'?'bad':'info';
        return `<tr><td><code>${esc(r.transport_code)}</code></td><td>${esc(r.origin)}</td><td>${esc(r.destination)}</td><td>${esc(r.departure_at||'—')}</td><td>${esc(r.arrival_at||'—')}</td><td><span class="status ${cls}">${esc(r.status)}</span></td></tr>`;
      }).join(''):'<tr><td colspan="6">Sin transportes.</td></tr>';

      document.getElementById('cc-msg').innerHTML='';
    }catch(err){document.getElementById('cc-msg').innerHTML=`<div class="status warn">${esc(err.message)}</div>`}
  }

  document.getElementById('cc-filter-device').onchange=e=>{filterDevice=e.target.value;load()};
  document.getElementById('cc-filter-status').onchange=e=>{filterStatus=e.target.value;load()};

  document.getElementById('cc-new-reading').onclick=()=>document.getElementById('cc-reading-dialog').showModal();
  document.getElementById('ccr-cancel').onclick=()=>document.getElementById('cc-reading-dialog').close();
  document.getElementById('cc-reading-form').onsubmit=async e=>{
    e.preventDefault();
    try{
      await coldChainData.addReading({
        device_id:v('ccr-device'),
        temperature:Number(v('ccr-temp')),
        reading_time:new Date(v('ccr-time')).toISOString(),
        location:v('ccr-location')||null,
        notes:v('ccr-notes')||null
      });
      document.getElementById('cc-reading-dialog').close();
      e.target.reset();
      document.getElementById('ccr-time').value=now();
      document.getElementById('cc-msg').innerHTML='<div class="status ok">Lectura registrada.</div>';
      await load();
    }catch(err){document.getElementById('cc-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
  };

  await load();
}
