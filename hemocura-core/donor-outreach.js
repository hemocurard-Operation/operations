import { loadDonorOutreach,createCampaign,setCampaignStatus } from './donor-outreach-data.js';
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
function n(v){return Number(v||0).toLocaleString('es-DO',{maximumFractionDigits:1})}
function today(){return new Date().toISOString().slice(0,10)}
export async function mountDonorOutreach(root){
  root.innerHTML='<section class="card"><div class="status info">Cargando captación de donantes…</div></section>';
  let state=null;
  async function load(){state=await loadDonorOutreach();render()}
  function render(){
    const branchMap=Object.fromEntries(state.branches.map(x=>[x.id,x]));
    const active=state.campaigns.filter(x=>x.status==='ACTIVA').length;
    const target=state.campaigns.filter(x=>['PLANIFICADA','ACTIVA'].includes(x.status)).reduce((a,x)=>a+Number(x.target_donors||0),0);
    const captured=state.campaigns.filter(x=>['PLANIFICADA','ACTIVA','CERRADA'].includes(x.status)).reduce((a,x)=>a+Number(x.donations_captured||0),0);
    root.innerHTML=`
      <div class="sales-toolbar"><div><h2 class="section-heading">Captación de Donantes</h2><div class="muted">Campañas dirigidas por demanda e inventario. El módulo no decide elegibilidad clínica.</div></div><button id="campaign-new">Nueva campaña</button></div>
      <div id="campaign-status"></div>
      <div class="grid sales-kpis"><section class="card"><div class="muted">Campañas activas</div><div class="kpi">${n(active)}</div></section><section class="card"><div class="muted">Meta abierta</div><div class="kpi">${n(target)}</div></section><section class="card"><div class="muted">Donaciones atribuidas</div><div class="kpi">${n(captured)}</div></section></div>
      <section class="card"><div class="status info"><strong>Cadena:</strong> brecha de demanda/inventario → campaña → donación registrada con campaña → resultado → aprendizaje de captación.</div></section>
      <section class="card"><div class="table-wrap"><table class="data-table"><thead><tr><th>Código</th><th>Campaña</th><th>Sucursal</th><th>Canal</th><th>Periodo</th><th>Meta</th><th>Captadas</th><th>%</th><th>Estado</th></tr></thead><tbody>${state.campaigns.map(c=>`<tr><td><code>${esc(c.campaign_code)}</code></td><td><strong>${esc(c.name)}</strong></td><td>${esc(branchMap[c.branch_id]?.name||'Corporativo')}</td><td>${esc(c.channel)}</td><td>${esc(c.start_date)} → ${esc(c.end_date||'abierta')}</td><td>${n(c.target_donors)}</td><td>${n(c.donations_captured)}</td><td>${n(c.attainment_pct)}%</td><td><select data-campaign-status="${esc(c.id)}"><option ${c.status==='PLANIFICADA'?'selected':''}>PLANIFICADA</option><option ${c.status==='ACTIVA'?'selected':''}>ACTIVA</option><option ${c.status==='PAUSADA'?'selected':''}>PAUSADA</option><option ${c.status==='CERRADA'?'selected':''}>CERRADA</option><option ${c.status==='CANCELADA'?'selected':''}>CANCELADA</option></select></td></tr>`).join('')||'<tr><td colspan="9" class="muted">No hay campañas registradas.</td></tr>'}</tbody></table></div></section>
      <dialog id="campaign-dialog" class="sales-dialog"><form id="campaign-form"><h3>Nueva campaña de donantes</h3>
        <label>Código<input id="campaign-code" required placeholder="CMP-2026-001"></label><label>Nombre<input id="campaign-name" required></label>
        <label>Sucursal<select id="campaign-branch"><option value="">Corporativa</option>${state.branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
        <label>Canal<select id="campaign-channel"><option>MIXTO</option><option>EMPRESAS</option><option>REDES_SOCIALES</option><option>MEDICOS</option><option>COMUNIDAD</option><option>UNIVERSIDADES</option></select></label>
        <label>Audiencia<input id="campaign-audience" placeholder="Empresas, familiares, comunidad…"></label>
        <div class="filter-grid"><label>Inicio<input id="campaign-start" type="date" value="${today()}" required></label><label>Fin<input id="campaign-end" type="date"></label><label>Meta donantes<input id="campaign-target" type="number" min="0" value="20"></label></div>
        <label>Notas<textarea id="campaign-notes"></textarea></label><div class="dialog-actions"><button type="button" class="secondary" id="campaign-cancel">Cancelar</button><button type="submit">Crear campaña</button></div>
      </form></dialog>`;
    root.querySelector('#campaign-new').onclick=()=>root.querySelector('#campaign-dialog').showModal();
    root.querySelector('#campaign-cancel').onclick=()=>root.querySelector('#campaign-dialog').close();
    root.querySelector('#campaign-form').onsubmit=async e=>{e.preventDefault();try{await createCampaign({campaign_code:root.querySelector('#campaign-code').value.trim(),branch_id:root.querySelector('#campaign-branch').value||null,name:root.querySelector('#campaign-name').value.trim(),channel:root.querySelector('#campaign-channel').value,audience:root.querySelector('#campaign-audience').value.trim()||null,start_date:root.querySelector('#campaign-start').value,end_date:root.querySelector('#campaign-end').value||null,target_donors:Number(root.querySelector('#campaign-target').value||0),status:'PLANIFICADA',notes:root.querySelector('#campaign-notes').value.trim()||null});root.querySelector('#campaign-dialog').close();await load()}catch(err){root.querySelector('#campaign-status').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}};
    root.querySelectorAll('[data-campaign-status]').forEach(sel=>sel.onchange=async()=>{try{await setCampaignStatus(sel.dataset.campaignStatus,sel.value);root.querySelector('#campaign-status').innerHTML='<div class="status ok">Campaña actualizada.</div>'}catch(err){root.querySelector('#campaign-status').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}});
  }
  try{await load()}catch(err){root.innerHTML=`<section class="card"><div class="status bad">${esc(err.message)}</div></section>`}
}
