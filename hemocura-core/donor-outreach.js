import { loadDonorOutreach,createCampaign,setCampaignStatus,linkDonationToCampaign } from './donor-outreach-data.js';
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
function n(v){return Number(v||0).toLocaleString('es-DO',{maximumFractionDigits:1})}
function money(v){return Number(v||0).toLocaleString('es-DO',{style:'currency',currency:'DOP',maximumFractionDigits:0})}
function today(){return new Date().toISOString().slice(0,10)}
function pctBar(pct,color){const w=Math.min(100,Math.max(0,Number(pct)||0));return `<div style="display:flex;align-items:center;gap:6px"><div style="flex:1;height:8px;background:#e0e0e0;border-radius:4px;overflow:hidden"><div style="width:${w}%;height:100%;background:${color};border-radius:4px"></div></div><span style="font-size:.8rem;min-width:40px">${n(pct)}%</span></div>`}
export async function mountDonorOutreach(root){
  root.innerHTML='<section class="card"><div class="status info">Cargando captación de donantes…</div></section>';
  let state=null,filterBranch='',filterCampaignStatus='';
  async function load(){state=await loadDonorOutreach();render()}
  function render(){
    const branchMap=Object.fromEntries(state.branches.map(x=>[x.id,x]));
    const campaigns=state.campaigns.filter(c=>(!filterBranch||c.branch_id===filterBranch)&&(!filterCampaignStatus||c.status===filterCampaignStatus));
    const allCampaigns=filterBranch?state.campaigns.filter(c=>c.branch_id===filterBranch):state.campaigns;
    const active=allCampaigns.filter(x=>x.status==='ACTIVA').length;
    const target=allCampaigns.filter(x=>['PLANIFICADA','ACTIVA'].includes(x.status)).reduce((a,x)=>a+Number(x.target_donors||0),0);
    const captured=allCampaigns.filter(x=>['PLANIFICADA','ACTIVA','CERRADA'].includes(x.status)).reduce((a,x)=>a+Number(x.donations_captured||0),0);
    const donations=filterBranch?state.donations.filter(d=>d.branch_id===filterBranch):state.donations;
    const unlinked=donations.filter(x=>!x.campaign_id).length;
    const totalContacts=allCampaigns.reduce((a,x)=>a+Number(x.contacts_reached||0),0);
    const totalDonations=allCampaigns.reduce((a,x)=>a+Number(x.donations_captured||0),0);
    const conversionPct=totalContacts?Math.round(totalDonations/totalContacts*100*10)/10:0;
    const totalCost=allCampaigns.reduce((a,x)=>a+Number(x.actual_cost||0),0);
    const costPerAcq=totalDonations?Math.round(totalCost/totalDonations):0;
    root.innerHTML=`
      <div class="sales-toolbar"><div><h2 class="section-heading">Captación de Donantes</h2><div class="muted">Campañas dirigidas por demanda e inventario. El módulo no decide elegibilidad clínica.</div></div><button id="campaign-new">Nueva campaña</button></div>
      <div id="campaign-status"></div>
      ${unlinked>0?`<div class="status warn" style="margin:0 0 12px">⚠ ${unlinked} donación${unlinked>1?'es':''} sin campaña atribuida. Asigne campañas en la tabla de atribución.</div>`:''}
      <form class="card filter-grid" id="do-filters">
        <label>Sucursal<select name="branch"><option value="">Todas</option>${state.branches.map(b=>`<option value="${esc(b.id)}" ${filterBranch===b.id?'selected':''}>${esc(b.name)}</option>`).join('')}</select></label>
        <label>Estado campaña<select name="cstatus"><option value="">Todos</option>${['PLANIFICADA','ACTIVA','PAUSADA','CERRADA','CANCELADA'].map(s=>`<option ${filterCampaignStatus===s?'selected':''}>${s}</option>`).join('')}</select></label>
        <button>Filtrar</button>
      </form>
      <div class="grid sales-kpis">
        <section class="card"><div class="muted">Campañas activas</div><div class="kpi">${n(active)}</div></section>
        <section class="card"><div class="muted">Meta abierta</div><div class="kpi">${n(target)}</div></section>
        <section class="card"><div class="muted">Donaciones atribuidas</div><div class="kpi">${n(captured)}</div></section>
        <section class="card"><div class="muted">Sin campaña</div><div class="kpi ${unlinked>0?'':'muted'}">${n(unlinked)}</div></section>
        <section class="card"><div class="muted">Conversión contactos→donaciones</div><div class="kpi">${conversionPct}%<br><small class="muted">${n(totalDonations)}/${n(totalContacts)}</small></div></section>
        <section class="card"><div class="muted">Costo por adquisición</div><div class="kpi">${costPerAcq?money(costPerAcq):'—'}</div></section>
      </div>
      <section class="card"><div class="status info"><strong>Cadena:</strong> brecha de demanda/inventario → campaña → donación registrada → atribución de campaña → resultado → aprendizaje de captación. La atribución no altera el estado clínico de la donación.</div></section>
      <section class="card"><h3>Campañas</h3><div class="table-wrap"><table class="data-table"><thead><tr><th>Código</th><th>Campaña</th><th>Sucursal</th><th>Canal</th><th>Periodo</th><th>Meta</th><th>Captadas</th><th>Progreso</th><th>Estado</th></tr></thead><tbody>${campaigns.map(c=>`<tr><td><code>${esc(c.campaign_code)}</code></td><td><strong>${esc(c.name)}</strong></td><td>${esc(branchMap[c.branch_id]?.name||'Corporativo')}</td><td>${esc(c.channel)}</td><td>${esc(c.start_date)} → ${esc(c.end_date||'abierta')}</td><td>${n(c.target_donors)}</td><td>${n(c.donations_captured)}</td><td>${pctBar(c.attainment_pct,Number(c.attainment_pct)>=80?'#2e7d32':Number(c.attainment_pct)>=50?'#e65100':'#c62828')}</td><td><select data-campaign-status="${esc(c.id)}"><option ${c.status==='PLANIFICADA'?'selected':''}>PLANIFICADA</option><option ${c.status==='ACTIVA'?'selected':''}>ACTIVA</option><option ${c.status==='PAUSADA'?'selected':''}>PAUSADA</option><option ${c.status==='CERRADA'?'selected':''}>CERRADA</option><option ${c.status==='CANCELADA'?'selected':''}>CANCELADA</option></select></td></tr>`).join('')||'<tr><td colspan="9" class="muted">No hay campañas registradas.</td></tr>'}</tbody></table></div></section>
      <section class="card"><div class="card-head"><h3>Atribución de donaciones recientes</h3><span class="muted">Solo relación administrativa campaña↔donación</span></div><div class="table-wrap"><table class="data-table"><thead><tr><th>Donación</th><th>Fecha</th><th>Sucursal</th><th>Estado registrado</th><th>Campaña</th></tr></thead><tbody>${donations.map(d=>`<tr><td><code>${esc(String(d.id).slice(0,8))}</code></td><td>${esc(d.donation_date)}</td><td>${esc(branchMap[d.branch_id]?.name||'—')}</td><td>${esc(d.status||'—')}</td><td><select data-donation-campaign="${esc(d.id)}"><option value="">Sin campaña</option>${state.campaigns.filter(c=>!c.branch_id||c.branch_id===d.branch_id).map(c=>`<option value="${esc(c.id)}" ${d.campaign_id===c.id?'selected':''}>${esc(c.campaign_code)} · ${esc(c.name)}</option>`).join('')}</select></td></tr>`).join('')||'<tr><td colspan="5" class="muted">No hay donaciones recientes visibles.</td></tr>'}</tbody></table></div></section>
      <dialog id="campaign-dialog" class="sales-dialog"><form id="campaign-form"><h3>Nueva campaña de donantes</h3>
        <label>Código<input id="campaign-code" required placeholder="CMP-2026-001"></label><label>Nombre<input id="campaign-name" required></label>
        <label>Sucursal<select id="campaign-branch"><option value="">Corporativa</option>${state.branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}</select></label>
        <label>Canal<select id="campaign-channel"><option>MIXTO</option><option>EMPRESAS</option><option>REDES_SOCIALES</option><option>MEDICOS</option><option>COMUNIDAD</option><option>UNIVERSIDADES</option></select></label>
        <label>Audiencia<input id="campaign-audience" placeholder="Empresas, familiares, comunidad…"></label>
        <div class="filter-grid"><label>Inicio<input id="campaign-start" type="date" value="${today()}" required></label><label>Fin<input id="campaign-end" type="date"></label><label>Meta donantes<input id="campaign-target" type="number" min="0" value="20"></label></div>
        <label>Notas<textarea id="campaign-notes"></textarea></label><div class="dialog-actions"><button type="button" class="secondary" id="campaign-cancel">Cancelar</button><button type="submit">Crear campaña</button></div>
      </form></dialog>`;
    root.querySelector('#do-filters').onsubmit=ev=>{ev.preventDefault();const f=new FormData(ev.target);filterBranch=f.get('branch');filterCampaignStatus=f.get('cstatus');render()};
    root.querySelector('#campaign-new').onclick=()=>root.querySelector('#campaign-dialog').showModal();
    root.querySelector('#campaign-cancel').onclick=()=>root.querySelector('#campaign-dialog').close();
    root.querySelector('#campaign-form').onsubmit=async e=>{e.preventDefault();try{await createCampaign({campaign_code:root.querySelector('#campaign-code').value.trim(),branch_id:root.querySelector('#campaign-branch').value||null,name:root.querySelector('#campaign-name').value.trim(),channel:root.querySelector('#campaign-channel').value,audience:root.querySelector('#campaign-audience').value.trim()||null,start_date:root.querySelector('#campaign-start').value,end_date:root.querySelector('#campaign-end').value||null,target_donors:Number(root.querySelector('#campaign-target').value||0),status:'PLANIFICADA',notes:root.querySelector('#campaign-notes').value.trim()||null});root.querySelector('#campaign-dialog').close();await load()}catch(err){root.querySelector('#campaign-status').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}};
    root.querySelectorAll('[data-campaign-status]').forEach(sel=>sel.onchange=async()=>{try{await setCampaignStatus(sel.dataset.campaignStatus,sel.value);root.querySelector('#campaign-status').innerHTML='<div class="status ok">Campaña actualizada.</div>'}catch(err){root.querySelector('#campaign-status').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}});
    root.querySelectorAll('[data-donation-campaign]').forEach(sel=>sel.onchange=async()=>{try{await linkDonationToCampaign(sel.dataset.donationCampaign,sel.value||null);root.querySelector('#campaign-status').innerHTML='<div class="status ok">Atribución guardada sin modificar el estado clínico.</div>';await load()}catch(err){root.querySelector('#campaign-status').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}});
  }
  try{await load()}catch(err){root.innerHTML=`<section class="card"><div class="status bad">${esc(err.message)}</div></section>`}
}
