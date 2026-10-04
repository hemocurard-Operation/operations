import { getSupabase } from './supabase.js';
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
async function safe(label,fn){try{const r=await fn();if(r?.error)throw r.error;return{label,ok:true,data:r?.data||[]}}catch(e){return{label,ok:false,data:[],error:e.message}}}
export async function mountOpsDashboard(root){
  const sb=getSupabase();
  root.innerHTML='<section class="card"><div class="status info">Cargando centro de operaciones…</div></section>';
  const [dispatches,incidents,nc,capa]=await Promise.all([
    safe('Despachos',()=>sb.from('dispatches').select('id,status,dispatch_date').order('dispatch_date',{ascending:false}).limit(100)),
    safe('Incidencias',()=>sb.from('incidents').select('id,status').limit(100)),
    safe('No conformidades',()=>sb.from('nonconformities').select('id,status').limit(100)),
    safe('CAPA',()=>sb.from('capa').select('id,status').limit(100))
  ]);
  const fs=[dispatches,incidents,nc,capa].filter(x=>!x.ok);
  const open=rows=>rows.filter(r=>!['CERRADO','CERRADA','CLOSED','CANCELADO'].includes(String(r.status||'').toUpperCase())).length;
  root.innerHTML=`
    <div class="sales-toolbar"><div><h2 class="section-heading">Centro de Operaciones · SGC · Compliance</h2>
    <div class="muted">CRM y prospección quedan fuera. Ventas se conserva solo como control operativo de salidas/facturación.</div></div>
    <span class="shadow-badge">v0.21.0</span></div>
    ${fs.length?`<div class="status warn">Carga parcial: ${esc(fs.map(x=>`${x.label}: ${x.error}`).join(' · '))}</div>`:''}
    <div class="grid sales-kpis">
      <section class="card"><div class="muted">Despachos recientes</div><div class="kpi">${dispatches.data.length}</div></section>
      <section class="card"><div class="muted">Incidencias abiertas</div><div class="kpi">${open(incidents.data)}</div></section>
      <section class="card"><div class="muted">NC abiertas</div><div class="kpi">${open(nc.data)}</div></section>
      <section class="card"><div class="muted">CAPA abiertas</div><div class="kpi">${open(capa.data)}</div></section>
    </div>
    <div class="scope-grid">
      <a class="scope-card" href="#sales"><strong>Ventas / Salidas</strong><span>Despachos, facturación y cobranza</span></a><a class="scope-card" href="#donors"><strong>Donantes</strong><span>Origen del inventario sanguíneo</span></a><a class="scope-card" href="#screening"><strong>Tamizaje</strong><span>Pruebas y trazabilidad</span></a><a class="scope-card" href="#bloodflow"><strong>Flujo Sanguíneo</strong><span>Trazabilidad y liberación</span></a><a class="scope-card" href="#bloodinventory"><strong>Inventario Sangre</strong><span>Disponibilidad por componente</span></a>
      <a class="scope-card" href="#requisitions"><strong>Requisiciones</strong><span>Insumos y abastecimiento</span></a>
      <a class="scope-card" href="#inspections"><strong>Inspecciones</strong><span>Cumplimiento por sucursal</span></a>
      <a class="scope-card" href="#quality"><strong>SGC</strong><span>Incidencias · NC · CAPA</span></a>
      <a class="scope-card" href="#documents"><strong>Documentos</strong><span>Fuente única y arquitectura</span></a>
      <a class="scope-card" href="#compliance"><strong>Compliance</strong><span>Riesgos y programa penal</span></a>
    </div>
    <section class="card"><div class="status warn">Clinical Core: FEFO por unidad, bloqueo térmico y trazabilidad donante→receptor siguen SHADOW/BLOCKED.</div></section>`;
}
