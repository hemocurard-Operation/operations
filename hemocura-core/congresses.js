import { listCongresses, createCongress, listAttendance, createAttendance, listNews, createNews, listReferrers } from './congresses-data.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
const today=()=>new Date().toISOString().slice(0,10);

export async function mountCongresses(root){
  let tab='congresses',scopeFilter='',congresses=[],news=[],referrers=[];

  async function loadAll(){
    [congresses,news,referrers]=await Promise.all([listCongresses(),listNews(),listReferrers()]);
  }

  function filtered(){
    if(!scopeFilter)return congresses;
    return congresses.filter(c=>c.scope===scopeFilter);
  }

  function render(){
    const fc=filtered();
    const upcoming=congresses.filter(c=>c.start_date>today()).length;
    const national=congresses.filter(c=>c.scope==='NACIONAL').length;
    const intl=congresses.filter(c=>c.scope==='INTERNACIONAL').length;
    const thisMonth=today().slice(0,7);
    const newsThisMonth=news.filter(n=>(n.published_at||'').startsWith(thisMonth)).length;
    const catClass={INVESTIGACION:'info',REGULATORIO:'warn',TECNOLOGIA:'ok',CONGRESO:'ok',OTRO:'info'};

    root.innerHTML=`
    <div class="sales-toolbar"><div><h2 class="section-heading">Congresos y Noticias Médicas</h2>
    <div class="muted">Calendario de congresos, asistencia de referidores y noticias del sector.</div></div>
    <div class="dialog-actions">
      ${tab==='congresses'?'<button id="cg-new">Nuevo congreso</button>':'<button id="cg-new-news">Nueva noticia</button>'}
    </div></div>

    <nav style="display:flex;gap:.5rem;margin-bottom:1rem">
      <button class="${tab==='congresses'?'primary':'secondary'}" data-cg-tab="congresses">Congresos</button>
      <button class="${tab==='news'?'primary':'secondary'}" data-cg-tab="news">Noticias médicas</button>
    </nav>

    <div id="cg-msg"></div>

    ${tab==='congresses'?`
      <div class="grid sales-kpis">
        <section class="card"><div class="muted">Total congresos</div><div class="kpi">${congresses.length}</div></section>
        <section class="card"><div class="muted">Próximos</div><div class="kpi">${upcoming}</div></section>
        <section class="card"><div class="muted">Nacionales</div><div class="kpi">${national}</div></section>
        <section class="card"><div class="muted">Internacionales</div><div class="kpi">${intl}</div></section>
      </div>

      <section class="card"><div class="filter-grid" style="margin-bottom:.75rem">
        <label>Ámbito<select id="cg-scope-filter">
          <option value="">Todos</option><option value="NACIONAL" ${scopeFilter==='NACIONAL'?'selected':''}>Nacional</option><option value="INTERNACIONAL" ${scopeFilter==='INTERNACIONAL'?'selected':''}>Internacional</option>
        </select></label>
      </div>
      <div class="table-wrap"><table class="data-table">
        <thead><tr><th>Nombre</th><th>Ámbito</th><th>Sede</th><th>Ciudad / País</th><th>Inicio</th><th>Fin</th><th>Asistentes</th></tr></thead>
        <tbody>${fc.length?fc.map(c=>`<tr data-cg-detail="${esc(c.id)}" style="cursor:pointer">
          <td><strong>${esc(c.name)}</strong></td>
          <td><span class="status ${c.scope==='INTERNACIONAL'?'ok':'info'}">${esc(c.scope)}</span></td>
          <td>${esc(c.venue||'—')}</td>
          <td>${esc([c.city,c.country].filter(Boolean).join(', ')||'—')}</td>
          <td>${esc(c.start_date||'—')}</td>
          <td>${esc(c.end_date||'—')}</td>
          <td>${esc(c.attendee_count??'—')}</td>
        </tr>`).join(''):'<tr><td colspan="7" class="muted">Sin congresos registrados.</td></tr>'}</tbody>
      </table></div></section>
    `:`
      <div class="grid sales-kpis">
        <section class="card"><div class="muted">Total noticias</div><div class="kpi">${news.length}</div></section>
        <section class="card"><div class="muted">Este mes</div><div class="kpi">${newsThisMonth}</div></section>
      </div>

      <div class="grid" style="gap:1rem">
        ${news.length?news.map(n=>`<section class="card">
          <div style="display:flex;justify-content:space-between;align-items:start;gap:.5rem">
            <div>
              <strong>${esc(n.title)}</strong>
              <div class="muted">${esc(n.source||'Sin fuente')} · ${esc(n.published_at||'')}</div>
            </div>
            <span class="status ${catClass[n.category]||'info'}">${esc(n.category||'OTRO')}</span>
          </div>
          <p style="margin:.5rem 0 0">${esc(n.summary||'')}</p>
          ${n.url?`<a href="${esc(n.url)}" target="_blank" rel="noopener" class="muted">Ver fuente →</a>`:''}
        </section>`).join(''):'<section class="card"><div class="muted">Sin noticias registradas.</div></section>'}
      </div>
    `}

    <dialog id="cg-congress-dialog" class="sales-dialog"><form id="cg-congress-form">
      <h3>Nuevo congreso</h3>
      <label>Nombre<input id="cg-name" required></label>
      <label>Ámbito<select id="cg-scope" required><option value="NACIONAL">Nacional</option><option value="INTERNACIONAL">Internacional</option></select></label>
      <label>Sede / lugar<input id="cg-venue"></label>
      <div class="filter-grid">
        <label>Ciudad<input id="cg-city"></label>
        <label>País<input id="cg-country" value="República Dominicana"></label>
      </div>
      <div class="filter-grid">
        <label>Fecha inicio<input id="cg-start" type="date" required></label>
        <label>Fecha fin<input id="cg-end" type="date"></label>
      </div>
      <label>Sitio web<input id="cg-website" type="url"></label>
      <label>Notas<textarea id="cg-notes"></textarea></label>
      <div class="dialog-actions"><button type="button" id="cg-cancel" class="secondary">Cancelar</button><button>Guardar</button></div>
    </form></dialog>

    <dialog id="cg-detail-dialog" class="sales-dialog">
      <div id="cg-detail-body"></div>
    </dialog>

    <dialog id="cg-news-dialog" class="sales-dialog"><form id="cg-news-form">
      <h3>Nueva noticia</h3>
      <label>Título<input id="cg-n-title" required></label>
      <label>Fuente<input id="cg-n-source" required></label>
      <label>URL<input id="cg-n-url" type="url"></label>
      <label>Resumen<textarea id="cg-n-summary" required></textarea></label>
      <div class="filter-grid">
        <label>Categoría<select id="cg-n-category">
          <option>INVESTIGACION</option><option>REGULATORIO</option><option>TECNOLOGIA</option><option>CONGRESO</option><option>OTRO</option>
        </select></label>
        <label>Fecha publicación<input id="cg-n-date" type="date" value="${today()}" required></label>
      </div>
      <div class="dialog-actions"><button type="button" id="cg-n-cancel" class="secondary">Cancelar</button><button>Publicar</button></div>
    </form></dialog>`;

    // Tab navigation
    root.querySelectorAll('[data-cg-tab]').forEach(b=>b.onclick=()=>{tab=b.dataset.cgTab;render()});

    // Scope filter
    document.getElementById('cg-scope-filter')?.addEventListener('change',e=>{scopeFilter=e.target.value;render()});

    // New congress
    document.getElementById('cg-new')?.addEventListener('click',()=>document.getElementById('cg-congress-dialog').showModal());
    document.getElementById('cg-cancel')?.addEventListener('click',()=>document.getElementById('cg-congress-dialog').close());
    document.getElementById('cg-congress-form')?.addEventListener('submit',async e=>{
      e.preventDefault();
      try{
        await createCongress({name:gv('cg-name'),scope:gv('cg-scope'),venue:gv('cg-venue')||null,city:gv('cg-city')||null,country:gv('cg-country')||null,start_date:gv('cg-start'),end_date:gv('cg-end')||null,website:gv('cg-website')||null,notes:gv('cg-notes')||null});
        document.getElementById('cg-congress-dialog').close();
        congresses=await listCongresses();
        render();
      }catch(err){msg(err.message,true)}
    });

    // New news
    document.getElementById('cg-new-news')?.addEventListener('click',()=>document.getElementById('cg-news-dialog').showModal());
    document.getElementById('cg-n-cancel')?.addEventListener('click',()=>document.getElementById('cg-news-dialog').close());
    document.getElementById('cg-news-form')?.addEventListener('submit',async e=>{
      e.preventDefault();
      try{
        await createNews({title:gv('cg-n-title'),source:gv('cg-n-source'),url:gv('cg-n-url')||null,summary:gv('cg-n-summary'),category:gv('cg-n-category'),published_at:gv('cg-n-date')});
        document.getElementById('cg-news-dialog').close();
        news=await listNews();
        render();
      }catch(err){msg(err.message,true)}
    });

    // Congress detail
    root.querySelectorAll('[data-cg-detail]').forEach(tr=>tr.onclick=()=>openDetail(tr.dataset.cgDetail));
  }

  async function openDetail(congressId){
    const c=congresses.find(x=>x.id===congressId);
    if(!c)return;
    const dialog=document.getElementById('cg-detail-dialog');
    const body=document.getElementById('cg-detail-body');
    body.innerHTML='<div class="status info">Cargando asistentes…</div>';
    dialog.showModal();

    try{
      const att=await listAttendance(congressId);
      body.innerHTML=`
        <h3>${esc(c.name)}</h3>
        <div class="muted">${esc(c.start_date||'')}${c.end_date?' → '+esc(c.end_date):''} · <span class="status ${c.scope==='INTERNACIONAL'?'ok':'info'}">${esc(c.scope)}</span></div>
        <p>${esc([c.venue,c.city,c.country].filter(Boolean).join(', '))}</p>
        ${c.website?`<p><a href="${esc(c.website)}" target="_blank" rel="noopener">Sitio web →</a></p>`:''}
        ${c.notes?`<p class="muted">${esc(c.notes)}</p>`:''}

        <h4 style="margin-top:1rem">Asistentes registrados (${att.length})</h4>
        <div class="table-wrap"><table class="data-table">
          <thead><tr><th>Médico</th><th>Especialidad</th><th>Rol</th><th>Presentación</th></tr></thead>
          <tbody>${att.length?att.map(a=>`<tr>
            <td>${esc(a.medical_referrers?.full_name||'—')}</td>
            <td>${esc(a.medical_referrers?.specialty||'—')}</td>
            <td><span class="status ${a.role==='EXPOSITOR'?'ok':a.role==='ORGANIZADOR'?'warn':'info'}">${esc(a.role)}</span></td>
            <td>${esc(a.presentation_title||'—')}</td>
          </tr>`).join(''):'<tr><td colspan="4" class="muted">Sin asistentes registrados.</td></tr>'}</tbody>
        </table></div>

        <h4 style="margin-top:1rem">Registrar asistente</h4>
        <form id="cg-att-form" class="filter-grid">
          <label>Médico<select id="cg-att-ref" required><option value="">Seleccionar…</option>${referrers.map(r=>`<option value="${esc(r.id)}">${esc(r.full_name)}${r.specialty?' · '+esc(r.specialty):''}</option>`).join('')}</select></label>
          <label>Rol<select id="cg-att-role" required><option>PARTICIPANTE</option><option>EXPOSITOR</option><option>ORGANIZADOR</option></select></label>
          <label>Título presentación<input id="cg-att-title" placeholder="Solo si es expositor"></label>
          <button type="submit">Agregar</button>
        </form>
        <div id="cg-att-msg"></div>

        <div class="dialog-actions" style="margin-top:1rem"><button type="button" id="cg-detail-close" class="secondary">Cerrar</button></div>`;

      document.getElementById('cg-detail-close').onclick=()=>dialog.close();
      document.getElementById('cg-att-form').onsubmit=async ev=>{
        ev.preventDefault();
        try{
          await createAttendance({congress_id:congressId,referrer_id:gv('cg-att-ref'),role:gv('cg-att-role'),presentation_title:gv('cg-att-title')||null});
          openDetail(congressId);
        }catch(err){document.getElementById('cg-att-msg').innerHTML=`<div class="status bad">${esc(err.message)}</div>`}
      };
    }catch(err){
      body.innerHTML=`<div class="status bad">${esc(err.message)}</div><div class="dialog-actions"><button type="button" id="cg-detail-close" class="secondary">Cerrar</button></div>`;
      document.getElementById('cg-detail-close').onclick=()=>dialog.close();
    }
  }

  function gv(id){return document.getElementById(id).value.trim()}
  function msg(text,bad=false){document.getElementById('cg-msg').innerHTML=`<div class="status ${bad?'bad':'ok'}">${esc(text)}</div>`}

  try{
    await loadAll();
    render();
  }catch(e){
    root.innerHTML=`<section class="card"><div class="status warn">${esc(e.message)}</div></section>`;
  }
}
