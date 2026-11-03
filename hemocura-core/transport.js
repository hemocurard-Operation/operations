import {transportData,transportStatuses} from './transport-data.js';
// Nota: el registro de temperatura en ruta (transport_temperature_readings) se omite
// hasta confirmar que la tabla existe en producción; ver sql/39_COLD_CHAIN_v0_39.sql.
import {getBranches} from './sales-data.js';
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
function today(){return new Date().toISOString().slice(0,10)}
function nowLocal(){return new Date().toISOString().slice(0,16)}
function fmt(dt){return dt?new Date(dt).toLocaleString('es-DO'):'—'}
function statusClass(s=''){
  const x=String(s).toUpperCase();
  if(x==='RECIBIDO')return 'sale-closed';
  if(x==='EN_TRANSITO')return 'sale-confirmed';
  if(x==='CUARENTENA')return 'sev-critical';
  if(x==='CANCELADO')return 'muted';
  return 'sale-draft';
}
const NEXT_STATUS={PLANIFICADO:'EN_TRANSITO',EN_TRANSITO:'RECIBIDO'};
const NEXT_LABEL={PLANIFICADO:'Marcar salida',EN_TRANSITO:'Marcar llegada'};

export async function mountTransport(root){
  root.innerHTML='<section class="card"><div class="status info">Cargando reporte de traslados…</div></section>';
  let branches=[];
  try{branches=await getBranches()}catch(e){root.innerHTML=`<section class="card"><div class="status bad">${esc(e.message)}</div></section>`;return}
  const bm=Object.fromEntries(branches.map(b=>[b.id,b.name]));
  let filters={branchId:'',status:'',from:'',to:''};
  let rows=[];

  function kpis(){
    const planificados=rows.filter(r=>r.status==='PLANIFICADO').length;
    const enTransito=rows.filter(r=>r.status==='EN_TRANSITO').length;
    const cuarentena=rows.filter(r=>r.status==='CUARENTENA').length;
    const recibidosHoy=rows.filter(r=>r.status==='RECIBIDO'&&(r.arrival_at||'').slice(0,10)===today()).length;
    return `<div class="grid sales-kpis">
      <section class="card"><div class="muted">Planificados</div><div class="kpi">${planificados}</div></section>
      <section class="card"><div class="muted">En tránsito</div><div class="kpi">${enTransito}</div></section>
      <section class="card"><div class="muted">En cuarentena</div><div class="kpi">${cuarentena}</div></section>
      <section class="card"><div class="muted">Recibidos hoy</div><div class="kpi">${recibidosHoy}</div></section>
    </div>`;
  }

  function rowHtml(r){
    const nextStatus=NEXT_STATUS[r.status];
    const actions=[];
    if(nextStatus)actions.push(`<button class="secondary compact" data-advance="${esc(r.id)}" data-next="${esc(nextStatus)}">${esc(NEXT_LABEL[r.status])}</button>`);
    if(r.status==='EN_TRANSITO')actions.push(`<button class="secondary compact" data-quarantine="${esc(r.id)}">Cuarentena</button>`);
    if(r.status!=='RECIBIDO'&&r.status!=='CANCELADO')actions.push(`<button class="secondary compact" data-cancel="${esc(r.id)}">Cancelar</button>`);
    actions.push(`<button class="secondary compact" data-detail="${esc(r.id)}">Detalle</button>`);
    return `<tr>
      <td><code>${esc(r.transport_code)}</code></td>
      <td>${esc(bm[r.branch_id]||'—')}</td>
      <td>${esc(r.origin)}</td>
      <td>${esc(r.destination)}</td>
      <td>${fmt(r.departure_at)}</td>
      <td>${fmt(r.arrival_at)}</td>
      <td>${esc(r.responsible||'—')}</td>
      <td><span class="sale-status ${statusClass(r.status)}">${esc(r.status)}</span></td>
      <td><div class="quick-links">${actions.join(' ')}</div></td>
    </tr>`;
  }

  async function load(){
    try{
      rows=await transportData.list(filters);
      render();
    }catch(e){
      document.getElementById('tr-msg').innerHTML=`<div class="status warn">${esc(e.message)} · Instale SQL v0.39.0.</div>`;
    }
  }

  function render(){
    root.innerHTML=`
      <div class="sales-toolbar"><div><h2 class="section-heading">Transporte</h2><div class="muted">Reporte de traslados entre sucursales y seguimiento de cadena de frío en ruta.</div></div><button id="tr-new">Nuevo traslado</button></div>
      <div id="tr-msg"></div>
      <form id="tr-filters" class="card filter-grid">
        <label>Sucursal<select id="tr-f-branch"><option value="">Todas</option>${branches.map(b=>`<option value="${esc(b.id)}"${filters.branchId===b.id?' selected':''}>${esc(b.name)}</option>`).join('')}</select></label>
        <label>Estado<select id="tr-f-status"><option value="">Todos</option>${transportStatuses().map(s=>`<option value="${esc(s)}"${filters.status===s?' selected':''}>${esc(s)}</option>`).join('')}</select></label>
        <label>Desde<input id="tr-f-from" type="date" value="${esc(filters.from)}"></label>
        <label>Hasta<input id="tr-f-to" type="date" value="${esc(filters.to)}"></label>
        <button type="submit">Filtrar</button>
      </form>
      ${kpis()}
      <section class="card"><div class="table-wrap"><table class="data-table"><thead><tr><th>Código</th><th>Sucursal</th><th>Origen</th><th>Destino</th><th>Salida</th><th>Llegada</th><th>Responsable</th><th>Estado</th><th>Acciones</th></tr></thead><tbody>${rows.length?rows.map(rowHtml).join(''):'<tr><td colspan="9">Sin traslados para los filtros seleccionados.</td></tr>'}</tbody></table></div></section>

      <dialog id="tr-dialog" class="sales-dialog"><form id="tr-form"><h3>Nuevo traslado</h3>
        <label>Código<input id="tr-code" required placeholder="TRA-2026-001"></label>
        <label>Sucursal<select id="tr-branch" required><option value="">Seleccionar…</option>${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
        <div class="filter-grid">
          <label>Origen<input id="tr-origin" required></label>
          <label>Destino<input id="tr-destination" required></label>
        </div>
        <div class="filter-grid">
          <label>Salida planificada<input id="tr-departure" type="datetime-local" value="${nowLocal()}"></label>
          <label>Responsable<input id="tr-responsible"></label>
        </div>
        <div class="filter-grid">
          <label>Temp. mínima<input id="tr-min-temp" type="number" step="0.1"></label>
          <label>Temp. máxima<input id="tr-max-temp" type="number" step="0.1"></label>
        </div>
        <label>Referencia de contenedor<input id="tr-container"></label>
        <label>Notas<textarea id="tr-notes"></textarea></label>
        <div class="dialog-actions"><button type="button" id="tr-cancel-dialog" class="secondary">Cancelar</button><button>Guardar</button></div>
      </form></dialog>

      <dialog id="tr-detail-dialog" class="sales-dialog"><div id="tr-detail-body"></div></dialog>
    `;

    document.getElementById('tr-filters').onsubmit=e=>{
      e.preventDefault();
      filters={
        branchId:document.getElementById('tr-f-branch').value,
        status:document.getElementById('tr-f-status').value,
        from:document.getElementById('tr-f-from').value,
        to:document.getElementById('tr-f-to').value
      };
      load();
    };

    document.getElementById('tr-new').onclick=()=>document.getElementById('tr-dialog').showModal();
    document.getElementById('tr-cancel-dialog').onclick=()=>document.getElementById('tr-dialog').close();
    document.getElementById('tr-form').onsubmit=async e=>{
      e.preventDefault();
      try{
        await transportData.create({
          transport_code:document.getElementById('tr-code').value.trim(),
          branch_id:document.getElementById('tr-branch').value,
          origin:document.getElementById('tr-origin').value.trim(),
          destination:document.getElementById('tr-destination').value.trim(),
          departure_at:document.getElementById('tr-departure').value||null,
          responsible:document.getElementById('tr-responsible').value.trim()||null,
          min_temp:document.getElementById('tr-min-temp').value||null,
          max_temp:document.getElementById('tr-max-temp').value||null,
          container_reference:document.getElementById('tr-container').value.trim()||null,
          notes:document.getElementById('tr-notes').value.trim()||null,
          status:'PLANIFICADO'
        });
        document.getElementById('tr-dialog').close();
        e.target.reset();
        await load();
      }catch(err){document.getElementById('tr-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
    };

    root.querySelectorAll('[data-advance]').forEach(btn=>btn.onclick=async()=>{
      const next=btn.dataset.next;
      const extra=next==='EN_TRANSITO'?{departure_at:new Date().toISOString()}:next==='RECIBIDO'?{arrival_at:new Date().toISOString()}:{};
      try{await transportData.updateStatus(btn.dataset.advance,next,extra);await load()}
      catch(err){document.getElementById('tr-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
    });
    root.querySelectorAll('[data-quarantine]').forEach(btn=>btn.onclick=async()=>{
      try{await transportData.updateStatus(btn.dataset.quarantine,'CUARENTENA');await load()}
      catch(err){document.getElementById('tr-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
    });
    root.querySelectorAll('[data-cancel]').forEach(btn=>btn.onclick=async()=>{
      try{await transportData.updateStatus(btn.dataset.cancel,'CANCELADO');await load()}
      catch(err){document.getElementById('tr-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
    });
    root.querySelectorAll('[data-detail]').forEach(btn=>btn.onclick=()=>openDetail(btn.dataset.detail));
  }

  async function openDetail(id){
    const dialog=document.getElementById('tr-detail-dialog');
    const body=document.getElementById('tr-detail-body');
    body.innerHTML='<p class="status info">Cargando detalle…</p>';
    dialog.showModal();
    try{
      const transport=await transportData.get(id);
      body.innerHTML=`
        <h3>Traslado ${esc(transport.transport_code)}</h3>
        <p><strong>Sucursal:</strong> ${esc(bm[transport.branch_id]||'—')} · <strong>Estado:</strong> ${esc(transport.status)}</p>
        <p><strong>Origen:</strong> ${esc(transport.origin)} → <strong>Destino:</strong> ${esc(transport.destination)}</p>
        <p><strong>Salida:</strong> ${fmt(transport.departure_at)} · <strong>Llegada:</strong> ${fmt(transport.arrival_at)}</p>
        <p><strong>Responsable:</strong> ${esc(transport.responsible||'—')} · <strong>Contenedor:</strong> ${esc(transport.container_reference||'—')}</p>
        <p><strong>Rango de temperatura:</strong> ${esc(transport.min_temp??'—')} a ${esc(transport.max_temp??'—')}</p>
        <p><strong>Notas:</strong> ${esc(transport.notes||'—')}</p>
        <div class="dialog-actions"><button type="button" id="tr-detail-close" class="secondary">Cerrar</button></div>
      `;
      body.querySelector('#tr-detail-close').onclick=()=>dialog.close();
    }catch(err){body.innerHTML=`<div class="status bad">${esc(err.message)}</div><div class="dialog-actions"><button type="button" id="tr-detail-close-err" class="secondary">Cerrar</button></div>`;body.querySelector('#tr-detail-close-err').onclick=()=>dialog.close()}
  }

  await load();
}
