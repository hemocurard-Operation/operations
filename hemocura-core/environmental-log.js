import {resourcesData} from './resources-data.js';
import {getBranches} from './sales-data.js';
import {loadAccess} from './access-control.js';
import {buildMonthMatrix,daysInMonth,monthRangeISO} from './environmental-domain.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
function environmentalStyles(){if(!document.querySelector('[data-env-style]')){const l=document.createElement('link');l.rel='stylesheet';l.href=new URL('../css/environmental-log.css',import.meta.url).href;l.dataset.envStyle='';document.head.append(l)}}
const SYMBOL={ok:'✓',bad:'✕',partial:'⚠',empty:'—'};
const MONTHS=['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
function today(){return new Date()}
function pad2(n){return String(n).padStart(2,'0')}
function stepTemps(min,max){
  const lo=Math.floor((min??0)-2),hi=Math.ceil((max??0)+2);
  const out=[];
  for(let v=lo;v<=hi;v+=0.5)out.push(Math.round(v*10)/10);
  return out;
}

export async function mountEnvironmentalLog(root){
  environmentalStyles();
  root.innerHTML='<section class="card"><div class="status info">Cargando control ambiental…</div></section>';
  let branches,access;
  try{[branches,access]=await Promise.all([getBranches(),loadAccess()])}
  catch(e){root.innerHTML=`<section class="card"><div class="status bad">${esc(e.message)}</div></section>`;return}
  const write=access.permissions.has('RESOURCES_WRITE');
  const now=today();
  let state={branchId:branches[0]?.id||'',year:now.getFullYear(),month:now.getMonth()+1};
  let points=[],readings=[],matrix={},profilesById={};

  async function load(){
    try{
      const [allPoints,people]=await Promise.all([resourcesData.points(),resourcesData.profiles()]);
      points=allPoints.filter(p=>p.branch_id===state.branchId);
      profilesById=Object.fromEntries(people.map(p=>[p.id,p.full_name]));
      const {fromISO,toISO}=monthRangeISO(state.year,state.month);
      readings=await resourcesData.readingsInRange(points.map(p=>p.id),fromISO,toISO);
      matrix=buildMonthMatrix(points,readings,state.year,state.month);
      render();
    }catch(e){
      root.innerHTML=`<section class="card"><div class="status bad">${esc(e.message)}</div></section>`;
    }
  }

  function dayDetail(pointId,day){
    return readings.filter(r=>r.point_id===pointId && new Date(r.reading_time).getDate()===day)
      .sort((a,b)=>a.reading_time.localeCompare(b.reading_time));
  }

  function monthGridHtml(){
    const total=daysInMonth(state.year,state.month);
    const head=Array.from({length:total},(_,i)=>i+1).map(d=>{
      const wd=new Date(state.year,state.month-1,d).getDay();
      return `<th class="env-day${wd===0||wd===6?' env-weekend':''}">${d}</th>`;
    }).join('');
    const rows=points.map(p=>{
      const cells=Array.from({length:total},(_,i)=>i+1).map(d=>{
        const s=matrix[p.id]?.[d]||'empty';
        return `<td><button type="button" class="env-cell env-${s}" data-point="${esc(p.id)}" data-day="${d}" title="${esc(p.point_code)} · día ${d}">${s==='empty'?'':SYMBOL[s]}</button></td>`;
      }).join('');
      return `<tr><td class="env-point"><strong>${esc(p.point_code)}</strong><div class="muted">${esc(p.area)} · ${esc(p.min_allowed??'—')} a ${esc(p.max_allowed??'—')} ${esc(p.unit)}</div></td>${cells}</tr>`;
    }).join('');
    return `<div class="table-wrap"><table class="data-table env-month-table"><thead><tr><th class="env-point">Punto de control</th>${head}</tr></thead><tbody>${rows||'<tr><td colspan="99">No hay puntos de control activos para esta sucursal.</td></tr>'}</tbody></table></div>`;
  }

  function printSheetHtml(){
    const total=daysInMonth(state.year,state.month);
    const head=Array.from({length:total},(_,i)=>i+1).map(d=>`<th>${d}</th>`).join('');
    const rows=points.map(p=>{
      const cells=Array.from({length:total},(_,i)=>i+1).map(d=>`<td class="env-print-${matrix[p.id]?.[d]||'empty'}">${SYMBOL[matrix[p.id]?.[d]||'empty']}</td>`).join('');
      return `<tr><td class="env-print-name">${esc(p.point_code)}<span>${esc(p.min_allowed??'—')}–${esc(p.max_allowed??'—')}${esc(p.unit)}</span></td>${cells}</tr>`;
    }).join('');
    const branchName=branches.find(b=>b.id===state.branchId)?.name||'';
    return `<div class="env-print-sheet">
      <h4>HemoCura · Control Ambiental — Reporte Mensual</h4>
      <div class="env-print-meta"><span>Sucursal: ${esc(branchName)}</span><span>Mes: ${esc(MONTHS[state.month-1])} ${esc(state.year)}</span><span>Generado: ${esc(today().toLocaleDateString('es-DO'))}</span></div>
      <table class="env-print-table"><thead><tr><th>Equipo</th>${head}</tr></thead><tbody>${rows}</tbody></table>
      <div class="env-print-legend"><span>✓ conforme</span><span>⚠ excursión corregida</span><span>✕ excursión sin corregir</span><span>— sin lectura</span></div>
      <p class="env-print-footnote">* Detalle de horario y responsable disponible en el sistema.</p>
      <div class="env-print-sign"><div>Responsable de laboratorio</div><div>Supervisor de calidad</div></div>
    </div>`;
  }

  function render(){
    root.innerHTML=`
      <div class="sales-toolbar"><div><h2 class="section-heading">Control Ambiental y Temperaturas</h2><div class="muted">Registro diario de neveras, congeladores, incubadoras y ambiente. Vista mensual por equipo; el detalle de horario y responsable se consulta por día.</div></div>${write?'<button id="env-new-point" class="secondary">+ Nuevo punto</button>':''}</div>
      <div id="env-msg"></div>
      <form id="env-filters" class="card filter-grid">
        <label>Sucursal<select id="env-f-branch">${branches.map(b=>`<option value="${esc(b.id)}" ${state.branchId===b.id?'selected':''}>${esc(b.name)}</option>`).join('')}</select></label>
        <label>Mes<select id="env-f-month">${MONTHS.map((m,i)=>`<option value="${i+1}" ${state.month===i+1?'selected':''}>${esc(m)}</option>`).join('')}</select></label>
        <label>Año<input id="env-f-year" type="number" value="${state.year}" min="2024" max="2100"></label>
        <button type="submit">Actualizar</button>
      </form>
      <section class="card">${monthGridHtml()}</section>
      <div class="env-legend">
        <span><i class="env-swatch env-ok"></i>✓ Todas las lecturas del día en rango</span>
        <span><i class="env-swatch env-partial"></i>⚠ Excursión corregida el mismo día</span>
        <span><i class="env-swatch env-bad"></i>✕ Excursión sin corregir</span>
        <span><i class="env-swatch env-empty"></i>Sin lecturas — clic para registrar</span>
      </div>
      <div class="sales-toolbar" style="margin-top:20px"><div><h3 class="section-heading">Hoja de impresión del mes</h3><div class="muted">Resumen diario por equipo en una sola página, sin desglose de horario.</div></div><button id="env-print" class="secondary">Imprimir reporte del mes</button></div>
      <section class="card">${printSheetHtml()}</section>
      ${write?'<dialog id="env-point-dialog" class="sales-dialog"></dialog>':''}
      <dialog id="env-reading-dialog" class="sales-dialog"></dialog>
    `;

    document.getElementById('env-filters').onsubmit=e=>{
      e.preventDefault();
      state={branchId:document.getElementById('env-f-branch').value,month:Number(document.getElementById('env-f-month').value),year:Number(document.getElementById('env-f-year').value)};
      load();
    };
    document.getElementById('env-print').onclick=()=>{
      const w=window.open('','_blank');
      if(!w)return;
      w.document.write(`<!doctype html><html><head><title>Control ambiental — ${esc(MONTHS[state.month-1])} ${esc(state.year)}</title><style>${PRINT_CSS}</style></head><body>${printSheetHtml()}</body></html>`);
      w.document.close();
      w.focus();
      w.print();
    };
    root.querySelectorAll('.env-cell').forEach(btn=>btn.onclick=()=>openDayDetail(btn.dataset.point,Number(btn.dataset.day)));
    document.getElementById('env-new-point')?.addEventListener('click',openNewPoint);
  }

  function openDayDetail(pointId,day){
    const point=points.find(p=>p.id===pointId);
    const dialog=document.getElementById('env-reading-dialog');
    const rows=dayDetail(pointId,day);
    dialog.innerHTML=`
      <div>
        <h3>${esc(point.point_code)} · ${day} de ${esc(MONTHS[state.month-1])}</h3>
        <p class="muted">${esc(point.area)} · rango ${esc(point.min_allowed??'—')} a ${esc(point.max_allowed??'—')} ${esc(point.unit)}</p>
        <div class="table-wrap"><table class="data-table"><thead><tr><th>Hora</th><th>Valor</th><th>Responsable</th></tr></thead><tbody>${rows.length?rows.map(r=>`<tr><td>${new Date(r.reading_time).toLocaleTimeString('es-DO',{hour:'2-digit',minute:'2-digit'})}</td><td>${esc(r.value)}${esc(point.unit)}</td><td>${esc(profilesById[r.recorded_by]||'—')}</td></tr>`).join(''):'<tr><td colspan="3">Sin lecturas este día.</td></tr>'}</tbody></table></div>
        ${write?readingFormHtml(point,day):''}
        <div class="dialog-actions"><button type="button" id="env-reading-close" class="secondary">Cerrar</button></div>
      </div>`;
    dialog.querySelector('#env-reading-close').onclick=()=>dialog.close();
    const form=dialog.querySelector('#env-reading-form');
    if(form)bindReadingForm(form,point,day,dialog);
    dialog.showModal();
  }

  function readingFormHtml(point,day){
    const options=stepTemps(point.min_allowed,point.max_allowed);
    const roleName=access.context?.full_name||access.context?.email||'Usuario autenticado';
    return `<form id="env-reading-form">
      <h4>Registrar lectura</h4>
      <div class="filter-grid">
        <label>Hora<input name="time" type="time" value="${pad2(today().getHours())}:${pad2(today().getMinutes())}" required></label>
        <label>${esc(point.parameter==='TEMPERATURA'?'Temperatura':'Valor')} (${esc(point.unit)})<select name="value" required>${options.map(v=>`<option${v===options[Math.floor(options.length/2)]?' selected':''}>${v}</option>`).join('')}</select></label>
      </div>
      <label>Observación<textarea name="observation" placeholder="Obligatoria si la lectura queda fuera de rango"></textarea></label>
      <div class="env-sign-box">
        <div class="env-sign-who"><strong>${esc(roleName)}</strong><div class="muted">Firma al registrar: queda sellado como responsable de esta lectura.</div></div>
        <button type="submit">Firmar y registrar lectura</button>
      </div>
    </form>`;
  }

  function bindReadingForm(form,point,day,dialog){
    form.onsubmit=async e=>{
      e.preventDefault();
      const fd=new FormData(form);
      const [hh,mm]=String(fd.get('time')||'00:00').split(':');
      const readingTime=new Date(state.year,state.month-1,day,Number(hh),Number(mm));
      const value=Number(fd.get('value'));
      if(point.min_allowed!=null && point.max_allowed!=null && (value<point.min_allowed||value>point.max_allowed) && !String(fd.get('observation')||'').trim()){
        root.querySelector('#env-msg').innerHTML='<div class="status bad">La observación es obligatoria cuando la lectura queda fuera de rango.</div>';
        return;
      }
      try{
        await resourcesData.addReading({point_id:point.id,reading_time:readingTime.toISOString(),value,observation:fd.get('observation')||null});
        dialog.close();
        await load();
      }catch(err){root.querySelector('#env-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
    };
  }

  function openNewPoint(){
    const dialog=document.getElementById('env-point-dialog');
    dialog.innerHTML=`<form id="env-point-form"><h3>Nuevo punto de control</h3>
      <label>Código<input name="point_code" required placeholder="NEV-PLASMA-01"></label>
      <label>Área<input name="area" required placeholder="Banco de sangre"></label>
      <div class="filter-grid">
        <label>Parámetro<select name="parameter"><option value="TEMPERATURA">Temperatura</option><option value="HUMEDAD">Humedad</option><option value="PRESION">Presión</option><option value="OTRO">Otro</option></select></label>
        <label>Unidad<input name="unit" required placeholder="°C"></label>
      </div>
      <div class="filter-grid">
        <label>Mínimo permitido<input name="min_allowed" type="number" step="0.1"></label>
        <label>Máximo permitido<input name="max_allowed" type="number" step="0.1"></label>
      </div>
      <div class="dialog-actions"><button type="button" id="env-point-close" class="secondary">Cancelar</button><button type="submit">Guardar</button></div>
    </form>`;
    dialog.querySelector('#env-point-close').onclick=()=>dialog.close();
    dialog.querySelector('#env-point-form').onsubmit=async e=>{
      e.preventDefault();
      const fd=Object.fromEntries(new FormData(e.target));
      try{
        await resourcesData.createPoint({...fd,branch_id:state.branchId,min_allowed:fd.min_allowed||null,max_allowed:fd.max_allowed||null,active:true});
        dialog.close();
        await load();
      }catch(err){root.querySelector('#env-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
    };
    dialog.showModal();
  }

  await load();
}

const PRINT_CSS=`
  body{font:12px/1.4 "IBM Plex Mono",monospace;color:#111;margin:24px}
  .env-print-sheet h4{font-family:Georgia,serif;font-size:16px;margin:0 0 6px}
  .env-print-meta{display:flex;gap:16px;font-size:10px;color:#555;margin-bottom:10px}
  .env-print-table{width:100%;border-collapse:collapse;font-size:9px;table-layout:fixed}
  .env-print-table th,.env-print-table td{border:1px solid #999;padding:3px 2px;text-align:center}
  .env-print-table td.env-print-name{text-align:left;padding-left:6px;width:160px}
  .env-print-name span{display:block;font-size:8px;color:#555}
  .env-print-ok{color:#2f6b3e;font-weight:700}
  .env-print-bad{color:#8a2d2d;font-weight:700;background:#fbe9e7}
  .env-print-partial{color:#8a5a12;font-weight:700}
  .env-print-legend{display:flex;gap:12px;font-size:9px;margin-top:10px}
  .env-print-footnote{font-size:9px;color:#555}
  .env-print-sign{display:flex;justify-content:space-between;margin-top:20px;font-size:10px;gap:20px}
  .env-print-sign div{flex:1;border-top:1px solid #333;padding-top:4px;text-align:center}
  @page{size:landscape}
`;
