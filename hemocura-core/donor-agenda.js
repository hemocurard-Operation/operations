import { esc, table, field } from './workflow-ui.js';
const STATES={FECHA_ALCANZADA:'Fecha alcanzada',PROXIMA:'Próxima',SIN_FECHA:'Sin fecha de última donación',FECHA_POR_VERIFICAR:'Fecha por verificar'};
export function renderDonorAgenda(root,rows,onOpen){
 let page=0,query='',state='',start='',end='';const size=25;
 const counted=s=>rows.filter(r=>r.agenda_state===s).length;
 root.innerHTML=`<details class="card donor-agenda" open><summary><strong>Agenda de próxima donación · 12 semanas</strong></summary><p class="muted">Última donación + 84 días. Las fechas calculadas sirven para coordinar el contacto y requieren evaluación clínica antes de donar.</p><div class="donor-flow"><span>Fecha alcanzada: <strong>${counted('FECHA_ALCANZADA')}</strong></span><span>Próximas: <strong>${counted('PROXIMA')}</strong></span><span>Sin fecha: <strong>${counted('SIN_FECHA')}</strong></span><span>Por verificar: <strong>${counted('FECHA_POR_VERIFICAR')}</strong></span></div><div class="filter-grid donor-agenda-filters">${field('agenda_search','Buscar donante','search','',{required:false})}${field('agenda_state','Estado de la fecha','select','',{required:false,items:[['','Todos'],...Object.entries(STATES)]})}${field('agenda_start','Desde (fecha calculada)','date','',{required:false})}${field('agenda_end','Hasta (fecha calculada)','date','',{required:false})}</div><div data-agenda-error role="status"></div><div data-agenda-table></div><div class="donor-actions"><button type="button" class="secondary" data-agenda-prev>Anterior</button><span data-agenda-count class="muted" aria-live="polite"></span><button type="button" class="secondary" data-agenda-next>Siguiente</button></div></details>`;
 function draw(){
  const invalid=start&&end&&start>end;root.querySelector('[data-agenda-error]').textContent=invalid?'La fecha Desde debe ser anterior o igual a Hasta.':'';
  const text=query.toLocaleLowerCase('es');const digits=query.replace(/\D/g,'');
  const filtered=invalid?[]:rows.filter(r=>{
   const match=!text||[r.full_name,r.donor_code,r.cedula,r.phone].some(v=>String(v||'').toLocaleLowerCase('es').includes(text))||(digits&&[r.cedula,r.phone].some(v=>String(v||'').replace(/\D/g,'').includes(digits)));
   return (!state||r.agenda_state===state)&&(!start||(r.next_donation_date&&r.next_donation_date>=start))&&(!end||(r.next_donation_date&&r.next_donation_date<=end))&&match;
  }).sort((a,b)=>(a.next_donation_date||'9999').localeCompare(b.next_donation_date||'9999')||String(a.full_name||'').localeCompare(String(b.full_name||''),'es'));
  const pages=Math.max(1,Math.ceil(filtered.length/size));page=Math.min(page,pages-1);
  root.querySelector('[data-agenda-table]').innerHTML=table(['Donante','Teléfono','Última donación','Próxima donación (84 días)','Estado de fecha','Origen','Acción'],filtered.slice(page*size,(page+1)*size).map(r=>[`${esc(r.full_name||r.donor_code)}<br><small>${esc(r.donor_code)}</small>`,esc(r.phone||'Sin teléfono'),esc(r.last_donation_date||'Sin registrar'),esc(r.next_donation_date||'Pendiente'),esc(STATES[r.agenda_state]||'Pendiente'),esc(r.reference_source==='REGISTRO_HEMOCURA'?'HemoCura':r.reference_source==='EXCEL_IMPORTADO'?'Antecedente del Excel':'—'),`<button type="button" class="secondary" data-agenda-open="${esc(r.id)}">Abrir ficha</button>`]));
  root.querySelector('[data-agenda-count]').textContent=`${filtered.length} donantes · Página ${page+1} de ${pages}`;
  root.querySelector('[data-agenda-prev]').disabled=page===0;root.querySelector('[data-agenda-next]').disabled=page===pages-1;
  root.querySelectorAll('[data-agenda-open]').forEach(b=>b.onclick=()=>onOpen(b.dataset.agendaOpen));
 }
 for(const [name,assign] of [['agenda_search',v=>query=v],['agenda_state',v=>state=v],['agenda_start',v=>start=v],['agenda_end',v=>end=v]])root.querySelector(`[name=${name}]`).addEventListener(name==='agenda_search'?'input':'change',e=>{assign(e.target.value);page=0;draw()});
 root.querySelector('[data-agenda-prev]').onclick=()=>{page--;draw()};root.querySelector('[data-agenda-next]').onclick=()=>{page++;draw()};draw();
}
