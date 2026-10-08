import { getSupabase } from './supabase.js';

function esc(v=''){
  return String(v ?? '').replace(/[&<>"']/g,c=>({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

async function safeRows(label,fn){
  try{
    const r=await fn();
    if(r?.error) throw r.error;
    return {label,ok:true,data:r?.data||[]};
  }catch(e){
    return {label,ok:false,data:[],error:e?.message||String(e)};
  }
}

async function safeCount(label,fn){
  try{
    const r=await fn();
    if(r?.error) throw r.error;
    return {label,ok:true,count:Number(r?.count||0)};
  }catch(e){
    return {label,ok:false,count:0,error:e?.message||String(e)};
  }
}

async function loadVersion(){
  try{
    const url=new URL('../VERSION.json',import.meta.url);
    const r=await fetch(url,{cache:'no-store'});
    if(!r.ok) throw new Error(`VERSION.json HTTP ${r.status}`);
    return await r.json();
  }catch(e){
    console.warn('[HEMOCURA_VERSION]',e);
    return {version:'desconocida',stage:'No disponible',clinical_core:'NO DECLARADO'};
  }
}

function localDateISO(date=new Date()){
  const y=date.getFullYear();
  const m=String(date.getMonth()+1).padStart(2,'0');
  const d=String(date.getDate()).padStart(2,'0');
  return `${y}-${m}-${d}`;
}

function openCount(rows=[]){
  const closed=new Set(['CERRADO','CERRADA','CLOSED','CANCELADO','CANCELADA','COMPLETADO','COMPLETADA']);
  return rows.filter(r=>!closed.has(String(r.status||'').trim().toUpperCase())).length;
}

function kpi(label,value,detail=''){
  return `<section class="card ops-kpi-card">
    <div class="muted">${esc(label)}</div>
    <div class="kpi">${esc(value)}</div>
    ${detail?`<small class="muted">${esc(detail)}</small>`:''}
  </section>`;
}

function action(route,title,detail){
  return `<a class="ops-action" href="#${esc(route)}">
    <strong>${esc(title)}</strong>
    <span>${esc(detail)}</span>
  </a>`;
}

function coreItem(label,status,tone='warn'){
  return `<div class="ops-core-item">
    <span>${esc(label)}</span>
    <strong class="state-pill state-${tone}">${esc(status)}</strong>
  </div>`;
}

export async function mountOpsDashboard(root){
  if(!root) throw new Error('ops-dashboard-root no disponible');
  const sb=getSupabase();

  root.innerHTML='<section class="card"><div class="status info">Cargando centro de operaciones…</div></section>';

  const today=localDateISO();
  const [version,dispatches,incidents,nc,capa]=await Promise.all([
    loadVersion(),
    safeCount('Despachos',()=>sb.from('dispatches').select('id',{count:'exact',head:true}).eq('dispatch_date',today)),
    safeCount('Incidencias',()=>sb.from('incidents').select('id',{count:'exact',head:true}).eq('requires_quality_followup',true)),
    safeRows('No conformidades',()=>sb.from('nonconformities').select('id,status').limit(200)),
    safeRows('CAPA',()=>sb.from('capa').select('id,status').limit(200))
  ]);

  const failures=[dispatches,incidents,nc,capa].filter(x=>!x.ok);

  root.innerHTML=`
    <section class="ops-hero">
      <div>
        <div class="eyebrow">HemoCura Operations</div>
        <h2 class="section-heading">Centro de Operaciones</h2>
        <div class="muted">${esc(version.stage||'Estado operativo')}</div>
      </div>
      <div class="ops-version">
        <span>Versión</span>
        <strong>${esc(version.version||'desconocida')}</strong>
      </div>
    </section>

    ${failures.length?`
      <div class="status warn">
        <strong>Carga parcial. Los indicadores afectados no están disponibles.</strong>
        ${esc(failures.map(x=>`${x.label}: ${x.error}`).join(' · '))}
      </div>`:''}

    <div class="sales-toolbar"><span class="muted">Consultado: ${esc(new Date().toLocaleString('es-DO',{timeZone:'America/Santo_Domingo'}))} · Datos visibles según permisos</span><button id="ops-retry" class="secondary">Actualizar datos</button></div>
    <section class="ops-section">
      <div class="ops-section-head"><div><div class="eyebrow">Ahora</div><h3>Estado operativo</h3></div></div>
      <div class="ops-kpi-grid">
        ${kpi('Despachos de hoy',dispatches.ok?dispatches.count:'No disponible',today)}
        ${kpi('Incidencias con seguimiento',incidents.ok?incidents.count:'No disponible','Incidencias que requieren revisión de Calidad')}
        ${kpi('NC activas',nc.ok?openCount(nc.data):'No disponible',nc.ok?'Hasta 200 registros visibles':'Consulta fallida')}
        ${kpi('CAPA activas',capa.ok?openCount(capa.data):'No disponible',capa.ok?'Hasta 200 registros visibles':'Consulta fallida')}
      </div>
    </section>

    <section class="ops-section">
      <div class="ops-section-head"><div><div class="eyebrow">Acciones</div><h3>Ir a lo importante</h3></div></div>
      <div class="ops-actions">
        ${action('command','Centro de Mando','Cierre diario y gestión por excepciones')}
        ${action('quality','SGC','Incidencias, NC, CAPA y alertas')}
        ${action('coldchain','Cadena de Frío','Temperatura, transporte y excursiones')}
        ${action('bi','Inteligencia de Negocios','Indicadores y análisis operativo')}
        ${action('diagnostics','Diagnóstico','Configuración, Auth, RLS y dependencias')}
        ${action('releasegate','Release Gate','Validación antes de promover')}
      </div>
    </section>

    <section class="card ops-core">
      <div class="ops-section-head">
        <div><div class="eyebrow">Guardrail clínico</div><h3>Clinical Core</h3></div>
        <strong class="state-pill state-info">${esc(version.clinical_core||'NO DECLARADO')}</strong>
      </div>
      <div class="ops-core-grid">
        ${coreItem('FEFO por unidad','SHADOW / BLOCKED')}
        ${coreItem('Bloqueo térmico','SHADOW / BLOCKED')}
        ${coreItem('Trazabilidad donante → receptor','SHADOW / BLOCKED')}
        ${coreItem('Decisión clínica automática','NO PERMITIDA','ok')}
      </div>
      <p class="muted ops-note">El estado operativo no sustituye verificación clínica, UAT, RLS ni liberación humana autorizada.</p>
    </section>`;
  root.querySelector('#ops-retry').onclick=()=>mountOpsDashboard(root);
}
