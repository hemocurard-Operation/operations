import {
  loadPlanningWorkspace,
  getPlanLines,
  refreshForecasts,
  createOperationalPlan,
  addPlanLine
} from './planning-data.js';
import { getBranches } from './sales-data.js';

const num = new Intl.NumberFormat('es-DO', { maximumFractionDigits:2 });
const money = new Intl.NumberFormat('es-DO', { style:'currency', currency:'DOP', maximumFractionDigits:0 });

function esc(v='') {
  return String(v ?? '').replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

function todayISO(){ return new Date().toISOString().slice(0,10); }
function daysAgoISO(days=30){ const d=new Date(); d.setDate(d.getDate()-days); return d.toISOString().slice(0,10); }
function daysForwardISO(days=30){ const d=new Date(); d.setDate(d.getDate()+days); return d.toISOString().slice(0,10); }

function planStatus(status='') {
  const s=String(status).toUpperCase();
  const cls=s==='APPROVED'||s==='CLOSED' ? 'stock-ok' : 'stock-warning';
  return `<span class="stock-pill ${cls}">${esc(status)}</span>`;
}

function attainmentStatus(status='') {
  const s=String(status).toUpperCase();
  if(s==='GREEN') return '<span class="plan-dot plan-green">GREEN</span>';
  if(s==='YELLOW') return '<span class="plan-dot plan-yellow">YELLOW</span>';
  if(s==='RED') return '<span class="plan-dot plan-red">RED</span>';
  return '<span class="plan-dot plan-na">N/A</span>';
}

function formatMetric(metric, value) {
  const n=Number(value || 0);
  if(['REVENUE','TOTAL_COST','GROSS_MARGIN'].includes(metric)) return money.format(n);
  return num.format(n);
}

function planRows(rows, branchMap) {
  if(!rows.length) return `<tr><td colspan="7" class="muted">No hay planes visibles.</td></tr>`;
  return rows.map(p=>`
    <tr>
      <td>${esc(branchMap[p.branch_id]?.name || p.branch_id)}</td>
      <td>${esc(p.period_start)}</td>
      <td>${esc(p.period_end)}</td>
      <td>${esc(p.period_type)}</td>
      <td>${planStatus(p.status)}</td>
      <td>${esc(p.notes || '')}</td>
      <td><button class="secondary compact" data-plan-id="${esc(p.id)}">Ver líneas</button></td>
    </tr>`).join('');
}

function planVsActualRows(rows) {
  if(!rows.length) return `<tr><td colspan="10" class="muted">No hay Plan vs Real visible.</td></tr>`;
  return rows.map(r=>`
    <tr>
      <td>${esc(r.branch)}</td>
      <td>${esc(r.period_start)} → ${esc(r.period_end)}</td>
      <td>${esc(r.product_name || 'General')}</td>
      <td>${esc(r.metric_code)}</td>
      <td class="num">${formatMetric(r.metric_code,r.target_value)}</td>
      <td class="num">${r.actual_value == null ? '—' : formatMetric(r.metric_code,r.actual_value)}</td>
      <td class="num">${r.attainment_pct == null ? '—' : num.format(Number(r.attainment_pct))+'%'}</td>
      <td>${attainmentStatus(r.status)}</td>
      <td class="num">${num.format(Number(r.warning_threshold_pct||90))}%</td>
      <td class="num">${num.format(Number(r.critical_threshold_pct||80))}%</td>
    </tr>`).join('');
}

function forecastRows(rows, branchMap) {
  if(!rows.length) return `<tr><td colspan="9" class="muted">No hay forecast para el filtro seleccionado.</td></tr>`;
  return rows.map(r=>`
    <tr>
      <td>${esc(r.forecast_date)}</td>
      <td>${esc(branchMap[r.branch_id]?.name || r.branch_id)}</td>
      <td>${esc(r.product_id || 'General')}</td>
      <td>${esc(r.metric_code)}</td>
      <td>${esc(r.horizon_days)} días</td>
      <td class="num">${formatMetric(r.metric_code,r.forecast_value)}</td>
      <td>${esc(r.method)}</td>
      <td>${esc(r.source_days)} días</td>
      <td>${esc(r.confidence_note || '')}</td>
    </tr>`).join('');
}

function lineRows(rows) {
  if(!rows.length) return `<tr><td colspan="6" class="muted">El plan no tiene líneas.</td></tr>`;
  return rows.map(r=>`
    <tr>
      <td>${esc(r.product_id || 'General')}</td>
      <td>${esc(r.metric_code)}</td>
      <td class="num">${formatMetric(r.metric_code,r.target_value)}</td>
      <td class="num">${num.format(Number(r.warning_threshold_pct||90))}%</td>
      <td class="num">${num.format(Number(r.critical_threshold_pct||80))}%</td>
      <td>${esc(r.created_at ? new Date(r.created_at).toLocaleString('es-DO') : '')}</td>
    </tr>`).join('');
}

function summarize(rows) {
  let green=0,yellow=0,red=0,na=0;
  for(const r of rows){
    const s=String(r.status).toUpperCase();
    if(s==='GREEN') green++;
    else if(s==='YELLOW') yellow++;
    else if(s==='RED') red++;
    else na++;
  }
  return {green,yellow,red,na};
}

export async function mountPlanning(root) {
  if(!root) return;

  root.innerHTML=`<section class="card"><h3>Planificación</h3><div class="status info">Cargando Plan vs Real y forecast…</div></section>`;

  try {
    const branches=await getBranches();
    const branchMap=Object.fromEntries(branches.map(b=>[b.id,b]));
    const state={workspace:null};

    root.innerHTML=`
      <div class="sales-toolbar">
        <div>
          <h2 class="section-heading">Planificación operativa</h2>
          <div class="muted">Plan vs Real + Forecast 7/15/30 días.</div>
        </div>
        <span class="shadow-badge">FORECAST · SHADOW</span>
      </div>

      <section class="card filters-card">
        <div class="filter-grid">
          <label>Sucursal
            <select id="plan-branch">
              <option value="">Todas las autorizadas</option>
              ${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}
            </select>
          </label>
          <label>Desde<input id="plan-from" type="date" value="${daysAgoISO(30)}"></label>
          <label>Hasta<input id="plan-to" type="date" value="${daysForwardISO(30)}"></label>
          <label>Horizonte forecast
            <select id="forecast-horizon">
              <option value="">7 / 15 / 30</option>
              <option value="7">7 días</option>
              <option value="15">15 días</option>
              <option value="30">30 días</option>
            </select>
          </label>
        </div>
        <div class="toolbar-row">
          <button id="plan-search">Aplicar filtros</button>
          <button id="forecast-refresh" class="secondary">Actualizar forecast</button>
          <button id="new-plan" class="secondary">Nuevo plan</button>
        </div>
      </section>

      <div class="status warn">
        El forecast es una proyección simple basada en media móvil y stock actual.
        No debe usarse para liberación clínica, FEFO ni decisiones transfusionales automáticas.
      </div>

      <div id="planning-errors"></div>
      <div id="planning-summary"></div>

      <section class="card">
        <div class="card-head"><h3>Plan vs Real</h3><span id="pva-count" class="muted"></span></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr>
              <th>Sucursal</th><th>Período</th><th>Producto</th><th>Métrica</th>
              <th>Meta</th><th>Real</th><th>Cumplimiento</th><th>Semáforo</th>
              <th>Warning</th><th>Critical</th>
            </tr></thead>
            <tbody id="pva-body"></tbody>
          </table>
        </div>
      </section>

      <section class="card">
        <div class="card-head"><h3>Planes operativos</h3><span class="muted">DRAFT · APPROVED · CLOSED</span></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Sucursal</th><th>Inicio</th><th>Fin</th><th>Tipo</th><th>Estado</th><th>Notas</th><th></th></tr></thead>
            <tbody id="plans-body"></tbody>
          </table>
        </div>
      </section>

      <section class="card hidden" id="plan-lines-card">
        <div class="card-head">
          <div><h3>Líneas del plan</h3><div id="plan-lines-meta" class="muted"></div></div>
          <button id="plan-lines-close" class="secondary">Cerrar</button>
        </div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Producto</th><th>Métrica</th><th>Meta</th><th>Warning</th><th>Critical</th><th>Creada</th></tr></thead>
            <tbody id="plan-lines-body"></tbody>
          </table>
        </div>
      </section>

      <section class="card">
        <div class="card-head"><h3>Forecast</h3><span class="muted">Snapshots 7 / 15 / 30 días</span></div>
        <div class="table-wrap">
          <table class="data-table">
            <thead><tr><th>Fecha</th><th>Sucursal</th><th>Producto</th><th>Métrica</th><th>Horizonte</th><th>Pronóstico</th><th>Método</th><th>Fuente</th><th>Nota</th></tr></thead>
            <tbody id="forecast-body"></tbody>
          </table>
        </div>
      </section>

      <dialog id="plan-dialog" class="sales-dialog">
        <form id="plan-form" method="dialog">
          <h3>Nuevo plan operativo</h3>
          <label>Sucursal
            <select id="new-plan-branch" required>
              <option value="">Seleccione</option>
              ${branches.map(b=>`<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('')}
            </select>
          </label>
          <label>Inicio<input id="new-plan-start" type="date" required></label>
          <label>Fin<input id="new-plan-end" type="date" required></label>
          <label>Tipo
            <select id="new-plan-type" required>
              <option value="DAILY">DAILY</option>
              <option value="WEEKLY">WEEKLY</option>
              <option value="MONTHLY">MONTHLY</option>
            </select>
          </label>
          <label>Notas<textarea id="new-plan-notes"></textarea></label>

          <hr>
          <h4>Primera línea del plan</h4>
          <label>Métrica
            <select id="new-plan-metric" required>
              <option>UNITS_SOLD</option>
              <option>REVENUE</option>
              <option>TOTAL_COST</option>
              <option>GROSS_MARGIN</option>
              <option>DONORS_PRESENTED</option>
              <option>DONORS_EFFECTIVE</option>
              <option>UNITS_PRODUCED</option>
              <option>ENDING_INVENTORY</option>
            </select>
          </label>
          <label>Meta<input id="new-plan-target" type="number" step="0.01" required></label>
          <label>Warning %<input id="new-plan-warning" type="number" value="90" min="0" max="100" required></label>
          <label>Critical %<input id="new-plan-critical" type="number" value="80" min="0" max="100" required></label>

          <div id="new-plan-status"></div>
          <div class="dialog-actions">
            <button type="button" id="new-plan-cancel" class="secondary">Cancelar</button>
            <button type="submit">Crear plan</button>
          </div>
        </form>
      </dialog>

      <div class="debug-strip">[HEMOCURA_PLANNING] listo · FORECAST_SHADOW</div>`;

    async function load() {
      const filters={
        branchId:document.getElementById('plan-branch').value,
        from:document.getElementById('plan-from').value,
        to:document.getElementById('plan-to').value,
        forecastDate:todayISO(),
        horizonDays:document.getElementById('forecast-horizon').value
      };

      const ws=await loadPlanningWorkspace(filters);
      state.workspace=ws;

      document.getElementById('plans-body').innerHTML=planRows(ws.plans,branchMap);
      document.getElementById('pva-body').innerHTML=planVsActualRows(ws.planVsActual);
      document.getElementById('forecast-body').innerHTML=forecastRows(ws.forecasts,branchMap);
      document.getElementById('pva-count').textContent=`${ws.planVsActual.length} línea(s)`;

      const s=summarize(ws.planVsActual);
      document.getElementById('planning-summary').innerHTML=`
        <div class="grid sales-kpis">
          <section class="card"><div class="muted">En meta</div><div class="kpi">${num.format(s.green)}</div></section>
          <section class="card"><div class="muted">Advertencia</div><div class="kpi">${num.format(s.yellow)}</div></section>
          <section class="card"><div class="muted">Crítico</div><div class="kpi">${num.format(s.red)}</div></section>
          <section class="card"><div class="muted">Sin dato / N.A.</div><div class="kpi">${num.format(s.na)}</div></section>
        </div>`;

      document.getElementById('planning-errors').innerHTML=ws.errors.length
        ? `<div class="status warn">Carga parcial: ${esc(ws.errors.join(' · '))}</div>`
        : '';

      document.querySelectorAll('[data-plan-id]').forEach(btn=>{
        btn.addEventListener('click',()=>openPlan(btn.dataset.planId));
      });

      console.info('[HEMOCURA_PLANNING] módulo OK');
    }

    async function openPlan(planId) {
      const p=state.workspace?.plans?.find(x=>x.id===planId);
      document.getElementById('plan-lines-card').classList.remove('hidden');
      document.getElementById('plan-lines-meta').textContent=p
        ? `${branchMap[p.branch_id]?.name || p.branch_id} · ${p.period_start} → ${p.period_end} · ${p.status}`
        : planId;
      document.getElementById('plan-lines-body').innerHTML=`<tr><td colspan="6">Cargando…</td></tr>`;

      try {
        const rows=await getPlanLines(planId);
        document.getElementById('plan-lines-body').innerHTML=lineRows(rows);
      } catch(error) {
        document.getElementById('plan-lines-body').innerHTML=
          `<tr><td colspan="6"><div class="status bad">${esc(error.message)}</div></td></tr>`;
      }
    }

    document.getElementById('plan-search').addEventListener('click',()=>load().catch(showError));

    document.getElementById('forecast-refresh').addEventListener('click', async ()=>{
      const btn=document.getElementById('forecast-refresh');
      const old=btn.textContent;
      btn.disabled=true;
      btn.textContent='Actualizando…';
      try {
        await refreshForecasts(todayISO());
        await load();
        console.info('[HEMOCURA_FORECAST_REFRESH] OK');
      } catch(error) {
        showError(error);
      } finally {
        btn.disabled=false;
        btn.textContent=old;
      }
    });

    document.getElementById('plan-lines-close').addEventListener('click',()=>{
      document.getElementById('plan-lines-card').classList.add('hidden');
    });

    document.getElementById('new-plan').addEventListener('click',()=>{
      document.getElementById('plan-form').reset();
      document.getElementById('new-plan-start').value=todayISO();
      document.getElementById('new-plan-end').value=daysForwardISO(30);
      document.getElementById('new-plan-warning').value=90;
      document.getElementById('new-plan-critical').value=80;
      document.getElementById('new-plan-status').innerHTML='';
      document.getElementById('plan-dialog').showModal();
    });

    document.getElementById('new-plan-cancel').addEventListener('click',()=>{
      document.getElementById('plan-dialog').close();
    });

    document.getElementById('plan-form').addEventListener('submit',async e=>{
      e.preventDefault();
      const box=document.getElementById('new-plan-status');
      box.innerHTML=`<div class="status info">Creando plan…</div>`;

      try {
        const plan=await createOperationalPlan({
          branchId:document.getElementById('new-plan-branch').value,
          periodStart:document.getElementById('new-plan-start').value,
          periodEnd:document.getElementById('new-plan-end').value,
          periodType:document.getElementById('new-plan-type').value,
          notes:document.getElementById('new-plan-notes').value.trim()
        });

        await addPlanLine({
          planId:plan.id,
          metricCode:document.getElementById('new-plan-metric').value,
          targetValue:document.getElementById('new-plan-target').value,
          warningPct:document.getElementById('new-plan-warning').value,
          criticalPct:document.getElementById('new-plan-critical').value
        });

        box.innerHTML=`<div class="status ok">Plan creado en DRAFT.</div>`;
        await load();
        setTimeout(()=>document.getElementById('plan-dialog').close(),450);
      } catch(error) {
        box.innerHTML=`<div class="status bad">${esc(error.message)}</div>`;
      }
    });

    function showError(error) {
      console.error('[HEMOCURA_PLANNING_ERROR]',error);
      document.getElementById('planning-errors').innerHTML=
        `<div class="status bad">${esc(error.message)}</div>`;
    }

    await load();

  } catch(error) {
    console.error('[HEMOCURA_PLANNING_ERROR]',error);
    root.innerHTML=`
      <section class="card">
        <h3>Planificación no disponible</h3>
        <div class="status bad">${esc(error.message)}</div>
        <p>Abra F12 → Console y busque <code>HEMOCURA_PLANNING_ERROR</code>.</p>
      </section>`;
  }
}
